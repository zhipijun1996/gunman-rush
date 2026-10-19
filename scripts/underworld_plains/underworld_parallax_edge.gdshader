shader_type canvas_item;
uniform float edge_fraction = 0.035;
uniform float plane_opacity = 1.0;
uniform vec4 fog_shadow : source_color = vec4(0.07,0.13,0.18,1.0);
uniform vec4 fog_highlight : source_color = vec4(0.17,0.25,0.30,1.0);
void fragment() {
	// Source-alpha paintings overlap in screen space. Only source-edge alpha
	// fades; no invented landscape, texture distortion or gameplay occlusion.
	float mask = smoothstep(0.0, edge_fraction * 2.0, UV.x)
		* smoothstep(0.0, edge_fraction * 2.0, 1.0-UV.x);
	// Atmospheric value mapping removes the playable terrain's green edge
	// signal. The dark clamp remains even with opaque silhouettes: this does
	// not rely on showing bright sky through the timber to imply distance.
	float value = clamp((dot(COLOR.rgb, vec3(0.2126,0.7152,0.0722))-0.04)*1.3,0.0,1.0);
	COLOR.rgb = mix(fog_shadow.rgb, fog_highlight.rgb, value);
	COLOR.a *= mask * plane_opacity;
}
