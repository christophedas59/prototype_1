extends "res://scripts/abilities/warrior/warrior_ability_base.gd"

var damage_ratio: float = 0.8
var stun_duration: float = 1.2
var hit_pause_duration: float = 0.06
var hit_pause_scale: float = 0.25

func _init() -> void:
	name = "Shield Slam"
	icon_path = "res://assets/sprites/ui/icons/abilities/warrior/shield_slam.png"
	cooldown = 10.0
	targeting_type = TargetingType.TARGETED
	cast_range = 1.6 * WORLD_UNIT_TO_PIXELS


func _cast(caster: CombatEntity, cast_context: Dictionary) -> bool:
	var target: CombatEntity = cast_context.get("target")
	if target == null or not target.is_alive():
		return false
	if caster.global_position.distance_to(target.global_position) > cast_range:
		return false

	if not _apply_damage(caster, target, damage_ratio):
		return false

	_apply_stun(target, stun_duration)
	_request_hit_pause(hit_pause_duration, hit_pause_scale)
	return true
