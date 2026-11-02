shader_type canvas_item;
// Same 1wu sampling lattice as the shared fine art; high-res sources are
// sampled at world scale, never made coarse by multiplying their texel size.
varying vec2 item_world_units;
varying vec4 vertex_tint;
uniform float death_progress = 0.0;
uniform vec2 eye_center = vec2(.86,.39);
uniform bool plant_body = false;
uniform int kind_code = 0;
uniform float hit_flash : hint_range(0.,1.) = 0.;
void vertex() {
	item_world_units = (MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy-MODEL_MATRIX[3].xy;
	vertex_tint = COLOR;
}
void fragment() {
	vec2 target = floor(item_world_units)+vec2(.5);
	mat2 jacobian = mat2(dFdx(item_world_units),dFdy(item_world_units));
	vec2 delta = inverse(jacobian)*(target-item_world_units);
	vec2 at = UV+dFdx(UV)*delta.x+dFdy(UV)*delta.y;
	vec4 body = texture(TEXTURE,clamp(at,vec2(0.),vec2(1.)));
	if(body.a<.5 || any(lessThan(at,vec2(0.))) || any(greaterThan(at,vec2(1.)))) discard;
	body.a=1.;
	float grey = dot(body.rgb,vec3(.299,.587,.114));
	float green = smoothstep(.005,.07,body.g-body.b)*step(body.r,body.g*1.16);
	body.rgb=mix(body.rgb,mix(vec3(grey)*vec3(.87,.80,.64),body.rgb,.45),death_progress*(plant_body?green*.8:.24));
	float eye = 1.-smoothstep(.035,.08,length((at-eye_center)*vec2(1.,1.2)));
	body.rgb=mix(body.rgb,body.rgb*.20,eye*smoothstep(.62,.96,death_progress));
	float abdomen = (1.-smoothstep(.14,.29,abs(at.x-.44)))*smoothstep(.47,.64,at.y)*(1.-smoothstep(.88,1.,at.y));
	float bell = smoothstep(.58,.73,at.x)*(1.-smoothstep(.52,.66,at.y));
	float organ = kind_code==1?abdomen:(kind_code==2?bell:0.);
	body.rgb *= 1.-organ*.40*smoothstep(.54,.96,death_progress);
	body.rgb=mix(body.rgb,vec3(1.,.949,.702),hit_flash);
	COLOR=body*vertex_tint;
}
