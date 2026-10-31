shader_type canvas_item;
uniform float wind_clock = 0.0;
varying vec2 fine_world_position;
varying vec4 fine_vertex_color;
void vertex() {
 fine_world_position=(MODEL_MATRIX*vec4(VERTEX,0.,1.)).xy;
 fine_vertex_color=COLOR;
}
void fragment() {
 vec4 source=texture(TEXTURE,UV);
 vec2 pixel=UV/TEXTURE_PIXEL_SIZE;
 if(mod(floor(pixel.y),32.0)<3.0 && source.g>source.r*1.04 && source.g>source.b*1.2){
  float shift=round(sin(fine_world_position.x*.025-wind_clock*1.35)*.9);
  float column=floor(pixel.x/32.0)*32.0+clamp(mod(floor(pixel.x),32.0)+shift,0.0,31.0)+.5;
  source=texture(TEXTURE,vec2(column*TEXTURE_PIXEL_SIZE.x,UV.y));
 }
 COLOR=source*fine_vertex_color;
}
// FINE-SPACE-05 production material: keep selected albedo. The small light-only floor lets very dark source rock
// receive light without lifting every unlit pixel or replacing its palette.
void light() {
	// Cap added response on already bright cloth/metal; retain dark-source bounce.
	vec3 response = min(COLOR.rgb * .4 + vec3(.045), vec3(.16));
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * response, LIGHT_COLOR.a);
}
