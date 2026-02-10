# Instructions Agent (Repository: christophedas59/prototype_1)

Ces règles s'appliquent à **ce repo uniquement**.

---

## Workflow Git obligatoire

### Précondition (avant toute modification)

Avant de modifier quoi que ce soit dans le repo :

1. Vérifier que la branche de travail est bien basée sur le dernier `main`.
2. Si un remote `origin` est configuré :
   - exécuter `git fetch origin`,
   - puis mettre à jour la branche via :
     - `git pull --rebase origin main`, **ou**
     - `git merge origin/main`.
3. Si aucun remote `origin` n’est disponible (environnement agent / Codex) :
   - supposer que le checkout correspond à la dernière version connue,
   - **ne pas échouer** ni bloquer sur l’absence de `origin`,
   - continuer le travail normalement.

Objectifs :
- éviter les divergences de branche,
- réduire les conflits de merge,
- garantir que toute PR part de l’état le plus récent possible de `main`.

---

### Quand l'utilisateur demande de "push" (ou équivalent)

1. Créer une nouvelle branche depuis `main`.
2. Ajouter et commit les changements avec un message de commit clair.
3. Push la branche sur `origin` avec suivi (`-u`) **si possible**.
4. Créer une Pull Request vers `main` avec :
   - un titre explicite,
   - un body complet (summary, changements, validation, notes utiles),
   - une checklist respectant les règles CI / tests ci-dessous.

---

### Quand l'utilisateur dit que la PR est mergée

1. Revenir sur `main`.
2. Mettre `main` à jour avec `git pull --ff-only` **si un remote est disponible**.
3. Supprimer la branche locale mergée.
4. Nettoyer les références distantes supprimées avec `git fetch --prune`.

---

## Règles de sécurité

- Ne pas utiliser de commandes destructives non demandées (ex: `git reset --hard`).
- Ne pas supprimer de fichiers non suivis sans demande explicite.
- Ne pas inclure de changements non liés dans le commit ou la PR.

---

## CI / Godot / Tests (règles techniques)

Ces règles complètent le workflow Git obligatoire ci-dessus.

### Contraintes CI / Environnement

- Ne jamais tenter de lancer l’éditeur Godot interactif.
- Toute commande Godot doit être compatible **headless**.
- Ne pas supposer que le binaire `godot` est disponible hors de GitHub Actions.
- Les commandes Godot peuvent être :
  - décrites,
  - préparées,
  - mais **leur exécution réelle est déléguée à la CI**.
- Ne jamais committer le dossier `.godot/` (cache local).

Les erreurs suivantes ne doivent **pas** être considérées comme bloquantes côté agent :
- `godot: command not found`
- `git pull origin main` sans remote configuré

---

### Tests & Qualité

- Toute PR qui modifie le gameplay (combat, hitbox/hurtbox, dégâts, skills, targeting, AI) doit :
  - ajouter au moins un test GUT pertinent, **ou**
  - mettre à jour un test existant, **ou**
  - expliquer clairement pourquoi aucun test n’est applicable.
- Les tests doivent en priorité couvrir :
  - les régressions connues,
  - les bugs signalés par l’utilisateur.
- Si une signature de fonction change, les tests associés doivent être mis à jour.

#### Gestion des fuites / orphelins dans les tests
- Libérer explicitement les Nodes créés (`queue_free()`), **ou**
- utiliser les helpers GUT appropriés (`autofree`, helpers de lifecycle).

---

### Commandes CI de référence (documentation)

- Import Godot (headless) :
  - `godot --headless --editor --quit --path .`
- Tests GUT (headless) :
  - `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Ces commandes servent de **référence CI** et ne doivent pas être exécutées localement par l’agent si l’environnement ne le permet pas.

---

### Définition de “Done”

Un changement est considéré comme terminé lorsque :
- le workflow GitHub Actions `godot-ci` est **au vert**,
- les changements gameplay sont couverts par au moins un test pertinent,
- la PR respecte le template et les règles du repo.
