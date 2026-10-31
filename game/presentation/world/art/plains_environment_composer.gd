class_name PlainsEnvironmentComposer
extends Node2D
## Candidate-only environment consumer. Shared plan owns geometry and anchors;
## the measured art catalog owns pixels, scale and attachment sockets.
const DEFAULT_CATALOG := "res://resources/visual_development/p1_environment_assets.json"
const TERRAIN := preload("res://game/presentation/world/art/plains_environment_terrain.gd")
var _stage: Node2D
var _plan: Dictionary
var _catalog: Dictionary
var _layers: Array[Dictionary] = []
var _old_background: CanvasLayer
var _background_was_visible := false
var _facts: Dictionary = {}
var _presented: Array[String] = []
var _sky: ColorRect

func install(stage: Node2D, plan: Dictionary) -> void:
	_stage = stage
	_plan = plan
	var path := str(plan.get("assets_catalog", DEFAULT_CATALOG))
	_facts = {"plan_contract_sha256":plan.get("contract_sha256", ""), "seed":plan.get("seed", ""), "catalog_path":path, "production_pool":false, "terrain":[], "objects":[], "layers":[], "omitted":[], "renderer_writes_collision":false, "shared_geometry_revised":true, "rng_used":false}
	if not FileAccess.file_exists(path):
		_facts.omitted.append({"reason":"measured_environment_catalog_missing", "path":path})
		publish_facts()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_facts.omitted.append({"reason":"invalid_environment_catalog"})
		publish_facts()
		return
	_catalog = parsed
	_facts["catalog_sha256"] = FileAccess.get_sha256(path)
	_build_background()
	_build_terrain()
	_build_objects()
	_build_layers()
	_retire_presented_fallbacks()
	publish_facts()

func _build_background() -> void:
	var app := _stage.get_parent()
	if app != null:
		_old_background = app.get_node_or_null("PlainsBackground") as CanvasLayer
	if _old_background != null:
		_background_was_visible = _old_background.visible
		_old_background.hide()
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -95
	add_child(sky_layer)
	_sky = ColorRect.new()
	_sky.name = "PaperSky"
	_sky.color = Color(str(_catalog.get("sky_color", "e9eeeb")))
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(_sky)
	# CanvasLayer has no Control parent; use the actual viewport, not a baked HUD size.
	_resize_sky()
	get_viewport().size_changed.connect(_resize_sky)

func _resize_sky() -> void:
	if is_instance_valid(_sky):
		_sky.size = get_viewport_rect().size

func _build_terrain() -> void:
	var spec: Dictionary = _catalog.get("terrain", {})
	var sections: Array = spec.get("sections", [])
	if sections.is_empty():
		_facts.omitted.append({"reason":"terrain_family_missing"})
		return
	var quiet := Color(str(spec.get("quiet_color", "d6d3bd")))
	for solid: Dictionary in _plan.get("solid_polygons", []):
		if str(solid.get("material", "")) in ["bridge", "wood", "timber", "postal_bridge", "bridge_abutment"]:
			continue
		var visual_solid := solid.duplicate(true)
		visual_solid["paint_grass"] = str(solid.get("material", "")) != "masonry"
		for surface: Dictionary in _plan.get("surfaces", []):
			if str(surface.solid_id) == str(solid.id) and str(surface.get("kind", "")) in ["terrain", "support"]:
				visual_solid["paint_top"] = surface.get("points", [])
		var node := TERRAIN.build(visual_solid, sections, quiet) as Node2D
		if node == null:
			_facts.omitted.append({"solid_id":solid.id, "reason":"natural_polygon_terrain_refused"})
			continue
		add_child(node)
		var receipt: Dictionary = node.get_meta("environment_terrain")
		_facts.terrain.append(receipt)
		if not receipt.pages.is_empty() and not bool(receipt.source_exhausted):
			_presented.append(str(solid.id))
		_build_side_assets(visual_solid, spec)

func _build_side_assets(solid: Dictionary, terrain: Dictionary) -> void:
	var outline := TERRAIN.points(solid.points)
	var top: Array = solid.get("paint_top", [])
	var expanded := Geometry2D.offset_polygon(outline, 16.0)
	var envelope: PackedVector2Array = expanded[0] if not expanded.is_empty() else outline
	for spec: Dictionary in terrain.get("side_assets", []):
		var side := str(spec.side)
		var world := _pair(top[0] if side == "left" else top[-1])
		var texture := _texture(spec)
		if texture == null:
			continue
		var factor := float(spec.world_height) / texture.get_height()
		var pivot := _pair(spec.pivot_px)
		var origin := world - pivot * factor
		var profile: Array = spec.outer_profile
		var direction := 1.0 if side == "left" else -1.0
		var data := TERRAIN.mesh_data()
		var atlas := texture as AtlasTexture
		var mesh_texture: Texture2D = atlas.atlas if atlas != null else texture
		for row: int in profile.size() - 1:
			var a: Array = profile[row]
			var b: Array = profile[row + 1]
			var strips := maxi(1, ceili((float(b[0]) - float(a[0])) * factor / 20.0))
			for strip: int in strips:
				var y0 := lerpf(float(a[0]), float(b[0]), float(strip) / strips)
				var y1 := lerpf(float(a[0]), float(b[0]), float(strip + 1) / strips)
				var x0 := _profile_x(profile, y0)
				var x1 := _profile_x(profile, y1)
				var exterior := -16.0 / factor
				var interior := 150.0 / factor
				var source_quad := PackedVector2Array([Vector2(x0 + direction * exterior, y0), Vector2(x0 + direction * interior, y0), Vector2(x1 + direction * interior, y1), Vector2(x1 + direction * exterior, y1)])
				var quad := PackedVector2Array()
				for pixel: Vector2 in source_quad:
					quad.append(origin + pixel * factor)
				for clipped: PackedVector2Array in Geometry2D.intersect_polygons(quad, envelope):
					var base: int = data.vertices.size()
					for point: Vector2 in clipped:
						var pixel := (point - origin) / factor
						var inward := (pixel.x - _profile_x(profile, pixel.y)) * direction * factor
						var depth := point.y - TERRAIN.surface_y(outline, {"world_top_polyline":top}, point.x)
						var opacity := 1.0 - smoothstep(60.0, 150.0, inward)
						# The complete original turn now owns its shoulder from the
						# true standing seam, replacing the withdrawn finite top cap.
						opacity *= smoothstep(-1.0, 1.0, depth)
						data.vertices.append(point)
						data.uv.append((atlas.region.position + pixel) / mesh_texture.get_size() if atlas != null else pixel / texture.get_size())
						data.colors.append(Color(1, 1, 1, opacity))
					for index: int in Geometry2D.triangulate_polygon(clipped):
						data.indices.append(base + index)
		TERRAIN.install_mesh(self, data, mesh_texture, -1, "FiniteNaturalTurn_" + str(solid.id) + "_" + side)
		if not data.indices.is_empty():
			_facts.objects.append({"role":"terrain_turn", "solid_id":solid.id, "side":side, "world_anchor":[world.x, world.y], "source":spec.texture, "source_region":spec.region, "source_outer_profile":profile, "uniform_scale":factor, "source_sha256":FileAccess.get_sha256(str(spec.texture)), "ribbon_world_width":150.0, "visual_envelope_foliage_margin_world":16.0, "whole_wall_overlay":false, "node_path":str(get_child(-1).get_path())})

func _profile_x(profile: Array, y: float) -> float:
	for index: int in profile.size() - 1:
		var a: Array = profile[index]
		var b: Array = profile[index + 1]
		if y <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((y - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0, 1))
	return float(profile[-1][1])

func _build_objects() -> void:
	var objects: Dictionary = _catalog.get("objects", {})
	var bridges: Array[String] = []
	for surface: Dictionary in _plan.get("surfaces", []):
		if str(surface.get("semantic", "")) != "bridge" and str(surface.get("kind", "")) != "bridge":
			continue
		if str(surface.solid_id) in bridges:
			continue
		bridges.append(str(surface.solid_id))
		_build_bridge(surface, objects.get("bridge", {}))
	for attachment: Dictionary in _plan.get("attachments", []):
		var role := str(attachment.get("role", ""))
		if role == "bridge_abutment":
			continue
		if not objects.has(role):
			_facts.omitted.append({"attachment_id":attachment.id, "role":role, "reason":"matching_complete_asset_missing"})
			continue
		var spec: Dictionary = objects[role]
		var texture := _texture(spec)
		if texture == null:
			continue
		var factor := float(spec.get("world_height", texture.get_height())) / texture.get_height()
		var anchor := _pair(attachment.position)
		var foundation := _foundation_facts(spec, attachment, factor)
		if not bool(foundation.ok):
			_facts.omitted.append({"attachment_id":attachment.id, "reason":"measured_foundation_feet_not_supported", "foundation":foundation})
			continue
		var sprite := _complete_object(spec, texture, anchor, factor, int(attachment.get("layer", -4)))
		sprite.name = "Environment_" + str(attachment.id)
		add_child(sprite)
		_facts.objects.append({"attachment_id":attachment.id, "role":role, "surface_id":attachment.get("surface_id", ""), "world_anchor":attachment.position, "uniform_scale":factor, "source":spec.texture, "source_sha256":FileAccess.get_sha256(str(spec.texture)), "source_selection_polygon":spec.get("source_polygon", []), "foundation_px":spec.get("foundation_px", []), "foundation":foundation, "node_path":str(sprite.get_path())})

func _foundation_facts(spec: Dictionary, attachment: Dictionary, factor: float) -> Dictionary:
	if not bool(spec.get("require_all_feet_supported", false)):
		return {"ok":true, "scope":"single declared root anchor; multiple feet not claimed"}
	var line := PackedVector2Array()
	for surface: Dictionary in _plan.get("surfaces", []):
		if str(surface.id) == str(attachment.surface_id):
			line = TERRAIN.points(surface.points)
	var measurements: Array[Dictionary] = []
	var ok := line.size() >= 2
	for pixel: Array in spec.get("foundation_px", []):
		var world := _pair(attachment.position) + (_pair(pixel) - _pair(spec.pivot_px)) * factor
		var error := INF
		for index: int in line.size() - 1:
			var a := line[index]
			var b := line[index + 1]
			if world.x >= minf(a.x, b.x) and world.x <= maxf(a.x, b.x) and absf(b.x - a.x) > 0.001:
				var y := lerpf(a.y, b.y, (world.x - a.x) / (b.x - a.x))
				error = minf(error, absf(world.y - y))
		var supported := error <= float(spec.foot_tolerance_world)
		ok = ok and supported
		measurements.append({"source_px":pixel, "world":[world.x, world.y], "surface_error_world":error if is_finite(error) else -1.0, "supported":supported})
	return {"ok":ok, "scope":"all measured foundation feet against exact shared standing surface", "surface_id":attachment.surface_id, "tolerance_world":spec.foot_tolerance_world, "feet":measurements}

func _complete_object(spec: Dictionary, texture: Texture2D, anchor: Vector2, factor: float, order: int) -> Node2D:
	if not spec.has("source_polygon"):
		return _sprite(spec, texture, anchor, factor, order)
	# A sheet can interleave a roof and crown in x while leaving a genuine
	# transparent winding gap. Select each whole object through that gap;
	# no pixel repainting, baked background, or neighbouring leaf crop.
	var selection := TERRAIN.points(spec.source_polygon)
	var pivot := _pair(spec.get("pivot_px", [0, 0]))
	var data := TERRAIN.mesh_data()
	for point: Vector2 in selection:
		data.vertices.append(point - pivot)
		data.uv.append(point / texture.get_size())
		data.colors.append(Color.WHITE)
	for index: int in Geometry2D.triangulate_polygon(selection):
		data.indices.append(index)
	var root := Node2D.new()
	root.position = anchor
	root.scale = Vector2.ONE * factor
	TERRAIN.install_mesh(root, data, texture, order, "CompletePaintedObject")
	return root

func _build_bridge(surface: Dictionary, spec: Dictionary) -> void:
	var raw: Array = surface.get("points", [])
	if spec.is_empty() or raw.size() < 2:
		_facts.omitted.append({"surface_id":surface.id, "reason":"complete_bridge_asset_or_resolved_surface_missing"})
		return
	var texture := _texture(spec)
	if texture == null:
		return
	var a := _pair(raw[0])
	var b := _pair(raw[-1])
	var source_a := _pair(spec.get("deck_left_px", [0, 0]))
	var source_b := _pair(spec.get("deck_right_px", [0, 0]))
	var span := source_a.distance_to(source_b)
	if span < 1.0:
		_facts.omitted.append({"surface_id":surface.id, "reason":"bridge_deck_sockets_uncalibrated"})
		return
	var factor := a.distance_to(b) / span
	var rotation_value := (b - a).angle() - (source_b - source_a).angle()
	var transform := Transform2D(rotation_value, Vector2.ONE * factor, 0.0, a)
	var deck_profile: Array = spec.get("deck_profile_px", [spec.get("deck_left_px", [0, 0]), spec.get("deck_right_px", [0, 0])])
	var expected := PackedVector2Array()
	for pixel: Array in deck_profile:
		expected.append(transform * (_pair(pixel) - source_a))
	for point: Array in raw:
		if _distance_to_line(_pair(point), expected) > 1.5:
			_facts.omitted.append({"surface_id":surface.id, "reason":"bridge_surface_differs_from_uniform_source_deck", "world_point":point})
			return
	if spec.has("world_span_range"):
		var limits: Array = spec.world_span_range
		if a.distance_to(b) < float(limits[0]) or a.distance_to(b) > float(limits[1]):
			_facts.omitted.append({"surface_id":surface.id, "reason":"bridge_outside_declared_discrete_span"})
			return
	var sprite := Sprite2D.new()
	sprite.name = "CompletePostalBridge_" + str(surface.solid_id)
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -source_a
	sprite.transform = transform
	sprite.z_as_relative = false
	sprite.z_index = -1
	add_child(sprite)
	_presented.append(str(surface.solid_id))
	for solid: Dictionary in _plan.get("solid_polygons", []):
		if str(solid.id) in ["postal_abutment_west", "postal_abutment_east"] and str(solid.get("material", "")) == "bridge_abutment":
			_presented.append(str(solid.id))
	_facts.objects.append({"role":"bridge", "surface_id":surface.id, "world_sockets":[raw[0], raw[-1]], "source_sockets":[spec.deck_left_px, spec.deck_right_px], "uniform_scale":factor, "rotation":rotation_value, "whole_object_stretched":false, "source":spec.texture, "source_sha256":FileAccess.get_sha256(str(spec.texture)), "node_path":str(sprite.get_path())})

func _distance_to_line(point: Vector2, line: PackedVector2Array) -> float:
	var result := INF
	for index: int in line.size() - 1:
		result = minf(result, point.distance_to(Geometry2D.get_closest_point_to_segment(point, line[index], line[index + 1])))
	return result

func _retire_presented_fallbacks() -> void:
	var assembler := _stage.get("assembler") as Node
	if assembler == null:
		return
	var modules: Array = assembler.get("modules")
	for module: Node2D in modules:
		if module.get("presented_solid_ids") != null:
			module.set("presented_solid_ids", _presented.duplicate())
			module.queue_redraw()
	_facts["presented_solid_ids"] = _presented.duplicate()

func _build_layers() -> void:
	for spec: Dictionary in _catalog.get("layers", []):
		var texture := _texture(spec)
		if texture == null:
			continue
		var anchor := _layer_anchor(str(spec.get("anchor_id", "")))
		if anchor.is_empty():
			_facts.omitted.append({"layer_id":spec.get("id", ""), "reason":"shared_layer_anchor_missing"})
			continue
		var world := _pair(anchor.position)
		var factor := float(spec.get("world_width", texture.get_width())) / texture.get_width()
		var depth := float(spec.get("depth_factor", 1.0))
		var sprite := _sprite(spec, texture, world, factor, int(spec.get("z_index", anchor.get("layer", -30))))
		sprite.name = "WorldLayer_" + str(spec.get("id", "painted"))
		add_child(sprite)
		_layers.append({"node":sprite, "base_position":world, "reference":_pair(spec.get("camera_reference", anchor.position)), "depth_factor":depth})
		_facts.layers.append({"id":spec.get("id", ""), "anchor_id":anchor.id, "anchor_world":anchor.position, "depth_factor":depth, "uniform_scale":factor, "source":spec.texture, "source_sha256":FileAccess.get_sha256(str(spec.texture)), "node_path":str(sprite.get_path()), "mapping":"world anchor + camera delta * (1-depth), no displacement clamp or reset"})

func _layer_anchor(id: String) -> Dictionary:
	for place: Dictionary in _plan.get("places", []):
		for anchor: Dictionary in place.get("layer_anchors", []):
			if str(anchor.id) == id:
				return anchor
	return {}

func _texture(spec: Dictionary) -> Texture2D:
	var path := str(spec.get("texture", ""))
	var result := load(path) as Texture2D if ResourceLoader.exists(path) else null
	if result == null:
		_facts.omitted.append({"reason":"source_texture_missing", "source":path})
		return null
	if spec.has("region"):
		var r: Array = spec.region
		var atlas := AtlasTexture.new()
		atlas.atlas = result
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		atlas.filter_clip = true
		return atlas
	return result

func _sprite(spec: Dictionary, texture: Texture2D, anchor: Vector2, factor: float, order: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.offset = -_pair(spec.get("pivot_px", [0, 0]))
	sprite.position = anchor
	sprite.scale = Vector2.ONE * factor
	sprite.z_as_relative = false
	sprite.z_index = order
	sprite.modulate.a = float(spec.get("opacity", 1.0))
	return sprite

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var center := camera.get_screen_center_position()
	for layer: Dictionary in _layers:
		var sprite: Sprite2D = layer.node
		sprite.position = (layer.base_position as Vector2) + (center - (layer.reference as Vector2)) * (1.0 - float(layer.depth_factor))

func _exit_tree() -> void:
	if is_instance_valid(_old_background):
		_old_background.visible = _background_was_visible

func publish_facts() -> void:
	set_meta("environment_composition", _facts)
	if is_instance_valid(_stage):
		_stage.set_meta("environment_composition", _facts)

func measured_nodes() -> Dictionary:
	return _facts.duplicate(true)

static func _pair(raw: Array) -> Vector2:
	return Vector2(raw[0], raw[1])
