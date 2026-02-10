extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")

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

	await get_tree().create_timer(entity.feedback_comp.i_frames_duration + 0.05).timeout

	entity.take_damage(1, attacker)
	assert_eq(entity.hp, initial_hp - 2, "Le second hit doit aussi retirer 1 HP après i-frames")
