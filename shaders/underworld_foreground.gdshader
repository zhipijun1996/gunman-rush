shader_type canvas_item;
render_mode unshaded;
uniform vec2 attachment;
uniform vec2 art_size;
uniform bool branch = false;
uniform float wind_time = 0.0;
uniform float wind_phase = 0.0;
uniform vec4 depth_shadow : source_color = vec4(.022,.044,.055,1.0);
uniform vec4 depth_highlight : source_color = vec4(.09,.145,.14,1.0);
varying vec4 item_tint;
void vertex() {
	item_tint=COLOR;
	float wind=sin(wind_time*.73+wind_phase)*1.25+sin(wind_time*1.17+wind_phase*.61)*.35;
	// These are affine shears through the true attachment. Interpolated
	// attachment pixels remain fixed; grass tips/branch ends move <2wu.
	if(branch) VERTEX.y+=wind*(VERTEX.x-attachment.x)/max(art_size.x,1.0);
	else VERTEX.x+=wind*(attachment.y-VERTEX.y)/max(art_size.y,1.0);
}
void fragment() {
	vec4 art=texture(TEXTURE,UV);
	float luma=dot(art.rgb,vec3(.2126,.7152,.0722));
	vec3 pigment=mix(depth_shadow.rgb,depth_highlight.rgb,clamp(luma*2.0,0.0,1.0));
	COLOR=vec4(pigment,art.a)*item_tint;
}
