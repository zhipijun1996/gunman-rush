shader_type canvas_item;
render_mode unshaded;
uniform float progress = 0.0;
void fragment() {
	vec2 p = UV-vec2(.5);
	float burst = exp(-pow((progress-.54)*11.0,2.0));
	float envelope = sin(clamp(progress,0.0,1.0)*3.14159265);
	float radius = length(p*vec2(1.7,1.0));
	float ring = 1.0-smoothstep(.025,.09,abs(radius-(progress-.22)*1.9));
	// Broad moving wind bands keep the center readable; no opaque white cut.
	float bands = pow(max(0.0,sin((UV.y+UV.x*.10-progress*.75)*92.0)),18.0);
	float edge = smoothstep(.16,.72,radius);
	vec3 tint = mix(vec3(.34,.65,.61),vec3(.96,.88,.63),burst);
	float alpha = envelope*(edge*.16+bands*edge*.10+ring*.17)+burst*.08*(.25+.75*edge);
	COLOR = vec4(tint,alpha);
}
