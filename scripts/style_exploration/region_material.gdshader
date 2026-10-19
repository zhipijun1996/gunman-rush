shader_type canvas_item;
uniform vec4 shadow_color : source_color;
uniform vec4 body_color : source_color;
uniform vec4 edge_color : source_color;
uniform vec4 light_color : source_color;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * vertex_tint;
	float value = clamp(dot(source.rgb, vec3(0.2126, 0.7152, 0.0722)) * 2.2, 0.0, 1.0);
	vec3 ramp = mix(shadow_color.rgb, body_color.rgb, smoothstep(0.0, 0.45, value));
	ramp = mix(ramp, edge_color.rgb, smoothstep(0.25, 0.78, value));
	ramp = mix(ramp, light_color.rgb, smoothstep(0.7, 1.0, value));
	COLOR = vec4(ramp, source.a);
}
