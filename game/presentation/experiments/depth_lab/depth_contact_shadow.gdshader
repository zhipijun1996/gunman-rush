shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.32;
void fragment(){
 float r=length((UV-vec2(.5))*2.0);
 ALBEDO=vec3(.025,.04,.045);
 ALPHA=(1.0-smoothstep(.25,1.0,r))*opacity;
}
