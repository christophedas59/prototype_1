extends "res://scripts/abilities/warrior/warrior_ability_base.gd"

const DAMAGE_RATIO := 0.8
const STUN_DURATION := 1.2
const HIT_PAUSE_DURATION := 0.06
const HIT_PAUSE_SCALE := 0.25

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

	if not _apply_damage(caster, target, DAMAGE_RATIO):
		return false

	_apply_stun(target, STUN_DURATION)
	_request_hit_pause(HIT_PAUSE_DURATION, HIT_PAUSE_SCALE)
	return true
