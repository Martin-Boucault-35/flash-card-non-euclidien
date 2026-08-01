<div align="center">

# 🧠 PolyMnesis — Mémoire Non-Euclidienne

**Des flashcards intelligentes où une réponse se cache derrière plusieurs indices,
avec répétition espacée (Leitner) et import de quiz de culture générale.**

[![CI](https://github.com/Martin-Boucault-35/flash-card-non-euclidien/actions/workflows/ci.yml/badge.svg)](https://github.com/Martin-Boucault-35/flash-card-non-euclidien/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Martin-Boucault-35/flash-card-non-euclidien?label=release)](https://github.com/Martin-Boucault-35/flash-card-non-euclidien/releases)

🌐 **Version web** : https://martin-boucault-35.github.io/flash-card-non-euclidien/
📦 **APK Android** : onglet [Releases](https://github.com/Martin-Boucault-35/flash-card-non-euclidien/releases)

</div>

---

## 💡 Le concept

Une flashcard classique, c'est *une question → une réponse*. Ici c'est l'inverse :
**une réponse ↔ plusieurs indices** (les *triggers*). Exemple :

> **Réponse :** Stromae
> **Indices :** « Paul Van Haver » · « Chanteur belge, 12 mars 1985 » · « Papaoutai »

Pendant le jeu, un indice tiré au hasard s'affiche ; si tu sèches, l'indice suivant
se dévoile. C'est plus proche de la vraie mémoire (associative, « non-euclidienne »)
qu'un simple recto/verso.

## ✨ Fonctionnalités

- 🃏 **Cartes réponse + N indices**, classées par thème (Classique, Histoire, Géographie,
  Moderne, Animaux, Sciences, Sport, Culture Générale).
- 📦 **Système de Leitner** : boîtes de révision, intervalles configurables, bonus
  « réponse rapide » (+2 boîtes) dont le seuil est réglable.
- 🎮 Deux modes : **entraînement** libre et **quotidien** (cartes dues du jour).
- ✅ **Correction tolérante** : insensible à la casse, aux accents, tirets et espaces
  (`orang-outan` = `orang outan`), plus une liste de **réponses acceptées** (variantes,
  synonymes, fautes courantes).
- 📥 **Import « La Table des Savoirs »** : récupère les questions d'un quiz joué et crée
  les cartes automatiquement (bons thèmes + réponses acceptées), directement depuis les
  paramètres de l'app.
- ☁️ **Sync Supabase** bidirectionnelle avec **déduplication** (aucun doublon, aucune perte) —
  restauration complète en saisissant simplement les identifiants.
- 🔔 **Rappels quotidiens** (notifications locales).
- 📱 **Multi-plateforme** : Android + Web (même base de code).

## 🛠️ Stack

Flutter · Provider (état) · Supabase (sync) · shared_preferences (stockage local) ·
flutter_local_notifications · GitHub Actions (CI/CD).

## 📂 Structure du dépôt

```
Polymnesis_flutter/   ← l'application (Flutter) — le projet principal
Polymnesis_react/     ← prototype web initial (React, AI Studio)
RELEASING.md          ← mémo CI/CD : versions, tags, releases, signature
.github/workflows/    ← CI (tests), Release (APK+Web), keep-alive Supabase
```

## 🚀 Démarrer (Flutter)

Prérequis : le [SDK Flutter](https://docs.flutter.dev/get-started/install) (3.41+).

```bash
cd Polymnesis_flutter
flutter pub get
flutter run          # -d <device> pour cibler un tel / chrome / linux
```

Build de production :

```bash
flutter build apk --release   # Android
flutter build web --release   # Web
```

## 🧪 Tests

```bash
cd Polymnesis_flutter
flutter analyze
flutter test          # ~270 tests (modèles, providers, écrans, sync)
```

La CI relance `analyze` + `test` sur chaque Pull Request.

## ☁️ Synchronisation

Optionnelle, via un projet **Supabase** gratuit (table `cards`). Renseigne *Project URL*
et *anon key* dans les paramètres de l'app pour activer la sync (et retrouver tes cartes
sur un autre appareil). La réconciliation fusionne local et cloud sans créer de doublon.

## 🗄️ Archive des quiz (backup)

Un workflow (`ltds-archive.yml`) archive chaque jour les quiz joués dans une table
Supabase **séparée** (`ltds_questions`) — un backup brut qui **n'alimente pas** le
système Leitner de l'app. Un run manuel permet un *backfill* sur une plage de jours.
SQL de la table : [`supabase/ltds_questions.sql`](supabase/ltds_questions.sql).

## 📦 Releases & déploiement

Chaque **PR mergée sur `main`** qui bumpe la version du `pubspec` déclenche
automatiquement : un **tag `vX.Y.Z`**, une **GitHub Release** (notes auto + APK), et le
**déploiement web** sur GitHub Pages. Détails et notions (SemVer, signature Android, tags…)
dans **[RELEASING.md](RELEASING.md)**.

## 📝 Licence

Projet personnel, à but d'apprentissage. Pas de licence de distribution.
