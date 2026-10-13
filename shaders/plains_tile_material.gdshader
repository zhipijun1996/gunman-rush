shader_type canvas_item;
render_mode unshaded;
uniform sampler2D painted_material : source_color, filter_linear;
uniform sampler2D painted_border : source_color, filter_linear;
uniform highp vec4 faces[64];
uniform int face_count = 0;
uniform vec4 block_bounds;
uniform int cell_masks[16];
uniform int block_width = 1;
uniform bool canonical_cells = true;
uniform vec4 outer_corners[32];
uniform int corner_count = 0;
varying highp vec2 shape_pixel;
varying highp vec2 material_pixel;
void vertex() { shape_pixel = VERTEX; material_pixel = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
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
    vec4 grass=horizontal_sample(vec2(material_pixel.x/384.0,clamp(top*4.0/1024.0,0.0,0.22)));
    vec4 paint=mix(grass,earth,smoothstep(22.0,42.0,top));
    paint.rgb *= mix(side_light,1.0,smoothstep(0.0,5.0,edge_distance));
    vec3 border_sum=vec3(0.0);
    float border_weight=0.0;
    for (int side=0;side<3;side++) {
        float depth=edge_depth[side];
        if (depth<10.0) {
            vec4 rim=border_sample(side==2 ? material_pixel.x : material_pixel.y,depth,side);
            float w=(1.0-smoothstep(0.0,10.0,depth))*rim.a;
            if (side!=2) w*=smoothstep(4.0,12.0,top);
            border_sum+=rim.rgb*w; border_weight+=w;
        }
    }
    if (border_weight>0.0) paint.rgb=mix(paint.rgb,border_sum/border_weight,min(0.85,border_weight));
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
    paint.a *= contour;
    COLOR=paint;
}
