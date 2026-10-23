shader_type canvas_item;
// Stable item-local 1wu texel selection. Physics and gameplay anchors stay free.
varying vec2 item_world_units;
varying vec4 source_vertex_color;
void vertex() {
	// Snap only the drawn origin. Node transforms and interaction anchors keep
	// their original subpixel coordinates (global transform snapping does not).
	vec2 origin=MODEL_MATRIX[3].xy;
	vec2 shift=round(origin)-origin;
	VERTEX+=inverse(mat2(MODEL_MATRIX[0].xy,MODEL_MATRIX[1].xy))*shift;
	item_world_units=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy-MODEL_MATRIX[3].xy;
	source_vertex_color=COLOR;
}
void fragment() {
	vec2 target=floor(item_world_units)+.5;
	mat2 jacobian=mat2(dFdx(item_world_units),dFdy(item_world_units));
	vec2 delta=inverse(jacobian)*(target-item_world_units);
	vec2 at=UV+dFdx(UV)*delta.x+dFdy(UV)*delta.y;
	COLOR=texture(TEXTURE,at)*source_vertex_color;
}
void light() {
	vec3 response=min(COLOR.rgb*.4+vec3(.045),vec3(.16));
	LIGHT=vec4(LIGHT_COLOR.rgb*LIGHT_ENERGY*response,LIGHT_COLOR.a);
}
