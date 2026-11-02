shader_type canvas_item;
render_mode unshaded;
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 displacement_px = vec2(0.0);
void fragment() {
	vec2 uv = clamp(SCREEN_UV + displacement_px * SCREEN_PIXEL_SIZE, SCREEN_PIXEL_SIZE * .5, vec2(1.0) - SCREEN_PIXEL_SIZE * .5);
	COLOR = texture(world_screen, uv);
}
