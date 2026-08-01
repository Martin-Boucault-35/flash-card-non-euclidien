#!/usr/bin/env python3
"""Archive les quiz "La Table des Savoirs" dans une table Supabase dédiée.

Utilisé par .github/workflows/ltds-archive.yml :
  - sans DAYS  -> mode AUTO-RÉPARATEUR : demande à Supabase les jours déjà
                  archivés et récupère tous ceux qui MANQUENT dans la fenêtre
                  des WINDOW derniers jours (30 par défaut). Un jour joué en
                  retard est ainsi rattrapé tout seul au run suivant.
  - avec DAYS  -> archive une plage précise, ex. "1-180" (backfill initial)

L'upsert étant idempotent (PK day/level/order), rejouer un jour est sans effet.

Variables d'environnement attendues (fournies par les secrets GitHub) :
  LTDS_TOKEN                  jeton Bearer LTDS (expire ~1 mois, à renouveler à la main)
  SUPABASE_URL                https://xxxx.supabase.co
  SUPABASE_KEY                clé Supabase : `anon` (avec la policy de la table)
                              ou `service_role` (contourne RLS) — au choix
  DAYS                        (optionnel) plage de jours à archiver
  WINDOW                      (optionnel) taille de la fenêtre de rattrapage (défaut 30)

Seuls les jours que TU AS JOUÉS exposent les réponses : les autres renvoient 404
et sont simplement ignorés.
"""

import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://api.latabledessavoirs.fr"
TABLE = "ltds_questions"
LEVELS = {"abordable": "facile", "expert": "difficile"}
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36"


def fail(msg: str) -> None:
    print(f"::error::{msg}")
    sys.exit(1)


def request(url: str, *, headers: dict, data: bytes | None = None, method: str = "GET"):
    """Renvoie (status, body_bytes). Ne lève pas sur les codes HTTP d'erreur."""
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def check_token_expiry(token: str) -> None:
    """Décode le JWT (sans vérifier la signature) pour alerter avant expiration."""
    try:
        payload = token.split(".")[1]
        payload += "=" * (-len(payload) % 4)
        exp = json.loads(base64.urlsafe_b64decode(payload)).get("exp")
        if not exp:
            return
        days_left = (exp - time.time()) / 86400
        if days_left <= 0:
            fail("Le jeton LTDS a EXPIRÉ. Mets à jour le secret LTDS_TOKEN.")
        if days_left < 7:
            print(f"::warning::Le jeton LTDS expire dans {days_left:.1f} jour(s) — "
                  "pense à mettre à jour le secret LTDS_TOKEN.")
        else:
            print(f"Jeton valide encore ~{days_left:.0f} jour(s).")
    except Exception as e:  # noqa: BLE001 - purement informatif
        print(f"(info) impossible de lire l'expiration du jeton : {e}")


def parse_days(raw: str) -> list[int]:
    """'1-5,9' -> [1,2,3,4,5,9]. Trié et dédupliqué."""
    days: set[int] = set()
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            lo_s, hi_s = part.split("-", 1)
            lo, hi = int(lo_s), int(hi_s)
            if lo > hi:
                lo, hi = hi, lo
            days.update(range(lo, hi + 1))
        else:
            days.add(int(part))
    return sorted(d for d in days if d >= 1)


def current_day() -> int:
    status, body = request(f"{API}/info", headers={"User-Agent": UA, "Accept": "application/json"})
    if status != 200:
        fail(f"/info a répondu {status}.")
    return int(json.loads(body)["currentDay"])


def find_questions(node) -> list[dict]:
    """Récupère récursivement les objets ayant 'text' + 'validAnswers' non vide."""
    found: list[dict] = []

    def visit(n):
        if isinstance(n, dict):
            text = n.get("text") or n.get("question")
            valid = n.get("validAnswers")
            if isinstance(text, str) and text.strip() and isinstance(valid, list) and valid:
                found.append(n)
            for v in n.values():
                visit(v)
        elif isinstance(n, list):
            for v in n:
                visit(v)

    visit(node)
    return sorted(found, key=lambda q: q.get("order") or 0)


def fetch_day(token: str, day: int, level: str) -> list[dict]:
    """Renvoie les lignes prêtes pour Supabase. [] si le jour n'a pas été joué."""
    status, body = request(
        f"{API}/game/{LEVELS[level]}/{day}",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json",
            "User-Agent": UA,
        },
    )
    if status == 401:
        fail("401 : jeton LTDS invalide ou expiré. Mets à jour le secret LTDS_TOKEN.")
    if status == 404:
        return []  # jour non joué à ce niveau
    if status != 200:
        print(f"::warning::jour {day} ({level}) : HTTP {status}, ignoré.")
        return []

    data = json.loads(body)
    day_theme = (data.get("day") or {}).get("theme") or ""
    rows = []
    for q in find_questions(data):
        valid = [str(v).strip() for v in q["validAnswers"] if str(v).strip()]
        if not valid:
            continue
        rows.append({
            "day": day,
            "level": level,
            "order": int(q.get("order") or 0),
            "theme": (q.get("theme") or day_theme or "").strip(),
            "question": (q.get("text") or q.get("question") or "").strip(),
            "answer": valid[0],
            "valid_answers": valid,
        })
    return rows


def archived_days(supabase_url: str, service_key: str, since: int) -> set[int]:
    """Jours (>= since) ayant déjà au moins une ligne archivée."""
    status, body = request(
        f"{supabase_url}/rest/v1/{TABLE}?select=day&day=gte.{since}",
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Accept": "application/json",
        },
    )
    if status >= 300:
        fail(f"Lecture Supabase impossible ({status}) : "
             f"{body[:200].decode(errors='replace')}")
    return {int(r["day"]) for r in json.loads(body)}


def upsert(rows: list[dict], supabase_url: str, service_key: str) -> None:
    """Upsert en lot sur la clé primaire (day, level, order)."""
    if not rows:
        return
    status, body = request(
        f"{supabase_url}/rest/v1/{TABLE}?on_conflict=day,level,order",
        method="POST",
        data=json.dumps(rows).encode(),
        headers={
            "apikey": service_key,
            "Authorization": f"Bearer {service_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
    )
    if status >= 300:
        fail(f"Supabase a répondu {status} : {body[:300].decode(errors='replace')}")


def main() -> None:
    token = (os.environ.get("LTDS_TOKEN") or "").strip()
    supabase_url = (os.environ.get("SUPABASE_URL") or "").strip().rstrip("/")
    service_key = (os.environ.get("SUPABASE_KEY") or "").strip()
    if not token or not supabase_url or not service_key:
        fail("Secrets manquants : LTDS_TOKEN, SUPABASE_URL, SUPABASE_KEY.")

    check_token_expiry(token)

    raw_days = (os.environ.get("DAYS") or "").strip()
    if raw_days:
        days = parse_days(raw_days)
        print(f"Backfill : {len(days)} jour(s) demandé(s) ({days[0]}..{days[-1]}).")
    else:
        # Mode auto-réparateur : on ne prend pas QUE la veille, sinon un jour
        # joué en retard (ou un run raté) laisserait un trou définitif.
        window = int(os.environ.get("WINDOW") or 30)
        last = current_day() - 1  # la veille : quiz terminé, résultat déterministe
        start = max(1, last - window + 1)
        already = archived_days(supabase_url, service_key, start)
        days = [d for d in range(start, last + 1) if d not in already]
        print(f"Fenêtre {start}..{last} : {len(already)} jour(s) déjà archivé(s), "
              f"{len(days)} à récupérer.")
        if not days:
            print("\n✅ Rien à faire, l'archive est à jour.")
            return

    total, days_ok = 0, 0
    for day in days:
        rows: list[dict] = []
        for level in LEVELS:
            rows += fetch_day(token, day, level)
            time.sleep(0.3)  # on ménage l'API
        if rows:
            upsert(rows, supabase_url, service_key)
            total += len(rows)
            days_ok += 1
            print(f"  jour {day} : {len(rows)} question(s) archivée(s)")

    print(f"\n✅ {total} question(s) sur {days_ok}/{len(days)} jour(s) "
          f"(les jours non joués sont ignorés).")


if __name__ == "__main__":
    main()
