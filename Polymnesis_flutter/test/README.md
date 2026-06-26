# Suite de tests — PolyMnesis

Couverture de tests **unitaires**, **widgets** et **d'intégration** de l'application
PolyMnesis (flashcards à répétition espacée — système Leitner).

- **211 tests** au total : 207 tests `flutter test` (unitaires + widgets) + 4 scénarios
  d'intégration end-to-end sur device.
- **~88,6 % de couverture de lignes** sur `lib/` (suite unitaire/widget seule ; le
  test d'intégration ajoute de la couverture réelle on-device).

---

## Lancer les tests

```bash
# 1) Tests unitaires + widgets (headless, rapide)
flutter test

# avec rapport de couverture -> coverage/lcov.info
flutter test --coverage

# un seul fichier
flutter test test/providers/card_provider_test.dart

# 2) Test d'intégration end-to-end (nécessite un device/desktop)
flutter test integration_test/app_test.dart -d linux
#   (ou -d <android-emulator-id>, -d macos, etc. ; en CI : un device configuré)
```

> Le dossier `integration_test/` est routé par l'outillage Flutter vers un **device**
> réel (et non le VM de test headless). En local on l'exécute sur le bureau Linux ;
> en CI, sur un émulateur/simulateur.

---

## Structure

```
test/
├── helpers/
│   └── test_helpers.dart        # Infrastructure partagée (voir plus bas)
├── models/                      # Tests unitaires purs (aucun binding lourd)
│   ├── card_model_test.dart         # FlashCard + FlashCardTheme (JSON, copyWith, égalité)
│   ├── game_model_test.dart         # GameState, GameConfig
│   ├── leitner_settings_test.dart   # intervalles, getIntervalDays, computeNextReview…
│   └── sync_credentials_test.dart   # isConfigured, JSON, copyWith
├── services/
│   ├── storage_service_test.dart    # SharedPreferences : round-trips, JSON corrompu, clés
│   ├── supabase_service_test.dart   # logique de garde uniquement (pas de réseau)
│   └── notification_service_test.dart # surface testable (no-op via fausse plateforme)
├── providers/
│   └── card_provider_test.dart      # CŒUR MÉTIER : CRUD, filtres, jeu, Leitner, sync off
├── widgets/
│   ├── app_button_test.dart         # variantes, état désactivé/chargement
│   ├── theme_badge_test.dart        # rendu par thème, fontSize
│   └── settings_modal_test.dart     # rendu, aide SQL, sauvegarde, clamp d'intervalle
├── screens/
│   ├── home_screen_test.dart        # accueil, compteur quotidien, navigation
│   ├── create_screen_test.dart      # création/édition, validations, triggers
│   ├── collection_screen_test.dart  # recherche, filtres thème/boîte, suppression
│   ├── game_screen_test.dart        # jeu libre : setup, cas vide, score
│   ├── daily_game_screen_test.dart  # jeu quotidien Leitner : ready/playing/résultats/échec
│   └── main_screen_test.dart        # coquille de nav, splash, paramètres, édition
├── theme/
│   └── app_theme_test.dart          # ThemeData sombre + palette
└── README.md                    # ce fichier

integration_test/
└── app_test.dart                # 4 scénarios end-to-end (boot, créer, jouer, rejouer)
```

---

## Infrastructure partagée — `test/helpers/test_helpers.dart`

| Fonction / classe | Rôle |
|---|---|
| `buildCard({id, theme, answer, triggers, createdAt, leitnerBox, nextReviewAt})` | Fabrique une `FlashCard` ; par défaut « due » (`nextReviewAt == createdAt == 1000`). |
| `daysFromNowMillis(days)` | `now + days` en millis. `-1` ⇒ carte due, `5` ⇒ non due. |
| `seedPrefs({cards, syncCreds, leitnerSettings})` | Pré-remplit le mock SharedPreferences. |
| `readRawPref(key)` | Lit la valeur brute stockée (vérification des clés). |
| `installFakeNotifications()` | Installe une **fausse plateforme** `flutter_local_notifications` (no-op). |
| `FakeNotificationsPlatform` | Implémentation no-op du plugin (utilisée ci-dessus). |
| `makeInitializedProvider()` | `CardProvider()..initialize()` (après `seedPrefs`). |
| `wrapWithProvider(child, {provider})` | Enveloppe un widget dans `MaterialApp + Scaffold + ChangeNotifierProvider`. |

Clés de stockage exposées : `kCardsKey`, `kSyncCredsKey`, `kLeitnerSettingsKey`.

---

## Conventions & pièges (importants)

1. **`TestWidgetsFlutterBinding.ensureInitialized()`** en tête de `main()` pour les
   fichiers à base de `test()` qui touchent prefs/channels.
2. **Notifications** : tout flux pouvant atteindre `CardProvider.markDailyCompleted`
   (fin du jeu quotidien) doit faire `setUp(() => installFakeNotifications())`, sinon
   `LateInitializationError` (le plugin résout une instance de plateforme `late`).
3. **Synchronisation toujours désactivée** : `SyncCredentials.enabled == false` par
   défaut, donc `SupabaseService` n'est jamais appelé (aucun réseau en test).
4. **Le provider réinjecte les 4 cartes par défaut** quand le stockage est vide
   (`CardProvider.initialize`). Pour obtenir réellement 0 carte, on supprime les
   cartes après init (cf. `game_screen_test.dart`, cas vide).
5. **`DateTime.now()` est l'horloge réelle** — ni `tester.pump()` ni `fakeAsync` ne la
   contrôlent. Conséquences :
   - on rend une carte due/non-due via `nextReviewAt` (passé/futur) ;
   - le **bonus « réponse rapide < 5 s »** du jeu quotidien se base sur le temps réel
     écoulé (~0 s dans un test classique) ⇒ par défaut c'est le chemin **rapide (+2)**
     qui se déclenche. Le chemin **lent (+1)** est testé via `tester.runAsync` qui laisse
     s'écouler ~6 s de temps **réel** (hors zone FakeAsync), franchissant le seuil lu par
     `DateTime.now()` — voir le groupe « chemin lent » de `daily_game_screen_test.dart`
     (test volontairement lent).
6. **Timer périodique** : la vue *playing* du jeu quotidien lance un
   `Timer.periodic(1 s)`. `pumpAndSettle()` ne se stabilise jamais avec un timer actif
   ⇒ en état *playing* on utilise `tester.pump(Duration)` explicite, et on **pilote
   toujours le flux jusqu'aux résultats** (le `_PlayingView` est alors disposé, timer
   annulé) pour ne laisser aucun timer pendant.
7. **`RichText`** : les scores de fin (`'1 / 1'`) sont rendus via `RichText`. Utiliser
   `find.text('1 / 1', findRichText: true)` (et non `find.text`/`textContaining`).
8. **Membres privés** (`_PlayingView`, `_normalize`, …) non importables : on teste leur
   comportement via le widget public ou l'API publique du provider.
9. **Mélange aléatoire** : `getCardsForGame` et `getDailyCards` mélangent — on n'asserte
   jamais l'ordre, seulement la longueur et l'appartenance.

---

## Couverture par fichier (suite unitaire/widget)

| Fichier | Couverture | Note |
|---|---:|---|
| `models/*`, `constants.dart`, `theme/app_theme.dart` | **100 %** | logique pure, entièrement couverte |
| `widgets/app_button`, `widgets/theme_badge`, `screens/home_screen` | **100 %** | |
| `screens/collection_screen` | 99 % | |
| `screens/create_screen` | 98 % | |
| `widgets/settings_modal` | 96 % | |
| `services/storage_service` | 91 % | |
| `screens/game_screen` | 90 % | |
| `main.dart` | 83 % | `main()` (init notifs/`runApp`) non couvert (hors device) |
| `screens/daily_game_screen` | 87 % | seuls les chemins temps-réel non déterministes restent (voir §5) |
| `providers/card_provider` | 80 % | branches de **sync Supabase** (réseau) non couvertes |
| `services/supabase_service` | 33 % | seules les **gardes** sont testables sans réseau |
| `services/notification_service` | 23 % | code **plateforme/privé** (planification, callbacks) |
| **Total `lib/`** | **~88,6 %** | |

Les zones de couverture plus basses sont **intrinsèquement** liées à la plateforme
(notifications locales, client Supabase/réseau) ou au **temps réel** (bonus de rapidité
Leitner) : elles sont validées au mieux par les gardes (sans réseau), par le test
d'intégration on-device, ou documentées comme non déterministes.

---

## Système Leitner — ce qui est couvert

Le cœur de l'app (répétition espacée) est testé à plusieurs niveaux :

- **Intervalles** (`leitner_settings_test.dart`) : `getIntervalDays` aux bornes
  (0, négatif, 1..6, 7, très grand), `computeNextReview` (fenêtre de tolérance),
  `boxLabel`.
- **Transitions de boîte** (`card_provider_test.dart`, avec des cartes semées dans
  différentes boîtes) :
  - bonne réponse **+1** (boîte 2 → 3) et **+2** « easy » (boîte 2 → 4) ;
  - **maîtrisée** par clamp à `boxCount+1` — via `+2` (6 → 7) **et** via `+1` (6 → 7),
    avec `nextReviewAt` ~ +10 ans ;
  - mauvaise réponse **−1** (4 → 3), **plancher** boîte 1 → 1, et **retour depuis
    maîtrisée** 7 → 6 ;
  - **reprogrammation de `nextReviewAt`** vérifiée pour les cas normaux (correct
    → intervalle de la nouvelle boîte ; incorrect → intervalle de la boîte reculée).
- **Sélection des dues** : `getDailyCards` ne garde que `nextReviewAt <= now` **et**
  exclut les maîtrisées ; `dailyCardCount` cohérent.
- **Planification par boîte** (`card_provider_test.dart`, test paramétré) : pour chaque
  boîte de départ, on vérifie que la période d'attente (`nextReviewAt`) correspond à
  l'intervalle de la boîte d'arrivée — bonne réponse boîtes 1→5 (3, 7, 14, 30, 90 j),
  mauvaise réponse boîtes 2→6 (1, 3, 7, 14, 30 j) — plus une **session mixte** (une
  boîte 2 et une boîte 5 réussies suivent chacune leur propre période : 7 j et 90 j).
- **Application via le jeu quotidien** (`daily_game_screen_test.dart`) : bonne réponse
  rapide **+2**, mauvaise réponse **−1** + ré-insertion en file, reprise correcte, et
  **atterrissage en douceur** (forçage **+1** au lieu de +2 près du sommet pour éviter
  le saut direct vers maîtrisé).
- **Chemin lent (> 5 s, sans bonus)** : testé **réellement** via `tester.runAsync` (vraie
  attente de ~6 s pour franchir le seuil que lit `DateTime.now()`) — réponse correcte
  tardive ⇒ **+1** seulement (boîte 1 → 2). ⚠️ Ce test est volontairement **lent (~6 s)**.

## Comportements réels notables mis en évidence par les tests

- **`LeitnerSettings`** ne copie **pas** défensivement une liste d'intervalles fournie
  (référence partagée ; seul le fallback par défaut est copié) — cf.
  `leitner_settings_test.dart`.
- **Jeu quotidien — carte ré-insérée** : une carte ratée est remise en fin de file en
  conservant **sa boîte d'avant l'échec** (l'objet de la file n'est pas muté par
  `leitnerIncorrect`, qui ne met à jour qu'une copie côté provider). Une reprise correcte
  recalcule donc à partir de cette valeur « périmée » — cf. `daily_game_screen_test.dart`,
  groupe « échec puis reprise ».

Ces points sont documentés (et non « corrigés ») : la suite teste le comportement réel
de l'application. Ils peuvent constituer des pistes d'amélioration côté code.
