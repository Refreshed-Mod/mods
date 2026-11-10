extends Node
func _initialize_mod(api: Variant) -> Variant:
	var fish: Variant = load("res://Resources/Creatures_Fish_Freshwater/fish_lake_perch.tres")
	if fish == null: return ERR_FILE_NOT_FOUND
	fish = fish.duplicate()
	fish.item_name = "Example Perch"
	fish.item_description = "A sample fish registered through the built-in mod API."
	fish.loot_table = "lake"
	fish.loot_weight = 0.5
	var result: Variant = api.register_fish("perch", fish)
	if result != OK: return result
	result = api.register_loot_table("pond")
	if result != OK: return result
	result = api.add_loot_entry(api.item_id("pond"), api.item_id("perch"), 1.0)
	if result != OK: return result
	return api.add_shop_item("general_shop", api.item_id("perch"), 75)
