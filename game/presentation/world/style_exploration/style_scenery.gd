class_name StyleScenery
extends Node2D
## Source-native layered art. All set dressing is non-colliding and owns a separate RNG.
const ROOT := "res://assets/style_exploration/"
const REGION_PALETTE := preload("res://game/presentation/world/style_exploration/style_palette.gd")
const CELL := 32.0
const COLORS := {
	"retro": [Color("081524"), Color("111d35"), Color("1f3951"), Color("74eff2")],
	"basic": [Color("8c9cc9"), Color("e4b6ae"), Color("b4bdce"), Color("fff2b6")],
	"scribble": [Color("f8f4e9"), Color("e6ede6"), Color("a9b3ae"), Color("edd07c")],
	"underworld": [Color("18263b"), Color("616d85"), Color("293d49"), Color("a5f29b")],
	"cavern": [Color("24233e"), Color("746287"), Color("49415d"), Color("e7b3da")]
}
var style_id := "retro"
var biome_id := "plains"
var _layout: Dictionary
var _camera: Camera2D
var _background: Node2D
var _decor: Node2D
var _lights: Node2D
var _parallax: Array[Dictionary] = []
var _sway: Array[Dictionary] = []
var _light_sources: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _decor_enabled := true
var _background_enabled := true
var _lights_enabled := true
var _glow_texture: Texture2D

func configure(value: String, layout: Dictionary, camera: Camera2D, biome: String = "plains") -> void:
	assert(biome in ["plains", "forest", "gear"])
	assert(biome == "plains" or value in ["underworld", "cavern"])
	style_id = value
	biome_id = biome
	_layout = layout
	_camera = camera
	for child: Node in get_children(): child.free()
	_parallax.clear()
	_sway.clear()
	_light_sources.clear()
	_rng.seed = ("style-lab/decor/v1/" + str(layout.seed) + ("/" + biome_id if biome_id != "plains" else "")).hash()
	_background = Node2D.new()
	_background.name = "ThreeDepthBackground"
	_background.z_index = -40
	add_child(_background)
	_decor = Node2D.new()
	_decor.name = "SupportedNativeSetDressing"
	_decor.z_index = -2
	add_child(_decor)
	_lights = Node2D.new()
	_lights.name = "BoundedAmbientMotes"
	_lights.z_index = 5
	add_child(_lights)
	_build_background()
	_build_decor()
	_build_lights()
	set_decor_enabled(_decor_enabled)
	set_background_enabled(_background_enabled)
	set_lights_enabled(_lights_enabled)

func set_decor_enabled(value: bool) -> void:
	_decor_enabled = value
	if is_instance_valid(_decor): _decor.visible = value

func set_background_enabled(value: bool) -> void:
	_background_enabled = value
	if is_instance_valid(_background): _background.visible = value

func set_lights_enabled(value: bool) -> void:
	_lights_enabled = value
	if is_instance_valid(_lights): _lights.visible = value

func _art_root() -> String:
	var base := ROOT + style_id + "/"
	if biome_id != "plains": return base + biome_id + "/"
	if style_id == "cavern" and (FileAccess.file_exists(base + "plains/chime_props.json") or ResourceLoader.exists(base + "plains/background_sky.png")):
		return base + "plains/"
	return base

func _palette() -> Array:
	if style_id in ["underworld", "cavern"]:
		return REGION_PALETTE.scenery_colors(style_id, biome_id)
	return COLORS[style_id]

func _source(filename: String) -> String:
	return ROOT + style_id + "/original/" + filename

func _texture(path: String, region: Rect2 = Rect2()) -> Texture2D:
	if not ResourceLoader.exists(path): return null
	var loaded := load(path) as Texture2D
	if region.size == Vector2.ZERO: return loaded
	var atlas := AtlasTexture.new()
	atlas.atlas = loaded
	atlas.region = region
	atlas.filter_clip = true
	return atlas

func _sprite(parent: Node2D, texture: Texture2D, foot: Vector2, height: float, tint := Color.WHITE) -> Sprite2D:
	if texture == null: return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	var ratio := height / texture.get_height()
	sprite.scale = Vector2.ONE * ratio
	sprite.position = foot - Vector2(texture.get_width() * ratio * 0.5, height)
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if style_id != "scribble" else CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(sprite)
	return sprite

func _depth(factor: float, order: int) -> Node2D:
	var group := Node2D.new()
	group.z_index = order
	_background.add_child(group)
	_parallax.append({"node": group, "factor": factor})
	return group

func _build_background() -> void:
	var palette: Array = _palette()
	# The sky is an atmospheric color field; source-native shapes carry the landscape.
	var gradient := Gradient.new()
	gradient.set_color(0, palette[0])
	gradient.set_color(1, palette[1])
	var sky_texture := GradientTexture2D.new()
	sky_texture.gradient = gradient
	sky_texture.width = 8
	sky_texture.height = 768
	sky_texture.fill_from = Vector2(0, 0)
	sky_texture.fill_to = Vector2(0, 1)
	var sky := Sprite2D.new()
	sky.texture = sky_texture
	sky.centered = false
	sky.position = Vector2(-1500, -700)
	sky.scale = Vector2(800, 2)
	sky.z_index = -4
	_background.add_child(sky)
	var far := _depth(0.14, -3)
	var middle := _depth(0.34, -2)
	var near := _depth(0.62, -1)
	match style_id:
		"retro":
			# Original outline trees and moons preserve VEXED's limited palette and void.
			var tree := _texture(_source("Environment.png"), Rect2(0, 96, 48, 48))
			for i: int in range(-2, 11):
				_sprite(far, tree, Vector2(i * 360 + 150, 580), 180, Color("214052"))
			for i: int in range(-1, 7):
				_sprite(middle, tree, Vector2(i * 490 + 260, 650), 230, Color("346977"))
			_sprite(far, _texture(_source("Environment.png"), Rect2(48, 1008, 32, 48)), Vector2(650, 230), 92, Color("92a8a6"))
		"basic":
			var tree := _texture(_source("sTileset.png"), Rect2(80, 96, 16, 48))
			for i: int in range(-1, 10):
				_sprite(middle, tree, Vector2(i * 350 + 110, 610), 220, Color("a6b3bd"))
			for i: int in range(-1, 8):
				_sprite(near, tree, Vector2(i * 430 + 200, 665), 185, Color("b8c4b2"))
		"scribble":
			for i: int in range(-1, 10):
				_sprite(far, _texture(_source("background_cloudA.png" if i % 2 == 0 else "background_cloudB.png")), Vector2(i * 350 + 230, 210 + (i % 3) * 40), 60, Color(1, 1, 1, 0.9))
			for i: int in range(-1, 10):
				_sprite(middle, _texture(_source("background_treeLarge.png")), Vector2(i * 340 + 170, 624), 220, Color(0.84, 0.89, 0.85, 0.52))
			for i: int in range(-1, 7):
				_sprite(near, _texture(_source("background_tree.png")), Vector2(i * 470 + 70, 665), 210, Color(0.95, 0.98, 0.94, 0.65))
		"underworld":
			var shape := _texture(_source("backgroundShapes.png"))
			for i: int in range(-1, 4):
				_sprite(far, shape, Vector2(i * 1404 + 702, 710), 480, Color("aec2c8"))
			for i: int in range(-1, 8):
				_sprite(middle, _texture(_source("TileSet.png"), Rect2(96, 32, 32, 16)), Vector2(i * 420 + 200, 640), 80, Color("53756b"))
		"cavern":
			for i: int in range(-1, 6):
				_sprite(far, _texture(_source("background.png")), Vector2(i * 384 + 192, 630), 576, Color("c9bdcf"))
			# Original back-wall silhouette is background only, never fake collision.
			for i: int in range(-1, 4):
				_sprite(middle, _texture(_source("back-walls.png")), Vector2(i * 1024 + 512, 716), 576, Color(1, 1, 1, 0.47))
	_install_generated_background(far, middle, near)

func _install_generated_background(far: Node2D, middle: Node2D, near: Node2D) -> void:
	var sky_path := _art_root() + "background_sky.png"
	if ResourceLoader.exists(sky_path):
		# A single panorama covers the entire camera sweep in far-layer coordinates.
		# No tiled seams, mirrored horizons or same-size tree wallpaper.
		for group: Node2D in [far, middle, near]:
			for child: Node in group.get_children(): child.free()
		var texture := _texture(sky_path)
		var viewport_width := 1280.0
		var scroll_width := maxf(0, float(_layout.bounds.size.x) - viewport_width)
		var required_width := viewport_width + scroll_width * 0.14 + 96.0
		var height := maxf(736.0, required_width / texture.get_width() * texture.get_height())
		_sprite(far, texture, Vector2(640 + scroll_width * 0.14 * 0.5, 736), height)
		if biome_id == "forest":
			# Enclosed tree columns and a distinct, low foreground of fern silhouettes.
			for x: float in [170.0, 1030.0, 1770.0, 2490.0]:
				_background_prop(middle, "tree", Vector2(x, 736), 420, 0.24)
			for x: float in [10.0, 380.0, 930.0, 1440.0, 2120.0, 2590.0]:
				_background_prop(near, "flowers", Vector2(x, 652), 114, 0.37)
		elif biome_id == "gear":
			# Hard gantry / boiler masses, horizontal catwalk spacing, fewer organic details.
			_background_prop(middle, "tree", Vector2(230, 700), 342, 0.26)
			_background_prop(middle, "tree", Vector2(1550, 706), 376, 0.24)
			_background_prop(middle, "tower", Vector2(2450, 704), 320, 0.22)
			_background_prop(near, "tower", Vector2(-15, 684), 236, 0.30)
			_background_prop(near, "tower", Vector2(1880, 686), 224, 0.28)
		else:
			# Open meadow: sparse landmarks leave the distant windmills and rolling ground visible.
			_background_prop(middle, "tower", Vector2(260, 672), 224, 0.22)
			_background_prop(middle, "tree", Vector2(1080, 682), 244, 0.20)
			_background_prop(middle, "tree", Vector2(2050, 684), 256, 0.20)
			_background_prop(near, "tree", Vector2(30, 674), 194, 0.24)
			_background_prop(near, "tower", Vector2(1870, 674), 202, 0.20)
	# Optional distinct far/mid artworks supersede only their own depth group.
	var names: Array[String] = ["far", "mid"]
	var groups: Array[Node2D] = [middle, near]
	for i: int in names.size():
		var path := _art_root() + "background_" + names[i] + ".png"
		if not ResourceLoader.exists(path): continue
		for child: Node in groups[i].get_children(): child.free()
		var texture := _texture(path)
		var factor: float = 0.34 if i == 0 else 0.62
		var width := 1280.0 + maxf(0, float(_layout.bounds.size.x) - 1280.0) * factor + 96.0
		var height := maxf(736, width / texture.get_width() * texture.get_height())
		_sprite(groups[i], texture, Vector2(640 + maxf(0, float(_layout.bounds.size.x) - 1280.0) * factor * 0.5, 736), height)

func _background_prop(parent: Node2D, kind: String, foot: Vector2, height: float, opacity: float) -> void:
	var metadata_path := _art_root() + "chime_props.json"
	var image_path := _art_root() + "chime_props.png"
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(image_path): return
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary: return
	var regions: Dictionary = metadata.get("regions", {})
	if not regions.has(kind): return
	var data: Dictionary = regions[kind]
	var r: Array = data.region
	var tint: Color = _palette()[2]
	tint.a = opacity
	_sprite(parent, _texture(image_path, Rect2(r[0], r[1], r[2], r[3])), foot, height, tint)

func _build_decor() -> void:
	var cells: Dictionary = _layout.cells
	for x: int in range(4, 79):
		var cell := Vector2i(x, 19)
		if not cells.has(cell): continue
		# Use the highest connected ground surface; floating platforms retain clean silhouettes.
		while cells.has(cell + Vector2i.UP): cell += Vector2i.UP
		var point := Vector2(cell) * CELL + Vector2(CELL * 0.5, 0)
		var density := 0.52 if biome_id == "forest" else (0.30 if biome_id == "gear" else 0.38)
		if _in_keepout(point) or _rng.randf() > density: continue
		var flower_roll := _rng.randf()
		if (biome_id != "plains" or style_id in ["basic", "scribble", "cavern"] or flower_roll < 0.45) and _generated_prop(point, "flowers"): continue
		if biome_id != "plains": continue # Missing region source remains missing; never plant grass in a factory.
		var tex: Texture2D
		var height := 28.0
		match style_id:
			"retro":
				tex = _texture(_source("Environment.png"), Rect2(288 + _rng.randi_range(0, 3) * 16, 16, 16, 16))
				height = 24
			"basic":
				tex = _texture(_source("sTileset.png"), Rect2(_rng.randi_range(0, 3) * 16, 96, 16, 16))
				height = 26
			"scribble":
				tex = _texture(_source("tile_grass.png" if x % 3 == 0 else "tile_bush.png"))
				height = 27
			"underworld":
				tex = _texture(_source("TileSet.png"), Rect2(96 + _rng.randi_range(0, 2) * 16, 32, 16, 16))
				height = 30
			"cavern":
				# Native chipped masonry cluster, taken from original transparent tiles layer.
				tex = _texture(_source("tiles.png"), Rect2(320, 16, 16, 32))
				height = 28
		var sprite := _sprite(_decor, tex, point, height)
		if sprite != null:
			_sway.append({"node": sprite, "base": sprite.position, "phase": _rng.randf() * TAU, "type": "grass"})
	# Main landmarks are sparse and rooted on three consecutive real solid cells.
	for anchor_x: int in [19, 39, 59]:
		var foot := Vector2(anchor_x * CELL + 16, 19 * CELL)
		if not _has_support(foot, 70): continue
		if not _generated_prop(foot, "tower" if anchor_x == 39 else "tree") and biome_id == "plains":
			_native_landmark(foot)

func _native_landmark(foot: Vector2) -> void:
	var texture: Texture2D
	var height := 124.0
	match style_id:
		"retro": texture = _texture(_source("Environment.png"), Rect2(0, 96, 48, 48))
		"basic": texture = _texture(_source("sTileset.png"), Rect2(80, 96, 16, 48))
		"scribble": texture = _texture(_source("background_tree.png")); height = 136
		_: return # No invented tree silhouette for packs that contain none.
	var tree := _sprite(_decor, texture, foot, height)
	if tree != null: tree.set_meta("support", "solid cells at " + str(foot))

func _generated_prop(foot: Vector2, kind: String) -> bool:
	var metadata_path := _art_root() + "chime_props.json"
	var image_path := _art_root() + "chime_props.png"
	if not FileAccess.file_exists(metadata_path) or not ResourceLoader.exists(image_path): return false
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if not metadata is Dictionary: return false
	var regions: Dictionary = metadata.get("regions", {})
	if not regions.has(kind): return false
	var data: Dictionary = regions[kind]
	var r: Array = data.region
	var anchor: Array = data.foot
	var height := float(data.get("world_height", 164))
	if kind in ["tree", "tower"] and not _has_support(foot, float(data.get("support_width", 70))): return false
	var texture := _texture(image_path, Rect2(r[0], r[1], r[2], r[3]))
	var pivot := Node2D.new()
	pivot.position = foot
	pivot.name = "Rooted" + biome_id.capitalize() + kind.capitalize()
	_decor.add_child(pivot)
	var sprite := _sprite(pivot, texture, Vector2.ZERO, height)
	if sprite == null:
		pivot.free()
		return false
	var ratio := height / float(r[3])
	sprite.position = -Vector2(anchor[0], anchor[1]) * ratio
	pivot.set_meta("support", "solid-only; foot=" + str(foot))
	pivot.set_meta("kind", kind)
	pivot.set_meta("biome", biome_id)
	pivot.set_meta("source_region", data.region)
	if data.has("light_anchor"):
		var bell: Array = data.light_anchor
		_light_sources.append({"source": pivot, "local": (Vector2(bell[0], bell[1]) - Vector2(anchor[0], anchor[1])) * ratio})
	if kind == "tree" and biome_id != "gear":
		_sway.append({"node": pivot, "base": foot, "phase": _rng.randf() * TAU, "type": "tree"})
	return true

func _has_support(foot: Vector2, width: float) -> bool:
	var y := int(foot.y / CELL)
	for x: int in range(int((foot.x - width * 0.5) / CELL), int((foot.x + width * 0.5) / CELL) + 1):
		if not _layout.cells.has(Vector2i(x, y)) or _layout.cells.has(Vector2i(x, y - 1)): return false
	return true

func _in_keepout(point: Vector2) -> bool:
	for bounds: Rect2 in _layout.keepouts:
		if bounds.grow(12).has_point(point): return true
	return false

func _build_lights() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.6))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 32
	glow.height = 32
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(0.5, 0)
	_glow_texture = glow
	var tint: Color = _palette()[3]
	for i: int in 28:
		var sprite := Sprite2D.new()
		sprite.texture = glow
		sprite.position = Vector2(_rng.randf_range(70, 2510), _rng.randf_range(280, 590))
		sprite.scale = Vector2.ONE * _rng.randf_range(0.13, 0.32)
		sprite.modulate = Color(tint, 0.72 if style_id != "scribble" else 0.36)
		_lights.add_child(sprite)
		_sway.append({"node": sprite, "base": sprite.position, "phase": _rng.randf() * TAU, "type": "mote"})

	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for source: Dictionary in _light_sources:
		var lamp := Sprite2D.new()
		lamp.name = "BellBoundWarmGlow"
		lamp.texture = glow
		lamp.scale = Vector2.ONE * 2.7
		lamp.material = additive
		lamp.modulate = Color(1.0, 0.66, 0.21, 0.34 if style_id != "scribble" else 0.18)
		lamp.set_meta("emitter", "visible bell in rooted tree/tower source PNG")
		_lights.add_child(lamp)
		source["glow"] = lamp
	_update_bound_glows()

func _update_bound_glows() -> void:
	var candidates: Array[Dictionary] = []
	for source: Dictionary in _light_sources:
		var prop: Node2D = source.source
		var glow: Sprite2D = source.glow
		glow.global_position = prop.to_global(source.local)
		glow.visible = false
		var distance := absf(glow.global_position.x - _camera.get_screen_center_position().x) if is_instance_valid(_camera) else 0.0
		if distance < 704.0: candidates.append({"source": source, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	for i: int in mini(2, candidates.size()):
		var source: Dictionary = candidates[i].source
		var glow: Sprite2D = source.glow
		glow.visible = _decor_enabled
		glow.scale = Vector2.ONE * (2.7 + sin(_elapsed * 1.4 + i) * 0.08)

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_camera):
		for layer: Dictionary in _parallax:
			var node: Node2D = layer.node
			node.position = (_camera.get_screen_center_position() - Vector2(640, 360)) * (1.0 - float(layer.factor))
	for item: Dictionary in _sway:
		var node: Node2D = item.node
		var phase := _elapsed + float(item.phase)
		if item.type == "mote":
			node.position = item.base + Vector2(sin(phase * 0.43) * 22, cos(phase * 0.68) * 11)
			node.modulate.a = 0.28 + (sin(phase) + 1) * 0.17
		elif item.type == "grass":
			node.skew = sin(phase * 1.3) * 0.035
		elif item.type == "tree":
			node.rotation = sin(phase * 0.7) * 0.006

	if is_instance_valid(_lights): _update_bound_glows()
