extends RefCounted

## Convention partagée pour les capacités Warrior.
## - Cooldown démarre uniquement à la validation du cast.
## - Une annulation ne démarre pas le cooldown.

const WORLD_UNIT_TO_PIXELS := 20.0

enum TargetingType {
	TARGETED,
	INSTANT_AOE,
	DIRECTIONAL
}

var name: String = ""
var icon_path: String = ""
var cooldown: float = 0.0
var targeting_type: TargetingType = TargetingType.TARGETED

# Distances exprimées en pixels pour le pipeline runtime.
var cast_range: float = 0.0
var radius: float = 0.0
var max_distance: float = 0.0

var _cooldown_remaining: float = 0.0
var _is_targeting: bool = false


func begin_targeting() -> bool:
	if is_on_cooldown():
		return false
	_is_targeting = true
	return true


func cancel_targeting() -> void:
	_is_targeting = false


func validate_cast(caster: CombatEntity, cast_context: Dictionary = {}) -> bool:
	if caster == null or is_on_cooldown() or not _is_targeting:
		return false

	var cast_success := _cast(caster, cast_context)
	if not cast_success:
		return false

	_is_targeting = false
	_cooldown_remaining = cooldown
	return true


func force_cast(caster: CombatEntity, cast_context: Dictionary = {}) -> bool:
	"""Utilitaire pour capacités instantanées sans phase de ciblage UI."""
	if not begin_targeting():
		return false
	return validate_cast(caster, cast_context)


func update_cooldown(delta: float) -> void:
	_cooldown_remaining = max(_cooldown_remaining - delta, 0.0)


func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.0


func get_cooldown_remaining() -> float:
	return _cooldown_remaining


func _cast(_caster: CombatEntity, _cast_context: Dictionary) -> bool:
	return false


func _scaled_damage(caster: CombatEntity, ratio: float) -> int:
	if caster == null:
		return 0
	return max(1, int(round(caster.attack_damage * ratio)))


func _apply_damage(caster: CombatEntity, target: CombatEntity, ratio: float) -> bool:
	if caster == null or target == null or not target.is_alive():
		return false

	target.take_damage(_scaled_damage(caster, ratio), caster)
	return true


func _apply_stun(target: CombatEntity, stun_duration: float) -> void:
	if target == null or stun_duration <= 0.0:
		return

	if target.has_method("apply_temporary_stun"):
		target.apply_temporary_stun(stun_duration)
		return

	# Fallback non-intrusif en attendant un composant de crowd control dédié.
	target.set_meta("stunned_until_msec", Time.get_ticks_msec() + int(stun_duration * 1000.0))


func _request_hit_pause(duration: float, time_scale: float) -> void:
	if duration <= 0.0:
		return

	HitPauseManager.request_hit_pause(duration, time_scale)
