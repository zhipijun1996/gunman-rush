shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 canvas_size = vec2(1280.0,720.0);
uniform float surface_y = 560.0;
uniform vec4 water_color : source_color = vec4(0.09,0.17,0.27,1.0);
uniform float strength = 0.64;
uniform float clock = 0.0;
uniform bool foreground = false;
uniform float front_start_y = 624.0;
uniform float front_full_y = 672.0;
void fragment(){
 float y = SCREEN_UV.y*canvas_size.y;
 float row = floor((y-surface_y)/3.0);
 float dx = floor(sin(row*1.6+clock*1.8)*2.0+sin(row*0.21+clock)*1.0);
 vec2 reflected_uv = vec2((SCREEN_UV.x*canvas_size.x+dx)/canvas_size.x,(2.0*surface_y-y)/canvas_size.y);
 vec3 reflected = texture(scene,reflected_uv).rgb;
 float band = mod(row,4.0)<1.0?0.32:1.0;
 float depth = clamp((y-surface_y)/(canvas_size.y-surface_y),0.0,1.0);
 vec3 base = water_color.rgb*mix(1.0,0.65,depth);
 float alpha = foreground?smoothstep(front_start_y,front_full_y,y):1.0;
 COLOR = vec4(mix(base,reflected,strength*band*mix(1.0,0.55,depth)),alpha);
}
