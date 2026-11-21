shader_type canvas_item;
uniform float darkness = 0.38;
void fragment(){
 float edge=smoothstep(0.0,0.22,UV.x)*smoothstep(0.0,0.22,1.0-UV.x)*smoothstep(0.0,0.28,UV.y)*smoothstep(0.0,0.28,1.0-UV.y);
 COLOR=vec4(0.02,0.04,0.065,darkness*edge);
}
