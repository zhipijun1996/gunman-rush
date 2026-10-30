shader_type canvas_item;
varying vec2 world_units;
varying vec4 vertex_tint;
void vertex(){
	world_units=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy-MODEL_MATRIX[3].xy;
	vertex_tint=COLOR;
}
void fragment(){
	vec2 target=floor(world_units)+vec2(.5);
	mat2 jacobian=mat2(dFdx(world_units),dFdy(world_units));
	vec2 delta=inverse(jacobian)*(target-world_units);
	vec2 at=UV+dFdx(UV)*delta.x+dFdy(UV)*delta.y;
	vec4 color=texture(TEXTURE,at);
	if(color.a<.5) discard;
	color.a=1.;
	COLOR=color*vertex_tint;
}
