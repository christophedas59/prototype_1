extends GutTest

const PlayerWarriorScene := preload("res://scenes/entities/player_warrior.tscn")
const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")


func test_player_warrior_health_bar_uses_player_style_texture() -> void:
	var player: CombatEntity = PlayerWarriorScene.instantiate()
	add_child_autofree(player)

	await get_tree().process_frame

	assert_eq(
		player.health_bar.texture_progress.resource_path,
		"res://assets/sprites/ui/bar/hp_progress_player.png",
		"Le warrior joueur doit conserver une barre principale verte"
	)


func test_default_combat_entity_keeps_enemy_style_texture() -> void:
	var enemy: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(enemy)

	await get_tree().process_frame

	assert_eq(
		enemy.health_bar.texture_progress.resource_path,
		"res://assets/sprites/ui/bar/hp_progress_enemy.png",
		"Les entités par défaut restent sur le style ennemi"
	)
