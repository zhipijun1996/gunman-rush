class_name PixelRegionScenery
extends Node2D
## Supported original props. Independent coordinate hash, no gameplay RNG.
const LANDMARKS := preload("res://scripts/art_foundation/pixel_region_landmarks.gd")
const PIXELS := preload("res://assets/pixel_plains/props.svg")
var placements: Array[Dictionary] = []
var protected_regions: Array[Rect2] = []
var supports: Array[Rect2] = []
var clock := 0.0
var presentation_manifest: Dictionary = {}
var compositions: Array[Dictionary] = []

func configure(stage: PlainsRegionStage) -> void:
	placements.clear()
	compositions.clear()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	supports = PlainsRegionScenery.solid_supports(stage)
	protected_regions = PlainsRegionScenery.protection(stage)
	var plan := PixelFormalTerrain.geometry_plan(supports)
	var seed_text := str(stage.generated.manifest.manifest_hash)
	for edge: Vector4 in plan.edges:
		if edge.y!=edge.w or edge.z<=edge.x: continue
		for x: int in range(ceili((edge.x+24)/48)*48,int(edge.z-24),48):
			var roll := posmod((seed_text+":pixel-scenery:"+str(x)+":"+str(edge.y)).hash(),1000)
			if roll>480: continue
			var kind := 0 if roll<220 else 1 if roll<330 else 5 if roll<410 else 4 if roll<455 else 3
			var at := Vector2(x,edge.y)
			var bounds := Rect2(at-Vector2(18,64),Vector2(36,64))
			var valid := true
			for blocked: Rect2 in protected_regions:
				if bounds.grow(6).intersects(blocked): valid=false;break
			# Do not draw through another ledge above the selected support.
			for solid: Rect2 in supports:
				if bounds.grow(-.01).intersects(solid): valid=false;break
			if valid: placements.append({"position":at,"kind":kind,"bounds":bounds})
	_build_landmarks(stage.generated.manifest)
	set_meta("presentation_only",true)

func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	var view := Rect2(camera.get_screen_center_position()-Vector2(800,500),Vector2(1600,1000)) if camera!=null else Rect2(-10000,-10000,20000,20000)
	for item: Dictionary in placements:
		if not view.intersects(item.bounds):continue
		var p: Vector2 = item.position
		var sway := 2*roundf(sin(clock*1.4+p.x*.012)) if int(item.kind) in [0,1,5] else 0.0
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16,24),Vector2(32,24)),Rect2(int(item.kind)*64,80,64,48))
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16-sway,64),Vector2(32,40)),Rect2(int(item.kind)*64,0,64,80))


func _build_landmarks(manifest: Dictionary) -> void:
	var items: Array[Dictionary] = []
	var omitted: Array[Dictionary] = []
	var counts: Dictionary = {}
	for area: Dictionary in manifest.areas:
		var identity := str(area.get("identity", ""))
		if not LANDMARKS.SIZES.has(identity): continue
		if int(counts.get(identity, 0)) >= 2: continue
		var texture: Texture2D = LANDMARKS.texture(identity)
		var origin := Vector2(area.position[0], area.position[1])
		var candidates: Array[Rect2] = []
		for solid: Rect2 in supports:
			if absf(solid.position.y - origin.y) <= 80 and solid.end.x >= origin.x - 600 and solid.position.x <= origin.x + 600:
				candidates.append(solid)
		candidates.sort_custom(func(a: Rect2, b: Rect2): return a.get_center().distance_squared_to(origin) < b.get_center().distance_squared_to(origin))
		var selected: Dictionary = {}
		# Prefer a 2x integer-pixel silhouette; a 1x small prop remains readable
		# when the authored support/protection offers no room for the full size.
		for pixel_scale: int in [2, 1]:
			var size := texture.get_size() * pixel_scale
			for solid: Rect2 in candidates:
				if solid.size.x < size.x + 16: continue
				for x: int in range(ceili(solid.position.x + 8), floori(solid.end.x - size.x - 8) + 1, 8):
					var bounds := Rect2(Vector2(x, solid.position.y - size.y), size)
					if protected_regions.any(func(blocked: Rect2): return bounds.grow(6).intersects(blocked)): continue
					if supports.any(func(other: Rect2): return bounds.grow(-0.01).intersects(other)): continue
					if items.any(func(other: Dictionary): return bounds.grow(12).intersects(Rect2(other.display_bounds[0],other.display_bounds[1],other.display_bounds[2],other.display_bounds[3]))): continue
					selected = {"area_id":str(area.id), "identity":identity, "asset_id":identity,
						"display_bounds":PlainsRegionScenery.rect_values(bounds), "foot":[bounds.get_center().x,bounds.end.y],
						"support":PlainsRegionScenery.rect_values(solid), "scale":pixel_scale,
						"asset_source":"scripts/art_foundation/pixel_region_landmarks.gd", "source_sha256":FileAccess.get_sha256("res://scripts/art_foundation/pixel_region_landmarks.gd"),
						"depth":"supported_pixel_landmark", "collision":false, "standing_edge":false,
						"reason":"actual_area_identity_on_clear_static_solid"}
					break
				if not selected.is_empty(): break
			if not selected.is_empty(): break
		if selected.is_empty():
			omitted.append({"area_id":str(area.id), "identity":identity, "reason":"no_clear_solid_support"})
			continue
		var sprite := Sprite2D.new()
		sprite.name = "PixelLandmark_" + str(area.id)
		sprite.texture = texture
		sprite.centered = false
		sprite.position = Vector2(selected.display_bounds[0], selected.display_bounds[1])
		sprite.scale = Vector2.ONE * int(selected.scale)
		sprite.z_index = -1
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.set_meta("landmark", selected.duplicate(true))
		sprite.set_meta("composition", selected.duplicate(true))
		add_child(sprite)
		items.append(selected)
		compositions.append(selected.duplicate(true))
		counts[identity] = int(counts.get(identity, 0)) + 1
	presentation_manifest = {"version":LANDMARKS.VERSION, "items":items, "omitted":omitted,
		"scope":"original non-colliding pixel identity landmarks; actual supports and protection; no gameplay RNG"}
