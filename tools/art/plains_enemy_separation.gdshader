shader_type canvas_item;
// Static review material only. Original C PNG pixels, alpha and sampling stay intact.
// Standard room lighting remains active; no unshaded rendering or emissive halo.
uniform sampler2D backdrop : hint_screen_texture, repeat_disable, filter_nearest;
uniform float saturation : hint_range(0.0,1.0) = 0.82;
uniform float midtone_lift : hint_range(0.0,0.3) = 0.14;
uniform float contour_strength : hint_range(0.0,1.0) = 0.78;
varying vec4 modulation;
void vertex() { modulation = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = TEXTURE_PIXEL_SIZE;
	float top = texture(TEXTURE, UV-vec2(0.0,p.y)).a;
	float left = texture(TEXTURE, UV-vec2(p.x,0.0)).a;
	float right = texture(TEXTURE, UV+vec2(p.x,0.0)).a;
	float bottom = texture(TEXTURE, UV+vec2(0.0,p.y)).a;
	float edge = 1.0-min(min(top,bottom),min(left,right));
	float upper_edge = 1.0-top;
	float ground = dot(texture(backdrop, SCREEN_UV).rgb,vec3(0.2126,0.7152,0.0722));
	float dark_ground = 1.0-smoothstep(0.12,0.42,ground);
	float value = dot(tex.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 rgb = mix(vec3(value),tex.rgb,saturation);
	rgb = (rgb-vec3(0.35))*1.18+vec3(0.35);
	float midtone = smoothstep(0.07,0.30,value)*(1.0-smoothstep(0.70,1.0,value));
	rgb += vec3(midtone_lift*midtone*dark_ground);
	rgb = mix(rgb,vec3(0.075,0.115,0.12),edge*(1.0-dark_ground)*contour_strength);
	rgb = mix(rgb,vec3(0.80,0.75,0.62),upper_edge*dark_ground*0.55);
	COLOR = vec4(clamp(rgb,vec3(0.0),vec3(1.0)),tex.a)*modulation;
}
