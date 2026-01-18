extends Node
##
## HitPauseManager.gd — Singleton pour gérer les hit-pauses globales
## Godot 4.5.x
##
## Optimisation : Remplace la logique statique par un système centralisé
## plus performant avec un seul timer au lieu de métadonnées multiples.
##

var _pause_end_time: float = 0.0
var _is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continue pendant les pauses


func _process(delta: float) -> void:
	if not _is_paused:
		return

	# Vérifie si la pause est terminée
	if Time.get_ticks_msec() / 1000.0 >= _pause_end_time:
		_restore_time_scale()


func request_hit_pause(duration: float, time_scale: float) -> void:
	if duration <= 0.0:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var new_end := now + duration

	# Si une pause existe déjà et dure plus longtemps, on ne raccourcit pas
	if _is_paused and new_end <= _pause_end_time:
		return

	_pause_end_time = new_end
	_is_paused = true
	Engine.time_scale = time_scale


func _restore_time_scale() -> void:
	Engine.time_scale = 1.0
	_is_paused = false


func force_restore() -> void:
	"""Utilisé en cas de changement de scène pour éviter de rester bloqué"""
	_restore_time_scale()
