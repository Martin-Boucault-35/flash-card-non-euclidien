# Releases & déploiement (PolyMnesis)

Mémo du fonctionnement CI/CD. L'app Flutter est dans `Polymnesis_flutter/`.

## Le flux : 1 PR = 1 version

1. Crée une branche, code ta feature, `flutter test`.
2. **Bumpe `version:` dans `Polymnesis_flutter/pubspec.yaml`** (voir SemVer ci-dessous).
3. Ouvre une **PR** → le workflow **CI** (`ci.yml`) lance `analyze` + `test`.
4. **Merge** la PR sur `main` → le workflow **Release** (`release.yml`) :
   - lit la version du pubspec ; si le tag `vX.Y.Z` n'existe pas encore →
   - build l'**APK** (+ signature, cf. plus bas) et le **Web** ;
   - crée le **tag** `vX.Y.Z` + une **GitHub Release** (notes auto = liste des PR)
     avec l'**APK en pièce jointe** ;
   - déploie le Web sur **GitHub Pages**.

> Si tu oublies de bumper la version, le tag existe déjà → aucune release (normal).

## SemVer et le numéro de build (`+N`)

`version: 1.2.0+5` :
- `1.2.0` = **versionName** (affiché). SemVer : `PATCH`=correctif, `MINOR`=feature,
  `MAJOR`=changement cassant. C'est **toi** qui le choisis dans le pubspec.
- `+5` = **versionCode** (entier Android). Doit **toujours augmenter** sinon
  Android refuse la mise à jour. **Géré automatiquement par la CI**
  (`--build-number=<numéro de run>`), tu n'as pas à t'en occuper.

## Réglages GitHub à faire UNE fois

1. **Pages** : Settings → Pages → **Source = GitHub Actions**.
   URL du site : `https://martin-boucault-35.github.io/flash-card-non-euclidien/`
2. **Keep-alive Supabase** (`keepalive.yml`) : Settings → Secrets and variables →
   Actions → ajouter `SUPABASE_URL` et `SUPABASE_ANON_KEY`.
3. **(Recommandé) Protéger `main`** : Settings → Branches → règle sur `main` :
   exiger une PR + le check **CI** vert avant merge. ⇒ plus de push direct.

## Signature de l'APK

Par défaut, l'APK de release est signé avec la **clé debug** (repli automatique).
C'est la **même clé** que tes installs actuelles → les mises à jour s'installent
**par-dessus**, sans reset, **sans perte de données**. Suffisant pour un usage perso.

### Passer à une vraie clé de release (plus tard, optionnel)

⚠️ Changer de clé = nouvelle signature ≠ ancienne → Android **force une
désinstallation** au prochain install → le stockage local est effacé. Ce n'est
sans risque que parce que **tes cartes sont sur Supabase** : après réinstall, tu
ressaisis Project URL + anon key et tout revient. (Fais quand même un export CSV.)

Étapes :
1. Créer la clé (**à sauvegarder hors dépôt, ne jamais perdre**) :
   ```
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Ajouter les **secrets** GitHub :
   - `ANDROID_KEYSTORE_BASE64` = `base64 -w0 ~/upload-keystore.jks`
   - `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`
3. C'est tout : dès que le secret `ANDROID_KEYSTORE_BASE64` existe, la CI signe
   avec la vraie clé. En local, poser un `Polymnesis_flutter/android/key.properties`
   (gitignoré) active aussi la signature release.

`key.properties`, `*.jks`, `*.keystore` sont **gitignorés** — ne jamais les committer.

## Où retrouver les livrables
- **APK** : onglet *Releases* du dépôt (pièce jointe `app-release.apk`).
- **Web** : l'URL Pages ci-dessus.
- **Logs CI/CD** : onglet *Actions*.
