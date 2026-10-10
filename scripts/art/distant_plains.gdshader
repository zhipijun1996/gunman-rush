shader_type canvas_item;
render_mode unshaded;
uniform float saturation : hint_range(0.0, 1.0) = 0.15;
uniform float mist : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.0, 3.0) = 1.5;
uniform vec4 mist_color : source_color = vec4(0.48, 0.55, 0.57, 1.0);
void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * softness;
	vec4 original = texture(TEXTURE, UV);
	vec4 paint = original * 0.4;
	paint += texture(TEXTURE, UV + vec2(offset.x, 0.0)) * 0.15;
	paint += texture(TEXTURE, UV - vec2(offset.x, 0.0)) * 0.15;
	paint += texture(TEXTURE, UV + vec2(0.0, offset.y)) * 0.15;
	paint += texture(TEXTURE, UV - vec2(0.0, offset.y)) * 0.15;
	float gray = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
	paint.rgb = mix(vec3(gray), paint.rgb, saturation);
	paint.rgb = mix(paint.rgb, mist_color.rgb, mist);
	// Preserve original silhouette alpha; fog never paints an opaque panel edge.
	COLOR = vec4(paint.rgb, original.a) * COLOR;
}
