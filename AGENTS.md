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
