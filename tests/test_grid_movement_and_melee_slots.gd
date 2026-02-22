extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")
const GridCombatSystemScript := preload("res://scripts/systems/grid_combat_system.gd")


func _spawn_system() -> GridCombatSystem:
	var system: GridCombatSystem = GridCombatSystemScript.new()
	system.cell_size = 32.0
	add_child_autofree(system)
	return system


func _spawn_entity(system: GridCombatSystem, position: Vector2, as_player := false, as_enemy := false) -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	entity.grid_combat_system = system
	entity.grid_mode = true
	entity.is_player = as_player
	entity.is_enemy = as_enemy
	add_child_autofree(entity)
	entity.global_position = position
	return entity


func test_grid_movement_blocks_diagonal_input_for_player_and_ai() -> void:
	var system := _spawn_system()
	var player := _spawn_entity(system, Vector2.ZERO, true, false)

	Input.action_press("move_right")
	Input.action_press("move_down")
	player.player_move()
	Input.action_release("move_right")
	Input.action_release("move_down")

	assert_true(player.velocity.x == 0.0 or player.velocity.y == 0.0, "Le joueur en grille ne doit jamais produire une vélocité diagonale")
	assert_ne(player.velocity, Vector2.ZERO)

	var enemy := _spawn_entity(system, Vector2(64, 64), false, true)
	var target := _spawn_entity(system, Vector2.ZERO, true, false)
	await get_tree().process_frame

	enemy.forced_target = target
	enemy.enemy_move()

	assert_true(enemy.velocity.x == 0.0 or enemy.velocity.y == 0.0, "L'IA en grille doit se déplacer cardinalement")
	assert_ne(enemy.velocity, Vector2.ZERO)


func test_grid_movement_advances_cell_by_cell_and_stops_at_cell_center() -> void:
	var system := _spawn_system()
	var player := _spawn_entity(system, Vector2.ZERO, true, false)

	Input.action_press("move_right")
	player.player_move()
	Input.action_release("move_right")
	assert_eq(player.velocity, Vector2(player.move_speed, 0.0), "Le déplacement doit viser la case suivante")

	player.global_position = Vector2(31.3, 0)
	player.player_move()
	assert_eq(player.velocity, Vector2(player.move_speed, 0.0), "Le déplacement doit continuer tant que le centre de case n'est pas atteint")

	player.global_position = Vector2(32.0, 0)
	player.player_move()
	assert_eq(player.global_position, Vector2(32.0, 0), "L'entité doit s'arrêter exactement au centre de la case")
	assert_eq(player.velocity, Vector2.ZERO, "Une fois la case atteinte, la vélocité doit retomber à zéro")


func test_only_four_adjacent_attackers_can_occupy_melee_slots_others_wait() -> void:
	var system := _spawn_system()
	var target := Node2D.new()
	add_child_autofree(target)
	target.global_position = Vector2(320, 320)
	system.reserve_cell(system.world_to_cell(target.global_position), target)

	var attackers: Array[Node2D] = []
	for i in range(5):
		var attacker := Node2D.new()
		add_child_autofree(attacker)
		attackers.append(attacker)

	for i in range(5):
		system.assign_attack_slot(attackers[i], target)

	var target_cell := system.world_to_cell(target.global_position)
	var adjacent_assignments := 0
	for i in range(4):
		var offset := system.get_assigned_cell(attackers[i]) - target_cell
		if abs(offset.x) + abs(offset.y) == 1:
			adjacent_assignments += 1

	assert_eq(adjacent_assignments, 4)
	assert_true(system.attacker_has_adjacent_slot(attackers[3]))
	assert_false(system.attacker_has_adjacent_slot(attackers[4]), "Le 5e attaquant doit rester en attente")


func test_waiting_slot_is_reassigned_when_an_adjacent_attacker_dies() -> void:
	var system := _spawn_system()
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

	assert_false(system.attacker_has_adjacent_slot(attackers[4]))
	system.notify_entity_died(attackers[0])
	assert_true(system.attacker_has_adjacent_slot(attackers[4]), "Un slot libéré doit être réattribué à un attaquant en attente")


func test_attack_range_only_accepts_cardinal_adjacency() -> void:
	var system := _spawn_system()
	var attacker := _spawn_entity(system, Vector2(32, 0), true, false)
	var target := _spawn_entity(system, Vector2.ZERO, false, true)
	await get_tree().process_frame

	assert_true(attacker._is_target_in_attack_range(target))

	target.global_position = Vector2(64, 32)
	assert_false(attacker._is_target_in_attack_range(target), "La diagonale ne doit pas être considérée dans la portée de mêlée")


func test_grid_knockback_is_disabled_or_applies_single_cell_push() -> void:
	var no_push_system := _spawn_system()
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2.ZERO
	no_push_system.reserve_cell(no_push_system.world_to_cell(attacker.global_position), attacker)

	var no_push_target := _spawn_entity(no_push_system, Vector2(32, 0), false, true)
	no_push_target.grid_push_on_hit = false
	await get_tree().process_frame
	no_push_target.feedback_comp.enable_hit_pause = false

	no_push_target.take_damage(1, attacker)
	assert_eq(no_push_target.global_position, Vector2(32, 0), "Sans push-case, la cible ne doit pas être déplacée")
	assert_eq(no_push_target.feedback_comp.get_knockback_velocity(), Vector2.ZERO, "Le knockback continu reste désactivé en grille")

	var push_system := _spawn_system()
	var push_attacker := Node2D.new()
	add_child_autofree(push_attacker)
	push_attacker.global_position = Vector2.ZERO
	push_system.reserve_cell(push_system.world_to_cell(push_attacker.global_position), push_attacker)

	var pushed_target := _spawn_entity(push_system, Vector2(32, 0), false, true)
	await get_tree().process_frame
	pushed_target.feedback_comp.enable_hit_pause = false

	pushed_target.take_damage(1, push_attacker)
	assert_eq(pushed_target.global_position, Vector2(64, 0), "Avec push-case activé, la cible doit reculer d'une case")
