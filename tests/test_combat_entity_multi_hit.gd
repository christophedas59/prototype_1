extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")

func _await_iframes_end(feedback: CombatFeedback, timeout_seconds: float = 1.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while feedback.is_invulnerable() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

	assert_false(feedback.is_invulnerable(), "Les i-frames auraient dû se terminer avant le timeout")


func test_take_damage_applies_on_two_successive_hits_after_iframes() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)

	var attacker := Node2D.new()
	add_child_autofree(attacker)
	attacker.global_position = Vector2(64, 0)

	await get_tree().process_frame
	entity.feedback_comp.enable_hit_pause = false

	var initial_hp := entity.hp
	entity.take_damage(1, attacker)
	assert_eq(entity.hp, initial_hp - 1, "Le premier hit doit retirer 1 HP")
	assert_true(entity.feedback_comp.is_invulnerable(), "Le premier hit doit activer les i-frames")

	await _await_iframes_end(entity.feedback_comp)

	entity.take_damage(1, attacker)
	assert_eq(entity.hp, initial_hp - 2, "Le second hit doit aussi retirer 1 HP après i-frames")
