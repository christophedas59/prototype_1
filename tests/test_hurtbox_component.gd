extends GutTest
const HurtboxComponent := preload("res://scripts/components/hurtbox_component.gd")

func test_receive_hit_emits_signal_with_expected_payload():
	var hurtbox := HurtboxComponent.new()

	var attacker = null
	var amount := 7
	var hit_pos := Vector2(12, 34)

	watch_signals(hurtbox)

	hurtbox.receive_hit(attacker, amount, hit_pos)

	assert_signal_emitted(hurtbox, "hit_received")
	assert_signal_emitted_with_parameters(hurtbox, "hit_received", [attacker, amount, hit_pos])

	hurtbox.queue_free()
