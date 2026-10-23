shader_type canvas_item;
render_mode unshaded;
uniform float edge_fraction = 0.035;
uniform float plane_opacity = 1.0;
uniform float source_detail_retention = 0.0;
uniform vec4 source_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 fog_shadow : source_color = vec4(0.07,0.13,0.18,1.0);
uniform vec4 fog_highlight : source_color = vec4(0.17,0.25,0.30,1.0);
void fragment() {
	// Extend the actual bottom source row; never repeat a skyline vertically.
	vec2 source_uv=clamp(UV,source_region.xy+TEXTURE_PIXEL_SIZE*.5,source_region.xy+source_region.zw-TEXTURE_PIXEL_SIZE*.5);
	vec4 source=texture(TEXTURE,source_uv);
	// Source-alpha paintings overlap in screen space. Only source-edge alpha
	// fades; no invented landscape, texture distortion or gameplay occlusion.
	float local_x=(UV.x-source_region.x)/source_region.z;
	float mask = smoothstep(0.0, edge_fraction * 2.0, local_x)
		* smoothstep(0.0, edge_fraction * 2.0, 1.0-local_x);
	// Atmospheric value mapping removes the playable terrain's green edge
	// signal. The dark clamp remains even with opaque silhouettes: this does
	// not rely on showing bright sky through the timber to imply distance.
	float value = clamp((dot(source.rgb, vec3(0.2126,0.7152,0.0722))-0.04)*1.3,0.0,1.0);
	vec3 atmosphere=mix(fog_shadow.rgb, fog_highlight.rgb, value);
	float luminance=dot(source.rgb,vec3(.2126,.7152,.0722));
	vec3 material=mix(vec3(luminance),source.rgb,.55);
	COLOR.rgb = mix(atmosphere,material,source_detail_retention);
	COLOR.a = source.a * mask * plane_opacity;
}
