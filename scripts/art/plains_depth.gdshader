shader_type canvas_item;
render_mode unshaded;
varying float world_y;
void vertex() { world_y=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).y; }
void fragment() {
 // Continuous world-space depth, stable through camera panning and node joins.
 float depth=smoothstep(120.0,1000.0,world_y);
 COLOR=vec4(0.08,0.14,0.13,depth*0.62);
}
