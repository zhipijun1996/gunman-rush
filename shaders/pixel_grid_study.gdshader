shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform float block_size = 2.0;
void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 pixel = (floor(SCREEN_UV * resolution / block_size) + .5) * block_size;
	COLOR = textureLod(world_screen, pixel / resolution, 0.0);
}
