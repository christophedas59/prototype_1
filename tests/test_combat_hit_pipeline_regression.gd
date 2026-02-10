extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func _spawn_entity(position: Vector2) -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.global_position = position
	return entity


func test_receive_hit_signal_reaches_entity_and_reduces_hp() -> void:
	var attacker := _spawn_entity(Vector2.ZERO)
	var target := _spawn_entity(Vector2(12, 0))

	attacker.feedback_comp.enable_hit_pause = false
	target.feedback_comp.enable_hit_pause = false

	await get_tree().process_frame
	watch_signals(target.hurtbox_comp)

	var initial_hp := target.hp
	target.hurtbox_comp.receive_hit(attacker, 3, target.global_position)
	await get_tree().process_frame

	assert_signal_emitted(target.hurtbox_comp, "hit_received")
	assert_eq(target.hp, initial_hp - 3, "receive_hit doit déclencher le handler d'entité et appliquer les dégâts")


func test_attack_range_does_not_start_before_hitbox_hurtbox_contact() -> void:
	var attacker := _spawn_entity(Vector2.ZERO)
	var target := _spawn_entity(Vector2.ZERO)

	await get_tree().process_frame

	var contact_range := attacker._get_melee_contact_range(target)
	assert_gt(contact_range, 0.0, "Le test nécessite une portée de contact valide")

	target.global_position = Vector2(contact_range + 0.5, 0)

	assert_false(
		attacker._is_target_in_attack_range(target),
		"L'attaque ne doit pas démarrer hors contact hitbox/hurtbox, sinon aucun hit ne peut être détecté"
	)
