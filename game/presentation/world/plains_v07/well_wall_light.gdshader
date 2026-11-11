shader_type canvas_item;
// A single world-fixed concave shaft, lit by the room's actual windows/lamps.
// Masonry remains native-scale: curvature never warps UVs or follows the camera.
uniform vec4 shaft = vec4(448.0, 0.0, 576.0, 2496.0);
varying vec2 world_point;
varying vec4 vertex_tint;
void vertex() {
 world_point = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
 vertex_tint = COLOR;
}
void fragment() {
 float in_shaft = 1.0 - smoothstep(shaft.y + shaft.w - 256.0, shaft.y + shaft.w, world_point.y);
 float across = clamp((world_point.x - shaft.x) / shaft.z * 2.0 - 1.0, -1.0, 1.0);
 float nx = -across * 0.8 * in_shaft;
 float nz = sqrt(1.0 - nx * nx);
 NORMAL = vec3(nx, 0.0, nz);
 // Broad diffuse sky fill decreases smoothly as the rear wall turns sideways.
 float diffuse_fill = mix(1.0, 0.25 + 0.75 * nz, in_shaft);
 COLOR = texture(TEXTURE, UV) * vertex_tint * vec4(vec3(diffuse_fill), 1.0);
}
