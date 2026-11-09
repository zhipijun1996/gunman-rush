shader_type canvas_item;
// Geometry correspondence data, never a blurred RGB frame or whole-sprite dissolve.
uniform sampler2D motion_vectors : filter_linear, repeat_disable;
uniform sampler2D backdrop : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 frame_origin;
uniform vec2 frame_pixels;
uniform vec2 next_origin;
uniform vec2 vector_origin;
uniform vec2 vector_size;
uniform float pose_mix = 0.0;
uniform float hit_flash = 0.0;
varying vec4 modulation;
void vertex() { modulation = COLOR; }
void fragment() {
 vec2 local = (UV-frame_origin)/TEXTURE_PIXEL_SIZE;
 vec2 cell = local/frame_pixels;
 vec4 data = texture(motion_vectors,vector_origin+clamp(cell,vec2(0.001),vec2(0.999))*vector_size);
 vec4 flow = (data*255.0-128.0)*(64.0/127.0);
 vec2 a = floor(clamp(local-pose_mix*flow.xy,vec2(0.0),frame_pixels-vec2(1.0)))+vec2(0.5);
 vec2 b = floor(clamp(local-(1.0-pose_mix)*flow.zw,vec2(0.0),frame_pixels-vec2(1.0)))+vec2(0.5);
 vec2 ua = frame_origin+a*TEXTURE_PIXEL_SIZE;
 vec2 ub = next_origin+b*TEXTURE_PIXEL_SIZE;
 vec4 ca=texture(TEXTURE,ua), cb=texture(TEXTURE,ub);
 float coverage=mix(ca.a,cb.a,pose_mix);
 vec3 raw=mix(ca.rgb*ca.a,cb.rgb*cb.a,pose_mix)/max(coverage,0.001);
 float top=texture(TEXTURE,ua-vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a;
 float left=texture(TEXTURE,ua-vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a;
 float right=texture(TEXTURE,ua+vec2(TEXTURE_PIXEL_SIZE.x,0.0)).a;
 float bottom=texture(TEXTURE,ua+vec2(0.0,TEXTURE_PIXEL_SIZE.y)).a;
 float edge=1.0-min(min(top,bottom),min(left,right));
 float ground=dot(texture(backdrop,SCREEN_UV).rgb,vec3(.2126,.7152,.0722));
 float dark_ground=1.0-smoothstep(.12,.42,ground);
 float value=dot(raw,vec3(.2126,.7152,.0722));
 vec3 rgb=mix(vec3(value),raw,.82);
 rgb=(rgb-vec3(.35))*1.18+vec3(.35);
 rgb+=vec3(.14*smoothstep(.07,.30,value)*(1.0-smoothstep(.70,1.0,value))*dark_ground);
 rgb=mix(rgb,vec3(.075,.115,.12),edge*(1.0-dark_ground)*.78);
 rgb=mix(rgb,vec3(.80,.75,.62),(1.0-top)*dark_ground*.55);
 rgb=mix(clamp(rgb,vec3(0.0),vec3(1.0)),vec3(1.0,.95,.78),hit_flash);
 COLOR=vec4(rgb,step(.5,coverage))*modulation;
}
