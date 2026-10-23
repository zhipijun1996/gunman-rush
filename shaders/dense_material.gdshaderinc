uniform sampler2D dense_master : filter_nearest, repeat_disable;
vec4 dense_wrap_sample(vec2 p,bool grass) {
	// Overlap source edges rather than mirror them into repeated diamonds.
	float u=mod(p.x,224.);
	float v=mod(p.y,160.);
	float source_y=grass ? clamp(floor(p.y)*3.+.5,.5,31.5) : 80.+v;
	vec4 a=texture(dense_master,vec2(16.+u,source_y)/256.);
	if(u<16.) a=mix(texture(dense_master,vec2(240.+u,source_y)/256.),a,smoothstep(0.,16.,u));
	if(!grass && v<16.) {
		vec4 b=texture(dense_master,vec2(16.+u,240.+v)/256.);
		if(u<16.) b=mix(texture(dense_master,vec2(240.+u,240.+v)/256.),b,smoothstep(0.,16.,u));
		a=mix(b,a,smoothstep(0.,16.,v));
	}
	return a;
}
vec4 dense_material(vec2 world_position,float distance_to_edge,int face) {
	vec2 p = floor(world_position)+.5;
	vec4 stone = dense_wrap_sample(p,false);
	stone.rgb=mix(vec3(.025,.036,.075),stone.rgb,.32);
	if (distance_to_edge<8. && face==0) {
		vec4 grass=dense_wrap_sample(vec2(p.x,distance_to_edge),true);
		stone=mix(stone,grass,.88*(1.-smoothstep(5.,8.,distance_to_edge)));
	} else if(face!=4 && face!=0) {
		stone.rgb*=.72+.28*smoothstep(0.,5.,distance_to_edge);
	}
	return stone;
}
void light() {
	vec3 response = min(COLOR.rgb*.4+vec3(.045),vec3(.16));
	LIGHT = vec4(LIGHT_COLOR.rgb*LIGHT_ENERGY*response,LIGHT_COLOR.a);
}
