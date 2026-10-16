# Architecture de Lielu Store

```
catalog/apps.json  ──(raw.githubusercontent.com)──►  CatalogRepository ─┐
                                                                         ├─► appViewsProvider ─► UI
GitHub API /repos/{repo}/releases ─► GithubReleaseClient ─► ReleaseRepository ┤
PackageManager (Kotlin) ─► StorePlatform.installed ──────────────────────────┘
```

## Choix

| Sujet | Décision | Raison |
| --- | --- | --- |
| Stack | Flutter + Riverpod + Dio, Kotlin natif pour le système | le dépôt existant était déjà Flutter avec chaîne de build/auto-update |
| Catalogue | JSON statique dans un dépôt public GitHub | zéro serveur, versionné, relu par PR ; copie embarquée dans l'APK pour le premier lancement hors-ligne |
| Versions/releases | **pas dans le catalogue** : lues en direct sur l'API GitHub | une release publiée apparaît sans toucher au catalogue |
| Quota GitHub | requêtes conditionnelles (ETag) + intervalle de rafraîchissement | 60 req/h/IP sans jeton ; un 304 n'est pas décompté |
| Installation | `PackageInstaller` (session) | résultats exploitables (conflit, stockage…) ; jamais silencieux |
| Visibilité des apps | `<queries>` sur l'intent LAUNCHER | pas de `QUERY_ALL_PACKAGES`, et une nouvelle app du catalogue est détectée sans republier |

## Modules (`lib/`)

- `core/` : comparaison de versions, politique d'URL (HTTPS + hôtes GitHub), formats.
- `catalog/` : modèle + lecture tolérante du JSON, dépôt (distant → cache → copie embarquée).
- `releases/` : client GitHub, **sélection de la release** (tag, préversions, brouillons) et **de l'APK** (motifs, architecture, jamais de devinette), cache.
- `install/` : téléchargement avec contrôle de chaque redirection, vérifications (`apk_verifier`), orchestration (`install_service`).
- `platform/` : pont Android (`StorePlatform`), remplaçable par un faux dans les tests.
- `state/` : providers Riverpod, états d'installation.
- `ui/` : écrans (Accueil, Toutes les apps, Fiche, Mises à jour, Téléchargements, Paramètres).
- `features/app_update/` : auto-mise à jour du store lui-même (existant).

## Limites connues

- Sans jeton, l'API GitHub est limitée (60 req/h/IP). Avec ~10 apps et un rafraîchissement toutes les 6 h c'est largement suffisant ; au-delà, passer à un `releases.json` généré par une GitHub Action dans le dépôt du catalogue.
- Pas de notification en arrière-plan : les mises à jour sont détectées à l'ouverture, selon l'intervalle des Paramètres.
- Une mise à jour silencieuse sans confirmation n'est pas possible pour une app ordinaire.
- La vérification d'intégrité dépend d'un SHA-256 publié (digest GitHub ou `.sha256`) : à défaut, le store l'indique.
