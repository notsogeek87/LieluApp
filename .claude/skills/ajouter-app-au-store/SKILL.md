---
name: ajouter-app-au-store
description: À utiliser quand David veut ajouter un de ses dépôts (app Android) au catalogue de LieluApp (le Lielu Store) : entrée catalog/apps.json, vrai logo, test, push main. Déclencheurs : « ajoute <app> à LieluApp », « mets <app> dans le store ».
---

# Ajouter un dépôt au Lielu Store (LieluApp)

Référence des champs : `docs/AJOUTER-UNE-APP.md`. Ce skill fixe la méthode et les pièges déjà rencontrés.
Travailler dans le dépôt `notsogeek87/LieluApp` ; le dépôt de l'app à ajouter doit être attaché à la session
(`add_repo`) et cloné à jour.

## 1. Lire les vraies valeurs dans le dépôt de l'app (ne jamais deviner)

Toujours partir de `origin/main` **fraîchement récupéré** (`git fetch origin main`) : un clone local ou une copie du
modèle peut dater du premier commit (une app dérivée de `lieluinit` évolue beaucoup, son logo aussi).

- **`packageName`** : `applicationId` réel dans `app/build.gradle.kts` (`com.lielu.xxx`, ou `eu.lielu.xxx`). Il est
  vérifié dans l'APK avant installation : une faute = installation refusée.
- **Nom** : `appName` dans `gradle.properties` (ou nom du lanceur).
- **`repo`** : `owner/depot`, public (`list_repos` donne la visibilité). Privé => le store ne peut pas lire les releases.
- **Releases** : `list_releases` : relever le format du tag (`v1.0.38`) et le nom exact de l'APK
  (`LieluTodo-1.0.38.apk`). En déduire `tagPattern` (`^v(\d+(?:\.\d+)*)$`) et `apkPattern` (`^LieluTodo-.*\.apk$`).
  Les apps issues de `lieluinit` publient aussi des pré-releases `staging-v…` avec `<Nom>-Staging-…apk` :
  ajouter `"apkExclude": "Staging"`.
- **Version figée** (versionName qui ne change pas) : `"updateDetection": "installedTag"`.
- **Catégorie / description** : lire le `README.md` et `CLAUDE.md` du dépôt ; écrire en français, une ligne courte
  (`shortDescription`) + une fiche (`description`). Ne rien inventer sur les fonctions.

## 2. Le vrai logo (point où l'on s'est trompé)

Ne **jamais dessiner** un logo ni prendre l'icône « L » du modèle. Chercher le logo réel de l'app, dans cet ordre :
1. `web/icon.svg`, `docs/**/logo*`, `docs/icon-512.png`, `*logo*.png|svg` (`git ls-tree -r origin/main`) ;
2. `app/src/main/res/drawable/ic_launcher_foreground.xml` + `ic_launcher_background.xml` (adaptive icon) et
   `res/values/colors.xml` ;
3. si rien n'est trouvé : **demander** à David où il est, sans en fabriquer un.

Produire `catalog/icons/<id>.png`, 256×256 (c'est ce fichier que le store embarque ; `iconUrl` n'est qu'un repli
réseau, facultatif). Rendu d'un SVG avec Chromium/Playwright préinstallé (`require('playwright')`), fond
transparent, puis **regarder l'image** (Read) avant de commiter. `<id>` = l'`id` de l'entrée.

## 3. Modifier le catalogue

Dans `catalog/apps.json` :
- ajouter l'entrée en fin de tableau `apps` (modèle : `docs/AJOUTER-UNE-APP.md`, exemple : `allcommand`) ;
  `id` = minuscules/chiffres/tirets ; `featured` seulement si David le demande ;
- mettre `updatedAt` à la date du jour (ISO, `T12:00:00Z`) ;
- JSON valide (`python3 -c "import json;json.load(open('catalog/apps.json'))"`).

Dans `test/real_releases_test.dart`, ajouter un test sur le modèle de `allCommand` avec les vrais tags/APK relevés
(une release normale + une pré-release `staging-v…` qui doit être ignorée).

## 4. Vérifier, commiter, pousser

- `flutter test test/catalog_test.dart test/real_releases_test.dart` si Flutter est installé ; sinon le dire :
  « tests non exécutés ici », ne pas présenter comme vérifié.
- Commits en français, un pour l'entrée (+ test) et l'icône peut suivre :
  `Catalogue : ajout de <Nom> (<packageName>)`. Terminer par les lignes d'attribution demandées par la session.
- Pousser la branche de travail, puis **`main`** si David l'a demandé (`git push origin HEAD:main`). Le dépôt publie
  `main` ET `staging` aux ajouts précédents : proposer `staging` en une phrase, ne pas le faire sans demande.
  La CI de LieluApp ne tourne que sur `main`/`staging`/PR : la consulter après le push (`actions_list`).

## 5. Compte rendu

Dire en quelques lignes : entrée ajoutée (packageName, repo), origine du logo, tests exécutés ou non, commit poussé.
