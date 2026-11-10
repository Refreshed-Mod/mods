extends Node

const Clock = preload("clock.gd")
const SKY_SHADER = preload("sky.gdshader")
var api: RefCounted
var clock: Node
var environments: Dictionary = {}
var music_period: String = ""

func _initialize_mod(context: RefCounted) -> Error:
	api = context
	clock = Clock.new()
	clock.api = api
	add_child(clock)
	var result: Error = api.register_host_option("sync_local_time", "Sync with local time", true, "Use the host's local clock. Disable for a 30-minute day/night cycle.")
	if result != OK: return result
	result = api.register_session_state(clock.snapshot)
	if result != OK: return result
	for event: String in ["world_loaded", "session_state", "session_reset", "environment_updated"]:
		result = api.on_event(event, Callable(self, "_" + event))
		if result != OK: return result
	return api.on_unload(_restore)

func _world_loaded(_data: Dictionary) -> void:
	clock.start()

func _session_state(data: Dictionary) -> void:
	if data.mod_id == api.mod_id: clock.receive(data.state)

func _session_reset(_data: Dictionary) -> void:
	clock.reset()
	_restore()

func _environment_updated(data: Dictionary) -> void:
	var env: WorldEnvironment = data.environment
	if not clock.running or not env.environment_effects_enabled:
		if environments.has(env.get_instance_id()):
			_restore_environment(environments[env.get_instance_id()])
			environments.erase(env.get_instance_id())
		return
	var light: DirectionalLight3D = env.get_node("DirectionalLight3D")
	if not environments.has(env.get_instance_id()):
		for id: int in environments.keys():
			if environments[id].node.get_ref() == null: environments.erase(id)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SKY_SHADER
		environments[env.get_instance_id()] = {"node": weakref(env), "sky": env.environment.sky, "mode": env.environment.background_mode, "energy": env.environment.background_energy_multiplier, "basis": light.basis, "color": light.light_color, "material": material}
		var sky: Sky = Sky.new()
		sky.radiance_size = Sky.RADIANCE_SIZE_32
		sky.sky_material = material
		env.environment.sky = sky
		env.environment.background_mode = Environment.BG_SKY
		env.environment.background_energy_multiplier = 1.0
	var material: ShaderMaterial = environments[env.get_instance_id()].material
	var lerp_val: float = 1.0 - exp(-data.delta * 3.0)
	var time: float = clock.phase()
	var colors: Dictionary = lighting(time)
	env.des_color = colors.sky
	env.des_ambient = colors.ambient
	env.des_light = colors.energy
	if env.rain:
		env.des_color = env.des_color.lerp(Color("#778688"), 0.45)
		env.des_ambient = env.des_ambient.lerp(Color("#778688"), 0.45)
		env.des_light *= 0.5
	light.light_color = light.light_color.lerp(colors.sun, lerp_val)
	var direction: Vector3 = sun_direction(time)
	var light_direction: Vector3 = direction if direction.y >= 0.0 else -direction
	light.look_at(light.global_position - light_direction, Vector3.UP)
	material.set_shader_parameter("sun_direction", direction)
	material.set_shader_parameter("sun_color", colors.sun_disc)
	material.set_shader_parameter("ray_rotation", Time.get_ticks_msec() * 0.000025)
	material.set_shader_parameter("sun_visibility", smoothstep(-0.02, 0.02, direction.y) * (0.2 if env.rain else 1.0))
	material.set_shader_parameter("sky_color", env.environment.background_color)

func _process(_delta: float) -> void:
	if not clock.running or not api.is_host(): return
	# same sun as the sky
	var period: String = "night" if sun_direction(clock.phase()).y < 0.0 else "day"
	if period != music_period:
		music_period = period
		api.set_music_period(period)

func _restore() -> void:
	music_period = ""
	api.set_music_period("")
	for state: Dictionary in environments.values(): _restore_environment(state)
	environments.clear()

func _restore_environment(state: Dictionary) -> void:
	var env: Node = state.node.get_ref()
	if env == null: return
	env.environment.sky = state.sky
	env.environment.background_mode = state.mode
	env.environment.background_energy_multiplier = state.energy
	env.get_node("DirectionalLight3D").basis = state.basis
	env.get_node("DirectionalLight3D").light_color = state.color
	env._rain_env(env.rain, true)

static func sun_direction(time: float) -> Vector3:
	var angle: float = (time - 0.25) * TAU
	return Vector3(-cos(angle), sin(angle) * 0.8660254, sin(angle) * 0.5).rotated(Vector3.UP, deg_to_rad(35.0)).normalized()

static func lighting(time: float) -> Dictionary:
	var height: float = sin((time - 0.25) * TAU)
	var daylight: float = smoothstep(-0.12, 0.18, height)
	var warmth: float = (1.0 - smoothstep(0.05, 0.45, absf(height))) * daylight
	return {
		"sky": Color("#16253f").lerp(Color("#ffeed5"), daylight).lerp(Color("#e8a06f"), warmth * 0.55),
		"ambient": Color("#7183aa").lerp(Color("#ffeed5"), daylight),
		"sun": Color("#8eaee5").lerp(Color("#fff0da"), daylight).lerp(Color("#ffb77f"), warmth),
		"sun_disc": Color("#ffe49a").lerp(Color("#ffaf64"), warmth),
		"energy": lerpf(0.035, 0.12, daylight),
	}

