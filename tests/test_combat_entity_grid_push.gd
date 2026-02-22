extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")
const GridCombatSystemScript := preload("res://scripts/systems/grid_combat_system.gd")


func _spawn_grid_entity(system: GridCombatSystem, pos: Vector2) -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	entity.grid_combat_system = system
	entity.grid_mode = true
	add_child_autofree(entity)
	entity.global_position = pos
	return entity


func test_grid_mode_disables_continuous_knockback_velocity() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	entity.grid_mode = true
	add_child_autofree(entity)

	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2(64, 0)

	await get_tree().process_frame
	entity.feedback_comp.enable_hit_pause = false

	entity.take_damage(1, attacker)
	assert_eq(entity.feedback_comp.get_knockback_velocity(), Vector2.ZERO, "Le knockback continu doit rester nul en mode grille")


func test_grid_mode_pushes_one_cardinal_cell_if_destination_is_free() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	system.cell_size = 32.0
	add_child_autofree(system)

	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2.ZERO
	system.reserve_cell(system.world_to_cell(attacker.global_position), attacker)

	var target := _spawn_grid_entity(system, Vector2(32, 0))

	await get_tree().process_frame
	target.feedback_comp.enable_hit_pause = false

	target.take_damage(1, attacker)

	assert_eq(target.global_position, Vector2(64, 0), "La cible doit être poussée d'une case opposée à l'attaquant")
	assert_false(system.is_cell_free(Vector2i(2, 0)), "La case poussée doit être réservée")


func test_grid_mode_does_not_push_when_destination_cell_is_blocked() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	system.cell_size = 32.0
	add_child_autofree(system)

	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2.ZERO
	system.reserve_cell(system.world_to_cell(attacker.global_position), attacker)

	var blocker := Node2D.new()
	add_child_autofree(blocker)
	blocker.global_position = Vector2(64, 0)
	system.reserve_cell(system.world_to_cell(blocker.global_position), blocker)

	var target := _spawn_grid_entity(system, Vector2(32, 0))

	await get_tree().process_frame
	target.feedback_comp.enable_hit_pause = false

	target.take_damage(1, attacker)

	assert_eq(target.global_position, Vector2(32, 0), "La cible ne doit pas être déplacée si la case de push est occupée")
	assert_eq(system.world_to_cell(target.global_position), Vector2i(1, 0), "La cible doit rester sur sa cellule d'origine")
