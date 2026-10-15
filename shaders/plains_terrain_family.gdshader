shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painted_material : source_color, filter_linear;
uniform sampler2D painted_border : source_color, filter_linear;
uniform sampler2D family_paint : source_color, filter_linear;
uniform bool outside_only = false;
uniform vec4 ownership_rect;
uniform float outward_limit = 3.0;
uniform highp vec4 faces[64];
uniform int face_count = 0;
uniform vec4 block_bounds;
uniform vec2 shape_origin;
uniform bool body_local_material = false;
uniform int cell_masks[16];
uniform int block_width = 1;
uniform bool canonical_cells = true;
uniform vec4 outer_corners[32];
uniform int corner_count = 0;
uniform bool well_bank_enabled = false;
uniform vec4 well_bank_regions[2];
uniform float well_bank_strength = 0.78;
varying highp vec2 well_world_pixel;
varying highp vec2 shape_pixel;
varying highp vec2 material_pixel;
void vertex() { well_world_pixel=(MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; shape_pixel = VERTEX+shape_origin; material_pixel = body_local_material ? shape_pixel : (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
// Each source seam fades into the middle of the other phase; retain painted detail.
// This repairs sampler continuity, not art quality.
vec4 horizontal_sample(vec2 uv) {
    float x = fract(uv.x);
    vec4 a = texture(painted_material, vec2(x, uv.y));
    float w = smoothstep(0.0, 0.12, min(x, 1.0-x));
    vec4 edge = texture(painted_material, vec2(fract(x+0.5),uv.y));
    return mix(edge, a, w);
}
vec4 earth_sample(vec2 p) {
    float y = fract(p.y / 208.0);
    vec4 a = horizontal_sample(vec2(p.x / 384.0, mix(0.18,0.999,y)));
    vec4 edge = horizontal_sample(vec2(p.x/384.0,mix(0.18,0.999,fract(y+0.5))));
    return mix(edge,a,smoothstep(0.0,0.12,min(y,1.0-y)));
}
// Painted rock edge strips share the same source and world phase. Interior
// alpha gates the pigment; the sprite's transparent RGB never becomes a halo.
vec4 border_tex(float phase, float depth, int side) {
    vec2 p = side==0 ? vec2(36.0+depth*4.0,192.0+phase*704.0)
           : side==1 ? vec2(1500.0-depth*4.0,192.0+phase*704.0)
           : vec2(160.0+phase*1216.0,940.0-depth*4.0);
    return texture(painted_border,p/vec2(1536.0,1024.0));
}
vec4 border_sample(float coordinate,float depth,int side) {
    float t=fract(coordinate/(side==2 ? 304.0 : 176.0));
    return mix(border_tex(fract(t+0.5),depth,side),border_tex(t,depth,side),smoothstep(0.0,0.12,min(t,1.0-t)));
}
// Use painted alpha only within a bounded inward contour band. This softens
// the silhouette without moving collision or inventing a new landing surface.
float border_alpha(float coordinate,float depth,int side) {
    float t=fract(coordinate/(side==3 || side==2 ? 304.0 : 176.0));
    float t2=fract(t+0.5);
    vec2 a=side==0 ? vec2(16.0+depth*48.0,192.0+t*704.0)
          : side==1 ? vec2(1520.0-depth*48.0,192.0+t*704.0)
          : vec2(160.0+t*1216.0,side==2 ? 976.0-depth*64.0 : 64.0+depth*64.0);
    vec2 b=side==0 ? vec2(a.x,192.0+t2*704.0)
          : side==1 ? vec2(a.x,192.0+t2*704.0)
          : vec2(160.0+t2*1216.0,a.y);
    float alpha=mix(texture(painted_border,b/vec2(1536.0,1024.0)).a,texture(painted_border,a/vec2(1536.0,1024.0)).a,smoothstep(0.0,0.12,min(t,1.0-t)));
    return min(1.0,alpha*1.06);
}
// Actual independently frozen source regions; all sampling uses .15 world/source.
vec4 family_at(vec2 p) { return texture(family_paint,p/vec2(2048.0,768.0)); }
vec4 family_edge(float coordinate,float depth,int side) {
    float period=side==2 ? 201.0 : 42.0;
    float t=fract(coordinate/period);
    vec2 p=side==0 ? vec2(55.0+depth/.15,220.0+t*280.0)
        : side==1 ? vec2(1987.0-depth/.15,220.0+t*280.0)
        : vec2(370.0+t*1340.0,626.0-depth/.15);
    vec2 q=side==2 ? vec2(370.0+fract(t+.5)*1340.0,p.y) : vec2(p.x,220.0+fract(t+.5)*280.0);
    // Blend two actual source phases only at the same declared seam interface.
    return mix(family_at(q),family_at(p),smoothstep(0.0,.10,min(t,1.0-t)));
}
void fragment() {
    float top = 10000.0;
    float edge_distance = 10000.0;
    float side_light = 1.0;
    vec3 edge_depth=vec3(10000.0);
    for (int i=0; i<64; i++) {
        if (i>=face_count) { break; }
        vec2 a=faces[i].xy;
        vec2 b=faces[i].zw;
        vec2 ab=b-a;
        float along=clamp(dot(shape_pixel-a,ab)/max(dot(ab,ab),0.01),0.0,1.0);
        float d=length(shape_pixel-a-along*ab);
        if (ab.y<0.0) edge_depth.x=min(edge_depth.x,d);
        if (ab.y>0.0) edge_depth.y=min(edge_depth.y,d);
        if (ab.x<0.0) edge_depth.z=min(edge_depth.z,d);
        if (d<edge_distance) {
            edge_distance=d;
            side_light=ab.x>0.0 ? 1.06 : ab.x<0.0 ? 0.66 : ab.y>0.0 ? 0.78 : 0.90;
        }
        // Clockwise boundaries: only an exposed up-facing edge grows grass.
        if (ab.x>0.0 && shape_pixel.y>=a.y ) {
            top=min(top,length(shape_pixel-vec2(clamp(shape_pixel.x,a.x,b.x),a.y)));
        }
    }
    vec4 earth=earth_sample(material_pixel);
    float section_depth=min(top+edge_depth.z,edge_depth.x+edge_depth.y);
    bool use_family=section_depth>=64.0;
    float turf_scale=clamp(section_depth/40.0,0.12,1.0);
    vec4 grass=horizontal_sample(vec2(material_pixel.x/384.0,clamp(top*6.0/(1024.0*turf_scale),0.0,0.22)));
    vec4 paint=mix(grass,earth,smoothstep(10.0*turf_scale,22.0*turf_scale,top));
    paint.rgb *= mix(side_light,1.0,smoothstep(0.0,5.0,edge_distance));
    vec3 border_sum=vec3(0.0); float border_weight=0.0;
    float family_alpha=1.0;
    for (int side=0;side<3;side++) {
        float depth=edge_depth[side];
        if (depth<18.0) {
            vec4 rim=use_family ? family_edge(side==2 ? material_pixel.x : material_pixel.y,depth,side) : border_sample(side==2 ? material_pixel.x : material_pixel.y,depth,side);
            float w=(1.0-smoothstep(0.0,use_family ? 6.0 : 10.0,depth))*rim.a;
            if (side!=2) w*=smoothstep(use_family ? 10.0 : 4.0,use_family ? 18.0 : 12.0,top);
            if (use_family) w=0.0; // alpha-only interface: keep admitted v8 RGB continuous
            border_sum+=rim.rgb*w; border_weight+=w;
            float inward=side==2 ? 6.0 : 4.0;
            if (use_family && depth<inward && top>10.0) family_alpha=min(family_alpha,mix(rim.a,1.0,smoothstep(inward-.5,inward,depth)));
        }
    }
    if (border_weight>0.0) paint.rgb=mix(paint.rgb,border_sum/border_weight,min(use_family ? .25 : .85,border_weight));
    // Rounded outer contours use the actual canonical mask, including thin rows.
    vec2 cell=floor((shape_pixel-block_bounds.xy)/32.0);
    int index=int(cell.y)*block_width+int(cell.x);
    int mask=cell_masks[clamp(index,0,15)];
    vec2 p=mod(shape_pixel-block_bounds.xy,32.0);
    float contour=1.0;
    float radius=2.5;
    if (canonical_cells && (mask&1)==0 && (mask&8)==0 && p.x<radius && p.y<radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(radius)));
    if (canonical_cells && (mask&1)==0 && (mask&2)==0 && p.x>32.0-radius && p.y<radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(32.0-radius,radius)));
    if (canonical_cells && (mask&4)==0 && (mask&8)==0 && p.x<radius && p.y>32.0-radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(radius,32.0-radius)));
    if (canonical_cells && (mask&4)==0 && (mask&2)==0 && p.x>32.0-radius && p.y>32.0-radius) contour=1.0-smoothstep(radius-0.4,radius+0.4,length(p-vec2(32.0-radius)));
    if (!canonical_cells) {
        for (int i=0;i<32;i++) {
            if (i>=corner_count) { break; }
            vec4 corner=outer_corners[i];
            int orientation=int(corner.z);
            vec2 direction=vec2((orientation==1 || orientation==3) ? -1.0 : 1.0,orientation>=2 ? -1.0 : 1.0);
            vec2 local=(shape_pixel-corner.xy)*direction;
            float r=corner.w;
            if (local.x>=0.0 && local.y>=0.0 && local.x<r && local.y<r) {
                contour=min(contour,1.0-smoothstep(r-0.4,r+0.4,length(local-vec2(r))));
            }
        }
    }
    if (!use_family) {
        float contour_band=min(1.75,section_depth*.125);
        for (int side=0;side<4;side++) {
            float depth=side==3 ? top : edge_depth[side];
            if (depth<contour_band && contour_band>0.0) contour=min(contour,mix(border_alpha(side>=2 ? material_pixel.x : material_pixel.y,depth/contour_band,side),1.0,smoothstep(0.0,contour_band,depth)));
        }
    }
    paint.a *= contour*family_alpha;
    // Optional formal well only. Original opacity, silhouette and grass are untouched.
    if (well_bank_enabled) {
        for (int bank=0;bank<2;bank++) {
            vec4 region=well_bank_regions[bank];
            vec2 local=well_world_pixel-region.xy;
            if (local.x>=0.0 && local.y>=0.0 && local.x<region.z && local.y<region.w) {
                float inner_distance=bank==0 ? region.z-local.x : local.x;
                float side=1.0-smoothstep(12.0,170.0,inner_distance);
                float below_grass=smoothstep(28.0,68.0,local.y);
                float depth=smoothstep(20.0,164.0,local.y);
                // Same approved painting, compressed horizontally on the thick inner face.
                vec4 side_paint=earth_sample(vec2(region.x+(material_pixel.x-region.x)*0.72,material_pixel.y));
                vec3 face=mix(paint.rgb,side_paint.rgb,side*0.55);
                vec3 ambient=mix(vec3(0.86,0.93,0.98),vec3(0.49,0.64,0.72),side);
                face*=ambient*mix(1.0,0.89,depth);
                paint.rgb=mix(paint.rgb,face,below_grass*well_bank_strength);
            }
        }
    }
    if (outside_only) {
        float best=10000.0; int selected=-1; float signed_depth=0.0;
        for (int i=0;i<64;i++) {
            if (i>=face_count) break;
            vec2 a=faces[i].xy;vec2 b=faces[i].zw;vec2 ab=b-a;
            float along=dot(shape_pixel-a,ab)/max(dot(ab,ab),.01);
            float depth=ab.y<0.0 ? shape_pixel.x-a.x : ab.y>0.0 ? a.x-shape_pixel.x : ab.x<0.0 ? a.y-shape_pixel.y : 10000.0;
            if (along>=0.0 && along<1.0 && depth<0.0 && -depth<best) { best=-depth;selected=ab.y<0.0 ? 0 : ab.y>0.0 ? 1 : 2;signed_depth=depth; }
        }
        if (selected<0 || best>outward_limit) discard;
        vec4 rim=family_edge(selected==2 ? material_pixel.x : material_pixel.y,signed_depth,selected);
        paint.a=rim.a; // source-authored alpha only; original v8 pigment remains continuous
        // The selected face's real extent bounds prevent invented corner caps.
    }
    COLOR=paint;
}
