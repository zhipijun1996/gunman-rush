shader_type canvas_item;
uniform sampler2D architecture : filter_nearest;
uniform vec2 canvas_size = vec2(1280.0,720.0);
uniform vec2 architecture_offset = vec2(0.0);
uniform float surface_y = 592.0;
uniform vec4 water_color : source_color = vec4(0.063,0.11,0.19,1.0);
uniform float strength = 0.3;
void fragment(){
	float y = surface_y + UV.y * (canvas_size.y-surface_y);
	float band = floor(y/3.0);
	float displacement = floor(sin(band*2.17)*3.0);
	vec2 reflected = (vec2(UV.x*canvas_size.x+displacement,2.0*surface_y-y)-architecture_offset)/canvas_size;
	vec4 source = texture(architecture,reflected);
	float stripe = mod(band,4.0)<1.0?0.18:1.0;
	float fade = (1.0-UV.y)*strength*source.a*stripe;
	vec3 depth_color = mix(water_color.rgb,water_color.rgb*0.56,UV.y);
	COLOR = vec4(mix(depth_color,source.rgb,fade),1.0);
}
