shader_type canvas_item;
render_mode unshaded;
uniform float saturation : hint_range(0.0, 1.0) = 0.65;
uniform float recession : hint_range(0.0, 1.0) = 0.16;
uniform vec4 atmosphere : source_color = vec4(0.60, 0.68, 0.63, 1.0);
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float luminance = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
	paint.rgb = mix(vec3(luminance), paint.rgb, saturation);
	paint.rgb = mix(paint.rgb, atmosphere.rgb, recession);
	// The original contour remains authoritative. No panel/filled aperture.
	COLOR = paint * item_tint;
}
