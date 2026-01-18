extends CharacterBody2D
##
## CombatEntity.gd — Entité de combat modulaire (Player + Ennemis)
## Godot 4.5.x — Prototype 2D top-down
##
## Utilise des composants réutilisables :
## - HealthBarComponent : Barres de vie + FTL
## - TargetingSystem : Ciblage optimisé avec cache
## - CombatFeedback : Flash, knockback, i-frames, hit-pause
##
## Rôle :
## - Déplacement (joueur ou IA)
## - Attaque auto + cooldown
## - Animations + orientation
## - Mort
##

# -------------------------------------------------------------------
# COMPOSANTS (ONREADY)
# -------------------------------------------------------------------

@onready var health_bar_comp: Node = $HealthBarComponent
@onready var targeting_comp: Node = $TargetingSystem
@onready var feedback_comp: Node = $CombatFeedback


# -------------------------------------------------------------------
# EXPORTS — Configuration générale
# -------------------------------------------------------------------

@export var is_player: bool = false
@export var is_enemy: bool = false
@export var autonomous: bool = false  # Autobattler : poursuite + attaque auto
@export var look_at_target: bool = false  # Regarde une cible quand immobile (mode manuel)

# Mouvement
@export var move_speed: float = 90.0

# Combat
@export var attack_range: float = 32.0
@export var attack_cooldown: float = 1.2
@export var attack_damage: int = 1

# Vie
@export var max_hp: int = 10

# Ciblage (legacy, peu utilisé maintenant)
@export var retarget_distance_bonus: float = 16.0

# Knockback
@export var facing_lock_on_knockback: bool = true


# -------------------------------------------------------------------
# RÉFÉRENCES NODES
# -------------------------------------------------------------------

@onready var visual: AnimatedSprite2D = $Visual
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var health_bar_ghost: TextureProgressBar = $HealthBarGhost
@onready var body_collision: CollisionShape2D = get_node_or_null("BodyCollision")


# -------------------------------------------------------------------
# ÉTAT RUNTIME
# -------------------------------------------------------------------

var hp: int
var facing: String = "down"

var attack_timer: float = 0.0
var is_attacking: bool = false
var is_dead: bool = false

var current_target: Node2D = null


# -------------------------------------------------------------------
# CYCLE DE VIE
# -------------------------------------------------------------------

func _ready() -> void:
	hp = max_hp

	# Initialise les composants
	_initialize_components()

	# Animation idle initiale
	var frames := visual.sprite_frames
	if frames != null and frames.has_animation("idle_" + facing):
		visual.play("idle_" + facing)

	# Connect l'animation finished
	if not visual.animation_finished.is_connected(_on_animation_finished):
		visual.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update composants
	targeting_comp.update(delta)
	feedback_comp.update(delta)

	# Timers
	attack_timer = max(attack_timer - delta, 0.0)

	# Logique de déplacement / IA
	if is_player:
		if autonomous:
			autonomous_move_and_fight()
		else:
			player_move()
	elif is_enemy:
		enemy_move()

	# Knockback
	velocity += feedback_comp.get_knockback_velocity()

	# Look at target (mode manuel uniquement)
	if look_at_target and not autonomous and velocity.length() <= 1.0:
		var target := targeting_comp.get_closest_target()
		if target != null:
			update_facing_from_vector(target.global_position - global_position)

	# Physics
	move_and_slide()

	update_animation()


func _exit_tree() -> void:
	HitPauseManager.force_restore()


# -------------------------------------------------------------------
# INITIALISATION COMPOSANTS
# -------------------------------------------------------------------

func _initialize_components() -> void:
	# HealthBarComponent
	health_bar_comp.initialize(health_bar, health_bar_ghost, max_hp, hp)

	# TargetingSystem
	var target_group := ""
	if is_player or autonomous:
		target_group = "enemy"
	elif is_enemy:
		target_group = "player"
	targeting_comp.initialize(self, target_group)

	# CombatFeedback
	feedback_comp.initialize(visual)


# -------------------------------------------------------------------
# DÉPLACEMENTS
# -------------------------------------------------------------------

func player_move() -> void:
	if is_attacking:
		velocity = Vector2.ZERO
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * move_speed


func autonomous_move_and_fight() -> void:
	# Garde la cible tant qu'elle est vivante
	if not targeting_comp.is_target_valid(current_target):
		current_target = targeting_comp.get_closest_target()

	if current_target == null:
		velocity = Vector2.ZERO
		return

	var to_target := current_target.global_position - global_position
	var dist := to_target.length()

	update_facing_from_vector(to_target)

	if dist <= attack_range:
		velocity = Vector2.ZERO
		try_attack(current_target)
		return

	velocity = Vector2.ZERO if is_attacking else to_target.normalized() * move_speed


func enemy_move() -> void:
	if is_attacking:
		velocity = Vector2.ZERO
		return

	var target := targeting_comp.get_closest_target()
	if target == null:
		velocity = Vector2.ZERO
		return

	current_target = target

	var to_target := target.global_position - global_position
	var dist := to_target.length()

	update_facing_from_vector(to_target)

	if dist <= attack_range:
		velocity = Vector2.ZERO
		try_attack(target)
		return

	velocity = to_target.normalized() * move_speed


# -------------------------------------------------------------------
# ATTAQUE / DÉGÂTS / MORT
# -------------------------------------------------------------------

func try_attack(target: Node2D) -> void:
	if is_dead or is_attacking or attack_timer > 0.0 or target == null:
		return

	attack_timer = attack_cooldown
	is_attacking = true

	var to_target := target.global_position - global_position
	if to_target.length() > 0.1:
		update_facing_from_vector(to_target)

	play_attack_animation()

	# Dégâts sans hitbox (proto)
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, self)


func play_attack_animation() -> void:
	var frames := visual.sprite_frames
	if frames == null:
		is_attacking = false
		return

	var anim := "slash_" + facing

	# Fallback
	if not frames.has_animation(anim):
		if frames.has_animation("slash_down"):
			anim = "slash_down"
		else:
			is_attacking = false
			return

	visual.play(anim)


func _on_animation_finished() -> void:
	# Fin de slash
	if visual.animation.begins_with("slash_"):
		is_attacking = false

	# Fin death
	if visual.animation == "death" and is_dead:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.25)
		tween.finished.connect(func():
			if is_instance_valid(self):
				queue_free()
		)


func take_damage(amount: int, from: Node2D = null) -> void:
	if is_dead or feedback_comp.is_invulnerable():
		return

	var previous_hp := hp
	hp = clamp(hp - amount, 0, max_hp)

	# Feedbacks via composant
	if from != null and from is Node2D:
		feedback_comp.apply_damage_feedback(from.global_position, global_position)
	else:
		feedback_comp.apply_flash()

	# Met à jour la barre de vie
	health_bar_comp.update_bars(max_hp, hp, previous_hp)

	if hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	current_target = null

	velocity = Vector2.ZERO
	feedback_comp.reset()

	# Cache les barres
	health_bar_comp.hide_bars()

	# Désactive collision
	if is_instance_valid(body_collision):
		body_collision.disabled = true

	# Anim death
	var frames := visual.sprite_frames
	if frames != null and frames.has_animation("death"):
		visual.play("death")
	else:
		# Fallback fade direct
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.25)
		tween.finished.connect(func():
			if is_instance_valid(self):
				queue_free()
		)


# -------------------------------------------------------------------
# ANIMATIONS / ORIENTATION
# -------------------------------------------------------------------

func update_facing_from_vector(v: Vector2) -> void:
	if v.length() < 0.001:
		return

	if abs(v.x) > abs(v.y):
		facing = "right" if v.x > 0 else "left"
	else:
		facing = "down" if v.y > 0 else "up"


func update_animation() -> void:
	if is_dead or is_attacking:
		return

	var moving := velocity.length() > 1.0

	# Recalcul du facing uniquement pour joueur manuel
	if moving and (not autonomous) and (not is_enemy):
		var knockbacking := feedback_comp.get_knockback_velocity().length() > 1.0
		if (not facing_lock_on_knockback) or (not knockbacking):
			update_facing_from_vector(velocity)

	var frames := visual.sprite_frames
	if frames == null:
		return

	var anim := ("walk_" if moving else "idle_") + facing
	if frames.has_animation(anim) and visual.animation != anim:
		visual.play(anim)
