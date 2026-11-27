shader_type canvas_item;
uniform float age : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	// The bell chain bends progressively below the suspension cable. The two
	// posts and the grounded stonework never move with the bells.
	float suspended = smoothstep(0.35, 0.5, UV.x) * (1.0 - smoothstep(0.56, 0.68, UV.x));
	float side_bells = smoothstep(0.23, 0.3, UV.x) * (1.0 - smoothstep(0.4, 0.47, UV.x))
		+ smoothstep(0.60, 0.68, UV.x) * (1.0 - smoothstep(0.75, 0.81, UV.x));
	float weight = max(suspended, side_bells) * smoothstep(0.38, 0.78, UV.y);
	float swing = sin(age * 31.0) * pow(1.0 - age, 1.7) * 0.045;
	vec4 sprite = texture(TEXTURE, UV - vec2(weight * swing, 0.0));
	sprite.rgb += vec3(0.32, 0.22, 0.06) * weight * (1.0 - smoothstep(0.05, 0.43, age));
	COLOR = sprite;
}
