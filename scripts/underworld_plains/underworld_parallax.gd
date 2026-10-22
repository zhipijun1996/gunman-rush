class_name UnderworldParallax
extends PixelPlainsParallax
## Independent authored planes, fine1wu camera sampling, no mirrored skyline.
## Sky wraps its source edge; alpha planes overlap. Bottom rows extend downward.
const BUILD_PATH := "res://assets/underworld_plains/scenery_build.json"
var layer_specs: Array = []
var layer_textures: Array[Texture2D] = []
var layer_hashes: Array[String] = []
var _explicit_camera: Camera2D
var _measured: Array[Dictionary] = []
var _wind_seconds := 0.0
var _phase_offset := 0.0

func configure(camera: Camera2D, _bounds: Rect2 = Rect2(), world_manifest: Dictionary = {}) -> void:
	_explicit_camera = camera
	var key := str(world_manifest.get("manifest_hash",world_manifest.get("seed","")))
	_phase_offset = float(posmod(key.hash(),512)) if not key.is_empty() else 0.0

func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_PAUSABLE
	layer_specs = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH)).backgrounds
	surface = Node2D.new()
	add_child(surface)
	for spec: Dictionary in layer_specs:
		var texture := load("res://" + str(spec.image)) as Texture2D
		layer_textures.append(texture)
		# Read source bytes once during setup. Evidence generation must never
		# turn the real render tick into three multi-megabyte file reads.
		# Imported PNGs need not be duplicated as raw Web files. The source build
		# binds this digest; native development also verifies the available bytes.
		var digest:=str(spec.get("source_sha256",""))
		if FileAccess.file_exists("res://"+str(spec.image)):
			var actual:=FileAccess.get_sha256("res://"+str(spec.image))
			assert(digest.is_empty() or digest==actual,"Background source differs from its build")
			digest=actual
		assert(digest.length()==64)
		layer_hashes.append(digest)
		for copy: int in 3:
			var panel := Sprite2D.new()
			panel.name = "Underworld_" + str(spec.id) + str(copy)
			panel.centered = false
			panel.texture = texture
			panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			panel.region_enabled = true
			if str(spec.repetition) == "same_orientation_seam_blend":
				var material := ShaderMaterial.new()
				material.shader = preload("res://scripts/underworld_plains/parallax_sky.gdshader")
				material.set_shader_parameter("source_size",Vector2(texture.get_size()))
				material.set_shader_parameter("seam_fraction",float(spec.get("edge_fraction",.035)))
				material.set_shader_parameter("upper_sky_gain",float(spec.get("upper_sky_gain",.72)))
				material.set_shader_parameter("upper_sky_saturation",float(spec.get("upper_sky_saturation",.90)))
				panel.material = material
			else:
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

func _process(delta: float) -> void:
	if not visible: return
	_wind_seconds += delta
	_update()

func _soft_drift(value: float, limit: float) -> float:
	return value / (1.0 + absf(value) / maxf(limit,.001))

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
		var width := ceilf(texture.get_width() * factor)
		factor = width / texture.get_width()
		var height := texture.get_height() * factor
		var drift := camera_offset * rate
		var opaque := str(spec.repetition) == "same_orientation_seam_blend"
		var stride := width if opaque else floorf(width * (1.0 - 2.0 * float(spec.get("edge_fraction",.035))))
		var phase := drift.x + _phase_offset * (.15 + float(i)*.2) + float(spec.get("composition_phase_wu",0.0))
		var first := floori(phase / stride) - 1
		var shared_x := roundf(-phase)
		var limit := size.y * float(spec.get("vertical_limit_ratio",.20))
		if opaque: limit = minf(limit,maxf(1.0,height-size.y))
		var vertical := _soft_drift(drift.y,limit)
		var y := roundf(size.y * float(spec.bottom_ratio) - height - vertical)
		if opaque: y = minf(y,0.0)
		var extended_pixels := maxi(texture.get_height(),ceili((size.y-y)/factor)+2)
		var cloud_phase := _wind_seconds * float(spec.get("cloud_speed_wu_per_second",0.0)) / factor
		var strips: Array[Dictionary] = []
		for copy: int in 3:
			var index := first + copy
			var panel := panels[i * 3 + copy]
			# Width, stride and origin are shared integers: all copies agree at
			# the fine1wu edge even for viewport widths not divisible by source.
			panel.position = Vector2(index * stride + shared_x, y)
			panel.scale = Vector2.ONE * factor
			panel.flip_h = false
			panel.region_rect = Rect2(0,0,texture.get_width(),extended_pixels)
			if opaque: (panel.material as ShaderMaterial).set_shader_parameter("cloud_phase_source_px",cloud_phase)
			strips.append({"index": index, "x": panel.position.x, "right": panel.position.x + width, "mirrored": panel.flip_h})
		_measured.append({"layer": spec.id, "texture_path": texture.resource_path, "texture_sha256": layer_hashes[i], "hash_method": "source_build_sha256_native_bytes_checked_when_available", "camera_coefficient": spec.camera_factor, "unwrapped_offset": [-drift.x, -drift.y], "screen_position": [panels[i * 3].position.x, y], "display_size": [width, extended_pixels*factor], "source_display_size":[width,height], "repeat_stride": stride, "vertical_clamped": false, "vertical_policy":"smooth_bounded_drift_with_bottom_source_row_extension", "vertical_applied":vertical, "bottom_source_extension_px":extended_pixels-texture.get_height(), "pixel_world_units":1, "repetition": spec.repetition, "cloud_phase_source_px":cloud_phase, "seed_phase":_phase_offset, "strips": strips, "visible": visible})

func measured_nodes() -> Array[Dictionary]:
	return _measured.duplicate(true)
