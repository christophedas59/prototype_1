extends Node

const ShieldSlamAbilityScript := preload("res://scripts/abilities/warrior/shield_slam_ability.gd")
const WhirlSlashAbilityScript := preload("res://scripts/abilities/warrior/whirl_slash_ability.gd")
const HeroicChargeAbilityScript := preload("res://scripts/abilities/warrior/heroic_charge_ability.gd")
const TauntShoutAbilityScript := preload("res://scripts/abilities/warrior/taunt_shout_ability.gd")

enum TargetingMode {
	NONE,
	TARGETED,
	DIRECTIONAL,
}

enum AbilityState {
	AUTO,
	TARGETING,
	CASTING,
}

signal targeting_confirmed(world_position: Vector2, target: Node2D, direction: Vector2, distance: float)
signal targeting_cancelled

@export var caster_path: NodePath
@export var preview_controller_path: NodePath
@export var default_target_group: StringName = &"enemy"

var _mode: TargetingMode = TargetingMode.NONE
var _targeting_max_distance: float = 0.0
var _caster: Node2D = null
var _preview: Node = null
var _owner_entity: CombatEntity = null

var state: AbilityState = AbilityState.AUTO
var active_slot_index: int = -1
var ability_slots: Array = []


func _ready() -> void:
	add_to_group("ability_system")
	_caster = get_node_or_null(caster_path) as Node2D
	if _caster == null and owner is Node2D:
		_caster = owner as Node2D
	if _caster is CombatEntity:
		_owner_entity = _caster as CombatEntity

	_preview = get_node_or_null(preview_controller_path)
	if _preview == null and get_parent() != null:
		_preview = get_parent().get_node_or_null("TargetingPreviewController")

	if ability_slots.is_empty():
		ability_slots = [
			ShieldSlamAbilityScript.new(),
			WhirlSlashAbilityScript.new(),
			HeroicChargeAbilityScript.new(),
			TauntShoutAbilityScript.new(),
		]

	set_process(true)


func _process(delta: float) -> void:
	for ability in ability_slots:
		if ability != null and ability.has_method("update_cooldown"):
			ability.update_cooldown(delta)


func request_cast(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= ability_slots.size():
		return false
	if state != AbilityState.AUTO:
		return false

	var ability = ability_slots[slot_index]
	if ability == null:
		return false
	if not ability.begin_targeting():
		return false

	active_slot_index = slot_index
	if _owner_entity != null:
		_owner_entity.set_ability_control_locked(true)

	var targeting_type := int(ability.targeting_type)
	if targeting_type == 1:  # INSTANT_AOE
		return _execute_active_ability({})

	state = AbilityState.TARGETING
	if targeting_type == 0:
		begin_targeted(float(ability.range), default_target_group)
	else:
		begin_directional(float(ability.max_distance))

	return true


func confirm_target(selection: Dictionary = {}) -> bool:
	if active_slot_index < 0 or active_slot_index >= ability_slots.size():
		return false
	if state != AbilityState.TARGETING:
		return false

	var ability = ability_slots[active_slot_index]
	if ability == null:
		return false

	if _mode == TargetingMode.TARGETED and not selection.has("target") and _preview != null and _preview.has_method("get_hovered_target"):
		selection["target"] = _preview.call("get_hovered_target")

	if _mode == TargetingMode.DIRECTIONAL:
		var point := _get_mouse_world_position()
		if _preview != null and _preview.has_method("get_clamped_target_point"):
			point = _preview.call("get_clamped_target_point")
		var origin := _caster.global_position if _caster != null else Vector2.ZERO
		selection["direction"] = (point - origin).normalized()

	return _execute_active_ability(selection)


func cancel_targeting() -> void:
	if active_slot_index >= 0 and active_slot_index < ability_slots.size():
		var ability = ability_slots[active_slot_index]
		if ability != null and ability.has_method("cancel_targeting"):
			ability.cancel_targeting()

	active_slot_index = -1
	state = AbilityState.AUTO
	_mode = TargetingMode.NONE
	if _owner_entity != null:
		_owner_entity.set_ability_control_locked(false)
	if _preview != null and _preview.has_method("clear_preview"):
		_preview.call("clear_preview")
	targeting_cancelled.emit()


func _execute_active_ability(selection: Dictionary) -> bool:
	if _owner_entity == null:
		cancel_targeting()
		return false

	state = AbilityState.CASTING
	var ability = ability_slots[active_slot_index]
	var cast_ok := bool(ability.validate_cast(_owner_entity, selection))

	if cast_ok and _preview != null:
		var final_pos := _owner_entity.global_position
		if selection.has("target") and selection["target"] is Node2D:
			final_pos = (selection["target"] as Node2D).global_position
		targeting_confirmed.emit(final_pos, selection.get("target", null), selection.get("direction", Vector2.ZERO), 0.0)

	active_slot_index = -1
	state = AbilityState.AUTO
	_mode = TargetingMode.NONE
	if _owner_entity != null:
		_owner_entity.set_ability_control_locked(false)
	if _preview != null and _preview.has_method("clear_preview"):
		_preview.call("clear_preview")

	return cast_ok


func is_targeting() -> bool:
	return state == AbilityState.TARGETING


func get_targeting_slot_index() -> int:
	return active_slot_index


func get_cooldown_remaining(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= ability_slots.size():
		return 0.0
	var ability = ability_slots[slot_index]
	return float(ability.get_cooldown_remaining()) if ability != null else 0.0


func get_cooldown_duration(slot_index: int) -> float:
	if slot_index < 0 or slot_index >= ability_slots.size():
		return 0.0
	var ability = ability_slots[slot_index]
	return float(ability.cooldown) if ability != null else 0.0


# API de preview ciblage utilisée aussi par les tests.
func begin_targeted(max_distance: float, target_group: StringName = default_target_group) -> void:
	if _caster == null or _preview == null:
		return
	_mode = TargetingMode.TARGETED
	_targeting_max_distance = max(max_distance, 0.0)
	if _preview.has_method("begin_targeted"):
		_preview.call("begin_targeted", _caster, target_group, _targeting_max_distance)


func begin_directional(max_distance: float) -> void:
	if _caster == null or _preview == null:
		return
	_mode = TargetingMode.DIRECTIONAL
	_targeting_max_distance = max(max_distance, 0.0)
	if _preview.has_method("begin_directional"):
		_preview.call("begin_directional", _caster, _targeting_max_distance)


func is_targeting_active() -> bool:
	return _mode != TargetingMode.NONE


func confirm_targeting_at(world_position: Vector2) -> void:
	if _mode == TargetingMode.NONE:
		return

	if _preview != null and _preview.has_method("set_cursor_world_position"):
		_preview.call("set_cursor_world_position", world_position)

	var target: Node2D = null
	var final_position := world_position
	var direction := Vector2.ZERO
	var distance := 0.0

	if _preview != null and _preview.has_method("get_clamped_target_point"):
		final_position = _preview.call("get_clamped_target_point")

	if _mode == TargetingMode.TARGETED and _preview != null and _preview.has_method("get_hovered_target"):
		target = _preview.call("get_hovered_target")
		if target != null:
			final_position = target.global_position

	if _caster != null:
		var to_target := final_position - _caster.global_position
		distance = to_target.length()
		direction = to_target.normalized() if distance > 0.0 else Vector2.ZERO

	targeting_confirmed.emit(final_position, target, direction, distance)
	_mode = TargetingMode.NONE
	if _preview != null and _preview.has_method("clear_preview"):
		_preview.call("clear_preview")


func _unhandled_input(event: InputEvent) -> void:
	if state == AbilityState.TARGETING:
		if event is InputEventMouseButton and event.pressed:
			var mouse_event := event as InputEventMouseButton
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				confirm_target({})
				get_viewport().set_input_as_handled()
				return
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_targeting()
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("ability_cancel"):
			cancel_targeting()
			get_viewport().set_input_as_handled()
			return

	if _mode == TargetingMode.NONE:
		return

	if event is InputEventMouseButton and event.pressed:
		var preview_event := event as InputEventMouseButton
		if preview_event.button_index == MOUSE_BUTTON_LEFT:
			confirm_targeting_at(_get_mouse_world_position())
			get_viewport().set_input_as_handled()
			return
		if preview_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ability_cancel"):
		cancel_targeting()
		get_viewport().set_input_as_handled()

	if state == AbilityState.AUTO:
		if event.is_action_pressed("ability_1"):
			request_cast(0)
		elif event.is_action_pressed("ability_2"):
			request_cast(1)
		elif event.is_action_pressed("ability_3"):
			request_cast(2)
		elif event.is_action_pressed("ability_4"):
			request_cast(3)


func _get_mouse_world_position() -> Vector2:
	if _caster != null:
		return _caster.get_global_mouse_position()
	var viewport := get_viewport()
	return viewport.get_mouse_position() if viewport != null else Vector2.ZERO
