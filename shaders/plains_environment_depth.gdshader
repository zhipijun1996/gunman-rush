shader_type canvas_item;
render_mode unshaded;
uniform float saturation : hint_range(0.0, 1.0) = 0.65;
uniform float recession : hint_range(0.0, 1.0) = 0.16;
uniform vec4 atmosphere : source_color = vec4(0.60, 0.68, 0.63, 1.0);
uniform float contrast = 1.0;
uniform float wind_seconds = 0.0;
uniform float wind_amount = 0.0;
uniform vec4 wind_region = vec4(0.0,0.0,1.0,1.0);
uniform float wind_world_origin = 0.0;
uniform float wind_world_width = 0.0;
varying vec4 item_tint;
void vertex() { item_tint = COLOR; }
void fragment() {
	vec2 local = (UV-wind_region.xy)/wind_region.zw;
	// Upper canopy only. Bottom55% (trunks, roots and the painted stone slope)
	// has identically zero displacement; buildings never receive wind_amount.
	float crown = 1.0-smoothstep(0.26,0.45,local.y);
	float phase = sin(wind_seconds*0.85-(wind_world_origin+local.x*wind_world_width)*0.004);
	vec2 moved_uv = UV-vec2(phase*wind_amount*crown,0.0);
	moved_uv = clamp(moved_uv,wind_region.xy+TEXTURE_PIXEL_SIZE*0.5,wind_region.xy+wind_region.zw-TEXTURE_PIXEL_SIZE*0.5);
	vec4 paint = texture(TEXTURE, moved_uv);
	float luminance = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
	paint.rgb = mix(vec3(luminance), paint.rgb, saturation);
	paint.rgb = mix(paint.rgb, atmosphere.rgb, recession);
	paint.rgb = clamp((paint.rgb-vec3(0.55))*contrast+vec3(0.55),vec3(0.0),vec3(1.0));
	// The original contour remains authoritative. No panel/filled aperture.
	COLOR = paint * item_tint;
}
