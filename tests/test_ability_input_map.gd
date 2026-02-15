extends GutTest


func test_ability_shortcuts_are_registered() -> void:
	for action in ["ability_1", "ability_2", "ability_3", "ability_4", "ability_cancel"]:
		assert_true(InputMap.has_action(action), "L'action %s doit exister" % action)


func test_ability_shortcuts_have_expected_keys() -> void:
	assert_true(_action_has_physical_key("ability_1", KEY_A))
	assert_true(_action_has_physical_key("ability_2", KEY_Z))
	assert_true(_action_has_physical_key("ability_3", KEY_E))
	assert_true(_action_has_physical_key("ability_4", KEY_R))


func _action_has_physical_key(action: StringName, key_code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key_code:
			return true
	return false
