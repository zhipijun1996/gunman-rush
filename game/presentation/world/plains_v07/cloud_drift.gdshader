shader_type canvas_item;
render_mode unshaded;
uniform float cloud_time = 0.0;
uniform float speed = .006;
uniform float phase = 0.0;
uniform float density = .72;
void fragment() {
 // Only this transparent cloud texture moves; the land/tower is a separate layer.
 vec2 sample_uv=vec2(fract(UV.x-cloud_time*speed+phase),UV.y);
 vec4 veil=texture(TEXTURE,sample_uv);
 float evolution=.84+.16*sin(cloud_time*.07+phase*6.28318+sample_uv.x*4.0);
 COLOR*=vec4(veil.rgb,veil.a*density*evolution);
}
