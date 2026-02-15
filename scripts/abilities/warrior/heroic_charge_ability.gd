extends "res://scripts/abilities/warrior/warrior_ability_base.gd"

const DAMAGE_RATIO := 1.2
const STUN_DURATION := 0.4

func _init() -> void:
	name = "Heroic Charge"
	icon_path = "res://assets/sprites/ui/icons/abilities/warrior/heroic_charge.png"
	cooldown = 15.0
	targeting_type = TargetingType.DIRECTIONAL
	max_distance = 5.5 * WORLD_UNIT_TO_PIXELS


func _cast(caster: CombatEntity, cast_context: Dictionary) -> bool:
	var direction: Vector2 = cast_context.get("direction", Vector2.ZERO)
	if direction.length() <= 0.001:
		return false
	direction = direction.normalized()

	var endpoint := caster.global_position + direction * max_distance
	var target := _find_first_collision_target(caster, cast_context, direction)
	if target != null:
		endpoint = target.global_position
		_apply_damage(caster, target, DAMAGE_RATIO)
		_apply_stun(target, STUN_DURATION)

	caster.global_position = endpoint
	return true


func _find_first_collision_target(caster: CombatEntity, cast_context: Dictionary, direction: Vector2) -> CombatEntity:
	var explicit_targets: Array = cast_context.get("targets_in_path", [])
	if explicit_targets.is_empty():
		explicit_targets = _collect_scene_candidates(caster)

	var nearest_target: CombatEntity = null
	var nearest_projection := max_distance + 1.0
	for candidate in explicit_targets:
		if not (candidate is CombatEntity):
			continue
		var target := candidate as CombatEntity
		if target == caster or not target.is_alive() or target.get_team() == caster.get_team():
			continue

		var offset := target.global_position - caster.global_position
		var projection := offset.dot(direction)
		if projection < 0.0 or projection > max_distance:
			continue

		var lateral_distance := (offset - direction * projection).length()
		if lateral_distance > caster.attack_range:
			continue

		if projection < nearest_projection:
			nearest_projection = projection
			nearest_target = target

	return nearest_target


func _collect_scene_candidates(caster: CombatEntity) -> Array:
	if caster == null or caster.get_parent() == null:
		return []

	var candidates: Array = []
	for child in caster.get_parent().get_children():
		if child is CombatEntity:
			candidates.append(child)
	return candidates
