shader_type canvas_item;
render_mode unshaded;
void fragment() {
	float edge = smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.75, 1.0, UV.x));
	float length_fade = pow(1.0 - UV.y, 1.5);
	COLOR = vec4(1.0, 0.82, 0.51, edge * length_fade * 0.12);
}
