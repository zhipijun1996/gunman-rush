shader_type canvas_item;
uniform vec2 shore_origin;
uniform float shore_width;
varying vec2 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	// Presentation crossfade inside the true solid; never masks collision.
	float x = local_position.x - shore_origin.x;
	float y = local_position.y - shore_origin.y;
	float edge = smoothstep(0.0, 36.0, x) * smoothstep(0.0, 36.0, shore_width - x);
	edge *= smoothstep(0.0, 18.0, y);
	COLOR.a *= edge;
}
