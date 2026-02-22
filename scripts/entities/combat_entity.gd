extends CharacterBody2D
class_name CombatEntity
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

@onready var health_bar_comp: HealthBarComponent = $HealthBarComponent
@onready var targeting_comp: TargetingSystem = $TargetingSystem
@onready var feedback_comp: CombatFeedback = $CombatFeedback
@onready var hurtbox_comp: HurtboxComponent = $Hurtbox
@onready var melee_hitbox_comp: MeleeHitboxComponent = $AttackHitbox
@onready var ability_system: Node = get_node_or_null("AbilitySystem")
var grid_combat_system: GridCombatSystem = null

const DEBUG_HITS := false


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
@export var health_bar_style: HealthBarComponent.HealthBarStyle = HealthBarComponent.HealthBarStyle.ENEMY

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
var ability_control_locked: bool = false
var stun_remaining: float = 0.0
var forced_target: CombatEntity = null
var forced_target_remaining: float = 0.0

var current_target: CombatEntity = null
var _last_grid_cell: Vector2i = Vector2i.ZERO


# -------------------------------------------------------------------
# CONTRAT PUBLIC (pour composants/IA externes)
# -------------------------------------------------------------------

func is_alive() -> bool:
	"""Contrat explicite : indique si l'entité est vivante."""
	return not is_dead


func get_team() -> String:
	"""Contrat explicite : expose la faction logique de l'entité."""
	if is_player or autonomous:
		return "player"
	if is_enemy:
		return "enemy"
	return "neutral"


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

	if not hurtbox_comp.hit_received.is_connected(_on_hurtbox_hit_received):
		hurtbox_comp.hit_received.connect(_on_hurtbox_hit_received)

	grid_combat_system = _resolve_grid_combat_system()
	_register_to_grid_system()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Update composants
	targeting_comp.update(delta)
	feedback_comp.update(delta)

	# Timers
	attack_timer = max(attack_timer - delta, 0.0)
	stun_remaining = max(stun_remaining - delta, 0.0)
	forced_target_remaining = max(forced_target_remaining - delta, 0.0)
	if forced_target_remaining <= 0.0:
		forced_target = null

	if stun_remaining > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		update_animation()
		return

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
	_sync_grid_reservation_from_world_position()

	update_animation()


# -------------------------------------------------------------------
# INITIALISATION COMPOSANTS
# -------------------------------------------------------------------

func _initialize_components() -> void:
	# HealthBarComponent
	health_bar_comp.health_bar_style = health_bar_style
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
	if ability_control_locked:
		velocity = Vector2.ZERO
		return

	# Garde la cible tant qu'elle est vivante
	if not targeting_comp.is_target_valid(current_target):
		current_target = _as_combat_entity(targeting_comp.get_closest_target())

	if current_target == null:
		velocity = Vector2.ZERO
		return

	var to_target := current_target.global_position - global_position
	var dist := to_target.length()
	var trigger_range := _get_attack_trigger_range(current_target)

	update_facing_from_vector(to_target)

	if dist <= trigger_range:
		velocity = Vector2.ZERO
		try_attack(current_target)
		return

	velocity = Vector2.ZERO if is_attacking else to_target.normalized() * move_speed


func enemy_move() -> void:
	if is_attacking:
		velocity = Vector2.ZERO
		return

	var target := forced_target if targeting_comp.is_target_valid(forced_target) else _as_combat_entity(targeting_comp.get_closest_target())
	if target == null:
		velocity = Vector2.ZERO
		return

	current_target = target

	var target_position := target.global_position
	if grid_combat_system == null:
		grid_combat_system = _resolve_grid_combat_system()
	if grid_combat_system != null:
		var assigned_cell := grid_combat_system.assign_attack_slot(self, target)
		target_position = grid_combat_system.cell_to_world(assigned_cell)

	var to_target := target_position - global_position
	var dist := to_target.length()
	var trigger_range := _get_attack_trigger_range(target)

	update_facing_from_vector(to_target)

	if dist <= trigger_range and _can_attack_current_target_in_grid(target):
		velocity = Vector2.ZERO
		try_attack(target)
		return

	velocity = to_target.normalized() * move_speed


func _as_combat_entity(target: Node2D) -> CombatEntity:
	if target == null or not (target is CombatEntity):
		return null
	return target as CombatEntity


# -------------------------------------------------------------------
# ATTAQUE / DÉGÂTS / MORT
# -------------------------------------------------------------------

func try_attack(target: CombatEntity) -> void:
	if ability_control_locked or is_dead or is_attacking or attack_timer > 0.0 or target == null:
		return
	if not _is_target_in_attack_range(target):
		return

	attack_timer = attack_cooldown
	is_attacking = true

	var to_target := target.global_position - global_position
	if to_target.length() > 0.1:
		update_facing_from_vector(to_target)

	play_attack_animation()

	# Déclenche la hitbox de mêlée (détection via hurtbox + événements)
	if DEBUG_HITS:
		print_debug(
			"[hits] try_attack/start_swing",
			self,
			"target=", target,
			"dist=", global_position.distance_to(target.global_position),
			"trigger_range=", _get_attack_trigger_range(target),
			"time_scale=", Engine.time_scale,
			"hit_pause_scale=", feedback_comp.hit_pause_scale,
			"hitbox layer/mask=", str(melee_hitbox_comp.collision_layer) + "/" + str(melee_hitbox_comp.collision_mask),
			"hurtbox layer/mask=", str(target.hurtbox_comp.collision_layer) + "/" + str(target.hurtbox_comp.collision_mask),
			"hitbox monitoring=", melee_hitbox_comp.monitoring,
			"hurtbox monitoring=", target.hurtbox_comp.monitoring
		)
	melee_hitbox_comp.start_swing(self, attack_damage)




func apply_temporary_stun(duration: float) -> void:
	stun_remaining = max(stun_remaining, duration)
	velocity = Vector2.ZERO


func apply_forced_target(target: CombatEntity, duration: float) -> void:
	if target == null:
		return
	forced_target = target
	forced_target_remaining = max(forced_target_remaining, duration)


func set_ability_control_locked(is_locked: bool) -> void:
	ability_control_locked = is_locked
	if ability_control_locked:
		velocity = Vector2.ZERO



func _is_target_in_attack_range(target: CombatEntity) -> bool:
	if target == null:
		return false

	var dist := global_position.distance_to(target.global_position)
	return dist <= _get_attack_trigger_range(target)


func _get_attack_trigger_range(target: CombatEntity) -> float:
	"""
	Évite la zone morte entre portée logique et portée collision réelle.
	On limite la portée de déclenchement au contact hitbox/hurtbox si connu.
	"""
	var contact_range := _get_melee_contact_range(target)
	if contact_range <= 0.0:
		return attack_range

	return min(attack_range, contact_range)


func _get_melee_contact_range(target: CombatEntity) -> float:
	if target == null or not is_instance_valid(melee_hitbox_comp):
		return -1.0

	var attack_radius := _get_area_circle_radius(melee_hitbox_comp)
	if attack_radius <= 0.0:
		return -1.0

	if not is_instance_valid(target.hurtbox_comp):
		return -1.0

	var hurtbox_radius := _get_area_circle_radius(target.hurtbox_comp)
	if hurtbox_radius <= 0.0:
		return -1.0

	return attack_radius + hurtbox_radius


func _get_area_circle_radius(area: Area2D) -> float:
	if area == null:
		return -1.0

	for child in area.get_children():
		if child is CollisionShape2D:
			var collision := child as CollisionShape2D
			if collision.shape is CircleShape2D:
				return (collision.shape as CircleShape2D).radius

	return -1.0



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




func _on_hurtbox_hit_received(attacker: Node2D, amount: int, _hit_position: Vector2) -> void:
	if DEBUG_HITS:
		print_debug("[hits] entity handler hit_received", self, attacker, amount)
	take_damage(amount, attacker)

func take_damage(amount: int, from: Node2D = null) -> void:
	if DEBUG_HITS:
		print_debug("[hits] take_damage called", self, "invuln?", feedback_comp.is_invulnerable(), "hp", hp, "amount", amount)
	if is_dead:
		if DEBUG_HITS:
			print_debug("[hits] take_damage early-return is_dead", self)
		return
	if feedback_comp.is_invulnerable():
		if DEBUG_HITS:
			print_debug("[hits] take_damage early-return invulnerable", self)
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
	_release_grid_allocations()

	# Cache les barres
	health_bar_comp.hide_bars()

	# Désactive collision
	if is_instance_valid(body_collision):
		body_collision.set_deferred("disabled", true)

	if is_instance_valid(hurtbox_comp):
		hurtbox_comp.monitoring = false
		if DEBUG_HITS:
			print_debug("[hits] hurtbox monitoring changed", self, hurtbox_comp.monitoring)
	if is_instance_valid(melee_hitbox_comp):
		melee_hitbox_comp.monitoring = false
		if DEBUG_HITS:
			print_debug("[hits] hitbox monitoring changed", self, melee_hitbox_comp.monitoring)

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
		var knockbacking: bool = feedback_comp.get_knockback_velocity().length() > 1.0
		if (not facing_lock_on_knockback) or (not knockbacking):
			update_facing_from_vector(velocity)

	var frames := visual.sprite_frames
	if frames == null:
		return

	var anim := ("walk_" if moving else "idle_") + facing
	if frames.has_animation(anim) and visual.animation != anim:
		visual.play(anim)


func _resolve_grid_combat_system() -> GridCombatSystem:
	var systems := get_tree().get_nodes_in_group("grid_combat_system")
	if not systems.is_empty():
		return systems[0] as GridCombatSystem

	var parent := get_parent()
	while parent != null:
		var candidate := parent.get_node_or_null("GridCombatSystem")
		if candidate != null and candidate is GridCombatSystem:
			return candidate as GridCombatSystem
		parent = parent.get_parent()

	return null


func _register_to_grid_system() -> void:
	if grid_combat_system == null:
		return

	_last_grid_cell = grid_combat_system.world_to_cell(global_position)
	grid_combat_system.reserve_cell(_last_grid_cell, self)


func _sync_grid_reservation_from_world_position() -> void:
	if grid_combat_system == null:
		grid_combat_system = _resolve_grid_combat_system()
	if grid_combat_system == null or is_dead:
		return

	var current_cell := grid_combat_system.world_to_cell(global_position)
	if current_cell == _last_grid_cell:
		return

	if grid_combat_system.reserve_cell(current_cell, self):
		_last_grid_cell = current_cell


func _release_grid_allocations() -> void:
	if grid_combat_system == null:
		return
	grid_combat_system.notify_entity_died(self)


func _can_attack_current_target_in_grid(target: CombatEntity) -> bool:
	if grid_combat_system == null:
		return true
	if not is_enemy:
		return true

	var attacker_cell := grid_combat_system.world_to_cell(global_position)
	var target_cell := grid_combat_system.world_to_cell(target.global_position)
	var offset := attacker_cell - target_cell
	return abs(offset.x) + abs(offset.y) == 1 and grid_combat_system.attacker_has_adjacent_slot(self)
