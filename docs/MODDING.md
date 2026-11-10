# Modding

TLDR: a mod is a folder with a `manifest.json` and a GDScript file. Copy an example, change it, hit Refresh.

Mods are Godot 4 GDScript. Old GDWeave and Godot 3 mods won't work as is, they need porting. I ported Otters and WB_Construct, grab them from the mod browser if you want to see what that looks like.

Heads up, mods run with full game rights, there's no sandbox. Only install stuff you trust.

## Quick start

1. Mods menu > **Open folder**.
2. Copy [hello_webfishing](../examples/hello_webfishing) in there.
3. Press **Refresh**, enable it, press **Say hello**.

`manifest.json`
```json
{
  "id": "myname.hello",
  "name": "Hello",
  "version": "1.0.0",
  "author": "Your name",
  "description": "Says hello",
  "api_version": 1,
  "network_scope": "client",
  "entry": "main.gd",
  "dependencies": {},
  "default_settings": { "greetings": 0 }
}
```

`main.gd`
```gdscript
extends Node

var api

func _initialize_mod(context):
	api = context
	api.add_menu_action("Say hello", _hello)
	return OK

func _hello():
	var settings = api.get_settings()
	settings.greetings += 1
	api.save_settings(settings)
	api.show_message("Hello #%d" % settings.greetings)
```

Return `OK` from `_initialize_mod`, or an error code if something went wrong. If it fails, everything you registered gets rolled back, so you don't have to clean up yourself.

If your script has a `_shutdown_mod()` function it gets called when the mod unloads, same idea as `on_unload`.

## Manifest

- `id`: lowercase letters, numbers, `.` `_` `-`. Has to be unique, `yourname.modname` works fine.
- `version`: `major.minor.patch`.
- `dependencies`: mod ID to minimum version.
- `network_scope`: `client` if only you see it, `content` for gameplay and maps. Everyone in a lobby needs the same content mods (same version and hash) to join. Mods that only add a map are only needed when that map is being played.
- `default_settings`: optional, new keys get added automatically when you update.
- `icon`: optional, or just drop an `icon.png` in the folder.
- `items`: optional item list (`{"id": {"resource": "x.tres", "legacy_ids": []}}`). These load even when the mod is off, so old saves don't lose items.

## API

Pretty much everything returns an `Error`, unless it obviously returns something else. The `api` already knows your mod ID, you don't pass it.

**Basics**

| Call | What it does |
|---|---|
| `resource_path(path)` | Path to a file in your mod folder |
| `get_settings()` / `save_settings(dict)` | Global mod settings |
| `get_save_data()` / `save_data(dict)` | Per character progress, max 256 KiB |
| `add_menu_action(label, callback)` | Button in the Mods menu |
| `show_message(text)` | Message in the Mods menu |
| `on_unload(callback)` | Undo your own changes on unload |
| `on_event(name, callback)` / `off_event` | Listen to events |
| `publish_service(name, factory)` / `get_service(mod, name)` | Share stuff with mods that depend on you. `factory` gets their `api` and returns what you give them |
| `is_host()` / `is_offline()` | Network state |
| `is_enabled()` | False after your mod is unloaded, check it in timers |
| `get_cosmetic_ids(category)` | All cosmetic IDs in a category, like `hat` |

**Content** (use `"network_scope": "content"`, otherwise other players won't have your stuff)

| Call | What it does |
|---|---|
| `register_item(id, item, legacy_ids)` / `register_fish(id, item)` | Add an item or fish, fish go in the resource's `loot_table` with its `loot_weight` |
| `register_loot_table(id)` / `add_loot_entry(table, item, weight)` | Custom loot |
| `add_shop_item(shop, item, cost, no_duplicates, category)` | Sell an item, `category` like "misc" puts it in that section |
| `register_daily_reward(goal, item)` | Item for a daily request milestone |
| `register_quest(title, action, goal, amount, reward, icon, id)` | Add a quest, always pass a stable `id` |
| `register_map(id, name, scene_path)` | Add a map, see [MAPS.md](MAPS.md) |
| `register_cosmetic(id, res, legacy_ids)` / `register_species(id, res, legacy_ids)` | Cosmetics and species |
| `assign_cosmetic_mesh(cosmetic, species, mesh)` / `assign_pattern_texture(pattern, species, tex)` | Make cosmetics fit a species |
| `register_player_sound(id, stream, spatial)` / `play_player_sound(player, id, position, pitch)` | Player sounds |
| `register_player_animation(id, anim)` / `play_player_animation(player, id, full_body)` | Player animations |
| `register_actor(id, scene, host_only, limit)` / `spawn_actor(id, pos, zone)` | Networked actors, `spawn_actor` returns the actor ID or -1 |
| `register_tool(item, callback)` / `play_tool_animation(player, swing, retract, callback)` | What happens when you use an item, see Usable items |
| `register_capture(...)` / `request_capture(...)` / `award_catch(...)` | Host checked catching, see Adding bugs |
| `register_host_option(id, label, default, tooltip)` / `host_option(id)` | On/off setting for the host |
| `register_session_state(callback)` / `publish_session_state(dict)` | Sync state from host to players, max 16 KiB, see Session state |
| `register_music(id, stream, period, volume_db)` | Music, period is `day`, `night` or `any`. The host picks songs for everyone |
| `set_music_period(period)` | For day/night mods: `day`, `night`, or `""` for all songs |

Use `item_id()`, `cosmetic_id()` and `media_id()` to get full IDs, don't build them by hand.

Quest actions: `catch`, `catch_type`, `catch_big`, `catch_small`, `catch_rain`, `catch_hightier`, `catch_treasure`.

Shops: `general_shop`, `bait_shop`, `progression_shop`, `spectral`, `vending`, `boat`, `test_shop`.

## Events

Callbacks get one Dictionary.

| Event | Payload |
|---|---|
| `world_loaded` | `world`, `map_id`, `epoch` |
| `map_changed` | `map_id`, `epoch` |
| `player_joined` | `player_id` |
| `fish_caught` | `item_id`, `ref`, `size`, `quality`, `zone` |
| `item_equipped` | `item`, `player_id` |
| `actor_caught` | `player_id`, `item_id` |
| `save_loaded` / `save_reset` | `slot` |
| `session_state` | `mod_id`, `state` |
| `session_reset` | none |
| `environment_updated` | `environment`, `delta` |

Events are local only, they don't let you control other players. Keep callbacks short and don't hang on to `world` after a scene change.

## Good to know

- Turning a mod off removes what it registered. Items you own get parked and come back when you turn it on again, progress is never deleted.
- Cosmetics stay loaded until the game closes, so equipped stuff doesn't break.
- Refresh and enable/disable only work from the main menu.

## Usable items

Simplest is doing what the game does. Set `action` and `action_params` on your `ItemResource` and using the item calls that player function. Here's a drink that gets you drunk like beer:

```
category = "tool"
action = "_consume_item"
action_params = [ "beer" ]
```

`"beer_big"` is the stronger one. The other effects are `growth`, `shrink`, `revert`, `speed`, `speed_burst`, `catch`, `catch_big`, `catch_deluxe`, `bounce` and `bounce_big`.

Want your own code instead? Use `register_tool`. The callback gets the player who used it, which is always you:

```gdscript
api.register_tool(api.item_id("my_drink"), func(player): player.drunk_timer += 9000)
```

This doesn't use up the item, remove it from the inventory yourself if you need to. `play_tool_animation` plays a swing first and calls your callback with the player when it's done.

## Session state

Only the host can send it. Call `publish_session_state(dict)` whenever something changes, and the dict your `register_session_state` callback returns gets sent to people when they join.

Players get it through the `session_state` event, but only if their copy of your mod called `register_session_state` too. So just call it on everyone. Don't trust what you get, check every field.

## Installing and sharing

**Mods > Browse** installs from the catalog, dependencies included. New mods install disabled. You can add more catalogs in **Refreshed > Source > Mod Sources**. Want to publish your own? See the [catalog README](../README.md).

Modpacks are just a list of mods to turn on together. Put a `pack.json` in **Mods > Modpacks > Open folder**:

```json
{
  "id": "myname.pack",
  "name": "My pack",
  "version": "1.0.0",
  "author": "Your name",
  "mods": { "myname.hello": "1.0.0" }
}
```

## Examples

Easiest way to learn is to copy one of these and poke at it.

| Example | Shows |
|---|---|
| [hello_webfishing](../examples/hello_webfishing) | Settings and menu action |
| [api_demo](../examples/api_demo) | Every API call |
| [example_fish](../examples/example_fish) | Fish, loot table, shop |
| [example_bug_pack](../examples/example_bug_pack) | Adding bugs |
| [day_night](../examples/day_night) | Environment and lighting, already built in so just read it |

## Adding bugs

Depend on `"refreshed.bugs": "1.1.0"`, then:

```gdscript
func _initialize_mod(api):
	var bugs = api.get_service("refreshed.bugs", "bugs")
	if bugs == null: return ERR_UNAVAILABLE
	return bugs.register_bug("firefly", load(api.resource_path("firefly.tres")), {"weight": 0.05, "flying": true})
```

The item needs an `icon`, category `bug` and `bug_habitat` set to `INLAND`, `TREES` or `BEACH`. Options: `weight`, `flying`, `sprite_sheet`, `frames`, `pixel_size`, `speed`, `run_speed`, `limit`. The built in bugs add up to weight 1, so 0.05 is pretty rare.

Stuck? Ask in the [Discord](https://discord.gg/EMtmmwT29W).
