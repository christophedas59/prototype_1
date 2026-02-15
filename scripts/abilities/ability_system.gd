extends Node
class_name AbilitySystem

signal state_changed(previous_state: AbilityState, new_state: AbilityState)


enum AbilityState {
	AUTO,
	TARGETING,
	CASTING,
	RECOVERY,
}

@export var slot_count: int = 4
@export var default_cooldown: float = 1.0
@export var slot_cooldowns: Array[float] = [1.0, 1.0, 1.0, 1.0]
@export var recovery_duration: float = 0.0

var state: AbilityState = AbilityState.AUTO
var ability_slots: Array[Variant] = [null, null, null, null]
var cooldowns_remaining: Dictionary = {}

var active_slot_index: int = -1
var active_target_data: Variant = null
var preview_mouse_position: Vector2 = Vector2.ZERO

var _recovery_timer: float = 0.0


func _process(delta: float) -> void:
	_update_cooldowns(delta)

	if state == AbilityState.RECOVERY and _recovery_timer > 0.0:
		_recovery_timer = max(_recovery_timer - delta, 0.0)
		if _recovery_timer <= 0.0:
			_set_state(AbilityState.AUTO)
			_set_owner_ability_lock(false)


func request_cast(slot_index: int) -> bool:
	if state != AbilityState.AUTO:
		return false
	if slot_index < 0 or slot_index >= slot_count:
		return false
	if _is_slot_on_cooldown(slot_index):
		return false

	active_slot_index = slot_index
	active_target_data = null
	_set_owner_ability_lock(true)
	_set_state(AbilityState.TARGETING)
	return true


func cancel_targeting() -> void:
	if state != AbilityState.TARGETING:
		return

	active_slot_index = -1
	active_target_data = null
	_set_state(AbilityState.AUTO)
	_set_owner_ability_lock(false)


func confirm_target(target_data: Variant) -> bool:
	if state != AbilityState.TARGETING or active_slot_index < 0:
		return false

	active_target_data = target_data
	_set_state(AbilityState.CASTING)
	_start_slot_cooldown(active_slot_index)
	_finish_cast()
	return true


func update_preview(mouse_pos: Vector2) -> void:
	if state != AbilityState.TARGETING:
		return
	preview_mouse_position = mouse_pos


func _finish_cast() -> void:
	active_slot_index = -1
	active_target_data = null

	if recovery_duration > 0.0:
		_recovery_timer = recovery_duration
		_set_state(AbilityState.RECOVERY)
		return

	_set_state(AbilityState.AUTO)
	_set_owner_ability_lock(false)


func _set_owner_ability_lock(is_locked: bool) -> void:
	var owner_entity := get_parent()
	if owner_entity != null and owner_entity.has_method("set_ability_control_locked"):
		owner_entity.call("set_ability_control_locked", is_locked)


func _is_slot_on_cooldown(slot_index: int) -> bool:
	return cooldowns_remaining.get(slot_index, 0.0) > 0.0


func _start_slot_cooldown(slot_index: int) -> void:
	var slot_cd := default_cooldown
	if slot_index < slot_cooldowns.size():
		slot_cd = max(slot_cooldowns[slot_index], 0.0)
	if slot_cd > 0.0:
		cooldowns_remaining[slot_index] = slot_cd
	else:
		cooldowns_remaining.erase(slot_index)


func _update_cooldowns(delta: float) -> void:
	for slot_index in cooldowns_remaining.keys():
		var updated := max(float(cooldowns_remaining[slot_index]) - delta, 0.0)
		if updated <= 0.0:
			cooldowns_remaining.erase(slot_index)
		else:
			cooldowns_remaining[slot_index] = updated


func _set_state(new_state: AbilityState) -> void:
	if state == new_state:
		return

	var previous_state := state
	state = new_state
	state_changed.emit(previous_state, new_state)
