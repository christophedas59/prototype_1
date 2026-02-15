extends "res://scripts/abilities/warrior/warrior_ability_base.gd"

var taunt_duration: float = 4.0

func _init() -> void:
	name = "Taunt Shout"
	icon_path = "res://assets/sprites/ui/icons/abilities/warrior/taunt_shout.png"
	cooldown = 20.0
	targeting_type = TargetingType.INSTANT_AOE
	radius = 5.0 * WORLD_UNIT_TO_PIXELS


func _cast(caster: CombatEntity, cast_context: Dictionary) -> bool:
	var targets: Array = cast_context.get("targets", [])
	if targets.is_empty():
		targets = _collect_targets_in_radius(caster)

	var affected := 0
	for candidate in targets:
		if not (candidate is CombatEntity):
			continue
		var target := candidate as CombatEntity
		if target == caster or not target.is_alive():
			continue
		if caster.global_position.distance_to(target.global_position) > radius:
			continue

		if target.has_method("apply_forced_target"):
			target.apply_forced_target(caster, taunt_duration)
		else:
			target.set_meta("taunted_by", caster)
			target.set_meta("taunted_until_msec", Time.get_ticks_msec() + int(taunt_duration * 1000.0))
		target.feedback_comp.apply_flash()
		affected += 1

	return affected > 0


func _collect_targets_in_radius(caster: CombatEntity) -> Array:
	if caster == null or caster.get_parent() == null:
		return []

	var team := caster.get_team()
	var targets: Array = []
	for child in caster.get_parent().get_children():
		if not (child is CombatEntity):
			continue
		var entity := child as CombatEntity
		if entity == caster or not entity.is_alive() or entity.get_team() == team:
			continue
		targets.append(entity)

	return targets
