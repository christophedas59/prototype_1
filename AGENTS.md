# Instructions Agent (Repo: prototype)

Ces règles s'appliquent à **ce repo uniquement**.

## Workflow Git obligatoire

### Quand l'utilisateur demande de "push" (ou équivalent)
1. Créer une nouvelle branche depuis `main`.
2. Ajouter et commit les changements avec un message de commit clair.
3. Push la branche sur `origin` avec suivi (`-u`).
4. Créer une Pull Request vers `main` avec :
- un titre explicite,
- un body complet (summary, changements, validation, notes utiles).

### Quand l'utilisateur dit que la PR est mergée
1. Revenir sur `main`.
2. Mettre `main` à jour avec `git pull --ff-only`.
3. Supprimer la branche locale mergée.
4. Nettoyer les références distantes supprimées avec `git fetch --prune`.

## Règles de sécurité
- Ne pas utiliser de commandes destructives non demandées (ex: `git reset --hard`).
- Ne pas supprimer de fichiers non suivis sans demande explicite.
- Ne pas inclure de changements non liés dans le commit/PR.
  
---

## CI / Godot / Tests (règles techniques)

Ces règles complètent le workflow Git obligatoire ci-dessus.

### Contraintes CI
- Ne jamais tenter de lancer l’éditeur Godot interactif.
- Toute commande Godot doit être compatible headless (CI).
- Ne pas supposer que Godot est installé hors de la CI GitHub Actions.
- Ne jamais committer le dossier `.godot/` (cache local).

### Tests & Qualité
- Toute PR qui modifie le gameplay (combat, hitbox/hurtbox, dégâts, skills, targeting, AI) doit :
  - ajouter au moins un test GUT pertinent, **ou**
  - mettre à jour un test existant, **ou**
  - expliquer clairement pourquoi aucun test n’est applicable.
- Si une signature de fonction change, les tests associés doivent être mis à jour.
- Les tests doivent éviter les fuites :
  - libérer les Nodes créés (`queue_free()`),
  - ou utiliser les helpers GUT adaptés.

### Commandes CI de référence
- Import Godot (headless) :
  - `godot --headless --editor --quit --path .`
- Tests GUT (headless) :
  - `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

### Définition de “Done”
- Le workflow GitHub Actions `godot-ci` doit être au vert.
- Les changements gameplay doivent être couverts par au moins un test pertinent.
