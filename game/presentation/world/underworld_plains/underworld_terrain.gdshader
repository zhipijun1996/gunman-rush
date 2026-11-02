shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source_pixels : filter_nearest, repeat_disable;
uniform vec2 source_size;
uniform vec2 shape_origin;
uniform int face_count;
uniform vec4 faces[64];
uniform int corner_count;
uniform vec4 corners[64];
varying vec2 local_position;
void vertex(){local_position=VERTEX;}
vec4 sample_pixel(vec2 region, vec2 at){return texture(source_pixels,(region+clamp(floor(at),vec2(0.0),vec2(15.0))+0.5)/source_size);}
void fragment(){
 vec2 p=shape_origin+local_position;
 vec2 phase=mod(floor(p/2.0),16.0);
 vec2 region=vec2(32.0,16.0);
 vec2 sample_at=phase;
 float best=16.0;
 for(int i=0;i<64;i++){
  if(i>=face_count)break;
  vec2 a=faces[i].xy;vec2 b=faces[i].zw;
  float distance_to_face=999999.0;
  vec2 candidate_region=region;vec2 candidate_at=phase;
  if(a.y==b.y && p.x>=min(a.x,b.x) && p.x<max(a.x,b.x)){
   if(b.x>a.x && p.y>=a.y){distance_to_face=p.y-a.y;candidate_region=vec2(32.0,0.0);candidate_at.y=distance_to_face/2.0;}
   if(b.x<a.x && p.y<=a.y){distance_to_face=a.y-p.y;candidate_region=vec2(32.0,32.0);candidate_at.y=16.0-distance_to_face/2.0;}
  }
  if(a.x==b.x && p.y>=min(a.y,b.y) && p.y<max(a.y,b.y)){
   if(b.y<a.y && p.x>=a.x){distance_to_face=p.x-a.x;candidate_region=vec2(16.0,16.0);candidate_at.x=distance_to_face/2.0;}
   if(b.y>a.y && p.x<=a.x){distance_to_face=a.x-p.x;candidate_region=vec2(48.0,16.0);candidate_at.x=16.0-distance_to_face/2.0;}
  }
  if(distance_to_face<best){best=distance_to_face;region=candidate_region;sample_at=candidate_at;}
 }
 // Source-native convex AND concave quarter pixels replace both adjacent strips.
 // This follows canonical union vertices, independent of authored rectangles.
 float corner_best=32.0;
 for(int i=0;i<64;i++){
  if(i>=corner_count)break;
  vec4 c=corners[i];int type=int(c.z);int orientation=type%4;
  vec2 direction=vec2((orientation==0 || orientation==2)?1.0:-1.0,orientation<2?1.0:-1.0);
  vec2 d=(p-c.xy)*direction;
  if(d.x>=0.0 && d.y>=0.0 && d.x<16.0 && d.y<16.0 && max(d.x,d.y)<corner_best){
   corner_best=max(d.x,d.y);
   sample_at=vec2(direction.x>0.0?d.x/2.0:16.0-d.x/2.0,direction.y>0.0?d.y/2.0:16.0-d.y/2.0);
   if(type<4){region=vec2(orientation%2==0?16.0:48.0,orientation<2?0.0:32.0);}
   else{region=vec2(orientation%2==0?80.0:64.0,orientation<2?16.0:0.0);}
  }
 }
 COLOR=sample_pixel(region,sample_at);
}
