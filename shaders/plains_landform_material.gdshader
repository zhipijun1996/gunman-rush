shader_type canvas_item;
render_mode unshaded;
// All three inputs are real, independently source-bound paintings. The outer
// contour belongs to the environment program, never a rectangular paint card.
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
uniform vec4 boundary_segments[64];
uniform vec4 boundary_frames[64]; // inward normal xy, accumulated arc, kind
uniform int boundary_count = 0;
varying highp vec2 world_pixel;
void vertex() { world_pixel = VERTEX; }
void fragment() {
    vec2 pixel = (world_pixel-world_origin)*pixels_per_world_unit;
    vec4 base = texture(core_paint, fract(pixel/core_dimensions));
    float nearest = 1000000.0;
    vec2 face_pixel = vec2(0.0);
    float face_kind = 0.0;
    for (int i=0; i<64; i++) {
        if(i>=boundary_count) break;
        vec2 a=boundary_segments[i].xy;
        vec2 edge=boundary_segments[i].zw-a;
        float edge_length=length(edge);
        vec2 tangent=edge/max(0.001,edge_length);
        float along=dot(world_pixel-a,tangent);
        float depth=dot(world_pixel-a,boundary_frames[i].xy);
        // Finite source-owned boundaries only. Connection cuts have no face.
        float outside=max(max(-along,along-edge_length),0.0);
        float metric=length(vec2(depth,outside));
        if(depth>=-0.01 && outside<0.01 && metric<nearest) {
            nearest=metric;
            face_pixel=vec2((along+boundary_frames[i].z)*pixels_per_world_unit,max(0.0,depth)*pixels_per_world_unit);
            face_kind=boundary_frames[i].w;
            if(face_kind<1.5) face_pixel.x=pixel.x;
        }
    }
    vec4 region=face_kind<1.5 ? surface_region : wall_region;
    vec2 dimensions=face_kind<1.5 ? surface_dimensions : wall_dimensions;
    if(nearest<100000.0 && face_pixel.y<region.w) {
        // Opaque complete transition into the same rock pigment. This mixes
        // paint colours inside one filled mesh; it never fades terrain alpha.
        vec2 local=vec2(mod(face_pixel.x,region.z),face_pixel.y);
        vec2 uv=(region.xy+clamp(local,vec2(0.5),region.zw-vec2(0.5)))/dimensions;
        vec4 face;
        if(face_kind<1.5) face=texture(surface_paint,uv);
        else face=texture(wall_paint,uv);
        float interior=smoothstep(region.w*0.80,region.w,face_pixel.y);
        base.rgb=mix(face.rgb,base.rgb,interior);
    }
    COLOR=vec4(base.rgb,1.0);
}
