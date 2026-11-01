# Lielu Store

Le store des applications Android Lielu : un catalogue unique, installation et mises à jour depuis les
releases GitHub publiques, sans compte ni connexion GitHub.

- **Ajouter une application** : [docs/AJOUTER-UNE-APP.md](docs/AJOUTER-UNE-APP.md) (une entrée dans `catalog/apps.json`, sans republier le store).
- **Architecture** : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

- **Widget d'écran d'accueil** « Applications Lielu » : grille de toutes les apps du catalogue (Android et web).
  L'ordre se règle à la main dans *Paramètres → Widget d'accueil* (glisser-déposer). Un appui ouvre l'app
  installée, l'app web dans le navigateur, ou la fiche du store si l'app n'est pas installée.

Application Flutter (Riverpod, Dio), avec une couche native Kotlin (`PackageManager` / `PackageInstaller`).
Package Android : `eu.lielu.lieluapp`.

## Développement

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

## Build et releases du store

Le workflow `.github/workflows/android-build.yml` compile l'APK à chaque push.

- `versionName` = version du `pubspec.yaml` (avant le `+`), `versionCode` = numéro de run du CI.
- Sur `main` : release GitHub permanente `v<version>.<run>` avec l'APK `LieluApp-<version>.<run>.apk`.
- Autres branches / PR : pré-release `debug-<branche>`, remplacée à chaque build.
- Signature : clé de publication du store, fournie au CI par les secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
  `KEY_ALIAS`, `KEY_PASSWORD`. Certificat `CN=Lielu Store, O=Lielu, C=FR`, empreinte SHA-256
  `7D:85:D0:66:C9:57:5D:76:AF:E3:B7:A2:B3:FE:84:17:A6:F9:05:9A:76:E5:03:4D:13:AB:A5:86:FE:D0:9E:4F`.
  Sans ces secrets, le build de `main` échoue et rien n'est publié ; le CI vérifie aussi l'empreinte avant chaque release.
  Les releases antérieures étaient signées par une clé de debug publique (`android/ci-debug.p12`, retirée) :
  passer de l'une à l'autre impose de désinstaller le store une fois.

### Auto-mise à jour du store

`lib/features/app_update/` interroge `releases/latest` du dépôt, compare le dernier segment du tag au
`versionCode` installé, télécharge l'APK (hôtes GitHub en HTTPS uniquement), vérifie le SHA-256 publié par GitHub,
puis fait lire l'APK par Android : paquet `eu.lielu.lieluapp`, empreinte de la clé du store
(`storeSigningCertSha256`) et version plus récente. Seulement alors il passe la main à l'installeur Android.
**Le dépôt `LieluApp` doit être public** pour que le store (et son catalogue distant) soient lisibles sans jeton.
