shader_type canvas_item;
render_mode unshaded;
uniform float mist = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE,UV);
	source.rgb = mix(source.rgb,vec3(.39,.53,.54),mist);
	// Feather only panorama boundaries in alpha; no texture/noise overlay.
	float edge = smoothstep(0.0,.035,UV.x)*smoothstep(0.0,.035,1.0-UV.x);
	COLOR = source*vec4(1.0,1.0,1.0,edge);
}
