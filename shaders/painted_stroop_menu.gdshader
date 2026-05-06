shader_type canvas_item;

// Hand-drawn ink-on-paper menu background, Balatro-style flowing swirls.
uniform vec4 ink_red    : source_color = vec4(0.93, 0.22, 0.26, 1.0);
uniform vec4 ink_blue   : source_color = vec4(0.16, 0.50, 0.88, 1.0);
uniform vec4 ink_yellow : source_color = vec4(0.97, 0.80, 0.22, 1.0);
uniform vec4 ink_green  : source_color = vec4(0.34, 0.70, 0.34, 1.0);
uniform vec4 paper      : source_color = vec4(0.97, 0.93, 0.84, 1.0);
uniform vec4 paper_edge : source_color = vec4(0.74, 0.62, 0.46, 1.0);
uniform float speed = 0.07;
uniform float swirl_scale = 1.7;
uniform float ink_intensity = 0.85;
uniform float vignette_strength = 0.55;
uniform float grain_strength = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = r * p * 2.02;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 p = (uv - 0.5) * swirl_scale;
	float t = TIME * speed;

	// Two-stage domain warping — slow painterly flow.
	vec2 q = vec2(
		fbm(p + vec2(0.0,  t)),
		fbm(p + vec2(5.2, -t * 0.7))
	);
	vec2 w = vec2(
		fbm(p + 3.6 * q + vec2(1.7, 9.2) + t * 0.5),
		fbm(p + 3.6 * q + vec2(8.3, 2.8) - t * 0.6)
	);
	float f = fbm(p + 4.0 * w);

	// Hand-drawn jitter so ink boundaries feel rough.
	float jitter = (vnoise(uv * 220.0) - 0.5) * 0.05;
	float jitter_lo = (vnoise(uv * 60.0) - 0.5) * 0.10;

	vec3 color = paper.rgb;

	// Layered ink washes — stroop colours bleed into each other.
	float blue_mask   = smoothstep(0.32, 0.58, f + jitter + jitter_lo) * ink_intensity;
	float red_mask    = smoothstep(0.55, 0.78, f + jitter) * ink_intensity;
	float yellow_mask = smoothstep(0.42, 0.62, length(q) + jitter * 0.5) * ink_intensity * 0.55;
	float green_mask  = smoothstep(0.55, 0.78, length(w) + jitter) * ink_intensity * 0.45;

	color = mix(color, ink_blue.rgb,   blue_mask);
	color = mix(color, ink_red.rgb,    red_mask);
	color = mix(color, ink_yellow.rgb, yellow_mask);
	color = mix(color, ink_green.rgb,  green_mask);

	// Subtle cross-hatch streaks evoke pencil shading.
	float hatch_a = sin((uv.x * 1.0 + uv.y * 1.2) * 520.0 + fbm(uv * 5.0) * 6.0);
	float hatch_b = sin((uv.x * 1.2 - uv.y * 0.9) * 460.0 + fbm(uv * 5.0 + 3.0) * 6.0);
	float hatch = (smoothstep(0.82, 1.0, hatch_a) + smoothstep(0.82, 1.0, hatch_b)) * 0.06;
	color *= 1.0 - hatch;

	// Paper fibre — long, thin horizontal noise.
	float fibre = fbm(uv * vec2(180.0, 6.0));
	color = mix(color, color * 0.92, smoothstep(0.45, 0.7, fibre) * 0.35);

	// Fine grain.
	float g = hash(floor(FRAGCOORD.xy));
	color += (g - 0.5) * grain_strength;

	// Aged-page vignette toward warm edge tone.
	float d = length(uv - 0.5);
	color = mix(color, paper_edge.rgb, smoothstep(0.30, 0.95, d) * vignette_strength);

	COLOR = vec4(color, 1.0);
}
