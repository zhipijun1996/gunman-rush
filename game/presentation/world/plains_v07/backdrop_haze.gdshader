shader_type canvas_item;
render_mode unshaded;
uniform vec4 haze : source_color = vec4(.43,.53,.52,.4);
void fragment() {
 vec4 surface=texture(TEXTURE,UV);
 COLOR*=vec4(mix(surface.rgb,haze.rgb,haze.a),surface.a);
}
