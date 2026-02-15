extends Node
class_name AbilitySystem

@export var ability_cooldowns := {
	"ability_1": 4.0,
	"ability_2": 6.0,
	"ability_3": 8.0,
	"ability_4": 12.0,
}

var _cooldowns_remaining := {}
var _targeting_ability: StringName = &""


func update(delta: float) -> void:
	for action in _cooldowns_remaining.keys():
		var remaining: float = max(float(_cooldowns_remaining[action]) - delta, 0.0)
		_cooldowns_remaining[action] = remaining


func start_targeting(action: StringName) -> bool:
	if not ability_cooldowns.has(action):
		return false
	if is_on_cooldown(action):
		return false
	_targeting_ability = action
	return true


func confirm_targeting() -> bool:
	if _targeting_ability == &"":
		return false

	var action := String(_targeting_ability)
	var cooldown: float = float(ability_cooldowns.get(action, 0.0))
	_cooldowns_remaining[action] = max(cooldown, 0.0)
	_targeting_ability = &""
	return true


func cancel_targeting() -> void:
	_targeting_ability = &""


func is_targeting() -> bool:
	return _targeting_ability != &""


func get_cooldown_remaining(action: StringName) -> float:
	return float(_cooldowns_remaining.get(String(action), 0.0))


func is_on_cooldown(action: StringName) -> bool:
	return get_cooldown_remaining(action) > 0.0
