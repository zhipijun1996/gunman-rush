shader_type canvas_item;
uniform float phase = 0.0;
uniform float height = 32.0;
void vertex() {
	float tip = clamp(-VERTEX.y / height, 0.0, 1.0);
	VERTEX.x += round(sin(phase + VERTEX.y * 0.03) * 1.5 * tip * tip);
}
