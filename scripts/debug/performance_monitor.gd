extends Node
##
## PerformanceMonitor.gd - Moniteur de performance optionnel
## Godot 4.5.x
##
## Utilisation : Ajouter comme enfant de la scène principale pour voir les stats
##

@onready var label: Label = Label.new()

var _frame_count: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	# Configure le label
	add_child(label)
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color.YELLOW


func _process(delta: float) -> void:
	_frame_count += 1
	_elapsed += delta

	# Mise à jour toutes les 0.5 secondes
	if _elapsed >= 0.5:
		var fps := _frame_count / _elapsed
		var physics_tps := Engine.physics_ticks_per_second

		var stats := "FPS: %.1f\n" % fps
		stats += "Physics TPS (target): %d\n" % physics_tps
		stats += "Time Scale: %.2f\n" % Engine.time_scale
		stats += "Nodes: %d\n" % get_tree().get_node_count()

		# Mémoire
		var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
		stats += "Memory: %.1f MB\n" % mem

		# Objets orphelins
		var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		stats += "Orphans: %d" % orphans

		label.text = stats

		_frame_count = 0
		_elapsed = 0.0
