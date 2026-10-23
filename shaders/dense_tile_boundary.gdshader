shader_type canvas_item;
#include "res://shaders/dense_material.gdshaderinc"
uniform vec2 shape_origin;
uniform int face_count;
uniform vec4 faces[64];
uniform int corner_count;
uniform vec4 corners[64];
varying vec2 local_position;
void vertex() { local_position=VERTEX; }
void fragment() {
	vec2 p = shape_origin+local_position;
	float best=32.; int face=4;
	for(int i=0;i<64;i++) {
		if(i>=face_count) break;
		vec2 a=faces[i].xy;vec2 b=faces[i].zw;
		float d=999999.;int kind=4;
		if(a.y==b.y && p.x>=min(a.x,b.x) && p.x<max(a.x,b.x)) {
			if(b.x>a.x && p.y>=a.y) {d=p.y-a.y;kind=0;}
			if(b.x<a.x && p.y<=a.y) {d=a.y-p.y;kind=2;}
		}
		if(a.x==b.x && p.y>=min(a.y,b.y) && p.y<max(a.y,b.y)) {
			if(b.y<a.y && p.x>=a.x) {d=p.x-a.x;kind=3;}
			if(b.y>a.y && p.x<=a.x) {d=a.x-p.x;kind=1;}
		}
		if(d<best) {best=d;face=kind;}
	}
	COLOR=dense_material(p,best,face);
	for(int i=0;i<64;i++) {
		if(i>=corner_count) break;
		int type=int(corners[i].z);
		if(type>=4) continue;
		vec2 direction=vec2((type==0 || type==2)?1.:-1.,type<2?1.:-1.);
		vec2 d=(p-corners[i].xy)*direction;
		if(d.x>=0. && d.y>=0. && d.x<4. && d.y<4. && length(d-vec2(4.))>4.) COLOR.a=0.;
	}
}
