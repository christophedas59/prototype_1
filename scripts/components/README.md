# Composants Réutilisables - Guide d'utilisation

Ce dossier contient des composants réutilisables pour créer des entités de combat dans Godot 4.5+.

---

## 📦 Composants disponibles

### 1. HealthBarComponent

**Responsabilité** : Gestion des barres de vie avec effet FTL (Faster Than Light).

**Fonctionnalités** :
- Affichage `TextureProgressBar` avec 4 styles : Player, Enemy, Elite, Boss
- Barre "ghost" qui rattrape avec délai (effet FTL)
- Préchargement des textures pour performance optimale

**API** :
```gdscript
# Initialisation (appeler dans _ready du parent)
health_bar_comp.initialize(health_bar: TextureProgressBar, ghost_bar: TextureProgressBar, max_hp: int, current_hp: int)

# Mise à jour après dégâts/soins
health_bar_comp.update_bars(max_hp: int, current_hp: int, previous_hp: int)

# Cache les barres (à la mort)
health_bar_comp.hide_bars()

# Change le style (réapplique les textures)
health_bar_comp.apply_style()
```

**Exports configurables** :
- `health_bar_style`: PLAYER / ENEMY / ELITE / BOSS
- `enable_ftl_bar`: Active/désactive la barre ghost
- `ftl_delay`: Délai avant rattrapage (défaut: 0.12s)
- `ftl_catchup_time`: Durée du rattrapage (défaut: 0.25s)

---

### 2. TargetingSystem

**Responsabilité** : Ciblage optimisé avec cache.

**Fonctionnalités** :
- Cache de cibles rafraîchi périodiquement (défaut: 0.1s)
- Recherche de la cible la plus proche
- Validation de cibles (vivantes, instance valide)
- Optimisation `distance_squared_to()` (évite sqrt)

**API** :
```gdscript
# Initialisation (appeler dans _ready du parent)
targeting_comp.initialize(owner: Node2D, target_group: String)

# Update dans _physics_process
targeting_comp.update(delta: float)

# Obtenir la cible la plus proche
var target: Node2D = targeting_comp.get_closest_target()

# Vérifier si une cible est valide
if targeting_comp.is_target_valid(my_target):
    attack(my_target)

# Vider le cache manuellement
targeting_comp.clear_cache()
```

**Exports configurables** :
- `cache_refresh_interval`: Intervalle de rafraîchissement (défaut: 0.1s)
- `target_group`: Groupe à cibler ("enemy", "player", etc.)

---

### 3. CombatFeedback

**Responsabilité** : Feedback visuel et physique lors de combat.

**Fonctionnalités** :
- Flash rouge lors de dégâts (tween réutilisé pour performance)
- Knockback (recul physique)
- I-frames (invincibilité temporaire)
- Hit-pause via `HitPauseManager` singleton

**API** :
```gdscript
# Initialisation (appeler dans _ready du parent)
feedback_comp.initialize(visual_node: Node2D)

# Update dans _physics_process
feedback_comp.update(delta: float)

# Appliquer tous les feedbacks lors de dégâts
feedback_comp.apply_damage_feedback(attacker_position: Vector2, entity_position: Vector2)

# Flash seulement (sans knockback)
feedback_comp.apply_flash()

# Vérifier si invulnérable
if not feedback_comp.is_invulnerable():
    take_damage(10)

# Obtenir la vitesse de knockback actuelle
velocity += feedback_comp.get_knockback_velocity()

# Réinitialiser (à la mort)
feedback_comp.reset()
```

**Exports configurables** :
- `i_frames_duration`: Durée d'invincibilité (défaut: 0.25s)
- `knockback_force`: Force du recul (défaut: 140.0)
- `knockback_friction`: Vitesse de décroissance (défaut: 800.0)
- `enable_hit_pause`: Active/désactive le hit-pause
- `hit_pause_duration`: Durée du freeze (défaut: 0.04s)
- `hit_pause_scale`: Échelle de temps (défaut: 0.05)
- `flash_color`: Couleur du flash (défaut: rouge pâle)
- `flash_duration`: Durée du flash (défaut: 0.08s)

---


### 4. HurtboxComponent

**Responsabilité** : Point d'entrée des dégâts via événements.

**Fonctionnalités** :
- Reçoit une attaque via `receive_hit(attacker, amount, hit_position)`
- Émet `hit_received(attacker, amount, hit_position)`
- Permet de découpler la détection de collision et l'application des dégâts

---

### 5. MeleeHitboxComponent

**Responsabilité** : Détection d'impact de mêlée pendant une fenêtre d'attaque courte.

**Fonctionnalités** :
- Activation temporaire de la hitbox via `start_swing(attacker, amount)`
- Détection des `HurtboxComponent` touchées
- Anti multi-hit sur la même cible pendant un swing
- Filtrage d'alliés via `get_team()` si disponible

---

## 🎯 Exemple d'utilisation : CombatEntity

Voir [scripts/combat_entity.gd](../combat_entity.gd) pour un exemple complet.

**Structure de scène requise** :
```
MyEntity (CharacterBody2D)
├── Visual (AnimatedSprite2D ou Sprite2D)
├── HealthBar (TextureProgressBar)
├── HealthBarGhost (TextureProgressBar)
├── Hurtbox (Area2D)
│   └── CollisionShape2D
├── AttackHitbox (Area2D)
│   └── CollisionShape2D
├── HealthBarComponent (Node)
├── TargetingSystem (Node)
└── CombatFeedback (Node)
```

**Script minimal** :
```gdscript
extends CharacterBody2D

@onready var health_bar_comp: Node = $HealthBarComponent
@onready var targeting_comp: Node = $TargetingSystem
@onready var feedback_comp: Node = $CombatFeedback
@onready var visual: AnimatedSprite2D = $Visual
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var health_bar_ghost: TextureProgressBar = $HealthBarGhost

var hp: int = 100
var max_hp: int = 100

func _ready() -> void:
    health_bar_comp.initialize(health_bar, health_bar_ghost, max_hp, hp)
    targeting_comp.initialize(self, "enemy")
    feedback_comp.initialize(visual)

func _physics_process(delta: float) -> void:
    targeting_comp.update(delta)
    feedback_comp.update(delta)

    # Ajouter knockback au mouvement
    velocity += feedback_comp.get_knockback_velocity()
    move_and_slide()

func take_damage(amount: int, from: Node2D) -> void:
    if feedback_comp.is_invulnerable():
        return

    hp -= amount
    health_bar_comp.update_bars(max_hp, hp, hp + amount)
    feedback_comp.apply_damage_feedback(from.global_position, global_position)

    if hp <= 0:
        die()
```

---

## 🚀 Créer une nouvelle entité (Tourelle)

**Exemple : Tourelle statique qui tire sur les ennemis**

```gdscript
extends StaticBody2D

@onready var targeting: Node = $TargetingSystem
@onready var health_comp: Node = $HealthBarComponent
@onready var feedback: Node = $CombatFeedback

var hp: int = 50
const MAX_HP: int = 50

func _ready() -> void:
    targeting.initialize(self, "enemy")
    health_comp.initialize($HealthBar, $HealthBarGhost, MAX_HP, hp)
    feedback.initialize($Visual)

func _physics_process(delta: float) -> void:
    targeting.update(delta)
    feedback.update(delta)

    var target := targeting.get_closest_target()
    if target and can_shoot():
        shoot_at(target)

func take_damage(amount: int, from: Node2D) -> void:
    if feedback.is_invulnerable():
        return

    hp -= amount
    health_comp.update_bars(MAX_HP, hp, hp + amount)
    feedback.apply_damage_feedback(from.global_position, global_position)
```

---

## 📝 Notes importantes

1. **Initialisation** : Toujours appeler `component.initialize()` dans `_ready()`
2. **Update** : Appeler `component.update(delta)` dans `_physics_process()` pour les composants qui en ont besoin
3. **Ordre d'ajout** : Les composants doivent être des enfants de l'entité dans la scène
4. **Contrat cible recommandé** : les entités ciblables devraient exposer `is_alive() -> bool` (fallback legacy géré sur `is_dead`)
5. **Contrat équipe recommandé** : les entités ciblables devraient exposer `get_team() -> String` pour filtrer les coups alliés
6. **Dégâts événementiels** : connecter `HurtboxComponent.hit_received` vers `take_damage` sur l'entité
7. **Dependencies** : CombatFeedback nécessite le singleton `HitPauseManager` (voir [project.godot](../../project.godot))
5. **Dependencies** : CombatFeedback nécessite le singleton `HitPauseManager` (voir [project.godot](../../project.godot))

---

## 🔧 Personnalisation

Chaque composant peut être :
- ✅ Utilisé seul ou en combinaison
- ✅ Configuré via exports dans l'Inspector
- ✅ Étendu via héritage GDScript
- ✅ Modifié pour de nouveaux besoins

**Exemple** : Créer un `BossHealthBarComponent` avec 3 barres de vie :
```gdscript
extends "res://scripts/components/health_bar_component.gd"

# Ajouter une troisième barre pour un boss avec plusieurs phases
```

---

## 📚 Références

- Documentation complète : [OPTIMIZATIONS.md](../../OPTIMIZATIONS.md)
- Exemple complet : [combat_entity.gd](../combat_entity.gd)
- Singleton hit-pause : [hit_pause_manager.gd](../hit_pause_manager.gd)
