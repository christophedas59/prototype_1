extends Node2D

enum PreviewMode {
	NONE,
	TARGETED,
	DIRECTIONAL,
}

const PREVIEW_COLOR := Color(0.25, 0.65, 1.0, 0.9)
const HIGHLIGHT_COLOR := Color(0.6, 0.85, 1.0, 1.0)
const HIGHLIGHT_GROUP := "targeting_preview_highlight"

var _mode: PreviewMode = PreviewMode.NONE
var _caster: Node2D = null
var _target_group: StringName = &"enemy"
var _max_distance: float = 0.0
var _cursor_world_position: Vector2 = Vector2.ZERO
var _hovered_target: Node2D = null
var _highlighted_targets: Dictionary = {}


func begin_targeted(caster: Node2D, target_group: StringName, max_distance: float) -> void:
	_caster = caster
	_target_group = target_group
	_max_distance = max(max_distance, 0.0)
	_mode = PreviewMode.TARGETED
	set_process(true)
	_update_preview_state()


func begin_directional(caster: Node2D, max_distance: float) -> void:
	_caster = caster
	_max_distance = max(max_distance, 0.0)
	_mode = PreviewMode.DIRECTIONAL
	_hovered_target = null
	_clear_highlights()
	set_process(true)
	_update_preview_state()


func set_cursor_world_position(world_position: Vector2) -> void:
	_cursor_world_position = world_position
	if _mode != PreviewMode.NONE:
		_update_preview_state()


func clear_preview() -> void:
	_mode = PreviewMode.NONE
	_hovered_target = null
	_clear_highlights()
	set_process(false)
	queue_redraw()


func get_hovered_target() -> Node2D:
	return _hovered_target


func get_clamped_target_point() -> Vector2:
	if _caster == null:
		return _cursor_world_position
	var to_cursor := _cursor_world_position - _caster.global_position
	if _max_distance > 0.0 and to_cursor.length() > _max_distance:
		return _caster.global_position + to_cursor.normalized() * _max_distance
	return _cursor_world_position


func _process(_delta: float) -> void:
	if _mode == PreviewMode.NONE:
		return
	_cursor_world_position = get_global_mouse_position()
	_update_preview_state()


func _update_preview_state() -> void:
	if _caster == null or not is_instance_valid(_caster):
		clear_preview()
		return

	if _mode == PreviewMode.TARGETED:
		_update_targeted_candidates()
	else:
		_hovered_target = null

	queue_redraw()


func _update_targeted_candidates() -> void:
	var best_target: Node2D = null
	var best_distance := INF
	var caster_position := _caster.global_position
	var valid_targets: Array[Node2D] = []

	for node in get_tree().get_nodes_in_group(String(_target_group)):
		if not (node is Node2D):
			continue
		if node == _caster:
			continue
		if not is_instance_valid(node):
			continue

		var target := node as Node2D
		var distance_from_caster := caster_position.distance_to(target.global_position)
		if _max_distance > 0.0 and distance_from_caster > _max_distance:
			continue

		valid_targets.append(target)

		var cursor_distance := _cursor_world_position.distance_to(target.global_position)
		if cursor_distance < best_distance:
			best_distance = cursor_distance
			best_target = target

	_hovered_target = best_target
	_apply_highlight(valid_targets)


func _apply_highlight(targets: Array[Node2D]) -> void:
	var keep_ids: Dictionary = {}

	for target in targets:
		var id := target.get_instance_id()
		keep_ids[id] = true

		if not _highlighted_targets.has(id):
			if target is CanvasItem:
				var canvas_item := target as CanvasItem
				_highlighted_targets[id] = canvas_item.modulate
				canvas_item.modulate = HIGHLIGHT_COLOR
			target.add_to_group(HIGHLIGHT_GROUP)

	for id in _highlighted_targets.keys():
		if keep_ids.has(id):
			continue
		_restore_target_highlight(id)


func _clear_highlights() -> void:
	for id in _highlighted_targets.keys():
		_restore_target_highlight(id)
	_highlighted_targets.clear()


func _restore_target_highlight(instance_id: int) -> void:
	var target := instance_from_id(instance_id)
	if target != null and is_instance_valid(target):
		if target is CanvasItem:
			(target as CanvasItem).modulate = _highlighted_targets.get(instance_id, Color.WHITE)
		target.remove_from_group(HIGHLIGHT_GROUP)
	_highlighted_targets.erase(instance_id)


func _draw() -> void:
	if _mode == PreviewMode.NONE or _caster == null:
		return

	var caster_local := to_local(_caster.global_position)

	if _mode == PreviewMode.TARGETED:
		if _max_distance > 0.0:
			draw_arc(caster_local, _max_distance, 0.0, TAU, 64, PREVIEW_COLOR, 2.0)
		if _hovered_target != null:
			var target_local := to_local(_hovered_target.global_position)
			draw_circle(target_local, 10.0, Color(PREVIEW_COLOR.r, PREVIEW_COLOR.g, PREVIEW_COLOR.b, 0.25))
	else:
		var clamped_global := get_clamped_target_point()
		var clamped_local := to_local(clamped_global)
		draw_line(caster_local, clamped_local, PREVIEW_COLOR, 3.0)

		var direction := (clamped_local - caster_local).normalized()
		if direction.length() > 0.0:
			var arrow_size := 10.0
			var normal := Vector2(-direction.y, direction.x)
			draw_colored_polygon([
				clamped_local,
				clamped_local - direction * arrow_size + normal * (arrow_size * 0.55),
				clamped_local - direction * arrow_size - normal * (arrow_size * 0.55)
			], PREVIEW_COLOR)

		_draw_distance_label(caster_local, clamped_local)


func _draw_distance_label(from: Vector2, to: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var midpoint := (from + to) * 0.5 + Vector2(0.0, -10.0)
	var distance := _caster.global_position.distance_to(get_clamped_target_point())
	var text := "%d px" % int(round(distance))
	draw_string(font, midpoint, text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, 14, PREVIEW_COLOR)
