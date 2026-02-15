extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_apply_stun_sets_stun_and_blocks_attack() -> void:
	var attacker: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(attacker)
	attacker.is_enemy = true

	var target: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(target)
	target.is_player = true

	await get_tree().process_frame

	attacker.attack_timer = 0.0
	attacker.apply_stun(0.5)

	assert_true(attacker.is_stunned(), "Le stun doit être actif immédiatement")
	attacker.try_attack(target)
	assert_false(attacker.is_attacking, "Une entité stun ne doit pas démarrer d'attaque")


func test_forced_target_priority_while_active() -> void:
	var enemy: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(enemy)
	enemy.is_enemy = true
	enemy.global_position = Vector2.ZERO

	var close_player: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(close_player)
	close_player.is_player = true
	close_player.add_to_group("player")
	close_player.global_position = Vector2(10, 0)

	var far_player: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(far_player)
	far_player.is_player = true
	far_player.add_to_group("player")
	far_player.global_position = Vector2(100, 0)

	await get_tree().process_frame
	enemy.targeting_comp.initialize(enemy, "player")
	enemy.targeting_comp.update(1.0)

	var default_target := enemy.targeting_comp.get_closest_target()
	assert_eq(default_target, close_player, "Sans taunt, la cible la plus proche doit être choisie")

	enemy.apply_forced_target(far_player, 1.0)
	var forced := enemy.targeting_comp.get_closest_target(enemy.forced_target)
	assert_eq(forced, far_player, "Avec taunt actif, la cible forcée doit être prioritaire")
