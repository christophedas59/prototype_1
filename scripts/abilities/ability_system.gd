extends Node
class_name AbilitySystem

enum TargetingMode {
	NONE,
	TARGETED,
	DIRECTIONAL,
}

signal targeting_confirmed(world_position: Vector2, target: Node2D, direction: Vector2, distance: float)
signal targeting_cancelled

@export var caster_path: NodePath
@export var preview_controller_path: NodePath
@export var default_target_group: StringName = &"enemy"

var _mode: TargetingMode = TargetingMode.NONE
var _targeting_max_distance: float = 0.0
var _caster: Node2D = null
var _preview: TargetingPreviewController = null


func _ready() -> void:
	_caster = get_node_or_null(caster_path) as Node2D
	if _caster == null and owner is Node2D:
		_caster = owner as Node2D

	_preview = get_node_or_null(preview_controller_path) as TargetingPreviewController


func begin_targeted(max_distance: float, target_group: StringName = default_target_group) -> void:
	if _caster == null or _preview == null:
		return
	_mode = TargetingMode.TARGETED
	_targeting_max_distance = max(max_distance, 0.0)
	_preview.begin_targeted(_caster, target_group, _targeting_max_distance)


func begin_directional(max_distance: float) -> void:
	if _caster == null or _preview == null:
		return
	_mode = TargetingMode.DIRECTIONAL
	_targeting_max_distance = max(max_distance, 0.0)
	_preview.begin_directional(_caster, _targeting_max_distance)


func is_targeting_active() -> bool:
	return _mode != TargetingMode.NONE


func cancel_targeting() -> void:
	if _mode == TargetingMode.NONE:
		return
	_mode = TargetingMode.NONE
	if _preview != null:
		_preview.clear_preview()
	targeting_cancelled.emit()


func confirm_targeting_at(world_position: Vector2) -> void:
	if _mode == TargetingMode.NONE:
		return

	if _preview != null:
		_preview.set_cursor_world_position(world_position)

	var target: Node2D = null
	var final_position := world_position
	var direction := Vector2.ZERO
	var distance := 0.0

	if _preview != null:
		final_position = _preview.get_clamped_target_point()

	if _mode == TargetingMode.TARGETED and _preview != null:
		target = _preview.get_hovered_target()
		if target != null:
			final_position = target.global_position

	if _caster != null:
		var to_target := final_position - _caster.global_position
		distance = to_target.length()
		direction = to_target.normalized() if distance > 0.0 else Vector2.ZERO

	targeting_confirmed.emit(final_position, target, direction, distance)
	_mode = TargetingMode.NONE
	if _preview != null:
		_preview.clear_preview()


func _unhandled_input(event: InputEvent) -> void:
	if _mode == TargetingMode.NONE:
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			confirm_targeting_at(_get_mouse_world_position())
			get_viewport().set_input_as_handled()
			return
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_targeting()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ability_cancel"):
		cancel_targeting()
		get_viewport().set_input_as_handled()


func _get_mouse_world_position() -> Vector2:
	if _caster != null:
		return _caster.get_global_mouse_position()
	var viewport := get_viewport()
	return viewport.get_mouse_position() if viewport != null else Vector2.ZERO
