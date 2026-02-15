extends WarriorAbilityBase
class_name ShieldSlamAbility

const DAMAGE_RATIO := 0.8
const STUN_DURATION := 1.2
const HIT_PAUSE_DURATION := 0.045
const HIT_PAUSE_SCALE := 0.22

func _init() -> void:
	name = "Shield Slam"
	icon_path = "res://assets/sprites/ui/components/icons/ui_icon_signal.png"
	cooldown = 5.0
	targeting_type = TargetingType.TARGETED
	range = 1.6 * WORLD_UNIT_TO_PIXELS


func _cast(caster: CombatEntity, cast_context: Dictionary) -> bool:
	var target: CombatEntity = cast_context.get("target")
	if target == null or not target.is_alive():
		return false
	if caster.global_position.distance_to(target.global_position) > range:
		return false

	if not _apply_damage(caster, target, DAMAGE_RATIO):
		return false

	_apply_stun(target, STUN_DURATION)
	_request_hit_pause(HIT_PAUSE_DURATION, HIT_PAUSE_SCALE)
	return true
