class_name UnderworldParallax
extends PixelPlainsParallax
## Three source paintings; each plane moves by its own real camera coefficient.
## The far sky mirrors identical source edges; transparent planes overlap with
## alpha-only edge fades. Repetition is explicit, not an infinite painted world.
const BUILD_PATH := "res://assets/underworld_plains/scenery_build.json"
var layer_specs: Array = []
var layer_textures: Array[Texture2D] = []
var layer_hashes: Array[String] = []
var _explicit_camera: Camera2D
var _measured: Array[Dictionary] = []

func configure(camera: Camera2D, _bounds: Rect2 = Rect2(), _manifest: Dictionary = {}) -> void:
	_explicit_camera = camera

func _ready() -> void:
	layer = -100
	layer_specs = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH)).backgrounds
	surface = Node2D.new()
	add_child(surface)
	for spec: Dictionary in layer_specs:
		var texture := load("res://" + str(spec.image)) as Texture2D
		layer_textures.append(texture)
		# Read source bytes once during setup. Evidence generation must never
		# turn the real render tick into three multi-megabyte file reads.
		layer_hashes.append(FileAccess.get_sha256("res://" + str(spec.image)))
		for copy: int in 3:
			var panel := Sprite2D.new()
			panel.name = "Underworld_" + str(spec.id) + str(copy)
			panel.centered = false
			panel.texture = texture
			panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if str(spec.repetition) == "overlapping_alpha_edge_fade":
				var material := ShaderMaterial.new()
				material.shader = preload("res://scripts/underworld_plains/underworld_parallax_edge.gdshader")
				material.set_shader_parameter("edge_fraction", float(spec.edge_fraction))
				material.set_shader_parameter("plane_opacity", float(spec.opacity))
				material.set_shader_parameter("fog_shadow", Color(str(spec.fog_shadow)))
				material.set_shader_parameter("fog_highlight", Color(str(spec.fog_highlight)))
				panel.material = material
			surface.add_child(panel)
			panels.append(panel)
	_update()

func _update() -> void:
	if not is_instance_valid(surface): return
	var size := get_viewport().get_visible_rect().size
	var camera := _explicit_camera if is_instance_valid(_explicit_camera) else get_viewport().get_camera_2d()
	var center := camera.get_screen_center_position() if camera != null else origin
	camera_offset = center - origin
	_measured.clear()
	for i: int in layer_specs.size():
		var spec: Dictionary = layer_specs[i]
		var texture := layer_textures[i]
		var rate := Vector2(float(spec.camera_factor[0]), float(spec.camera_factor[1]))
		var factor := maxf(size.x * float(spec.width_ratio) / texture.get_width(), size.y * float(spec.minimum_height_ratio) / texture.get_height())
		var width := ceilf(texture.get_width() * factor / 2.0) * 2.0
		factor = width / texture.get_width()
		var height := texture.get_height() * factor
		var drift := camera_offset * rate
		var mirrored := str(spec.repetition) == "alternating_mirrored_strips"
		var stride := width if mirrored else width * (1.0 - 2.0 * float(spec.edge_fraction))
		var first := floori(drift.x / stride) - 1
		var y := size.y * float(spec.bottom_ratio) - height
		y -= clampf(drift.y, -size.y * .10, size.y * .10)
		if i == 0: y = clampf(y, size.y - height, 0.0)
		var strips: Array[Dictionary] = []
		for copy: int in 3:
			var index := first + copy
			var panel := panels[i * 3 + copy]
			# Unsnap X: snapping adjacent strips independently can leave a one-pixel
			# gap at non-integer viewport scales. Shared width/offset is exact.
			panel.position = Vector2(index * stride - drift.x, roundf(y))
			panel.scale = Vector2.ONE * factor
			panel.flip_h = mirrored and posmod(index, 2) == 1
			strips.append({"index": index, "x": panel.position.x, "right": panel.position.x + width, "mirrored": panel.flip_h})
		_measured.append({"layer": spec.id, "texture_path": texture.resource_path, "texture_sha256": layer_hashes[i], "hash_method": "raw_source_sha256_cached_once_in_ready", "camera_coefficient": spec.camera_factor, "unwrapped_offset": [-drift.x, -drift.y], "screen_position": [panels[i * 3].position.x, y], "display_size": [width, height], "repeat_stride": stride, "vertical_clamped": absf(drift.y) > size.y * .10 or (i == 0 and (is_equal_approx(y, 0) or is_equal_approx(y, size.y-height))), "repetition": spec.repetition, "strips": strips, "visible": visible})

func measured_nodes() -> Array[Dictionary]:
	return _measured.duplicate(true)
