shader_type canvas_item;
render_mode unshaded;

uniform int role = 0; // terrain, sky, props
uniform vec4 stone_dark : source_color;
uniform vec4 stone_light : source_color;
uniform vec4 grass_dark : source_color;
uniform vec4 grass_light : source_color;
uniform vec4 sky_top : source_color;
uniform vec4 sky_bottom : source_color;

vec3 terrain_grade(vec3 c) {
	float v = dot(c, vec3(.2126, .7152, .0722));
	float grass = smoothstep(.004, .055, c.g - max(c.r, c.b));
	float rock = clamp((v-.035)*3.3, 0., 1.);
	// Keep the source clusters, suppress the near-black salt-and-pepper noise.
	vec3 stone = mix(stone_dark.rgb, stone_light.rgb, rock*rock);
	vec3 leaf = mix(grass_dark.rgb, grass_light.rgb, clamp(v*2.2, 0., 1.));
	return mix(stone, leaf, grass);
}

void fragment() {
	vec4 c = COLOR;
	if (role == 0) {
		c.rgb = terrain_grade(c.rgb);
	} else if (role == 1) {
		float v = dot(c.rgb, vec3(.2126, .7152, .0722));
		float cloud = smoothstep(.02, .35, c.r-c.b*.8);
		vec3 sky = mix(sky_top.rgb, sky_bottom.rgb, smoothstep(.18, .85, UV.y));
		// Source brushwork and source horizon remain; no replacement landscape.
		c.rgb = mix(sky, sky_bottom.rgb, cloud*.8);
		// Original source hills determine the horizon silhouette, not a flat band.
		float hill = smoothstep(.76, .80, UV.y)*(1.-smoothstep(.11,.30,v));
		vec3 hill_color = mix(stone_dark.rgb, sky_bottom.rgb, clamp(.37+v*1.8,0.,1.));
		c.rgb = mix(c.rgb, hill_color, hill);
	} else {
		// Lift local sprites independently of sky and terrain. Keep hue semantics.
		c.rgb = pow(max(c.rgb, vec3(0.)), vec3(.72))*1.12;
		c.rgb *= mix(vec3(1.), grass_light.rgb, .10);
	}
	COLOR = c;
}
