shader_type canvas_item;
render_mode unshaded;
uniform vec3 light_color = vec3(0.8,0.86,0.79);
uniform float opacity = 0.095;
void fragment() {
	float edge = smoothstep(0.0, 0.15, UV.x) * (1.0 - smoothstep(0.75, 1.0, UV.x));
	float length_fade = pow(1.0 - UV.y, 1.1);
	COLOR = vec4(light_color, edge * length_fade * opacity);
}
