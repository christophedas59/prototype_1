extends Node
class_name TauntShoutAbility

@export var forced_target_duration: float = 2.0

func apply_taunt(caster: CombatEntity, targets: Array[CombatEntity]) -> void:
	if caster == null:
		return

	for target in targets:
		if target == null:
			continue
		target.apply_forced_target(caster, forced_target_duration)
