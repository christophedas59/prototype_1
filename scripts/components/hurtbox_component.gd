extends Area2D
class_name HurtboxComponent

signal hit_received(attacker: Node2D, amount: int, hit_position: Vector2)

func receive_hit(attacker: Node2D, amount: int, hit_position: Vector2) -> void:
	hit_received.emit(attacker, amount, hit_position)
