shader_type canvas_item;
render_mode unshaded;
uniform float cloud_time = 0.0;
uniform bool tower_landscape = false;
void fragment() {
 // Only the painted upper sky drifts. Hills, ground and the Clockheart silhouette remain registered.
 float sky_band = 1.0-smoothstep(.23,.38,UV.y);
 float tower_guard = tower_landscape ? smoothstep(.50,.59,UV.x)*(1.0-smoothstep(.84,.92,UV.x)) : 0.0;
 float offset = sin(cloud_time*.023)*.018*sky_band*(1.0-tower_guard);
 vec2 sample_uv = vec2(clamp(UV.x+offset,0.001,.999),UV.y);
 COLOR = texture(TEXTURE,sample_uv)*COLOR;
}
