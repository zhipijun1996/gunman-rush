shader_type canvas_item;
render_mode unshaded;
uniform vec4 fracture_region_px = vec4(640.0,560.0,520.0,360.0);
uniform float fracture_recession = 0.62;
varying vec4 item_tint;
void vertex() { item_tint=COLOR; }
void fragment() {
    vec4 original=texture(TEXTURE,UV);
    vec2 pixel=UV/TEXTURE_PIXEL_SIZE;
    vec2 local=pixel-fracture_region_px.xy;
    vec2 end=fracture_region_px.zw-local;
    float band=smoothstep(0.0,64.0,min(min(local.x,local.y),min(end.x,end.y)));
    float gray=dot(original.rgb,vec3(0.2126,0.7152,0.0722));
    vec3 distant=mix(original.rgb,vec3(gray)*vec3(0.76,0.89,0.94),0.38)*0.75;
    // Source alpha/UV never change: this is role lighting, not a painted platform mask.
    COLOR=vec4(mix(original.rgb,distant,band*fracture_recession),original.a)*item_tint;
}
