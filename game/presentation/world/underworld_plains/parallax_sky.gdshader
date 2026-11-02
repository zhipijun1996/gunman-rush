shader_type canvas_item;
render_mode unshaded;
// Continuous same-orientation wrap; source paintings remain unchanged.
uniform vec2 source_size = vec2(1672.0,941.0);
uniform float seam_fraction = 0.035;
uniform float cloud_phase_source_px = 0.0;
uniform float upper_sky_gain = 0.72;
uniform float upper_sky_saturation = 0.90;
void fragment() {
	float seam = max(1.0,floor(source_size.x*seam_fraction));
	float period = source_size.x-2.0*seam;
	// Clouds translate gently; the hill horizon stays fixed in this plane.
	float sky_weight = 1.0-smoothstep(.66,.79,UV.y);
	vec2 pixel = vec2(UV.x*period+cloud_phase_source_px*sky_weight,UV.y*source_size.y);
	float x = mod(pixel.x,period);
	float y = clamp(floor(pixel.y)+.5,.5,source_size.y-.5);
	COLOR = texture(TEXTURE,vec2(seam+x,y)/source_size);
	if(x<seam) {
		vec4 tail = texture(TEXTURE,vec2(source_size.x-seam+x,y)/source_size);
		COLOR = mix(tail,COLOR,smoothstep(0.0,seam,x));
	}
	float upper=1.0-smoothstep(.45,.80,UV.y);
	vec3 neutral=vec3(dot(COLOR.rgb,vec3(.2126,.7152,.0722)));
	COLOR.rgb=mix(COLOR.rgb,mix(neutral,COLOR.rgb,upper_sky_saturation)*upper_sky_gain,upper);
	COLOR.a=1.0;
}
