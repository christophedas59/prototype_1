extends CharacterBody2D
##
## Fighter.gd (script commun Warrior + Zombies)
## Godot 4.5.x — Prototype 2D top-down
##
## Rôle :
## - Déplacement (joueur ou IA)
## - Ciblage (plus proche)
## - Attaque auto + cooldown
## - PV + barre de vie (TextureProgressBar) + barre “ghost” façon FTL
## - Feedback : hit-pause, flash, knockback, i-frames
## - Mort : anim death + fade + queue_free
##

# -------------------------------------------------------------------
# 1) CONSTANTES — Préchargement des textures (optimisation)
# -------------------------------------------------------------------

const TEX_HP_UNDER = preload("res://art/ui/bar/hp_under.png")
const TEX_HP_OVER = preload("res://art/ui/bar/hp_over.png")
const TEX_HP_PLAYER = preload("res://art/ui/bar/hp_progress_player.png")
const TEX_HP_ENEMY = preload("res://art/ui/bar/hp_progress_enemy.png")
const TEX_HP_ELITE = preload("res://art/ui/bar/hp_progress_elite.png")
const TEX_HP_BOSS = preload("res://art/ui/bar/hp_progress_boss.png")
const TEX_HP_GHOST_PLAYER = preload("res://art/ui/bar/hp_ghost_player.png")
const TEX_HP_GHOST_ENEMY = preload("res://art/ui/bar/hp_ghost_enemy.png")


# -------------------------------------------------------------------
# 2) PARAMÈTRES (EXPORTS) — réglables dans l'Inspector
# -------------------------------------------------------------------

@export var is_player: bool = false
@export var is_enemy: bool = false

# Si true, le perso se joue comme un autobattler (poursuite + attaque auto sur cible la plus proche)
@export var autonomous: bool = false

# Optionnel : quand on est immobile (et en mode manuel), on peut “regarder” une cible
@export var look_at_target: bool = false

# Mouvement
@export var move_speed: float = 90.0

# Combat
@export var attack_range: float = 32.0
@export var attack_cooldown: float = 1.2
@export var attack_damage: int = 1

# Vie
@export var max_hp: int = 10

# I-frames : invincibilité courte après un hit (évite la “mitraillette”)
@export var i_frames: float = 0.25

# Knockback (recul)
@export var knockback_force: float = 140.0
@export var knockback_friction: float = 800.0 # plus haut = revient plus vite à 0
@export var facing_lock_on_knockback: bool = true # évite les flips d’orientation durant un recul

# Ciblage
@export var retarget_distance_bonus: float = 16.0 # (utile si tu réactives un ciblage “souple”)

# Style de barre de vie (couleur selon entité)
enum HealthBarStyle { PLAYER, ENEMY, ELITE, BOSS }
@export var health_bar_style: HealthBarStyle = HealthBarStyle.ENEMY

# Barre FTL (ghost retardée)
@export var enable_ftl_bar: bool = true
@export var ftl_delay: float = 0.12
@export var ftl_catchup_time: float = 0.25

# Hit-pause (hit-stop)
@export var enable_hit_pause: bool = true
@export var hit_pause_duration: float = 0.04   # ~0.03 à 0.06
@export var hit_pause_scale: float = 0.05      # 0.0 = freeze total ; 0.05 = quasi-freeze


# -------------------------------------------------------------------
# 3) RÉFÉRENCES NODES (ONREADY)
# -------------------------------------------------------------------

@onready var visual: AnimatedSprite2D = $Visual
@onready var health_bar: TextureProgressBar = $HealthBar
@onready var health_bar_ghost: TextureProgressBar = $HealthBarGhost
@onready var body_collision: CollisionShape2D = get_node_or_null("BodyCollision")


# -------------------------------------------------------------------
# 4) ÉTAT RUNTIME (variables internes)
# -------------------------------------------------------------------

var hp: int
var facing: String = "down"

var attack_timer: float = 0.0
var invuln_timer: float = 0.0

var is_attacking: bool = false
var is_dead: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var ghost_tween: Tween

# Cible persistante (autobattler + ennemis)
var current_target: Node2D = null

# Cache pour le ciblage (optimisation)
var _cached_targets: Array[Node2D] = []
var _target_cache_timer: float = 0.0
const TARGET_CACHE_INTERVAL: float = 0.1  # Mise à jour tous les 0.1s

# Réutilisation du flash tween (optimisation)
var _flash_tween: Tween = null




# -------------------------------------------------------------------
# 5) CYCLE DE VIE
# -------------------------------------------------------------------

func _ready() -> void:
	hp = max_hp

	apply_health_bar_style()
	update_health_bar()

	# Initialise ghost bar à la valeur actuelle
	if enable_ftl_bar and is_instance_valid(health_bar_ghost):
		health_bar_ghost.max_value = max_hp
		health_bar_ghost.value = hp
		health_bar_ghost.visible = health_bar.visible

	# Animation idle initiale
	var frames := visual.sprite_frames
	if frames != null and frames.has_animation("idle_" + facing):
		visual.play("idle_" + facing)

	# Connect une seule fois (slash + death)
	if not visual.animation_finished.is_connected(_on_animation_finished):
		visual.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Timers internes
	attack_timer = max(attack_timer - delta, 0.0)
	invuln_timer = max(invuln_timer - delta, 0.0)

	# Mise à jour du cache de ciblage
	_target_cache_timer -= delta
	if _target_cache_timer <= 0.0:
		_update_target_cache()
		_target_cache_timer = TARGET_CACHE_INTERVAL

	# --- Logique de déplacement / IA ---
	if is_player:
		if autonomous:
			autonomous_move_and_fight("enemy")
		else:
			player_move()
	elif is_enemy:
		enemy_move()

	# --- Knockback : s'applique par-dessus le mouvement et décroit ---
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	# Optionnel : en mode manuel uniquement, regarder une cible quand immobile
	if look_at_target and not autonomous and velocity.length() <= 1.0:
		var target := get_closest_alive_in_group("enemy")
		if target != null:
			update_facing_from_vector(target.global_position - global_position)

	# Un seul appel à move_and_slide() par frame (optimisation)
	move_and_slide()

	update_animation()


func _exit_tree() -> void:
	# Sécurité : éviter de rester "ralenti" si on quitte la scène pendant un hit-pause
	HitPauseManager.force_restore()


# -------------------------------------------------------------------
# 6) DÉPLACEMENTS
# -------------------------------------------------------------------

func player_move() -> void:
	# Pour un proto lisible : pas de déplacement pendant le slash
	if is_attacking:
		velocity = Vector2.ZERO
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	velocity = input_dir * move_speed


func autonomous_move_and_fight(target_group: String) -> void:
	# Autobattler : on garde la cible tant qu'elle est vivante / valide
	if not is_target_valid(current_target):
		current_target = get_closest_alive_in_group(target_group)

	if current_target == null:
		velocity = Vector2.ZERO
		return

	var to_target := current_target.global_position - global_position
	var dist := to_target.length()

	# Toujours faire face à la cible
	update_facing_from_vector(to_target)

	# Attaque si à portée
	if dist <= attack_range:
		velocity = Vector2.ZERO
		try_attack(current_target)
		return

	# Poursuite si pas en train de slasher
	velocity = Vector2.ZERO if is_attacking else to_target.normalized() * move_speed


func enemy_move() -> void:
	# Ennemi : même logique que l'autobattler, mais la cible est le groupe player
	if is_attacking:
		velocity = Vector2.ZERO
		return

	var target := get_closest_alive_in_group("player")
	if target == null:
		velocity = Vector2.ZERO
		return

	current_target = target

	var to_target := target.global_position - global_position
	var dist := to_target.length()

	# Toujours faire face à la cible (même si on recule)
	update_facing_from_vector(to_target)

	if dist <= attack_range:
		velocity = Vector2.ZERO
		try_attack(target)
		return

	velocity = to_target.normalized() * move_speed


# -------------------------------------------------------------------
# 7) CIBLAGE / UTILITAIRES
# -------------------------------------------------------------------

func is_target_valid(t: Node2D) -> bool:
	return is_instance_valid(t) and t.get("is_dead") != true


func _update_target_cache() -> void:
	"""Met à jour le cache des cibles potentielles (optimisation)"""
	_cached_targets.clear()

	# Détermine le groupe à cibler
	var target_group := ""
	if is_player or autonomous:
		target_group = "enemy"
	elif is_enemy:
		target_group = "player"
	else:
		return

	var nodes := get_tree().get_nodes_in_group(target_group)
	for n in nodes:
		if n is Node2D:
			var nd := n as Node2D
			if nd.get("is_dead") != true:
				_cached_targets.append(nd)


func get_closest_alive_in_group(group_name: String) -> Node2D:
	"""Trouve la cible la plus proche en utilisant le cache"""
	var best: Node2D = null
	var best_d: float = INF

	# Utilise le cache si disponible et valide
	var search_list: Array = _cached_targets if _cached_targets.size() > 0 else get_tree().get_nodes_in_group(group_name)

	for n in search_list:
		if not is_instance_valid(n) or not (n is Node2D):
			continue

		var nd := n as Node2D

		# Ignore les morts
		if nd.get("is_dead") == true:
			continue

		var d: float = global_position.distance_squared_to(nd.global_position)  # Plus rapide que distance_to
		if d < best_d:
			best_d = d
			best = nd

	return best


# -------------------------------------------------------------------
# 8) ATTAQUE / DÉGÂTS / MORT
# -------------------------------------------------------------------

func try_attack(target: Node2D) -> void:
	if is_dead or is_attacking or attack_timer > 0.0 or target == null:
		return

	attack_timer = attack_cooldown
	is_attacking = true

	# Facing au moment de l'attaque (évite les vecteurs quasi nuls)
	var to_target := target.global_position - global_position
	if to_target.length() > 0.1:
		update_facing_from_vector(to_target)

	play_attack_animation()

	# Proto : dégâts sans hitbox
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage, self)


func play_attack_animation() -> void:
	var frames := visual.sprite_frames
	if frames == null:
		is_attacking = false
		return

	var anim := "slash_" + facing

	# Fallback si une direction manque
	if not frames.has_animation(anim):
		if frames.has_animation("slash_down"):
			anim = "slash_down"
		else:
			is_attacking = false
			return

	visual.play(anim)


func _on_animation_finished() -> void:
	# Fin de slash = fin d'attaque
	if visual.animation.begins_with("slash_"):
		is_attacking = false

	# Fin death = fade + suppression
	if visual.animation == "death" and is_dead:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.25)
		tween.finished.connect(func():
			if is_instance_valid(self):
				queue_free()
		)


func take_damage(amount: int, from: Node2D = null) -> void:
	if is_dead:
		return
	if invuln_timer > 0.0:
		return

	invuln_timer = i_frames

	hp = clamp(hp - amount, 0, max_hp)
	update_health_bar()

	# Hit-pause (feedback d'impact) via singleton
	if enable_hit_pause:
		HitPauseManager.request_hit_pause(hit_pause_duration, hit_pause_scale)

	# Knockback (recul) si on connaît l'attaquant
	if from != null and from is Node2D:
		var dir := (global_position - from.global_position).normalized()
		knockback_velocity = dir * knockback_force

	# Flash rouge rapide (réutilisation du tween)
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()

	visual.modulate = Color(1, 0.6, 0.6)
	_flash_tween = create_tween()
	_flash_tween.tween_interval(0.08)
	_flash_tween.tween_property(visual, "modulate", Color(1, 1, 1), 0.0)

	if hp <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	current_target = null

	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO

	# Stop la ghost bar si elle était en tween
	if ghost_tween != null and ghost_tween.is_running():
		ghost_tween.kill()

	# Cache les barres
	if is_instance_valid(health_bar):
		health_bar.visible = false
	if is_instance_valid(health_bar_ghost):
		health_bar_ghost.visible = false

	# Désactive la collision pour éviter les interactions post-mort
	if is_instance_valid(body_collision):
		body_collision.disabled = true

	# Joue l'anim death si dispo, sinon fallback fade direct
	var frames := visual.sprite_frames
	if frames != null and frames.has_animation("death"):
		visual.play("death")
	else:
		var tween := create_tween()
		tween.tween_property(visual, "modulate:a", 0.0, 0.25)
		tween.finished.connect(func():
			if is_instance_valid(self):
				queue_free()
		)


# -------------------------------------------------------------------
# 9) UI : BARRE DE VIE + STYLE (couleurs)
# -------------------------------------------------------------------

func update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return

	# Barre réelle (HP instant)
	health_bar.max_value = max_hp
	health_bar.value = hp

	var show := hp < max_hp and not is_dead
	health_bar.visible = show

	# Barre ghost (FTL : rattrapage retardé)
	if not enable_ftl_bar or not is_instance_valid(health_bar_ghost):
		return

	health_bar_ghost.max_value = max_hp
	health_bar_ghost.visible = show

	# Soin : on snap la ghost (sinon visuellement étrange)
	if health_bar_ghost.value < hp:
		health_bar_ghost.value = hp
		return

	# Dégâts : la ghost rattrape après un délai
	if ghost_tween != null and ghost_tween.is_running():
		ghost_tween.kill()

	ghost_tween = create_tween()
	ghost_tween.tween_interval(ftl_delay)
	ghost_tween.tween_property(health_bar_ghost, "value", hp, ftl_catchup_time)


func apply_health_bar_style() -> void:
	if not is_instance_valid(health_bar):
		return

	# Barre principale (HP réel) - utilise les constantes préchargées
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

	# Barre ghost (FTL)
	if not enable_ftl_bar or not is_instance_valid(health_bar_ghost):
		return

	health_bar_ghost.texture_under = TEX_HP_UNDER
	health_bar_ghost.texture_over = TEX_HP_OVER

	match health_bar_style:
		HealthBarStyle.PLAYER:
			health_bar_ghost.texture_progress = TEX_HP_GHOST_PLAYER
		_:
			health_bar_ghost.texture_progress = TEX_HP_GHOST_ENEMY


# -------------------------------------------------------------------
# 10) ANIMATIONS / ORIENTATION
# -------------------------------------------------------------------

func update_facing_from_vector(v: Vector2) -> void:
	if v.length() < 0.001:
		return

	if abs(v.x) > abs(v.y):
		facing = "right" if v.x > 0 else "left"
	else:
		facing = "down" if v.y > 0 else "up"


func update_animation() -> void:
	if is_dead or is_attacking:
		return

	var moving := velocity.length() > 1.0

	# Important : on ne recalcule le facing depuis la vitesse QUE pour le joueur manuel.
	# - Autobattler : facing géré par la cible
	# - Ennemi : facing géré par la cible
	if moving and (not autonomous) and (not is_enemy):
		var knockbacking := knockback_velocity.length() > 1.0
		if (not facing_lock_on_knockback) or (not knockbacking):
			update_facing_from_vector(velocity)

	var frames := visual.sprite_frames
	if frames == null:
		return

	var anim := ("walk_" if moving else "idle_") + facing
	if frames.has_animation(anim) and visual.animation != anim:
		visual.play(anim)
