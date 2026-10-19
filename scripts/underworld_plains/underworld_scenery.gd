class_name UnderworldScenery
extends Node2D
## Sparse, grounded original Underworld props. Own seed; never touches gameplay RNG.
const BUILD_PATH := "res://assets/underworld_plains/scenery_build.json"
var placements: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var presentation_manifest: Dictionary = {}
var _spec: Dictionary = {}
var _props: Dictionary = {}
var _atlas: Texture2D
var _seed := ""
var _phase := 0.0

func configure(stage: PlainsRegionStage) -> void:
	configure_geometry(PlainsRegionScenery.solid_supports(stage), PlainsRegionScenery.protection(stage), str(stage.generated.manifest.manifest_hash), {"world_bounds": stage.bounds})

func configure_geometry(slabs: Array[Rect2], blocked: Array[Rect2], seed_value: String, _metadata: Dictionary = {}) -> void:
	for child: Node in get_children(): child.free()
	placements.clear()
	omitted.clear()
	supports = slabs.duplicate()
	protected_regions = blocked.duplicate()
	_spec = JSON.parse_string(FileAccess.get_file_as_string(BUILD_PATH)).decor
	_props = JSON.parse_string(FileAccess.get_file_as_string("res://" + str(_spec.regions_metadata))).regions
	_atlas = load("res://" + str(_spec.atlas)) as Texture2D
	_seed = seed_value + ":" + str(_spec.seed_namespace)
	var exposed := PixelFormalTerrain.geometry_plan(supports)
	var zone_counts: Dictionary = {}
	var accent_counts: Dictionary = {}
	var edges: Array[Vector4] = []
	for edge: Vector4 in exposed.edges:
		if is_equal_approx(edge.y, edge.w) and edge.z - edge.x >= 72.0: edges.append(edge)
	# Stable spatial ordering means source-array ordering cannot change composition.
	edges.sort_custom(func(a: Vector4, b: Vector4): return a.x < b.x if not is_equal_approx(a.x, b.x) else a.y < b.y)
	for edge: Vector4 in edges:
		for zone: int in range(floori(edge.x / 1280.0), floori(edge.z / 1280.0) + 1):
			var left := maxf(edge.x, zone * 1280.0)
			var right := minf(edge.z, (zone + 1) * 1280.0)
			var width := right - left
			var roll := posmod((_seed + ":" + str(zone) + ":" + str(edge.y)).hash(), 1000)
			var count := int(zone_counts.get(zone, 0))
			# Macro rhythm is one focal object on selected broad banks, quiet banks
			# between them. Zone windows cross authored module boundaries.
			if width >= 210.0 and roll < 620 and count < int(_spec.max_landmarks_per_1280):
				var kind := "tree" if roll % 3 != 0 else "tower"
				var height := 170.0 if kind == "tree" else 152.0
				var placed := false
				# A bounded set of authored quiet-bank sockets finds legitimate
				# support instead of deleting almost all props after one bad roll.
				for ratio: float in [float(roll % 100) / 100.0,.16,.84,.34,.66,.50]:
					for target_height: float in [height, height * .76]:
						var x := lerpf(left + 100.0, right - 100.0, ratio)
						if _try_place(kind, Vector2(x, edge.y), target_height, edge, 390.0):
							zone_counts[zone] = count + 1
							placed = true
							break
					if placed: break
			if width >= 82.0 and roll % 5 == 0:
				var x := lerpf(left + 38.0, right - 38.0, .36 if roll % 2 == 0 else .72)
				_try_place("flowers", Vector2(x, edge.y), 22.0, edge, 180.0)
			if width >= 84.0 and int(accent_counts.get(zone,0)) < int(_spec.max_small_accents_per_1280):
				for ratio: float in [.23,.77]:
					var x := lerpf(left + 24.0,right - 24.0,ratio)
					if _try_place("grass",Vector2(x,edge.y),18.0,edge,210.0):
						accent_counts[zone] = int(accent_counts.get(zone,0)) + 1
						if int(accent_counts[zone]) >= int(_spec.max_small_accents_per_1280): break
	presentation_manifest = {"schema": "underworld-scenery-runtime-v1", "seed_namespace": _spec.seed_namespace, "independent_seed": _seed, "collision": false, "placements": placements.duplicate(true), "omitted": omitted.duplicate(true), "source": _spec.atlas}
	set_meta("presentation_only", true)

func _ready() -> void:
	z_index = -12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _try_place(kind: String, foot: Vector2, height: float, edge: Vector4, spacing: float) -> bool:
	var region: Dictionary = _props[kind]
	var r: Array = region.region
	var scale_value := height / float(r[3])
	var anchor := Vector2(float(region.foot[0]), float(region.foot[1])) * scale_value
	var size := Vector2(float(r[2]), float(r[3])) * scale_value
	var bounds := Rect2(foot - anchor, size)
	# Conservative whole-source-width support: the complete root fan is over a
	# real exposed static top, rather than checking only a root center point.
	var reason := ""
	if bounds.position.x < edge.x + 8.0 or bounds.end.x > edge.z - 8.0: reason = "root_span_not_supported"
	for blocked: Rect2 in protected_regions:
		if bounds.grow(8.0).intersects(blocked): reason = "gameplay_keepout"; break
	var aerial := Rect2(bounds.position, Vector2(bounds.size.x, maxf(0, foot.y - bounds.position.y - .5)))
	for solid: Rect2 in supports:
		if aerial.intersects(solid): reason = "overhead_or_side_solid"; break
	for prior: Dictionary in placements:
		var previous: Vector2 = prior.position
		if previous.distance_to(foot) < spacing: reason = "quiet_spacing"; break
	if not reason.is_empty():
		omitted.append({"kind": kind, "position": [foot.x, foot.y], "reason": reason})
		return false
	var texture := AtlasTexture.new()
	texture.atlas = load("res://"+str(region.atlas)) as Texture2D if region.has("atlas") else _atlas
	texture.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	texture.filter_clip = true
	var sprite := Sprite2D.new()
	sprite.name = "Underworld_" + kind + str(placements.size())
	sprite.centered = false
	sprite.texture = texture
	sprite.position = bounds.position
	sprite.scale = Vector2.ONE * scale_value
	add_child(sprite)
	placements.append({"kind": kind, "position": foot, "bounds": bounds, "support_edge": edge, "root_span": [bounds.position.x, bounds.end.x], "source_region": r, "scale": scale_value, "node": sprite.name, "collision": false})
	return true

func _process(delta: float) -> void:
	_phase += delta
	# No sprite sway: moving roots would break support. Only tiny atmospheric
	# motes move, below the brightness of functional bells and danger tells.
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	var center := camera.get_screen_center_position()
	var size := get_viewport_rect().size / camera.zoom
	for i: int in 12:
		var p := center - size * .5 + Vector2(fposmod(i * 173.0 + _phase * 7.0, size.x), size.y * (.38 + .05 * (i % 7)) + sin(_phase * .7 + i) * 6.0)
		draw_rect(Rect2(p.snapped(Vector2(2, 2)), Vector2(2, 2)), Color(.63, .69, .49, .25))
