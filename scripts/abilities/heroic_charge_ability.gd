extends Node
class_name HeroicChargeAbility

@export var stun_duration: float = 1.2

func apply_on_impact(_caster: CombatEntity, target: CombatEntity) -> void:
	if target == null:
		return
	target.apply_stun(stun_duration)
