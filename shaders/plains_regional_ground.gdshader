shader_type canvas_item;
render_mode unshaded;
uniform sampler2D geological_paint : source_color, filter_linear, repeat_enable;
uniform vec4 exposed_tops[96];
uniform int top_count = 0;
uniform float horizontal_period = 1160.0;
uniform float painted_depth = 260.0;
uniform vec2 source_surface = vec2(0.0, 0.0);
uniform float regional_depth = 0.0;
uniform vec4 atmospheric_color : source_color = vec4(0.7,0.8,0.75,1.0);
uniform float atmospheric_mix = 0.0;
uniform bool quiet_background = false;
varying highp vec2 world_pixel;
void vertex() { world_pixel=VERTEX; }
void fragment() {
    float depth=100000.0;
    for (int i=0;i<96;i++) {
        if(i>=top_count) break;
        vec4 edge=exposed_tops[i];
        if(world_pixel.y>=edge.y-0.5) {
            float x=clamp(world_pixel.x,edge.x,edge.z);
            float y=mix(edge.y,edge.w,clamp((x-edge.x)/max(0.01,edge.z-edge.x),0.0,1.0));
            depth=min(depth,length(world_pixel-vec2(x,y)));
        }
    }
    if(depth>99999.0) depth=max(0.0,world_pixel.y-source_surface.y);
    // One complete painting supplies turf, shoulder, strata and core. The
    // coordinate is continuous across every source rectangle and union seam.
    // No independent top strip, side sprite, transparent blend or alpha mask.
    float painted_y=max(0.002,depth/painted_depth);
    // Actual opaque chalk-core painting supplies deep strata. Mirror the
    // original interior interval, rather than clamping its last pixel column,
    // stretching grass down a cliff, or inventing procedural rock details.
    // The first complete surface-to-core section remains the original image.
    if(painted_y>0.995) {
        float core_phase=mod(painted_y-0.995,0.99);
        painted_y=0.5+abs(core_phase-0.495);
    }
    vec2 uv=vec2(world_pixel.x/horizontal_period,painted_y);
    if(quiet_background) uv.y=0.64+abs(mod(depth/2400.0,0.68)-0.34);
    vec4 pigment=texture(geological_paint,uv);
    vec3 atmospheric=mix(vec3(1.0),vec3(0.79,0.87,0.88),regional_depth);
    COLOR=vec4(mix(pigment.rgb*atmospheric,atmospheric_color.rgb,atmospheric_mix),1.0);
}
