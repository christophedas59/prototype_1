extends GutTest

const AbilitySystem := preload("res://scripts/abilities/ability_system.gd")
const TargetingPreviewController := preload("res://scripts/abilities/targeting_preview_controller.gd")


func test_targeted_confirm_emits_selected_enemy_and_cleans_preview() -> void:
	var rig := _build_targeting_rig()
	var ability: AbilitySystem = rig["ability"]
	var preview: TargetingPreviewController = rig["preview"]
	var enemy: Node2D = rig["enemy"]

	watch_signals(ability)

	ability.begin_targeted(200.0, &"enemy")
	preview.set_cursor_world_position(enemy.global_position)

	assert_true(enemy.is_in_group("targeting_preview_highlight"))

	ability.confirm_targeting_at(enemy.global_position)

	assert_signal_emitted(ability, "targeting_confirmed")
	assert_false(ability.is_targeting_active())
	assert_eq(preview.get_hovered_target(), null)
	assert_false(enemy.is_in_group("targeting_preview_highlight"))


func test_unhandled_input_cancel_on_right_click_resets_targeting_state() -> void:
	var rig := _build_targeting_rig()
	var ability: AbilitySystem = rig["ability"]
	var preview: TargetingPreviewController = rig["preview"]
	var enemy: Node2D = rig["enemy"]

	watch_signals(ability)

	ability.begin_targeted(200.0, &"enemy")
	preview.set_cursor_world_position(enemy.global_position)

	var cancel_event := InputEventMouseButton.new()
	cancel_event.button_index = MOUSE_BUTTON_RIGHT
	cancel_event.pressed = true
	ability._unhandled_input(cancel_event)

	assert_signal_emitted(ability, "targeting_cancelled")
	assert_false(ability.is_targeting_active())
	assert_eq(preview.get_hovered_target(), null)
	assert_false(enemy.is_in_group("targeting_preview_highlight"))


func _build_targeting_rig() -> Dictionary:
	var root: Node2D = autofree(Node2D.new())
	add_child(root)

	var caster := Node2D.new()
	caster.name = "Caster"
	caster.position = Vector2.ZERO
	root.add_child(caster)

	var enemy := Node2D.new()
	enemy.name = "Enemy"
	enemy.position = Vector2(100.0, 0.0)
	enemy.add_to_group("enemy")
	root.add_child(enemy)

	var preview := TargetingPreviewController.new()
	preview.name = "TargetingPreviewController"
	root.add_child(preview)

	var ability := AbilitySystem.new()
	ability.caster_path = NodePath("../Caster")
	ability.preview_controller_path = NodePath("../TargetingPreviewController")
	root.add_child(ability)

	return {
		"root": root,
		"caster": caster,
		"enemy": enemy,
		"preview": preview,
		"ability": ability,
	}
