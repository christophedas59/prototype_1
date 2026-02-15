extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_request_cast_locks_controls_and_prevents_basic_attack() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.autonomous = true
	entity.is_player = true

	var target: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(target)
	target.is_enemy = true
	target.global_position = entity.global_position

	await get_tree().process_frame

	var ability = entity.get_node("AbilitySystem")
	assert_not_null(ability, "Le système d'abilities doit être présent sur l'entité de combat")

	var request_result: bool = ability.request_cast(0)
	assert_true(request_result, "Le cast doit pouvoir démarrer en mode AUTO")
	assert_true(entity.ability_control_locked, "Le lock IA doit être actif pendant TARGETING")

	entity.try_attack(target)
	assert_false(entity.is_attacking, "Une attaque auto ne doit pas démarrer si le lock d'ability est actif")

	var confirm_result: bool = ability.confirm_target({"target": target})
	assert_true(confirm_result, "La confirmation de cible doit terminer le cast")
	assert_false(entity.ability_control_locked, "Le lock IA doit être retiré après le cast")


func test_cancel_targeting_releases_control_lock() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	await get_tree().process_frame

	var ability = entity.get_node("AbilitySystem")
	ability.request_cast(0)
	assert_true(entity.ability_control_locked, "Le lock doit être actif pendant TARGETING")

	ability.cancel_targeting()
	assert_false(entity.ability_control_locked, "Annuler le targeting doit rendre la main à l'autobattler")


func test_exported_warrior_parameters_are_applied_to_ability_slots() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	var ability_system := entity.get_node("AbilitySystem")
	ability_system.shield_slam_cooldown = 7.5
	ability_system.shield_slam_range_units = 2.1
	ability_system.shield_slam_damage_ratio = 1.4
	ability_system.whirl_slash_radius_units = 3.4
	ability_system.heroic_charge_max_distance_units = 6.2
	ability_system.taunt_shout_duration = 5.8
	add_child_autofree(entity)

	await get_tree().process_frame

	var slots: Array = ability_system.ability_slots
	assert_eq(slots.size(), 4, "Les 4 abilities warrior doivent être chargées")
	assert_eq(slots[0].cooldown, 7.5)
	assert_eq(slots[0].cast_range, 42.0)
	assert_eq(slots[0].damage_ratio, 1.4)
	assert_eq(slots[1].radius, 68.0)
	assert_eq(slots[2].max_distance, 124.0)
	assert_eq(slots[3].taunt_duration, 5.8)
