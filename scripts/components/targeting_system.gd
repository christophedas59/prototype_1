extends Node
class_name TargetingSystem
##
## TargetingSystem.gd — Composant réutilisable pour ciblage optimisé
## Godot 4.5.x
##
## Gère :
## - Cache de cibles rafraîchi périodiquement
## - Recherche de la cible la plus proche
## - Validation de cibles (vivantes, valides)
## - Optimisation : distance_squared_to() au lieu de distance_to()
##

# -------------------------------------------------------------------
# EXPORTS
# -------------------------------------------------------------------

@export var cache_refresh_interval: float = 0.1  # Mise à jour tous les 0.1s
@export var target_group: String = ""  # Groupe à cibler (ex: "enemy" ou "player")


# -------------------------------------------------------------------
# ÉTAT INTERNE
# -------------------------------------------------------------------

var _cached_targets: Array[CombatEntity] = []
var _cache_timer: float = 0.0
var _owner_node: CombatEntity = null  # Référence au node parent (pour distance)


# -------------------------------------------------------------------
# INITIALISATION
# -------------------------------------------------------------------

func initialize(owner: CombatEntity, group: String) -> void:
	"""Doit être appelé par le parent après _ready()"""
	_owner_node = owner
	target_group = group
	_update_cache()


# -------------------------------------------------------------------
# UPDATE (appelé depuis _physics_process du parent)
# -------------------------------------------------------------------

func update(delta: float) -> void:
	"""Met à jour le cache périodiquement"""
	_cache_timer -= delta
	if _cache_timer <= 0.0:
		_update_cache()
		_cache_timer = cache_refresh_interval


# -------------------------------------------------------------------
# API PUBLIQUE
# -------------------------------------------------------------------

func get_closest_target() -> CombatEntity:
	"""Trouve la cible la plus proche en utilisant le cache"""
	if not is_instance_valid(_owner_node):
		return null

	var best: CombatEntity = null
	var best_dist_sq: float = INF

	# Utilise le cache si disponible, sinon fallback direct
	var search_list: Array = _cached_targets if _cached_targets.size() > 0 else get_tree().get_nodes_in_group(target_group)

	for n in search_list:
		if not is_instance_valid(n) or not (n is CombatEntity):
			continue

		var node := n as CombatEntity

		# Ignore les morts
		if node.is_dead:
			continue

		# Utilise distance_squared_to (plus rapide que distance_to)
		var dist_sq: float = _owner_node.global_position.distance_squared_to(node.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = node

	return best


func is_target_valid(target: CombatEntity) -> bool:
	"""Vérifie si une cible est valide (existe et vivante)"""
	return is_instance_valid(target) and not target.is_dead


func clear_cache() -> void:
	"""Vide le cache (utile lors de changements de scène)"""
	_cached_targets.clear()


# -------------------------------------------------------------------
# INTERNE
# -------------------------------------------------------------------

func _update_cache() -> void:
	"""Rafraîchit la liste des cibles vivantes"""
	_cached_targets.clear()

	if target_group == "":
		return

	var nodes := get_tree().get_nodes_in_group(target_group)
	for n in nodes:
		if n is CombatEntity:
			var node := n as CombatEntity
			if not node.is_dead:
				_cached_targets.append(node)
