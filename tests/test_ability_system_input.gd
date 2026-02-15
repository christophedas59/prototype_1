extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_keyboard_ability_action_starts_targeting_and_locks_ai() -> void:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.is_player = true
	entity.autonomous = true

	await get_tree().process_frame

	var ability = entity.get_node("AbilitySystem")
	assert_not_null(ability)
	assert_eq(ability.state, ability.AbilityState.AUTO)

	var event := InputEventAction.new()
	event.action = "ability_1"
	event.pressed = true
	ability._unhandled_input(event)

	assert_eq(ability.state, ability.AbilityState.TARGETING, "Le raccourci clavier doit déclencher le mode targeting")
	assert_true(entity.ability_control_locked, "Le lock IA doit être actif pendant le targeting")
