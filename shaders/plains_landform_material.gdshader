shader_type canvas_item;
render_mode unshaded;
// Real source paintings keep one common pixel/world scale. The environment
// owns the complete contour; paint coverage never changes terrain alpha.
uniform sampler2D core_paint : source_color, filter_linear, repeat_enable;
uniform sampler2D surface_paint : source_color, filter_linear, repeat_enable;
uniform sampler2D wall_paint : source_color, filter_linear, repeat_enable;
uniform vec2 world_origin = vec2(0.0);
uniform float pixels_per_world_unit = 2.0;
uniform vec2 core_dimensions = vec2(1024.0);
uniform vec4 surface_region = vec4(0.0, 0.0, 1024.0, 320.0);
uniform vec2 surface_dimensions = vec2(1024.0, 320.0);
uniform vec4 wall_region = vec4(0.0, 0.0, 1024.0, 320.0);
uniform vec2 wall_dimensions = vec2(1024.0, 320.0);
// x: source-row offset; y: complete valid depth; z: opaque pigment fade start.
// Source pixels are cropped, never squeezed to fit a terrain's whole depth.
uniform vec3 surface_depth_registration = vec3(0.0,280.0,200.0);
uniform vec3 wall_depth_registration = vec3(96.0,160.0,64.0);
uniform vec4 boundary_segments[64];
uniform vec4 boundary_frames[64]; // inward normal xy; reserved arc; face kind
uniform int boundary_count = 0;
// Identity by default; only a source-owned rear plane opts into quieter colour.
uniform float paint_contrast = 1.0;
uniform float paint_saturation = 1.0;
uniform float paint_mist = 0.0;
uniform vec4 paint_mist_color : source_color = vec4(0.54,0.60,0.60,1.0);
varying highp vec2 world_pixel;
void vertex() { world_pixel = VERTEX; }
void fragment() {
    vec2 pixel=(world_pixel-world_origin)*pixels_per_world_unit;
    vec4 base=texture(core_paint,fract(pixel/core_dimensions));
    float top_distance=1000000.0;
    float top_cap=0.0;
    float wall_distance=1000000.0;
    for(int i=0;i<64;i++) {
        if(i>=boundary_count) break;
        vec2 a=boundary_segments[i].xy;
        vec2 edge=boundary_segments[i].zw-a;
        float edge_length=length(edge);
        vec2 tangent=edge/max(0.001,edge_length);
        float along=dot(world_pixel-a,tangent);
        vec2 nearest=a+tangent*clamp(along,0.0,edge_length);
        float distance_to_segment=length(world_pixel-nearest);
        if(boundary_frames[i].w<1.5) {
            // Standing paint has a finite reach beyond the actual top's ends;
            // it does not wrap grass around an entire side or cave ceiling.
            float outside=max(max(-along,along-edge_length),0.0);
            float cap=1.0-smoothstep(0.0,12.0,outside);
            float inward=dot(world_pixel-a,boundary_frames[i].xy);
            if(inward>=-0.01 && distance_to_segment<top_distance) {
                top_distance=distance_to_segment;
                top_cap=cap;
            }
        } else {
            // A continuous scalar distance to finite cave/side boundaries.
            // No selected short edge rotates the whole painting's coordinate.
            wall_distance=min(wall_distance,distance_to_segment);
        }
    }
    float top_px=top_distance*pixels_per_world_unit;
    float wall_px=wall_distance*pixels_per_world_unit;
    float top_weight=(1.0-smoothstep(surface_depth_registration.z,surface_depth_registration.y,top_px))*top_cap;
    float wall_weight=1.0-smoothstep(wall_depth_registration.z,wall_depth_registration.y,wall_px);
    if(wall_weight>0.0) {
        vec2 local=vec2(mod(pixel.x,wall_region.z),wall_depth_registration.x+wall_px);
        vec2 uv=(wall_region.xy+clamp(local,vec2(0.5),wall_region.zw-vec2(0.5)))/wall_dimensions;
        base.rgb=mix(base.rgb,texture(wall_paint,uv).rgb,wall_weight*(1.0-top_weight));
    }
    if(top_weight>0.0) {
        vec2 local=vec2(mod(pixel.x,surface_region.z),surface_depth_registration.x+top_px);
        vec2 uv=(surface_region.xy+clamp(local,vec2(0.5),surface_region.zw-vec2(0.5)))/surface_dimensions;
        base.rgb=mix(base.rgb,texture(surface_paint,uv).rgb,top_weight);
    }
    float luminance=dot(base.rgb,vec3(0.2126,0.7152,0.0722));
    vec3 pigment=mix(vec3(luminance),base.rgb,paint_saturation);
    pigment=clamp((pigment-vec3(0.5))*paint_contrast+vec3(0.5),vec3(0.0),vec3(1.0));
    pigment=mix(pigment,paint_mist_color.rgb,paint_mist);
    COLOR=vec4(pigment,1.0);
}
