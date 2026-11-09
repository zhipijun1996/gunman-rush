shader_type canvas_item;
render_mode unshaded;

uniform sampler2D platform_mask : filter_nearest, repeat_disable;
uniform vec2 mask_origin = vec2(-64.0, 0.0);
uniform vec2 mask_size = vec2(768.0, 360.0);
uniform vec2 hero_center = vec2(118.0, 266.0);
uniform vec2 hero_radius = vec2(30.0, 48.0);
uniform float hero_min_alpha = 0.15;
uniform bool has_reveal = true;
uniform bool protection_enabled = true;
varying vec2 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    vec2 pixel_position = floor(world_position);
    vec2 mask_uv = (pixel_position - mask_origin + vec2(0.5)) / mask_size;
    float alpha = texture(platform_mask, mask_uv).a;
    if (has_reveal && protection_enabled) {
        float distance_to_hero = length((pixel_position - hero_center) / max(hero_radius, vec2(1.0)));
        alpha *= mix(hero_min_alpha, 1.0, smoothstep(0.35, 1.0, distance_to_hero));
    }
    COLOR.a *= alpha;
}
