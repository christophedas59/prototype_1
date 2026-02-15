extends GutTest

const AbilityBarScene := preload("res://scenes/ui/ability_bar.tscn")
const SLOT_COUNT := 4


func test_ability_bar_caches_all_slots_with_required_nodes() -> void:
	var ability_bar: AbilityBar = AbilityBarScene.instantiate()
	add_child_autofree(ability_bar)

	await get_tree().process_frame

	var slots: Array = ability_bar.get("_slots")
	assert_eq(slots.size(), SLOT_COUNT, "AbilityBar doit mettre en cache exactement 4 slots valides")

	for index in slots.size():
		var slot: Dictionary = slots[index]
		assert_true(slot.has("button"), "Le slot %d doit exposer la clé 'button'" % index)
		assert_true(slot.has("cooldown"), "Le slot %d doit exposer la clé 'cooldown'" % index)
		assert_true(slot.has("overlay"), "Le slot %d doit exposer la clé 'overlay'" % index)
		assert_true(slot.has("glow"), "Le slot %d doit exposer la clé 'glow'" % index)
		assert_not_null(slot.get("button"), "Le bouton du slot %d doit être non nul" % index)
		assert_not_null(slot.get("cooldown"), "Le cooldown du slot %d doit être non nul" % index)
		assert_not_null(slot.get("overlay"), "L'overlay du slot %d doit être non nul" % index)
		assert_not_null(slot.get("glow"), "Le glow du slot %d doit être non nul" % index)
