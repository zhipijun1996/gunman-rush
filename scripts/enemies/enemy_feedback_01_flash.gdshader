shader_type canvas_item;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_ink : source_color = vec4(1.0, 0.949, 0.702, 1.0);

void fragment() {
	// CanvasItem's fragment COLOR already includes texture and vertex tint.
	vec4 body = COLOR;
	// Replace RGB inside the existing alpha silhouette. Multiplication alone
	// cannot make a dark source pixel read as a bright accepted impact.
	body.rgb = mix(body.rgb, flash_ink.rgb, hit_flash);
	COLOR = body;
}
