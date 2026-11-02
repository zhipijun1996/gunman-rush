shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painted_stone : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 stone_tint : source_color = vec4(1.0);
uniform vec4 edges[24];
uniform int edge_count = 0;
uniform bool local_phase = false;
uniform float distance_mist = 0.0;
varying vec2 world_point;
varying vec2 local_point;
void vertex() { local_point = VERTEX; world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 phase = (local_phase ? local_point : world_point) * vec2(0.00265);
	vec2 uv = phase;
	vec3 paint = texture(painted_stone, uv).rgb;
	// Same world phase across every polygon: no per-component rectangular reset.
	vec3 broad = texture(painted_stone, phase * 0.43 + vec2(0.41,0.16)).rgb;
	paint = mix(paint, broad, 0.14);
	float closest = 100000.0;
	vec2 normal = vec2(0.0, -1.0);
	for (int i=0; i<24; i++) {
		if (i >= edge_count) { break; }
		vec2 a = edges[i].xy; vec2 ab = edges[i].zw - a;
		float t = clamp(dot(local_point-a, ab) / max(dot(ab,ab), 0.001), 0.0, 1.0);
		float d = length(local_point-a-t*ab);
		if (d < closest) { closest=d; normal=normalize(vec2(ab.y,-ab.x)); }
	}
	float rim = 1.0-smoothstep(1.0,9.0,closest);
	float light = dot(normal, normalize(vec2(-0.55,-0.83)));
	paint *= 1.0 + rim * light * 0.26;
	paint = mix(paint, vec3(0.20,0.28,0.28), (1.0-smoothstep(0.0,1.25,closest))*0.30);
	vec3 colored = paint * stone_tint.rgb;
	colored = mix(colored, vec3(0.64,0.72,0.68), distance_mist);
	COLOR = vec4(colored, stone_tint.a);
}
