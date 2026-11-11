shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
uniform vec2 origin;
uniform vec2 anchor;
uniform float radius = 2000.0;
uniform float phase = 0.0;
uniform float height = 32.0;
varying vec2 room_position;
void vertex() {
	room_position = VERTEX + anchor;
	float tip = clamp(-VERTEX.y / height, 0.0, 1.0);
	VERTEX.x += round(sin(phase + VERTEX.y * 0.025) * tip * tip * 1.5 * progress);
}
void fragment() {
	float arrival = distance(room_position, origin) / radius;
	float growth = smoothstep(arrival, arrival + 0.18, progress * 1.25);
	COLOR.a *= growth;
}
