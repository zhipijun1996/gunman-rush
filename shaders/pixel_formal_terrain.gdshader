shader_type canvas_item;
render_mode unshaded;
uniform highp vec2 shape_origin;
uniform int face_count = 0;
uniform highp vec4 faces[64];
varying highp vec2 local_position;
void vertex() { local_position = VERTEX; }
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void fragment() {
	highp vec2 p = shape_origin + local_position;
	vec3 ink = vec3(0.0667, 0.1176, 0.1686);
	vec3 deep = vec3(0.1255, 0.2314, 0.2745);
	vec3 stone = vec3(0.2118, 0.3529, 0.3490);
	vec3 moss = vec3(0.4314, 0.5686, 0.5020);
	vec3 cream = vec3(0.6902, 0.7255, 0.4824);
	vec3 col = deep;
	// Broad quiet fractured planes; no outlines, grain, or repeated tile stamps.
	vec2 q = floor(p/2.0)*2.0;
	float row = floor(q.y/94.0);
	float shift = floor(hash21(vec2(row,43.0))*80.0)*2.0;
	vec2 block = floor(vec2(q.x+shift,q.y)/vec2(172.0,94.0));
	float plane = hash21(block+91.0);
	vec2 within = mod(vec2(q.x+shift,q.y),vec2(172.0,94.0));
	float cut = 112.0+floor(hash21(block+3.0)*18.0)*2.0;
	if (plane > .56 && within.x < cut-min(24.0,floor(within.y/18.0)*4.0)) col=mix(deep,stone,.14);
	float top = 99999.0;
	float side = 99999.0;
	float bottom = 99999.0;
	for (int i = 0; i < 64; i++) {
		if (i >= face_count) break;
		vec2 a = faces[i].xy;
		vec2 b = faces[i].zw;
		if (a.y == b.y && p.x >= min(a.x,b.x) && p.x <= max(a.x,b.x)) {
			if (b.x > a.x && p.y >= a.y) top = min(top,p.y-a.y);
			if (b.x < a.x && p.y <= a.y) bottom = min(bottom,a.y-p.y);
		}
		if (a.x == b.x && p.y >= min(a.y,b.y) && p.y <= max(a.y,b.y)) side=min(side,abs(p.x-a.x));
	}
	// A quiet body, with a few low contrast two-pixel wind chips.
	// Large irregular hash cells avoid a tile-sized repeating scratch grid.
	vec2 cell = floor(p / vec2(78.0,58.0));
	vec2 chip_at = cell * vec2(78.0,58.0) + floor(vec2(hash21(cell),hash21(cell+7.0))*vec2(34.0,22.0))*2.0;
	vec2 chip = floor(p/2.0)*2.0-chip_at;
	if (hash21(cell+17.0) > .84 && chip.x >= 0.0 && chip.x < 6.0 && chip.y >= 0.0 && chip.y < 2.0) col = mix(deep,stone,.32);
	if (side < 2.0) col = ink;
	if (bottom < 4.0) col = ink;
	if (top < 8.0) col = stone;
	if (top < 4.0) col = moss;
	// Highlights are small sparse moss flecks, not an all-edge bright outline.
	float ridge = hash21(vec2(floor(p.x/14.0),floor((p.y-top)/2.0)));
	if (top < 2.0 && ridge > .72) col = cream;
	COLOR = vec4(col,1.0);
}
