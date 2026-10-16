# Ajouter une application à Lielu Store

Le store lit **un seul fichier** : [`catalog/apps.json`](../catalog/apps.json). Ajouter une application
= ajouter une entrée dans ce fichier. **Aucune nouvelle version du store n'est nécessaire.**

## En 3 étapes

### 1. Publier l'APK dans une release GitHub publique

Le dépôt de l'app doit être **public**. À chaque build, la CI crée une release qui contient l'APK
(c'est déjà le cas de vos dépôts : `gh release create v<version> <apk>`). Règles à respecter :

| Règle | Pourquoi |
| --- | --- |
| Le **tag** contient la version : `v1.0.152` | le store compare cette version au `versionName` installé |
| Le **`versionName`** de l'APK = la version du tag (ou, à défaut, voir `updateDetection` plus bas) | sinon le store ne sait pas dire « à jour » |
| Le **`versionCode`** augmente à chaque release | Android refuse de rétrograder ; le store aussi |
| Les builds de test sont en **pré-release** (`--prerelease`) | ignorées par défaut |
| **Même clé de signature** à chaque build | sinon Android refuse la mise à jour (le store l'affiche clairement) |
| Un seul APK par release, ou un nom de fichier qui permet de choisir (`apkPattern`) | le store ne devine jamais |

Facultatif mais recommandé : publier un fichier `<apk>.sha256` (ou compter sur le champ `digest` que
GitHub ajoute automatiquement aux assets) pour que le store vérifie l'intégrité du fichier.

### 2. Ajouter l'entrée au catalogue

Dans `catalog/apps.json`, tableau `apps` :

```json
{
  "id": "mon-app",
  "name": "Mon App",
  "packageName": "eu.lielu.monapp",
  "repo": "notsogeek87/mon-app",
  "category": "Outils",
  "shortDescription": "Une phrase pour la liste.",
  "description": "Description détaillée pour la fiche.",
  "iconUrl": "https://raw.githubusercontent.com/notsogeek87/mon-app/main/docs/icon-512.png",
  "screenshots": [],
  "maintenance": "active",
  "featured": false,
  "minSdk": 26,
  "release": {
    "tagPattern": "^v(\\d+(?:\\.\\d+)*)$",
    "apkPattern": "^MonApp-.*\\.apk$"
  }
}
```

### 3. Commit et push sur la branche publiée du catalogue

Le store récupère le fichier depuis `https://raw.githubusercontent.com/notsogeek87/LieluApp/main/catalog/apps.json`
(modifiable à la compilation : `--dart-define=CATALOG_URL=...`). Au prochain rafraîchissement
(réglable, ou « Vérifier les mises à jour » dans les Paramètres), l'app apparaît avec sa dernière version.

> ⚠️ `raw.githubusercontent.com` ne sert que les dépôts **publics**. Tant que `LieluApp` est privé, le
> store utilise la copie du catalogue embarquée dans l'APK (le fichier ci-dessus au moment du build).

## Référence des champs

| Champ | Obligatoire | Description |
| --- | --- | --- |
| `id` | oui | identifiant unique : minuscules, chiffres, tirets |
| `name` | oui | nom public |
| `packageName` | oui | `applicationId` Android **réel** (il est vérifié dans l'APK avant installation) |
| `repo` | oui | `proprietaire/depot` GitHub public |
| `shortDescription` | oui | une ligne pour les listes |
| `description` | non | texte de la fiche (défaut : `shortDescription`) |
| `category` | non | `Actualités`, `Productivité`, `Divertissement`, `Outils`, `Éducation`… (défaut : `Autres`) |
| `iconUrl`, `screenshots[]` | non | URL HTTPS d'hôte GitHub uniquement (`raw.githubusercontent.com`, …) |
| `maintenance` | non | `active`, `maintenance`, `paused`, `archived` |
| `featured` | non | affichée dans « Applications à la une » |
| `minSdk` | non | indication affichée ; la vraie valeur est relue dans l'APK |
| `signingCertSha256` | non | empreinte SHA-256 du certificat attendu : imposée **dès la première installation** (commande : `apksigner verify --print-certs app.apk`) |
| `listed` | non | `false` = entrée conservée dans le fichier mais masquée |
| `release.tagPattern` | non | regex, **le groupe 1 est la version**. Défaut : `^v?(\d+(?:\.\d+)*…)$` |
| `release.apkPattern` | non | regex sur le nom de fichier de l'APK à prendre |
| `release.apkExclude` | non | regex des fichiers à écarter (ex. `Staging`) |
| `release.includePrereleases` | non | `true` pour proposer aussi les pré-versions |
| `release.updateDetection` | non | `versionName` (défaut) ou `installedTag` |

### Cas particuliers

- **Plusieurs familles de tags** (ex. SwiperNews : `v1.5.6` et `android-v1.5.6.80`) : un seul `tagPattern`
  avec un groupe optionnel `^(?:android-)?v(\d+(?:\.\d+)*)$`. La plus haute *version* gagne.
- **Plusieurs variantes d'APK** (arm64/x86, staging/production) : `apkPattern` + `apkExclude`.
  Les noms contenant `arm64-v8a`, `armeabi-v7a`, `x86_64`, `x86`, `universal` sont triés selon l'architecture
  du téléphone ; en cas d'égalité, le store **refuse de choisir** et affiche l'ambiguïté.
- **`versionName` figé** (ex. toujours `0.1.0` alors que le tag change) : `"updateDetection": "installedTag"`.
  Le store compare alors le dernier tag *qu'il a lui-même installé* ; une app installée autrement
  apparaît « installée » sans pouvoir dire si elle est à jour.
- **Tag type `v0.1.0-12`** : lu comme une pré-version SemVer ; ça reste ordonné correctement
  (`-12` < `-13`), mais préférez `v0.1.0.12`.

## Vérifier avant de publier

```bash
flutter test test/catalog_test.dart   # valide catalog/apps.json (doublons, regex, URLs…)
```

Une entrée invalide n'empêche pas les autres de s'afficher : elle est ignorée et listée dans
*Paramètres → Entrées du catalogue ignorées*.

## Ce que vérifie le store avant d'installer

1. HTTPS et hôte GitHub, **à chaque redirection**.
2. Taille reçue = taille annoncée.
3. SHA-256 = celui publié (`digest` GitHub ou fichier `.sha256`) — sinon l'écran dit *« intégrité non vérifiée »*.
4. Android lit l'APK : `packageName` identique au catalogue, `minSdk` et architecture compatibles,
   `versionCode` strictement supérieur à l'installé.
5. **Signature** identique à celle de l'app déjà installée (ou à `signingCertSha256`). Sinon : refus, rien n'est modifié.
6. Installation par `PackageInstaller` : Android affiche toujours sa confirmation.
