extends GutTest

const AbilitySystemScript := preload("res://scripts/components/ability_system.gd")


func _spawn_ability_system() -> AbilitySystem:
	var ability_system: AbilitySystem = AbilitySystemScript.new()
	add_child_autofree(ability_system)
	return ability_system


func test_cooldown_starts_on_confirm_not_on_targeting_entry() -> void:
	var ability_system := _spawn_ability_system()

	assert_true(ability_system.start_targeting(&"ability_1"))
	assert_true(ability_system.is_targeting())
	assert_eq(ability_system.get_cooldown_remaining(&"ability_1"), 0.0)

	assert_true(ability_system.confirm_targeting())
	assert_gt(ability_system.get_cooldown_remaining(&"ability_1"), 0.0)


func test_cancel_targeting_does_not_apply_cooldown() -> void:
	var ability_system := _spawn_ability_system()

	assert_true(ability_system.start_targeting(&"ability_2"))
	ability_system.cancel_targeting()

	assert_false(ability_system.is_targeting())
	assert_eq(ability_system.get_cooldown_remaining(&"ability_2"), 0.0)
	assert_false(ability_system.is_on_cooldown(&"ability_2"))
