extends CanvasLayer
class_name AbilityBar

const ICONS: Array[Texture2D] = [
	preload("res://assets/sprites/ui/icons/abilities/warrior/shield_slam.png"),
	preload("res://assets/sprites/ui/icons/abilities/warrior/whirl_slash.png"),
	preload("res://assets/sprites/ui/icons/abilities/warrior/heroic_charge.png"),
	preload("res://assets/sprites/ui/icons/abilities/warrior/taunt_shout.png")
]

const KEY_LABELS := ["A", "Z", "E", "R"]
const SLOT_COUNT := 4
const COOLDOWN_OVERLAY_ALPHA := 0.6

var _ability_system: Node = null
var _slots: Array[Dictionary] = []


func _ready() -> void:
	_cache_slots()
	_refresh_ability_system_reference()
	set_process(true)


func _process(_delta: float) -> void:
	if not is_instance_valid(_ability_system):
		_refresh_ability_system_reference()

	_update_slot_states()


func _cache_slots() -> void:
	_slots.clear()

	for index in SLOT_COUNT:
		var slot_root: Control = get_node_or_null("Root/Slots/Slot%d" % index)
		if slot_root == null:
			push_error("AbilityBar: slot root manquant pour le slot %d (Root/Slots/Slot%d)." % [index, index])
			continue

		var button: TextureButton = slot_root.get_node_or_null("Button")
		var cooldown_label: Label = slot_root.get_node_or_null("Button/Cooldown")
		var key_label: Label = slot_root.get_node_or_null("Key")
		var cooldown_overlay: TextureProgressBar = slot_root.get_node_or_null("Button/CooldownOverlay")
		var glow: Panel = slot_root.get_node_or_null("Button/Glow")

		var missing_nodes: Array[String] = []
		if button == null:
			missing_nodes.append("Button")
		if cooldown_label == null:
			missing_nodes.append("Cooldown")
		if cooldown_overlay == null:
			missing_nodes.append("CooldownOverlay")
		if glow == null:
			missing_nodes.append("Glow")
		if key_label == null:
			missing_nodes.append("Key")

		if not missing_nodes.is_empty():
			push_error("AbilityBar: noeud(s) critique(s) manquant(s) pour le slot %d: %s." % [index, ", ".join(missing_nodes)])
			continue

		button.texture_normal = ICONS[index]
		button.texture_pressed = ICONS[index]
		button.texture_hover = ICONS[index]
		button.texture_disabled = ICONS[index]
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.ignore_texture_size = true
		button.pressed.connect(_on_slot_pressed.bind(index))

		key_label.text = KEY_LABELS[index]
		cooldown_label.visible = false
		cooldown_label.text = ""
		glow.visible = false

		cooldown_overlay.min_value = 0.0
		cooldown_overlay.max_value = 1.0
		cooldown_overlay.value = 0.0
		cooldown_overlay.tint_progress = Color(0.0, 0.0, 0.0, COOLDOWN_OVERLAY_ALPHA)

		_slots.append({
			"button": button,
			"cooldown": cooldown_label,
			"overlay": cooldown_overlay,
			"glow": glow
		})


func _refresh_ability_system_reference() -> void:
	_ability_system = get_tree().get_first_node_in_group("ability_system")

	if is_instance_valid(_ability_system):
		return

	var current_scene := get_tree().current_scene
	if is_instance_valid(current_scene):
		_ability_system = current_scene.find_child("AbilitySystem", true, false)
	else:
		_ability_system = null


func _on_slot_pressed(slot_index: int) -> void:
	if not is_instance_valid(_ability_system):
		_refresh_ability_system_reference()

	if not is_instance_valid(_ability_system):
		return

	if _ability_system.has_method("request_cast"):
		_ability_system.request_cast(slot_index)


func _update_slot_states() -> void:
	for index in _slots.size():
		var slot: Dictionary = _slots[index]
		if not _is_slot_valid(slot):
			push_warning("AbilityBar: slot %d invalide détecté dans _slots, entrée ignorée." % index)
			continue

		var remaining := _get_cooldown_remaining(index)
		var duration := _get_cooldown_duration(index)
		var has_cooldown := remaining > 0.0

		var button: TextureButton = slot["button"]
		var cooldown_label: Label = slot["cooldown"]
		var cooldown_overlay: TextureProgressBar = slot["overlay"]
		var glow: Panel = slot["glow"]

		button.modulate = Color(0.45, 0.45, 0.45, 1.0) if has_cooldown else Color.WHITE
		cooldown_label.visible = has_cooldown
		cooldown_label.text = _format_cooldown(remaining)

		if has_cooldown and duration > 0.001:
			cooldown_overlay.visible = true
			cooldown_overlay.value = clampf(remaining / duration, 0.0, 1.0)
		else:
			cooldown_overlay.visible = false
			cooldown_overlay.value = 0.0

		glow.visible = _is_targeting() and _get_targeting_slot_index() == index


func _is_slot_valid(slot: Dictionary) -> bool:
	return (
		slot.has("button")
		and slot.has("cooldown")
		and slot.has("overlay")
		and slot.has("glow")
		and slot["button"] != null
		and slot["cooldown"] != null
		and slot["overlay"] != null
		and slot["glow"] != null
	)


func _format_cooldown(seconds: float) -> String:
	if seconds >= 10.0:
		return "%ds" % int(round(seconds))

	return "%.1fs" % snappedf(seconds, 0.1)


func _is_targeting() -> bool:
	if not is_instance_valid(_ability_system):
		return false

	if _ability_system.has_method("is_targeting"):
		return bool(_ability_system.is_targeting())

	if _has_property(_ability_system, "state"):
		var state_value = _ability_system.get("state")
		if typeof(state_value) == TYPE_STRING or typeof(state_value) == TYPE_STRING_NAME:
			return String(state_value).to_upper() == "TARGETING"

		if _has_property(_ability_system, "TARGETING"):
			return state_value == _ability_system.get("TARGETING")

	return false


func _get_targeting_slot_index() -> int:
	if not is_instance_valid(_ability_system):
		return -1

	for method_name in ["get_targeting_slot_index", "get_selected_slot_index", "get_active_slot_index", "get_current_slot_index"]:
		if _ability_system.has_method(method_name):
			return int(_ability_system.call(method_name))

	for property_name in ["targeting_slot_index", "selected_slot_index", "active_slot_index", "current_slot_index"]:
		if _has_property(_ability_system, property_name):
			return int(_ability_system.get(property_name))

	return -1


func _get_cooldown_remaining(slot_index: int) -> float:
	if not is_instance_valid(_ability_system):
		return 0.0

	for method_name in ["get_cooldown_remaining", "get_slot_cooldown_remaining", "get_ability_cooldown_remaining"]:
		if _ability_system.has_method(method_name):
			return maxf(0.0, float(_ability_system.call(method_name, slot_index)))

	for property_name in ["cooldowns_remaining", "slot_cooldowns_remaining", "ability_cooldowns_remaining"]:
		if _has_property(_ability_system, property_name):
			var values = _ability_system.get(property_name)
			if values is Array and slot_index >= 0 and slot_index < values.size():
				return maxf(0.0, float(values[slot_index]))

	return 0.0


func _get_cooldown_duration(slot_index: int) -> float:
	if not is_instance_valid(_ability_system):
		return 0.0

	for method_name in ["get_cooldown_duration", "get_slot_cooldown_duration", "get_ability_cooldown_duration"]:
		if _ability_system.has_method(method_name):
			return maxf(0.0, float(_ability_system.call(method_name, slot_index)))

	for property_name in ["cooldown_durations", "slot_cooldown_durations", "ability_cooldown_durations"]:
		if _has_property(_ability_system, property_name):
			var values = _ability_system.get(property_name)
			if values is Array and slot_index >= 0 and slot_index < values.size():
				return maxf(0.0, float(values[slot_index]))

	return 0.0


func _has_property(node: Object, property_name: String) -> bool:
	for property_data in node.get_property_list():
		if String(property_data.name) == property_name:
			return true

	return false
