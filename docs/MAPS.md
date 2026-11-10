# Maps

## Hosting

**Create Game > Map** shows your installed maps, pick one. Main Island is the default. The host can also switch maps while playing from **Pause > Change Map**, everyone reloads into the new map. Props and drawings are cleared, inventories are kept.

Everyone needs the same map installed. If someone doesn't have it, the join or switch is cancelled and they get told which one is missing. Maps aren't downloaded automatically, install them from **Mods > Browse**.

## Making a map

Use `"network_scope": "content"` and register the scene:

```gdscript
extends Node

func _initialize_mod(api):
	return api.register_map("my_map", "My Map", "Scenes/my_map.tscn")
```

The ID becomes `your.mod.my_map`. The scene path is relative to your mod folder.

The scene must:
- extend `res://Scenes/Map/main_map.gd`
- have `spawn_position` and `tutorial_spawn_position` Marker3Ds
- have a `zones` node with the same zones as the base game
