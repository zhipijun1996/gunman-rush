shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment(){
	vec4 original = texture(screen_texture,SCREEN_UV);
	float value = dot(original.rgb,vec3(0.2126,0.7152,0.0722));
	COLOR = vec4(vec3(value),original.a);
}
