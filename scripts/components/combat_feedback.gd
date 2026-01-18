extends Node
##
## CombatFeedback.gd — Composant réutilisable pour feedback de combat
## Godot 4.5.x
##
## Gère :
## - Flash visuel lors de dégâts (tween réutilisé)
## - Knockback (recul physique)
## - I-frames (invincibilité temporaire)
## - Hit-pause (via HitPauseManager singleton)
##

# -------------------------------------------------------------------
# EXPORTS
# -------------------------------------------------------------------

@export var i_frames_duration: float = 0.25
@export var knockback_force: float = 140.0
@export var knockback_friction: float = 800.0
@export var enable_hit_pause: bool = true
@export var hit_pause_duration: float = 0.04
@export var hit_pause_scale: float = 0.05
@export var flash_color: Color = Color(1.0, 0.6, 0.6)
@export var flash_duration: float = 0.08


# -------------------------------------------------------------------
# ÉTAT INTERNE
# -------------------------------------------------------------------

var invuln_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var _flash_tween: Tween = null
var _visual: Node2D = null  # Référence au sprite/visual


# -------------------------------------------------------------------
# INITIALISATION
# -------------------------------------------------------------------

func initialize(visual_node: Node2D) -> void:
	"""Doit être appelé par le parent après _ready()"""
	_visual = visual_node


# -------------------------------------------------------------------
# UPDATE (appelé depuis _physics_process du parent)
# -------------------------------------------------------------------

func update(delta: float) -> void:
	"""Met à jour les timers et knockback"""
	invuln_timer = max(invuln_timer - delta, 0.0)

	# Décroissance du knockback
	if knockback_velocity.length() > 0.1:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)


# -------------------------------------------------------------------
# API PUBLIQUE
# -------------------------------------------------------------------

func is_invulnerable() -> bool:
	"""Retourne true si les i-frames sont actives"""
	return invuln_timer > 0.0


func apply_damage_feedback(attacker_position: Vector2, entity_position: Vector2) -> void:
	"""Applique tous les feedbacks lors de dégâts"""
	# Active les i-frames
	invuln_timer = i_frames_duration

	# Hit-pause global
	if enable_hit_pause:
		HitPauseManager.request_hit_pause(hit_pause_duration, hit_pause_scale)

	# Knockback
	var dir := (entity_position - attacker_position).normalized()
	knockback_velocity = dir * knockback_force

	# Flash visuel
	apply_flash()


func apply_flash() -> void:
	"""Flash rouge rapide sur le sprite"""
	if not is_instance_valid(_visual):
		return

	# Réutilisation du tween (optimisation)
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()

	_visual.modulate = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_interval(flash_duration)
	_flash_tween.tween_property(_visual, "modulate", Color.WHITE, 0.0)


func get_knockback_velocity() -> Vector2:
	"""Retourne la vitesse de knockback actuelle"""
	return knockback_velocity


func reset() -> void:
	"""Réinitialise tous les feedbacks (utile à la mort)"""
	invuln_timer = 0.0
	knockback_velocity = Vector2.ZERO

	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()

	if is_instance_valid(_visual):
		_visual.modulate = Color.WHITE
