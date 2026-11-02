shader_type canvas_item;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_ink : source_color = vec4(1.0, 0.949, 0.702, 1.0);
// Opt-in, task-local Underworld sample. The legacy atlas keeps its own palette.
uniform float readable_material : hint_range(0.0, 1.0) = 0.0;
uniform float copper_wings : hint_range(0.0, 1.0) = 0.0;
uniform float lifeless : hint_range(0.0, 1.0) = 0.0;
uniform float authored_palette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 frame_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	// CanvasItem's fragment COLOR already includes texture and vertex tint.
	vec4 body = COLOR;
	float value = max(body.r, max(body.g, body.b));
	// The source's broad inner planes are almost black as well as its ink.
	// Only lift that interior when all four neighbouring source pixels are
	// opaque. Silhouette pixels keep the original dark edge and alpha.
	float interior = min(min(texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a,
		texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a));
	float material_mask = max(smoothstep(0.035, 0.15, value), smoothstep(0.92, 0.99, interior) * 0.86);
	// Authored RGB has brighter source values than the small original sprites;
	// match their material range while keeping one tone map per species family.
	float material_value = mix(value, value*mix(0.8, 0.6, copper_wings), authored_palette);
	float plane = smoothstep(0.04, 0.78, material_value);
	// Separate existing warm metal pixels from cool shell pixels. Leave the
	// darkest ink/recesses alone; this is not a full-sprite exposure multiplier.
	float warm = smoothstep(0.018, 0.10, body.r - body.b);
	// New full-color atlas moss is yellow-green; r-b alone mistakes it for
	// brass. Keep the original live source branch unchanged, classify new
	// material by red-vs-green contrast instead.
	float authored_warm = smoothstep(0.07, 0.22, (body.r-body.g)/max(value, 0.03));
	warm = mix(warm, authored_warm, authored_palette);
	vec2 frame_uv = (UV-frame_uv_rect.xy)/max(frame_uv_rect.zw, vec2(0.0001));
	float top_light = 1.0 - smoothstep(0.22, 0.82, frame_uv.y);
	vec3 shell = mix(vec3(0.22, 0.37, 0.25) + vec3(0.10, 0.15, 0.05)*top_light, vec3(0.76, 0.84, 0.51), plane);
	vec3 stone = mix(vec3(0.25, 0.37, 0.43) + vec3(0.07, 0.13, 0.14)*top_light, vec3(0.76, 0.87, 0.83), plane);
	vec3 brass = mix(vec3(0.47, 0.29, 0.12), vec3(1.0, 0.82, 0.44), plane);
	vec3 planes = mix(mix(shell, stone, copper_wings), brass, warm);
	body.rgb = mix(body.rgb, planes, material_mask * readable_material);
	// A corpse retains opaque, readable material, but loses living saturation.
	float grey = dot(body.rgb, vec3(0.299, 0.587, 0.114));
	vec3 remains = mix(vec3(grey), body.rgb, 0.28) * vec3(0.97, 0.99, 1.02);
	body.rgb = mix(body.rgb, remains, lifeless);
	// Replace RGB inside the existing alpha silhouette. Multiplication alone
	// cannot make a dark source pixel read as a bright accepted impact.
	body.rgb = mix(body.rgb, flash_ink.rgb, hit_flash);
	COLOR = body;
}
