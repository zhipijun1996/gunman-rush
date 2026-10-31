shader_type canvas_item;
uniform float wind_offset_wu = 0.0;
void fragment() {
	// The four left native columns include the pole and remain fixed. Only
	// cloth samples move; transparent padding keeps the sway inside its frame.
	float cloth_weight=clamp((UV.x*19.0-4.0)/14.0,0.0,1.0);
	vec2 at=UV-vec2(0.0,wind_offset_wu*cloth_weight*TEXTURE_PIXEL_SIZE.y);
	COLOR=texture(TEXTURE,at);
}
void light() {
	vec3 response=min(COLOR.rgb*.4+vec3(.045),vec3(.16));
	LIGHT=vec4(LIGHT_COLOR.rgb*LIGHT_ENERGY*response,LIGHT_COLOR.a);
}
