shader_type canvas_item;
uniform float cell_world_units = 2.0;
varying vec2 item_world_units;
varying vec4 source_vertex_color;
void vertex() {
	// Exclude translation: an actor's source texel selection cannot change
	// just because its body or the camera moved a fraction of a world unit.
	item_world_units = (MODEL_MATRIX * vec4(VERTEX,0.,1.)).xy - MODEL_MATRIX[3].xy;
	source_vertex_color = COLOR;
}
void fragment() {
	vec2 target = (floor(item_world_units / cell_world_units) + .5) * cell_world_units;
	mat2 local_jacobian = mat2(dFdx(item_world_units),dFdy(item_world_units));
	vec2 screen_delta = inverse(local_jacobian) * (target-item_world_units);
	vec2 source_uv = UV + dFdx(UV)*screen_delta.x + dFdy(UV)*screen_delta.y;
	COLOR = texture(TEXTURE,source_uv) * source_vertex_color;
}
