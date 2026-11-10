extends Node

func _initialize_mod(api: RefCounted) -> Error:
	var bugs: Variant = api.get_service("refreshed.bugs", "bugs")
	if bugs == null: return ERR_UNAVAILABLE
	return bugs.register_bug("firefly", load(api.resource_path("firefly.tres")), {
		"weight": 0.05, "flying": true, "speed": 1.0, "run_speed": 3.0,
	})
