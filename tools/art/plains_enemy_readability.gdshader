shader_type canvas_item;
// Preview-only material. Original art stays unchanged and receives room lighting.
uniform float edge_strength : hint_range(0.0,1.0) = 0.48;
uniform float contrast : hint_range(1.0,1.3) = 1.16;
uniform vec4 contour : source_color = vec4(0.10,0.17,0.18,1.0);
varying vec4 modulation;
void vertex() { modulation = COLOR; }
void fragment() {
	vec4 tex = texture(TEXTURE,UV);
	vec2 p = TEXTURE_PIXEL_SIZE;
	float around = min(min(texture(TEXTURE,UV+vec2(p.x,0.0)).a,texture(TEXTURE,UV-vec2(p.x,0.0)).a),min(texture(TEXTURE,UV+vec2(0.0,p.y)).a,texture(TEXTURE,UV-vec2(0.0,p.y)).a));
	float value = dot(tex.rgb,vec3(0.2126,0.7152,0.0722));
	vec3 lift = vec3(0.028,0.047,0.052)*(1.0-smoothstep(0.08,0.48,value));
	vec3 rgb = clamp((tex.rgb-vec3(0.42))*contrast+vec3(0.42)+lift,vec3(0.0),vec3(1.0));
	rgb = mix(rgb,contour.rgb,(1.0-around)*edge_strength);
	COLOR = vec4(rgb,tex.a)*modulation;
}
