extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")
const GridCombatSystemScript := preload("res://scripts/systems/grid_combat_system.gd")


func test_basic_cell_reservation_and_release() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	add_child_autofree(system)
	system.cell_size = 32.0

	var entity := Node2D.new()
	add_child_autofree(entity)
	entity.global_position = Vector2(64, 32)

	var cell := system.world_to_cell(entity.global_position)
	assert_eq(cell, Vector2i(2, 1))
	assert_true(system.is_cell_free(cell))
	assert_true(system.reserve_cell(cell, entity))
	assert_false(system.is_cell_free(cell))

	system.release_cell(cell)
	assert_true(system.is_cell_free(cell))


func test_fifth_attacker_gets_waiting_cell_when_four_adjacent_slots_are_taken() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	add_child_autofree(system)
	system.cell_size = 32.0

	var target := Node2D.new()
	add_child_autofree(target)
	target.global_position = Vector2(320, 320)
	system.reserve_cell(system.world_to_cell(target.global_position), target)

	var attackers: Array[Node2D] = []
	for i in range(5):
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		attackers.append(attacker)

	var assigned_cells: Array[Vector2i] = []
	for attacker in attackers:
		assigned_cells.append(system.assign_attack_slot(attacker, target))

	var target_cell := system.world_to_cell(target.global_position)
	var adjacent_count := 0
	for i in range(4):
		var offset := assigned_cells[i] - target_cell
		if abs(offset.x) + abs(offset.y) == 1:
			adjacent_count += 1
	assert_eq(adjacent_count, 4, "Les 4 premiers attaquants doivent occuper les slots adjacents")

	var waiting_offset := assigned_cells[4] - target_cell
	assert_true(abs(waiting_offset.x) > 1 or abs(waiting_offset.y) > 1, "Le 5e attaquant doit attendre sur l'anneau externe")


func test_waiting_attacker_moves_to_adjacent_slot_when_slot_becomes_free() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	add_child_autofree(system)
	system.cell_size = 32.0

	var target := Node2D.new()
	add_child_autofree(target)
	target.global_position = Vector2(256, 256)
	system.reserve_cell(system.world_to_cell(target.global_position), target)

	var attackers: Array[Node2D] = []
	for i in range(5):
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		attackers.append(attacker)
		system.assign_attack_slot(attacker, target)

	var waiting_cell_before := system.get_assigned_cell(attackers[4])
	var target_cell := system.world_to_cell(target.global_position)
	var waiting_offset_before := waiting_cell_before - target_cell
	assert_true(abs(waiting_offset_before.x) > 1 or abs(waiting_offset_before.y) > 1)

	system.notify_entity_died(attackers[0])

	var waiting_cell_after := system.get_assigned_cell(attackers[4])
	var waiting_offset_after := waiting_cell_after - target_cell
	assert_eq(abs(waiting_offset_after.x) + abs(waiting_offset_after.y), 1, "Un attaquant en attente doit avancer sur un slot libéré")


func test_combat_entity_die_releases_reserved_grid_slot() -> void:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	add_child_autofree(system)
	system.cell_size = 32.0

	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.global_position = Vector2(96, 96)

	await get_tree().process_frame

	var entity_cell := system.world_to_cell(entity.global_position)
	assert_false(system.is_cell_free(entity_cell), "La cellule doit être réservée au spawn")

	entity.die()
	await get_tree().process_frame

	assert_true(system.is_cell_free(entity_cell), "La cellule doit être libérée à la mort")
