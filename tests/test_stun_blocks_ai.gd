extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func _spawn_entity(position: Vector2) -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.global_position = position
	return entity


func test_stun_blocks_attack_until_timer_expires() -> void:
	var enemy := _spawn_entity(Vector2.ZERO)
	var target := _spawn_entity(Vector2.ZERO)

	await get_tree().process_frame

	enemy.attack_timer = 0.0
	enemy.apply_stun(0.5)
	enemy.try_attack(target)

	assert_true(enemy.is_stunned())
	assert_eq(enemy.attack_timer, 0.0, "Le stun doit empêcher de lancer une attaque")
	assert_false(enemy.is_attacking)

	enemy._update_control_effects(0.6)
	enemy.try_attack(target)

	assert_false(enemy.is_stunned())
	assert_true(enemy.attack_timer > 0.0, "Une attaque redevient possible une fois le stun terminé")


func test_stun_stops_movement_while_active() -> void:
	var enemy := _spawn_entity(Vector2.ZERO)

	await get_tree().process_frame

	enemy.velocity = Vector2(20, 0)
	enemy.apply_stun(0.2)
	enemy._physics_process(0.1)

	assert_eq(enemy.velocity, Vector2.ZERO, "Le stun doit annuler le déplacement pendant sa durée")
