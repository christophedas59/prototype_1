extends Node
class_name ShieldSlamAbility

@export var stun_duration: float = 0.8

func apply_on_hit(_caster: CombatEntity, target: CombatEntity) -> void:
	if target == null:
		return
	target.apply_stun(stun_duration)
