shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ink_color : source_color = vec3(0.05, 0.04, 0.08);
uniform vec3 glow_color : source_color = vec3(0.96, 0.86, 0.42);

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv);

	// Vignette darkening edges
	float vignette = smoothstep(0.18, 0.92, d);

	// Concentric ink ripples that breathe outward
	float rings = sin(d * 36.0 - TIME * 5.0) * 0.5 + 0.5;
	rings = pow(rings, 5.0);

	// Slow-moving angular streaks for halftime "shutter" feel
	float ang = atan(uv.y, uv.x);
	float streaks = pow(0.5 + 0.5 * sin(ang * 6.0 + TIME * 0.7), 8.0);

	vec3 col = mix(ink_color, glow_color, rings * 0.55 + streaks * 0.18);

	float a = (vignette * 0.85 + rings * 0.12 + streaks * 0.10) * intensity;
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
