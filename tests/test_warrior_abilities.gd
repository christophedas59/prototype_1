extends GutTest

const CombatEntityScene := preload("res://scenes/entities/combat_entity.tscn")
const ShieldSlamAbility := preload("res://scripts/abilities/warrior/shield_slam_ability.gd")
const WhirlSlashAbility := preload("res://scripts/abilities/warrior/whirl_slash_ability.gd")


func _spawn_entity(position: Vector2, as_enemy: bool) -> CombatEntity:
	var entity: CombatEntity = CombatEntityScene.instantiate()
	add_child_autofree(entity)
	entity.global_position = position
	entity.is_player = not as_enemy
	entity.autonomous = false
	entity.is_enemy = as_enemy
	return entity


func test_cooldown_starts_on_validate_only_and_cancel_keeps_spell_available() -> void:
	var ability := ShieldSlamAbility.new()
	assert_false(ability.is_on_cooldown(), "Pré-condition: pas de cooldown")

	assert_true(ability.begin_targeting(), "Le ciblage doit pouvoir démarrer hors cooldown")
	assert_false(ability.is_on_cooldown(), "Le cooldown ne démarre pas au début du targeting")

	ability.cancel_targeting()
	assert_false(ability.is_on_cooldown(), "Une annulation ne doit jamais déclencher le cooldown")
	assert_true(ability.begin_targeting(), "On doit pouvoir recibler immédiatement après annulation")


func test_shield_slam_applies_scaled_damage_and_stun_meta() -> void:
	var caster := _spawn_entity(Vector2.ZERO, false)
	var target := _spawn_entity(Vector2(20, 0), true)

	await get_tree().process_frame
	caster.attack_damage = 10
	caster.feedback_comp.enable_hit_pause = false
	target.feedback_comp.enable_hit_pause = false

	var ability := ShieldSlamAbility.new()
	assert_true(ability.begin_targeting())

	var initial_hp := target.hp
	var cast_success := ability.validate_cast(caster, {"target": target})
	assert_true(cast_success, "Le cast validé doit réussir")
	assert_true(ability.is_on_cooldown(), "Le cooldown démarre à la validation")
	assert_eq(target.hp, initial_hp - 8, "Shield Slam doit infliger 0.8 * attack_damage")
	assert_true(target.has_meta("stunned_until_msec"), "Un fallback de stun doit être enregistré")


func test_whirl_slash_hits_each_enemy_once_in_radius() -> void:
	var caster := _spawn_entity(Vector2.ZERO, false)
	var in_range_enemy := _spawn_entity(Vector2(30, 0), true)
	var far_enemy := _spawn_entity(Vector2(80, 0), true)

	await get_tree().process_frame
	caster.attack_damage = 10

	var ability := WhirlSlashAbility.new()
	assert_true(ability.begin_targeting())
	var cast_success := ability.validate_cast(caster, {"targets": [in_range_enemy, far_enemy]})

	assert_true(cast_success)
	assert_eq(in_range_enemy.hp, in_range_enemy.max_hp - 6, "Whirl Slash doit infliger 0.6 * attack_damage en AOE")
	assert_eq(far_enemy.hp, far_enemy.max_hp, "Les cibles hors rayon ne doivent pas être touchées")
