extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_enemy_grid_movement_uses_single_cardinal_step() -> void:
	var enemy: CombatEntity = CombatEntityScene.instantiate()
	enemy.is_enemy = true
	enemy.use_grid_movement = true
	enemy.cell_size = Vector2(16.0, 16.0)
	enemy.step_duration = 0.05
	add_child_autofree(enemy)

	var target: CombatEntity = CombatEntityScene.instantiate()
	target.is_player = true
	target.use_grid_movement = true
	add_child_autofree(target)

	enemy.global_position = Vector2(8.0, 8.0)
	target.global_position = Vector2(56.0, 56.0)

	await get_tree().process_frame
	enemy.apply_forced_target(target, 1.0)

	enemy.enemy_move()
	assert_eq(enemy.facing, "down", "L'ennemi doit choisir un seul axe cardinal (Y prioritaire)")

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_eq(enemy.global_position, Vector2(8.0, 24.0), "Le premier step doit avancer d'une seule cellule sans diagonale")
