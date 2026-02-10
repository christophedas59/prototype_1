extends Area2D
class_name HurtboxComponent

signal hit_received(attacker: Node2D, amount: int, hit_position: Vector2)

const DEBUG_HITS := false

func receive_hit(attacker: Node2D, amount: int, hit_position: Vector2) -> void:
	if DEBUG_HITS:
		print_debug(
			"[hits] hurtbox receive_hit",
			self,
			"attacker=", attacker,
			"amount=", amount,
			"pos=", hit_position,
			"monitoring=", monitoring,
			"monitorable=", monitorable,
			"layer=", collision_layer,
			"mask=", collision_mask,
			"time_scale=", Engine.time_scale
		)
		print_debug("[hits] emit hit_received", self, attacker, amount, hit_position)
	hit_received.emit(attacker, amount, hit_position)
