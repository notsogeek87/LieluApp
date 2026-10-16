# LieluApp

Application Flutter Android, même chaîne de build et de mise à jour que [LieluFind](https://github.com/notsogeek87/LieluFind).

## Build et releases

Le workflow `.github/workflows/android-build.yml` compile l'APK à chaque push.

- `versionName` = version du `pubspec.yaml` (avant le `+`), `versionCode` = numéro de run du CI.
- Sur `main` : release GitHub permanente `v<version>.<run>` avec l'APK `LieluApp-<version>.<run>.apk`.
- Autres branches / PR : pré-release `debug-<branche>`, remplacée à chaque build.
- Signature : clé de debug commitée (`android/ci-debug.p12`), identique à chaque build, donc chaque APK s'installe par-dessus le précédent.

## Mise à jour dans l'app

`lib/features/app_update/` interroge `releases/latest` du dépôt, compare le dernier segment du tag au `versionCode` installé, propose la mise à jour, télécharge l'APK dans l'app puis passe la main à l'installeur Android (`ApkInstallerChannel.kt`, FileProvider `apk_provider_paths.xml`).

Le dépôt doit être public pour que l'app puisse lire les releases sans jeton.

## Identifiant

Package Android : `eu.lielu.lieluapp`.
