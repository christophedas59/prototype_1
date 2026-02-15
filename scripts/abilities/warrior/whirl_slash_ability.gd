extends "res://scripts/abilities/warrior/warrior_ability_base.gd"

const DAMAGE_RATIO := 0.6

func _init() -> void:
	name = "Whirl Slash"
	icon_path = "res://assets/sprites/ui/icons/abilities/warrior/whirl_slash.png"
	cooldown = 12.0
	targeting_type = TargetingType.INSTANT_AOE
	radius = 2.6 * WORLD_UNIT_TO_PIXELS


func _cast(caster: CombatEntity, cast_context: Dictionary) -> bool:
	var targets: Array = cast_context.get("targets", [])
	if targets.is_empty():
		targets = _collect_targets_in_radius(caster)

	var hit_count := 0
	for candidate in targets:
		if not (candidate is CombatEntity):
			continue
		var target := candidate as CombatEntity
		if target == caster or not target.is_alive():
			continue
		if caster.global_position.distance_to(target.global_position) > radius:
			continue

		if _apply_damage(caster, target, DAMAGE_RATIO):
			hit_count += 1

	return hit_count > 0


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
