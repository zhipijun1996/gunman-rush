shader_type canvas_item;
render_mode unshaded;
// Air perspective reduces distant detail contrast without lighting a landmark
// like a foreground prop. The source silhouette and transparent holes remain.
uniform vec4 air : source_color = vec4(0.59, 0.66, 0.62, 0.62);
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	COLOR = vec4(mix(source.rgb, air.rgb, air.a), source.a * 0.88);
}
