shader_type canvas_item;
uniform sampler2D vines : source_color, repeat_enable, filter_nearest;
uniform sampler2D reveal_mask : filter_linear, repeat_disable;
uniform vec2 texture_origin;
uniform vec2 texture_span;
uniform float revealed_alpha;
void fragment() {
	vec4 leaf = texture(vines, texture_origin + UV * texture_span);
	float revealed = texture(reveal_mask, UV).r;
	COLOR = leaf * vec4(1.0, 1.0, 1.0, mix(1.0, revealed_alpha, revealed)) * COLOR;
}
