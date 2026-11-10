extends Node

const EVENTS = ["player_joined", "world_loaded", "fish_caught", "item_equipped", "map_changed"]
var api: Variant
var event_counts: Dictionary = {}
var listening: bool = false
var last_event: String = "No gameplay events yet."

func _initialize_mod(context: Variant) -> Variant:
	api = context
	var species: Variant = load("res://Resources/Cosmetics/species_cat.tres").duplicate()
	species.name = "API Demo Cat"
	species.desc = "A cat registered through the species API."
	var face: Variant = load("res://Scenes/Entities/Player/Face/player_face.tscn").instantiate()
	species.face_animation = face.get_node("AnimationPlayer").get_animation("cat_face").duplicate()
	face.free()
	var result: Variant = api.register_species("cat", species)
	if result != OK: return result
	var pattern: Variant = load("res://Resources/Cosmetic_Patterns/pattern_tux.tres").duplicate()
	pattern.name = "API Demo Tux"
	result = api.register_cosmetic("tux", pattern)
	if result != OK: return result
	result = api.assign_pattern_texture(api.cosmetic_id("tux"), api.cosmetic_id("cat"), pattern.body_pattern[1])
	if result != OK: return result
	result = api.assign_cosmetic_mesh("hat_beanie_blue", api.cosmetic_id("cat"), load("res://Resources/Cosmetic_Hats/hat_beanie_blue.tres").mesh)
	if result != OK: return result
	var rod: Variant = load("res://Resources/Item_Tools/fishing_rod_simple.tres").duplicate()
	rod.item_name = "API Demo Rod"
	rod.unselectable = false
	rod.item_description = "An ordinary fishing rod registered by a mod."
	result = api.register_item("rod", rod)
	if result != OK: return result
	var fish: Variant = load("res://Resources/Creatures_Fish_Freshwater/fish_lake_perch.tres").duplicate()
	fish.item_name = "API Demo Perch"
	fish.catch_blurb = "The mod API works!"
	fish.loot_table = "lake"
	fish.loot_weight = 1.0
	result = api.register_fish("perch", fish)
	if result != OK: return result
	result = api.register_loot_table("pond")
	if result != OK: return result
	result = api.add_loot_entry(api.item_id("pond"), api.item_id("perch"), 1.0)
	if result != OK: return result
	for item: Variant in ["rod", "perch"]:
		result = api.add_shop_item("general_shop", api.item_id(item), 25)
		if result != OK: return result
	result = api.register_map("island", "API Demo Island", "Scenes/demo_map.tscn")
	if result != OK: return result
	result = _set_listening(true)
	if result != OK: return result
	api.add_menu_action("Run API checks and save counter", _check)
	api.add_menu_action("Show observed gameplay events", _report_events)
	api.add_menu_action("Toggle gameplay event hooks", _toggle_events)
	api.add_menu_action("Unlock demo cosmetics for this save", _unlock)
	return OK

func _set_listening(enabled: Variant) -> Variant:
	for event: Variant in EVENTS:
		var callback: Variant = _event.bind(event)
		var result: Variant = api.on_event(event, callback) if enabled else api.off_event(event, callback)
		if result != OK: return result
	listening = enabled
	return OK

func _event(payload: Variant, event: Variant) -> void:
	event_counts[event] = event_counts.get(event, 0) + 1
	# Keep values only, a world reference goes invalid after a map change
	last_event = event + ": " + str(payload.get("item_id", payload.get("map_id", payload.get("player_id", ""))))

func _check() -> void:
	if api.cosmetic_id("cat") not in api.get_cosmetic_ids("species") or api.cosmetic_id("tux") not in api.get_cosmetic_ids("pattern"):
		api.show_message("Demo cosmetics are missing.")
		return
	var settings: Variant = api.get_settings()
	settings.checks = int(settings.checks) + 1
	var result: Variant = api.save_settings(settings)
	api.show_message("API checks passed; saved check #%d. Mod: %s" % [settings.checks, api.mod_id] if result == OK else "Settings save failed: " + error_string(result))

func _toggle_events() -> void:
	var result: Variant = _set_listening(not listening)
	api.show_message("Gameplay event hooks " + ("enabled." if listening else "disabled.") if result == OK else "Hook update failed: " + error_string(result))

func _report_events() -> void:
	var lines: Array = [last_event]
	for event: Variant in EVENTS: lines.append(event + ": " + str(event_counts.get(event, 0)))
	api.show_message("\n".join(lines))

func _unlock() -> void:
	if PlayerData.cosmetics_equipped.is_empty():
		api.show_message("Enter a save first, then unlock from Pause → Settings → Mods.")
		return
	for id: Variant in ["cat", "tux"]: PlayerData._unlock_cosmetic(api.cosmetic_id(id))
	api.show_message("Unlocked API Demo Cat and API Demo Tux for this save.")
