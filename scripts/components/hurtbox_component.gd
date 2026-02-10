extends Area2D
class_name HurtboxComponent

signal hit_received(attacker: Node2D, amount: int, hit_position: Vector2)

const DEBUG_HITS := false

func receive_hit(attacker: Node2D, amount: int, hit_position: Vector2) -> void:
	if DEBUG_HITS:
		print_debug("hurtbox receive_hit", self, attacker, amount, hit_position)
		print_debug("emit hit_received", self, attacker, amount, hit_position)
	hit_received.emit(attacker, amount, hit_position)
