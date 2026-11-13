shader_type canvas_item;
// Material coordinates belong to each sheet, never to the camera or screen.
uniform sampler2D paper_noise : repeat_enable, filter_linear;
uniform vec4 pigment : source_color = vec4(0.2, 0.4, 0.4, 1.0);
uniform float strength = 0.12;
uniform float seed = 0.0;
varying vec2 sheet_position;
void vertex() { sheet_position = VERTEX; }
void fragment() {
    vec2 p = sheet_position + vec2(seed * 137.1, seed * 49.7);
    float wash = texture(paper_noise, p / 713.0).r;
    float bloom = texture(paper_noise, mat2(vec2(0.8,-0.6),vec2(0.6,0.8))*p / 191.0).r;
    float tooth = texture(paper_noise, p / 27.7).r;
    float fiber = texture(paper_noise, p * vec2(0.19,0.035)).r;
    float tint = (wash - 0.5) * 0.7 + (bloom - 0.5) * 0.25;
    float grain = (tooth-0.5)*0.015 + (fiber-0.5)*0.008;
    vec3 ink = pigment.rgb * (1.0 + tint * strength + grain);
    COLOR = vec4(ink, pigment.a);
}
