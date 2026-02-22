extends Node
class_name GridCombatSystem

@export var cell_size: float = 32.0
@export var waiting_ring_radius: int = 2

const CARDINAL_DIRECTIONS = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP
]

var _cell_to_entity: Dictionary = {}
var _entity_to_cell: Dictionary = {}
var _attacker_to_assignment: Dictionary = {}
var _target_to_attackers: Dictionary = {}


func _ready() -> void:
	add_to_group("grid_combat_system")


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_position.x / cell_size)),
		int(round(world_position.y / cell_size))
	)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size, cell.y * cell_size)


func is_cell_free(cell: Vector2i) -> bool:
	return not _cell_to_entity.has(cell)


func reserve_cell(cell: Vector2i, entity: Node) -> bool:
	if entity == null:
		return false

	var entity_id = entity.get_instance_id()
	if _entity_to_cell.has(entity_id):
		var previous_cell: Vector2i = _entity_to_cell[entity_id]
		if previous_cell == cell:
			return true
		release_cell(previous_cell)

	if not is_cell_free(cell):
		return false

	_cell_to_entity[cell] = entity
	_entity_to_cell[entity_id] = cell
	return true


func release_cell(cell: Vector2i) -> void:
	if not _cell_to_entity.has(cell):
		return

	var entity: Node = _cell_to_entity[cell]
	_cell_to_entity.erase(cell)
	if entity != null and is_instance_valid(entity):
		_entity_to_cell.erase(entity.get_instance_id())


func get_adjacent_cells(target: Node2D) -> Array[Vector2i]:
	if target == null:
		return []

	var center = world_to_cell(target.global_position)
	var result: Array[Vector2i] = []
	for direction in CARDINAL_DIRECTIONS:
		result.append(center + direction)
	return result


func assign_attack_slot(attacker: Node2D, target: Node2D) -> Vector2i:
	if attacker == null or target == null:
		return Vector2i.ZERO

	var attacker_id = attacker.get_instance_id()
	var target_id = target.get_instance_id()
	var existing: Dictionary = _attacker_to_assignment.get(attacker_id, {})
	if not existing.is_empty() and existing.get("target_id", -1) == target_id:
		return existing.get("cell", Vector2i.ZERO)

	release_attack_slot(attacker)

	var target_cell = world_to_cell(target.global_position)
	var slots = get_adjacent_cells(target)
	for slot_cell in slots:
		if _can_claim_slot(slot_cell, attacker, target_cell):
			_set_assignment(attacker, target, slot_cell, false)
			return slot_cell

	var waiting_cell = _find_waiting_cell(target_cell)
	if waiting_cell != target_cell:
		_set_assignment(attacker, target, waiting_cell, true)
		return waiting_cell

	return _entity_to_cell.get(attacker_id, target_cell)


func release_attack_slot(attacker: Node2D) -> void:
	if attacker == null:
		return

	var attacker_id = attacker.get_instance_id()
	if not _attacker_to_assignment.has(attacker_id):
		return

	var assignment: Dictionary = _attacker_to_assignment[attacker_id]
	_attacker_to_assignment.erase(attacker_id)

	var target_id: int = assignment.get("target_id", -1)
	if _target_to_attackers.has(target_id):
		var target_attackers: Array = _target_to_attackers[target_id]
		target_attackers.erase(attacker)
		if target_attackers.is_empty():
			_target_to_attackers.erase(target_id)
		else:
			_target_to_attackers[target_id] = target_attackers

	var cell: Vector2i = assignment.get("cell", Vector2i.ZERO)
	if _cell_to_entity.get(cell) == attacker:
		release_cell(cell)

	_recalculate_target_queue(target_id)


func notify_entity_died(entity: Node2D) -> void:
	if entity == null:
		return

	var entity_id = entity.get_instance_id()
	var cell: Vector2i = _entity_to_cell.get(entity_id, world_to_cell(entity.global_position))
	release_attack_slot(entity)
	release_cell(cell)

	var attackers_for_target: Array = _target_to_attackers.get(entity_id, []).duplicate()
	for attacker in attackers_for_target:
		if attacker != null and is_instance_valid(attacker):
			release_attack_slot(attacker)

	_target_to_attackers.erase(entity_id)


func get_assigned_cell(attacker: Node2D) -> Vector2i:
	if attacker == null:
		return Vector2i(-99999, -99999)
	var assignment: Dictionary = _attacker_to_assignment.get(attacker.get_instance_id(), {})
	return assignment.get("cell", Vector2i(-99999, -99999))


func attacker_has_adjacent_slot(attacker: Node2D) -> bool:
	if attacker == null:
		return false
	var assignment: Dictionary = _attacker_to_assignment.get(attacker.get_instance_id(), {})
	return not assignment.get("waiting", true)


func _set_assignment(attacker: Node2D, target: Node2D, cell: Vector2i, waiting: bool) -> void:
	reserve_cell(cell, attacker)
	var attacker_id = attacker.get_instance_id()
	var target_id = target.get_instance_id()
	_attacker_to_assignment[attacker_id] = {
		"target_id": target_id,
		"cell": cell,
		"waiting": waiting,
	}
	var target_attackers: Array = _target_to_attackers.get(target_id, [])
	if not target_attackers.has(attacker):
		target_attackers.append(attacker)
	_target_to_attackers[target_id] = target_attackers


func _recalculate_target_queue(target_id: int) -> void:
	if target_id < 0 or not _target_to_attackers.has(target_id):
		return

	var target: Node2D = null
	for attacker in _target_to_attackers[target_id]:
		if attacker != null and is_instance_valid(attacker):
			var assignment: Dictionary = _attacker_to_assignment.get(attacker.get_instance_id(), {})
			target = instance_from_id(assignment.get("target_id", -1)) as Node2D
			if target != null and is_instance_valid(target):
				break
	if target == null:
		return

	var attackers: Array = _target_to_attackers[target_id].duplicate()
	for attacker in attackers:
		if attacker == null or not is_instance_valid(attacker):
			continue
		var attacker_id = attacker.get_instance_id()
		if not _attacker_to_assignment.has(attacker_id):
			continue
		var assignment: Dictionary = _attacker_to_assignment[attacker_id]
		if not assignment.get("waiting", false):
			continue

		var adjacent = get_adjacent_cells(target)
		var target_cell = world_to_cell(target.global_position)
		for candidate in adjacent:
			if _can_claim_slot(candidate, attacker, target_cell):
				reserve_cell(candidate, attacker)
				assignment["cell"] = candidate
				assignment["waiting"] = false
				_attacker_to_assignment[attacker_id] = assignment
				break


func _find_waiting_cell(target_cell: Vector2i) -> Vector2i:
	for radius in range(waiting_ring_radius, waiting_ring_radius + 2):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var candidate = target_cell + Vector2i(x, y)
				if is_cell_free(candidate):
					return candidate
	return target_cell


func _can_claim_slot(cell: Vector2i, attacker: Node2D, target_cell: Vector2i) -> bool:
	if cell == target_cell:
		return false
	if is_cell_free(cell):
		return true
	return _cell_to_entity.get(cell) == attacker
