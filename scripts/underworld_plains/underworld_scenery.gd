class_name UnderworldScenery
extends Node2D
## Sparse, grounded original Underworld props. Own seed; never touches gameplay RNG.
const BUILD_PATH := "res://assets/underworld_plains/scenery_build.json"
const CONTACT := preload("res://scripts/underworld_plains/grounded_contact.gd")
var placements: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var presentation_manifest: Dictionary = {}
var manifest: Dictionary = {}
var identity_items: Array[Dictionary] = []
var _source_hashes: Dictionary = {}
var _spec: Dictionary = {}
var _props: Dictionary = {}
var _atlas: Texture2D
var _seed := ""
var _phase := 0.0

func configure(value: Variant, slabs: Array[Rect2] = [], blocked: Array[Rect2] = []) -> void:
	if value is PlainsRegionStage:
		var stage := value as PlainsRegionStage
		manifest = stage.generated.manifest
		configure_geometry(PlainsRegionScenery.solid_supports(stage), PlainsRegionScenery.protection(stage), str(manifest.manifest_hash), {"world_bounds": stage.bounds,"areas":manifest.areas})
	elif value is Dictionary:
		manifest = value
		configure_geometry(slabs,blocked,str(manifest.get("manifest_hash","manifest")),{"areas":manifest.get("areas",[])})

func configure_geometry(slabs: Array[Rect2], blocked: Array[Rect2], seed_value: String, _metadata: Dictionary = {}) -> void:
	for child: Node in get_children(): child.free()
	placements.clear()
	omitted.clear()
	identity_items.clear()
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
	_place_identities(edges,_metadata.get("areas",[]))
	if _props.has("well") and not _metadata.get("areas",[]).is_empty():
		var composition := UnderworldLocalComposition.new()
		composition.name="PlainsRegionComposition"
		add_child(composition)
		composition.configure(_metadata.areas,_props.well,protected_regions,supports,_spec.local_composition)
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
			if width >= 84.0 and int(accent_counts.get(zone,0)) < int(_spec.max_small_accents_per_1280):
				# Small rooted clusters enrich quiet banks without adding tall
				# landmarks or covering playable rims, signals or landing routes.
				for ratio: float in [.14,.38,.62,.86]:
					var x := lerpf(left + 24.0,right - 24.0,ratio)
					var accent_roll := posmod((_seed+":accent:"+str(zone)+":"+str(edge.y)+":"+str(ratio)).hash(),100)
					var kind := "flowers" if accent_roll % 4 == 0 else "grass"
					var height := 16.0 + 2.0 * (accent_roll % 3) if kind == "flowers" else 12.0 + 3.0 * (accent_roll % 3)
					if _try_place(kind,Vector2(x,edge.y),height,edge,82.0):
						accent_counts[zone] = int(accent_counts.get(zone,0)) + 1
						if int(accent_counts[zone]) >= int(_spec.max_small_accents_per_1280): break
	presentation_manifest = {"schema": "underworld-scenery-runtime-v1", "seed_namespace": _spec.seed_namespace, "independent_seed": _seed, "collision": false, "items":identity_items.duplicate(true), "placements": placements.duplicate(true), "omitted": omitted.duplicate(true), "source": _spec.atlas}
	set_meta("presentation_only", true)

func _ready() -> void:
	z_index = -12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _place_identities(edges: Array[Vector4], areas: Array) -> void:
	if not _spec.has("identity_landmarks"): return
	for identity: String in _spec.identity_landmarks:
		var entry: Dictionary = _spec.identity_landmarks[identity]
		var candidates: Array[Dictionary] = []
		for area: Dictionary in areas:
			if str(area.get("identity",""))!=identity: continue
			var at := Vector2(float(area.position[0]),float(area.position[1]))
			for edge: Vector4 in edges:
				if absf(edge.y-at.y)>224.0: continue
				var center := Vector2(clampf(at.x,edge.x,edge.z),edge.y)
				if center.distance_to(at)>1000.0: continue
				candidates.append({"edge":edge,"area":area,"at":at,"score":center.distance_to(at)})
		candidates.sort_custom(func(a:Dictionary,b:Dictionary):return float(a.score)<float(b.score))
		var placed := false
		for candidate: Dictionary in candidates:
			var edge: Vector4 = candidate.edge
			var area: Dictionary = candidate.area
			for height_value: Variant in entry.heights:
				var height := float(height_value)
				for x: float in _identity_x_candidates(str(entry.kind),height,edge,float(area.position[0])):
					if absf(x-float(area.position[0]))>1000.0: continue
					if _try_place(str(entry.kind),Vector2(x,edge.y),height,edge,260.0,{"identity":identity,"area_id":str(area.id)}): placed=true;break
				if placed: break
			if placed: break
		if not placed: omitted.append({"identity":identity,"kind":entry.kind,"reason":"no_clear_actual_static_root_span_in_identity_area","candidate_count":candidates.size()})

func _identity_x_candidates(kind: String, height: float, edge: Vector4, desired: float) -> Array[float]:
	var region: Dictionary = _props[kind]
	var scale_value := height / float(region.foot[1])
	var left := float(region.foot[0]) * scale_value
	var right := (float(region.region[2])-float(region.foot[0])) * scale_value
	# Half a pixel reserves the shared1wu origin snap without relaxing the
	# original whole-object eight-unit support/functional protection margin.
	var minimum := edge.x+8.5+left
	var maximum := edge.z-8.5-right
	if maximum<minimum: return []
	var values: Array[float] = [minimum,maximum,clampf(desired,minimum,maximum),(minimum+maximum)*.5]
	# Exact interval boundaries find narrow but genuinely legal bank sockets.
	# A fixed 33-point scan can miss a 1-world-unit admissible interval.
	for keepout: Rect2 in protected_regions:
		var inset:=CONTACT.depth(kind)
		if keepout.end.y<edge.y-height+inset-8.5 or keepout.position.y>edge.y+inset+8.5: continue
		for x: float in [keepout.position.x-8.51-right,keepout.end.x+8.51+left]:
			if x>=minimum and x<=maximum: values.append(x)
	values.sort_custom(func(a:float,b:float):return absf(a-desired)<absf(b-desired))
	return values

func _try_place(kind: String, foot: Vector2, height: float, edge: Vector4, spacing: float, identity: Dictionary = {}) -> bool:
	var region: Dictionary = _props[kind]
	var r: Array = region.region.duplicate()
	# Exclude only declared transparent below-root padding. A shallow visual
	# inset then plants this measured root into the fine terrain grass/soil;
	# the logical support foot remains on the real exposed collision surface.
	if not identity.is_empty(): r[3] = int(region.foot[1])
	var scale_value := height / float(r[3])
	var anchor := Vector2(float(region.foot[0]), float(region.foot[1])) * scale_value
	var size := Vector2(float(r[2]), float(r[3])) * scale_value
	var contact_depth:=CONTACT.depth(kind)
	var bounds := Rect2(CONTACT.origin(foot,Vector2(region.foot[0],region.foot[1]),scale_value,contact_depth),size)
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
	var render_root:=sprite.position+anchor
	sprite.set_meta("grounded_surface_foot",foot)
	sprite.set_meta("grounded_render_root",render_root)
	sprite.set_meta("grounded_inset_wu",render_root.y-foot.y)
	add_child(sprite)
	if not identity.is_empty():
		var source := str(region.get("atlas",_spec.atlas))
		if not _source_hashes.has(source): _source_hashes[source] = FileAccess.get_sha256("res://"+source)
		var item := {"identity":identity.identity,"area_id":identity.area_id,"asset_id":kind,"asset_source":source,"source_sha256":_source_hashes[source],"display_bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"foot":[foot.x,foot.y],"source_foot":region.foot.duplicate(),"render_root":[render_root.x,render_root.y],"ground_inset_wu":render_root.y-foot.y,"support":[edge.x,edge.y,edge.z-edge.x,0.0],"depth":"grounded_noninteractive_local_landmark","collision":false,"standing_edge":false,"node":sprite.name}
		sprite.set_meta("landmark",item.duplicate(true))
		identity_items.append(item)
	placements.append({"kind": kind, "position": foot, "render_root":render_root,"ground_inset_wu":render_root.y-foot.y,"bounds": bounds, "support_edge": edge, "root_span": [bounds.position.x, bounds.end.x], "source_region": r, "scale": scale_value, "node": sprite.name, "collision": false})
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
		draw_rect(Rect2(p.snapped(Vector2.ONE),Vector2.ONE), Color(.63, .69, .49, .25))
