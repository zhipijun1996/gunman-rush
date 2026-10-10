shader_type canvas_item;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(1.0, 0.73, 0.16, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.32;
uniform float edge_width : hint_range(0.01, 0.49) = 0.22;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Transparent center; soft warm edges independent of camera and resolution.
	vec2 border = min(UV, vec2(1.0) - UV);
	float edge = 1.0 - smoothstep(0.0, edge_width, min(border.x, border.y));
	COLOR = vec4(tint.rgb, edge * opacity * strength);
}
