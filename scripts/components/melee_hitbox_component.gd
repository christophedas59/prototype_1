extends Area2D
class_name MeleeHitboxComponent

signal hit_confirmed(target: Node2D, amount: int)

@export var active_time: float = 0.08

var _attacker: Node2D = null
var _damage: int = 0
var _active: bool = false
var _already_hit: Dictionary = {}

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func start_swing(attacker: Node2D, amount: int) -> void:
	if _active:
		return

	_attacker = attacker
	_damage = amount
	_active = true
	_already_hit.clear()
	monitoring = true

	var timer := get_tree().create_timer(active_time)
	timer.timeout.connect(_end_swing)


func _end_swing() -> void:
	monitoring = false
	_active = false
	_attacker = null
	_damage = 0
	_already_hit.clear()


func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area == null or not area.has_method("receive_hit"):
		return

	var target_owner: Node = area.get_parent()
	if target_owner == null:
		return
	if target_owner == _attacker:
		return

	var target_id: int = target_owner.get_instance_id()
	if _already_hit.has(target_id):
		return
	if not _can_hit_target(target_owner):
		return

	_already_hit[target_id] = true
	area.call("receive_hit", _attacker, _damage, global_position)
	hit_confirmed.emit(target_owner as Node2D, _damage)


func _can_hit_target(target_owner: Node) -> bool:
	if _attacker == null:
		return false

	if _attacker.has_method("get_team") and target_owner.has_method("get_team"):
		var attacker_team: Variant = _attacker.call("get_team")
		var target_team: Variant = target_owner.call("get_team")
		if typeof(attacker_team) == TYPE_STRING and attacker_team != "":
			if attacker_team == target_team:
				return false

	return true
