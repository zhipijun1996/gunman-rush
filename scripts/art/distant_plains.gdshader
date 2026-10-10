shader_type canvas_item;
render_mode unshaded;
uniform float saturation : hint_range(0.0, 1.0) = 0.15;
uniform float mist : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.0, 3.0) = 1.5;
uniform vec4 mist_color : source_color = vec4(0.48, 0.55, 0.57, 1.0);
uniform vec4 texture_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float content_fraction : hint_range(0.01, 1.0) = 1.0;
uniform vec4 ground_color : source_color = vec4(0.60, 0.64, 0.53, 1.0);
uniform float bottom_fade : hint_range(0.0, 0.3) = 0.0;
varying vec4 item_tint;
void vertex() {
	item_tint = COLOR;
}
void fragment() {
	vec2 offset = TEXTURE_PIXEL_SIZE * softness;
	vec2 local_uv = (UV - texture_region.xy) / texture_region.zw;
	// Painted silhouette keeps its original height; extend the opaque lower
	// pasture sample below it so atlas baselines never reveal a strip of sky.
	vec2 sample_local = vec2(local_uv.x, min(local_uv.y / content_fraction, 0.97));
	vec2 mapped_uv = texture_region.xy + sample_local * texture_region.zw;
	vec2 lower = texture_region.xy + TEXTURE_PIXEL_SIZE * 2.0;
	vec2 upper = texture_region.xy + texture_region.zw - TEXTURE_PIXEL_SIZE * 2.0;
	vec4 original = texture(TEXTURE, clamp(mapped_uv, lower, upper));
	vec4 paint = original * 0.4;
	paint += texture(TEXTURE, clamp(mapped_uv + vec2(offset.x, 0.0), lower, upper)) * 0.15;
	paint += texture(TEXTURE, clamp(mapped_uv - vec2(offset.x, 0.0), lower, upper)) * 0.15;
	paint += texture(TEXTURE, clamp(mapped_uv + vec2(0.0, offset.y), lower, upper)) * 0.15;
	paint += texture(TEXTURE, clamp(mapped_uv - vec2(0.0, offset.y), lower, upper)) * 0.15;
	float gray = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
	paint.rgb = mix(vec3(gray), paint.rgb, saturation);
	paint.rgb = mix(paint.rgb, mist_color.rgb, mist);
	// Preserve original silhouette alpha; fog never paints an opaque panel edge.
	// Fragment COLOR already includes the original texture in Godot.
	// Multiply only the vertex tint; sampling it twice restores strong blue.
	float alpha = original.a;
	if (content_fraction < 0.999) {
		// Dissolve the painting's last rows into broad atmospheric color before
		// its baseline. Extending a texture column would create vertical streaks.
		float extension_blend = smoothstep(0.80, 1.02, local_uv.y / content_fraction);
		paint.rgb = mix(paint.rgb, ground_color.rgb, extension_blend);
		alpha = mix(alpha, 1.0, extension_blend);
	}
	if (content_fraction < 0.999 && local_uv.y >= content_fraction) {
		alpha = 1.0;
	}
	if (bottom_fade > 0.0) {
		alpha *= 1.0 - smoothstep(1.0 - bottom_fade, 1.0, local_uv.y);
	}
	COLOR = vec4(paint.rgb, alpha) * item_tint;
}
