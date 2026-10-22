shader_type canvas_item;
// Keep original albedo. The small light-only floor lets very dark source rock
// receive light without lifting every unlit pixel or replacing its palette.
void light() {
	// Cap added response on already bright cloth/metal; retain dark-source bounce.
	vec3 response = min(COLOR.rgb * .4 + vec3(.045), vec3(.16));
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * response, LIGHT_COLOR.a);
}
