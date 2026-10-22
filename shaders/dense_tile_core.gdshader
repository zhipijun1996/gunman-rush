shader_type canvas_item;
#include "res://shaders/dense_material.gdshaderinc"
uniform sampler2D edge_field : filter_nearest, repeat_disable;
varying vec2 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy; }
void fragment() {
	vec4 data = texture(edge_field,UV);
	COLOR = dense_material(world_position,round(data.r*255.),int(round(data.g*255.)));
	COLOR.a *= data.a;
}
