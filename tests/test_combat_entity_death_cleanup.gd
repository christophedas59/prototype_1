extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_die_disables_collision_and_areas_after_deferred_frame() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)

	await get_tree().process_frame
	assert_false(entity.is_dead, "Précondition: entité vivante")
	assert_false(entity.body_collision.disabled, "Précondition: collision active")
	assert_true(entity.hurtbox_comp.monitoring, "Précondition: hurtbox active")

	entity.die()
	await get_tree().process_frame

	assert_true(entity.is_dead, "die() doit marquer l'entité comme morte")
	assert_true(entity.body_collision.disabled, "La collision du corps doit être désactivée en fin de frame")
	assert_false(entity.hurtbox_comp.monitoring, "La hurtbox doit être désactivée en fin de frame")
	assert_false(entity.melee_hitbox_comp.monitoring, "La hitbox doit être désactivée en fin de frame")
