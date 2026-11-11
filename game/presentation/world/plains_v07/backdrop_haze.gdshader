shader_type canvas_item;
render_mode unshaded;
uniform vec4 haze : source_color = vec4(.43,.53,.52,.4);
varying vec4 item_tint;
void vertex() {
 item_tint=COLOR;
}
void fragment() {
 vec4 surface=texture(TEXTURE,UV);
 COLOR=vec4(mix(surface.rgb,haze.rgb,haze.a),surface.a)*item_tint;
}
