shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 8.0) = 2.5;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 0.25);

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec2 px = blur_amount * SCREEN_PIXEL_SIZE;
	vec3 col = vec3(0.0);
	float total = 0.0;

	// 9-tap gaussian
	float weights[3] = {0.227027, 0.316216, 0.070270};
	vec2 offs[5] = {
		vec2(0.0, 0.0),
		vec2(1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(-1.0, 0.0),
		vec2(0.0, -1.0)
	};

	col += texture(screen_tex, SCREEN_UV).rgb * weights[0];
	total += weights[0];
	for (int i = 1; i < 5; i++) {
		vec2 o = offs[i] * px;
		col += texture(screen_tex, SCREEN_UV + o).rgb * weights[1];
		col += texture(screen_tex, SCREEN_UV + o * 2.0).rgb * weights[2];
		total += weights[1] + weights[2];
	}
	col /= total;
	col = mix(col, tint.rgb, tint.a);
	COLOR = vec4(col, 1.0);
}
