shader_type canvas_item;
render_mode unshaded;

uniform sampler2D atlas : source_color, filter_linear;
uniform float platform_width;
uniform float art_scale = 0.2;
uniform float draw_height;

// Sample in premultiplied space: transparent atlas RGB is not painted pigment.
vec4 sample_paint(float x, float y) {
    vec4 c = texture(atlas, vec2(x, y) / vec2(1536.0, 1024.0));
    return vec4(c.rgb * c.a, c.a);
}

// Only the cap-free interior repeats. At a wrap both sides converge to the
// SAME interior sample; the atlas was not authored as a seamless strip.
vec4 body(float x, float y) {
    float t = fract(x / 340.0);
    vec4 a = sample_paint(140.0 + t * 340.0, y);
    vec4 b = sample_paint(140.0 + fract(t + 0.5) * 340.0, y);
    return mix(b, a, smoothstep(0.0, 0.15, min(t, 1.0 - t)));
}

void fragment() {
    float x = UV.x * platform_width / art_scale;
    float width = platform_width / art_scale;
    float y = 710.0 + UV.y * draw_height / art_scale;
    vec4 c = body(x, y);
    // One authored terminal per exposed end. Short platforms scale uniformly;
    // cap transition bands never overlap. No world-coordinate clipping phase.
    float left_weight = 1.0 - smoothstep(95.0, 145.0, x);
    float right_weight = 1.0 - smoothstep(95.0, 145.0, width - x);
    c = mix(c, sample_paint(20.0 + min(x, 145.0), y), left_weight);
    c = mix(c, sample_paint(598.0 - min(width - x, 145.0), y), right_weight);
    COLOR = vec4(c.rgb / max(c.a, 0.0001), c.a);
}
