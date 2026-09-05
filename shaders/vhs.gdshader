shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.5) = 0.72;
uniform float threat : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.6, 1.8) = 1.12;

float tape_noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float strength = clamp(intensity, 0.0, 1.5);
	float frame = floor(TIME * 23.976);
	float band_y = fract(TIME * 0.043 + 0.19);
	float band = 1.0 - smoothstep(0.0, 0.016, abs(uv.y - band_y));
	float line_noise = tape_noise(vec2(floor(uv.y * 360.0), frame));
	uv.x += (line_noise - 0.5) * 0.00048 * strength;
	uv.x += band * sin(TIME * 3.7) * 0.0014 * strength;
	float edge = smoothstep(0.15, 0.72, length(SCREEN_UV - vec2(0.5)));
	float fringe = (0.00042 + edge * 0.00065) * strength;
	vec3 color;
	color.r = texture(screen_texture, uv + vec2(fringe, 0.0)).r;
	color.g = texture(screen_texture, uv).g;
	color.b = texture(screen_texture, uv - vec2(fringe, 0.0)).b;
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(luma) * vec3(1.035, 1.005, 0.93), 0.22 * strength);
	float scanline = sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 3.14159265);
	color *= 1.0 - (0.012 + scanline * 0.008) * strength;
	float grain = tape_noise(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + vec2(frame, frame * 0.73)) - 0.5;
	color += grain * 0.027 * strength;
	color *= 1.0 - edge * 0.31 * min(strength, 1.0);
	color *= 1.0 + sin(TIME * 1.71) * 0.004 * strength;
	color -= vec3(band * 0.012 * strength);
	float dread = clamp(threat, 0.0, 1.0) * edge;
	color = mix(color, color * vec3(1.10, 0.76, 0.70), dread * 0.48);
	color += vec3(0.019, 0.002, 0.001) * dread;
	COLOR = vec4(max(color * brightness, vec3(0.0)), 1.0);
}
