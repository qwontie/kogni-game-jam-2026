shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(0.98, 0.93, 0.72, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.0, 289.0))) * 19081.17);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = uv - 0.5;
	float p = smoothstep(0.0, 1.0, progress);
	float wobble = noise(uv * 9.0 + vec2(TIME * 1.8, -TIME)) - 0.5;
	float wave = sin((uv.y + wobble * 0.18) * 34.0 + TIME * 10.0) * 0.018 * p;
	float pull = p * p * (0.18 + length(center) * 0.45);
	vec2 smear = normalize(center + vec2(0.001)) * pull + vec2(wave, wobble * 0.10 * p);

	vec3 base = texture(screen_texture, uv + smear).rgb;
	vec3 red = texture(screen_texture, uv + smear + vec2(0.018 * p, 0.0)).rgb;
	vec3 blue = texture(screen_texture, uv + smear - vec2(0.014 * p, 0.0)).rgb;
	vec3 split = vec3(red.r, base.g, blue.b);

	float cover = smoothstep(0.18, 1.0, p);
	vec3 color = mix(split, flash_color.rgb, cover);
	float alpha = smoothstep(0.02, 0.12, p);
	COLOR = vec4(color, alpha);
}
