# 🎮 Pull Request — prototype_1 (Godot 4.5.1)

## Résumé
<!-- Décris le besoin gameplay/technique et le résultat attendu en 3-6 lignes -->

## Pourquoi ce changement ?
- Problème / besoin :
- Impact joueur :
- Alternative(s) considérée(s) :

## Type de changement
- [ ] Feature gameplay
- [ ] Fix bug gameplay
- [ ] Refactor technique
- [ ] Performance / optimisation
- [ ] UI / feedback visuel
- [ ] Documentation
- [ ] CI / tooling

## Scope (fichiers / systèmes touchés)
- Systèmes :
- Scènes :
- Scripts :
- Assets :

## Checklist spécifique au jeu

### 1) Combat (core loop)
- [ ] Le combat fonctionne dans `scenes/levels/test_arena.tscn` (joueur + zombies).
- [ ] Les attaques se déclenchent uniquement dans une portée cohérente (pas de coups "dans le vide").
- [ ] Le cooldown d’attaque est respecté (pas de spam involontaire).
- [ ] Le ciblage reste correct (cible valide, vivante, groupe attendu).
- [ ] Les dégâts sont appliqués exactement une fois par hit attendu.
- [ ] Aucun blocage de state machine (attaque, déplacement, mort).

### 2) Hitbox / Hurtbox
- [ ] Les couches/masks de collision sont documentés et cohérents.
- [ ] La hitbox d’attaque ne touche pas l’attaquant lui-même.
- [ ] Le filtrage allié/adversaire via `get_team()` est correct.
- [ ] Pas de multi-hit involontaire sur une même cible pendant un swing.
- [ ] La fenêtre d’activation de hitbox (`active_time`) est justifiée.
- [ ] Le contact réel correspond à la portée logique d’attaque.

### 3) Feedback de combat (lisibilité)
- [ ] La barre de vie se met à jour correctement à chaque dégât.
- [ ] Le flash rouge sur hit est visible et revient à l’état normal.
- [ ] Le knockback est ressenti sans casser le contrôle.
- [ ] Les i-frames empêchent bien les doubles impacts instantanés.
- [ ] Le hit-pause est perceptible mais non gênant.
- [ ] Aucun feedback ne persiste après la mort d’une unité.

### 4) Unités / entités
- [ ] `player_warrior.tscn` est valide après changement.
- [ ] `enemy_zombie.tscn` est valide après changement.
- [ ] `combat_entity.tscn` reste réutilisable (nouveaux nodes bien câblés).
- [ ] Les contrats `is_alive()` / `get_team()` restent cohérents.
- [ ] Les groupes Godot (`player`, `enemy`) sont correctement utilisés.

### 5) Compétences / attaques spéciales (si concerné)
- [ ] Description claire de la compétence (effet, portée, timing, coût).
- [ ] Interaction avec hitbox/hurtbox testée.
- [ ] Règles d’empilement (stacks, DOT, slow, stun, etc.) définies.
- [ ] Priorité/annulation avec attaque de base gérée.
- [ ] Télégraphie visuelle/sonore suffisante pour lecture gameplay.

### 6) Performance / robustesse
- [ ] Pas de boucle coûteuse ajoutée dans `_physics_process` sans justification.
- [ ] Pas d’allocations/tweens inutiles en rafale pendant le combat.
- [ ] Aucune erreur/warning Godot nouvelle en console liée à cette PR.
- [ ] Comportement stable si une cible meurt pendant l’attaque.

## Plan de validation manuelle

### Scène(s) testée(s)
- [ ] `scenes/levels/test_arena.tscn`
- [ ] Autre(s) : <!-- préciser -->

### Cas de test gameplay exécutés
- [ ] Duel 1v1 (joueur vs zombie)
- [ ] 1vN (joueur vs plusieurs zombies)
- [ ] Mort d’une cible pendant une attaque
- [ ] Changement de cible après mort
- [ ] Vérification visuelle HP / flash / knockback
- [ ] Vérification du rythme combat (cooldown / hit-pause)

## Tests automatisés (GUT) — recommandés

### État
- [ ] Pas de test GUT ajouté (expliquer pourquoi)
- [ ] Tests GUT ajoutés / mis à jour

### Checklist GUT
- [ ] Test `TargetingSystem`: ignore cibles mortes, choisit la plus proche.
- [ ] Test `MeleeHitboxComponent`: `start_swing` active, touche une fois/cible.
- [ ] Test `MeleeHitboxComponent`: ne touche pas allié (`get_team`).
- [ ] Test `HurtboxComponent`: émet `hit_received` avec bons paramètres.
- [ ] Test `CombatEntity`: `take_damage` met à jour HP + déclenche feedback.
- [ ] Test `CombatEntity`: `die()` désactive collisions/hitboxes.
- [ ] Test régression: pas de "dead-zone" portée logique vs portée collision.

### Exemple de fichiers de test à créer (suggestion)
- [ ] `tests/gut/test_targeting_system.gd`
- [ ] `tests/gut/test_melee_hitbox_component.gd`
- [ ] `tests/gut/test_hurtbox_component.gd`
- [ ] `tests/gut/test_combat_entity_damage_flow.gd`

## CI / workflow GitHub
- [ ] Le workflow CI passe (lint/tests/checks).
- [ ] Si CI Godot est modifiée: matrice/versions/documentation mises à jour.
- [ ] Les artefacts/logs CI sont consultables en cas d’échec.

## Risques & rollback
- Risques identifiés :
- Plan de rollback :

## Notes reviewer
- Points d’attention en review :
- Captures/vidéos gameplay (si pertinent) :
