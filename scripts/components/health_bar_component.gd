extends Node
class_name HealthBarComponent
##
## HealthBarComponent.gd — Composant réutilisable pour barres de vie
## Godot 4.5.x
##
## Gère :
## - Affichage TextureProgressBar avec styles (Player/Enemy/Elite/Boss)
## - Barre "ghost" FTL (rattrapage retardé type Faster Than Light)
## - Préchargement des textures pour performance
##

# -------------------------------------------------------------------
# TEXTURES PRÉCHARGÉES (optimisation)
# -------------------------------------------------------------------

const TEX_HP_UNDER = preload("res://assets/sprites/ui/bar/hp_under.png")
const TEX_HP_OVER = preload("res://assets/sprites/ui/bar/hp_over.png")
const TEX_HP_PLAYER = preload("res://assets/sprites/ui/bar/hp_progress_player.png")
const TEX_HP_ENEMY = preload("res://assets/sprites/ui/bar/hp_progress_enemy.png")
const TEX_HP_ELITE = preload("res://assets/sprites/ui/bar/hp_progress_elite.png")
const TEX_HP_BOSS = preload("res://assets/sprites/ui/bar/hp_progress_boss.png")
const TEX_HP_GHOST_PLAYER = preload("res://assets/sprites/ui/bar/hp_ghost_player.png")
const TEX_HP_GHOST_ENEMY = preload("res://assets/sprites/ui/bar/hp_ghost_enemy.png")


# -------------------------------------------------------------------
# EXPORTS
# -------------------------------------------------------------------

enum HealthBarStyle { PLAYER, ENEMY, ELITE, BOSS }

@export var health_bar_style: HealthBarStyle = HealthBarStyle.ENEMY
@export var enable_ftl_bar: bool = true
@export var ftl_delay: float = 0.12
@export var ftl_catchup_time: float = 0.25


# -------------------------------------------------------------------
# RÉFÉRENCES (définies par le parent)
# -------------------------------------------------------------------

var health_bar: TextureProgressBar = null
var health_bar_ghost: TextureProgressBar = null

var ghost_tween: Tween = null


# -------------------------------------------------------------------
# INITIALISATION
# -------------------------------------------------------------------

func initialize(bar: TextureProgressBar, ghost_bar: TextureProgressBar, max_hp: int, current_hp: int) -> void:
	"""Doit être appelé par le parent après _ready()"""
	health_bar = bar
	health_bar_ghost = ghost_bar

	apply_style()
	update_bars(max_hp, current_hp, max_hp)


# -------------------------------------------------------------------
# API PUBLIQUE
# -------------------------------------------------------------------

func update_bars(max_hp: int, current_hp: int, previous_hp: int) -> void:
	"""Met à jour les barres de vie (appelé lors de dégâts/soins)"""
	if not is_instance_valid(health_bar):
		return

	# Barre réelle (HP instant)
	health_bar.max_value = max_hp
	health_bar.value = current_hp

	var show := current_hp < max_hp
	health_bar.visible = show

	# Barre ghost (FTL)
	if not enable_ftl_bar or not is_instance_valid(health_bar_ghost):
		return

	health_bar_ghost.max_value = max_hp
	health_bar_ghost.visible = show

	# Soin : on snap la ghost
	if health_bar_ghost.value < current_hp:
		health_bar_ghost.value = current_hp
		return

	# Dégâts : la ghost rattrape après un délai
	if ghost_tween != null and ghost_tween.is_running():
		ghost_tween.kill()

	ghost_tween = create_tween()
	ghost_tween.tween_interval(ftl_delay)
	ghost_tween.tween_property(health_bar_ghost, "value", current_hp, ftl_catchup_time)


func hide_bars() -> void:
	"""Cache les barres (utile à la mort)"""
	if is_instance_valid(health_bar):
		health_bar.visible = false
	if is_instance_valid(health_bar_ghost):
		health_bar_ghost.visible = false

	if ghost_tween != null and ghost_tween.is_running():
		ghost_tween.kill()


func apply_style() -> void:
	"""Applique le style de barre selon le type d'entité"""
	if not is_instance_valid(health_bar):
		return

	# Barre principale
	health_bar.texture_under = TEX_HP_UNDER
	health_bar.texture_over = TEX_HP_OVER

	match health_bar_style:
		HealthBarStyle.PLAYER:
			health_bar.texture_progress = TEX_HP_PLAYER
		HealthBarStyle.ENEMY:
			health_bar.texture_progress = TEX_HP_ENEMY
		HealthBarStyle.ELITE:
			health_bar.texture_progress = TEX_HP_ELITE
		HealthBarStyle.BOSS:
			health_bar.texture_progress = TEX_HP_BOSS

	# Barre ghost
	if not enable_ftl_bar or not is_instance_valid(health_bar_ghost):
		return

	health_bar_ghost.texture_under = TEX_HP_UNDER
	health_bar_ghost.texture_over = TEX_HP_OVER

	match health_bar_style:
		HealthBarStyle.PLAYER:
			health_bar_ghost.texture_progress = TEX_HP_GHOST_PLAYER
		_:
			health_bar_ghost.texture_progress = TEX_HP_GHOST_ENEMY
