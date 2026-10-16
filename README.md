# Lielu Store

Le store des applications Android Lielu : un catalogue unique, installation et mises à jour depuis les
releases GitHub publiques, sans compte ni connexion GitHub.

- **Ajouter une application** : [docs/AJOUTER-UNE-APP.md](docs/AJOUTER-UNE-APP.md) (une entrée dans `catalog/apps.json`, sans republier le store).
- **Architecture** : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

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
- Signature : clé de debug commitée (`android/ci-debug.p12`), identique à chaque build, donc chaque APK s'installe par-dessus le précédent.

### Auto-mise à jour du store

`lib/features/app_update/` interroge `releases/latest` du dépôt, compare le dernier segment du tag au
`versionCode` installé, télécharge l'APK et passe la main à l'installeur Android.
**Le dépôt `LieluApp` doit être public** pour que le store (et son catalogue distant) soient lisibles sans jeton.
