shader_type canvas_item;
render_mode unshaded;
uniform vec2 attachment;
uniform vec2 art_size;
uniform float source_to_world = 1.0;
uniform bool branch = false;
uniform int protection_count = 0;
uniform vec4 protection_rects[64];
uniform bool protection_overflow = false;
uniform float mask_soft_margin = 24.0;
uniform float root_visibility = 1.0;
uniform float wind_time = 0.0;
uniform float wind_phase = 0.0;
uniform vec4 depth_shadow : source_color = vec4(.025,.055,.066,1.0);
uniform vec4 depth_highlight : source_color = vec4(.25,.35,.29,1.0);
varying vec4 item_tint;
varying vec2 item_world_units;
void vertex() {
	item_tint=COLOR;
	float wind=(sin(wind_time*.73+wind_phase)*1.25+sin(wind_time*1.17+wind_phase*.61)*.35)/max(source_to_world,.01);
	// Affine shears pin the real source attachment. Even when sampling the
	// larger original crop, leaf tips move less than 2 world units.
	if(branch) VERTEX.y+=wind*(VERTEX.x-attachment.x)/max(art_size.x,1.0);
	else VERTEX.x+=wind*(attachment.y-VERTEX.y)/max(art_size.y,1.0);
	item_world_units=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy-MODEL_MATRIX[3].xy;
}
void fragment() {
	// Resolve the original high-detail atlas crop onto the shared fine grid.
	// Translation is excluded so texel choice stays stable during camera drift.
	vec2 target=floor(item_world_units)+vec2(.5);
	mat2 jacobian=mat2(dFdx(item_world_units),dFdy(item_world_units));
	vec2 screen_delta=inverse(jacobian)*(target-item_world_units);
	vec2 source_uv=UV+dFdx(UV)*screen_delta.x+dFdy(UV)*screen_delta.y;
	vec4 art=texture(TEXTURE,source_uv);
	float luma=dot(art.rgb,vec3(.2126,.7152,.0722));
	// Keep the blue-green near-plane silhouette on bright air, but preserve
	// enough leaf light to read its shape over the dark foreground rock.
	vec3 pigment=mix(depth_shadow.rgb,depth_highlight.rgb,clamp(luma*2.8,0.0,1.0));
	// Screen pixels share the same coordinates as actual Control/canvas
	// rectangles. Uploaded strict rectangles already include 3wu wind margin.
	// A sudden HUD/projectile never waits for the slower object fade to finish.
	vec2 screen_point=SCREEN_UV/SCREEN_PIXEL_SIZE;
	float protection=protection_overflow ? 0.0 : 1.0;
	for(int i=0;i<64;i++) {
		if(i>=protection_count) break;
		vec4 rect=protection_rects[i];
		vec2 outside=max(max(rect.xy-screen_point,screen_point-rect.zw),vec2(0.0));
		float distance_to_rect=length(outside);
		// Interior and boundary have exactly distance zero and alpha zero.
		protection=min(protection,smoothstep(0.0,max(mask_soft_margin,.001),distance_to_rect));
	}
	COLOR=vec4(pigment,art.a*protection*root_visibility)*item_tint;
}
