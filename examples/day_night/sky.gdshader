shader_type sky;
render_mode disable_fog;

uniform vec3 sky_color : source_color = vec3(1.0, 0.933, 0.835);
uniform vec3 sun_color : source_color = vec3(1.0, 0.894, 0.604);
uniform vec3 rim_color : source_color = vec3(0.957, 0.663, 0.337);
uniform vec3 sun_direction = vec3(0.0, 0.866, 0.5);
uniform float sun_visibility = 0.0;
uniform float ray_rotation = 0.0;

void sky() {
	float alignment = dot(normalize(EYEDIR), sun_direction);
	COLOR = sky_color;
	if (sun_visibility > 0.0 && alignment > cos(radians(9.0))) {
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), sun_direction));
		vec3 up = cross(sun_direction, right);
		vec2 local = vec2(dot(EYEDIR, right), dot(EYEDIR, up)) / alignment / tan(radians(2.7));
		vec2 pixel = floor(local * 12.0 + 0.5) / 12.0;
		float radius = length(pixel);
		float disc = 1.0 - step(1.0, radius);
		float core = 1.0 - step(0.84, radius);
		float angle = atan(pixel.y, pixel.x + 0.00001) + ray_rotation;
		float rays = step(0.88, cos(angle * 8.0)) * step(1.1, radius) * (1.0 - step(1.42, radius));
		float glow = (1.0 - smoothstep(1.0, 3.2, length(local))) * 0.14;
		vec3 gold = mix(sun_color, rim_color, 0.25);
		vec3 fill = mix(sun_color, vec3(1.0, 0.98, 0.78), clamp(pixel.y * 0.5 + 0.5, 0.0, 1.0) * 0.3);
		COLOR = mix(COLOR, gold, glow * sun_visibility);
		COLOR = mix(COLOR, gold, rays * sun_visibility);
		COLOR = mix(COLOR, mix(rim_color, fill, core), disc * sun_visibility);
	}
}
