extends GutTest

const MeleeHitboxComponent := preload("res://scripts/components/melee_hitbox_component.gd")

var _previous_time_scale: float = 1.0


func test_swing_window_closes_even_when_time_scale_is_low() -> void:
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 0.02

	var hitbox := MeleeHitboxComponent.new()
	add_child_autofree(hitbox)
	hitbox.active_time = 0.08

	var attacker := Node2D.new()
	add_child_autofree(attacker)

	hitbox.start_swing(attacker, 1)
	assert_true(hitbox.monitoring, "La hitbox doit être active juste après start_swing")

	await get_tree().create_timer(0.2, true, true).timeout

	assert_false(hitbox.monitoring, "La hitbox doit se fermer même sous hit-pause/time_scale faible")


func after_each() -> void:
	Engine.time_scale = _previous_time_scale
