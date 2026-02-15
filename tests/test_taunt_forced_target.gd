extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func _spawn_entity() -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	return entity


func test_taunt_forces_target_to_warrior_then_releases_after_duration() -> void:
	var enemy := _spawn_entity()
	var warrior := _spawn_entity()

	await get_tree().process_frame

	enemy.apply_taunt(warrior, 0.5)

	assert_eq(enemy._get_priority_target(), warrior, "Taunt doit forcer la cible sur le warrior pendant sa durée")

	enemy._update_control_effects(0.6)

	assert_eq(enemy.forced_target, null, "La cible forcée doit être relâchée à la fin du taunt")
	assert_eq(enemy._get_priority_target(), null, "Sans cible disponible, la cible forcée ne doit plus persister")
