class_name PlainsRegionComposition
extends Node2D
## Low-contrast local middle distance, deliberately behind gameplay silhouettes.
## No collision, grass standing edge or gameplay authority in this subtree.
const ROCK := preload("res://assets/plains_v8/painted_limestone_material.png")
const WOOD := preload("res://assets/plains_v3/terrain/brass_wood_bridge.png")
# Complete declared ivy Atlas:162x374; top alpha>=128 spans x68..73.
const IVY_TOP_ANCHOR := Vector2(70.5,0)
const IVY_BURY := 6.0
const IVY_MAX_DISTANCE := 360.0
const IVY_MAX_CANDIDATES := 16
var hanging_ivy: Array[Dictionary] = []
var ivy_omitted: Array[Dictionary] = []
var _stage: PlainsRegionStage
var compositions: Array[Dictionary] = []
var manifest: Dictionary
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var landscape: PlainsSemanticLandscape
var enabled_identities: Array[String] = ["windmill_plateau", "creek_well", "clock_court", "repair_gallery"]
func configure(recorded: Dictionary, slabs: Array[Rect2] = [], blocked: Array[Rect2] = []) -> void:
	manifest = recorded
	supports = slabs.duplicate()
	protected_regions = blocked.duplicate()
func _ready() -> void:
	z_index = -5
	var stage := get_parent().get_parent() as PlainsRegionStage
	_stage=stage
	if stage != null:
		landscape = PlainsSemanticLandscape.new()
		landscape.name = "DirectedSemanticLandscape"
		landscape.configure(stage, supports, protected_regions)
		add_child(landscape)
	if stage != null and "--legacy-waterworks-contract" not in OS.get_cmdline_user_args():
		var connected := PlainsConnectedLandscape.new()
		connected.name = "ConnectedLandscape"
		connected.configure(stage, protected_regions)
		add_child(connected)
	if stage != null and "--legacy-waterworks-contract" in OS.get_cmdline_user_args() and not manifest.get("creek_discovery", {}).is_empty():
		var visual_space := PlainsVisualSpace.new()
		visual_space.name = "CreekWaterworksSpace"
		visual_space.configure(stage)
		add_child(visual_space)
	if stage != null and "--legacy-waterworks-contract" not in OS.get_cmdline_user_args():
		var observer := PlainsLandscapeObserver.new()
		observer.name = "ActualLandscapeObserver"
		observer.configure(stage, landscape)
		add_child(observer)
		var app := stage.get_parent() as DemoApp
		if app != null:
			var background := app.get_node_or_null("PlainsBackground") as PlainsBackground
			if background != null: background.use_region_layers()
	var selected_camp := str(manifest.get("creek_discovery", {}).get("camp", ""))
	for area: Dictionary in manifest.areas:
		var identity := str(area.get("identity",""))
		if identity not in enabled_identities: continue
		# Retire old local props only after an actual valid replacement exists.
		# A missing/rejected family leaves the last playable presentation intact.
		if is_instance_valid(landscape) and landscape.replaces_area(str(area.id)):
			continue
		var origin := Vector2(area.position[0],area.position[1])
		# Existing painted series, placed in a visibly receding local layer.
		# These roots extend behind the actual foreground rock, never make ledges.
		if identity == "clock_court":
			_backdrop(area, "ruin_arch", origin+Vector2(205,165), 360, Color(.62,.71,.67,.42))
		elif identity == "repair_gallery" and str(area.id) == selected_camp:
			# This selected return view exposed the old cropped windmill bottom.
			# Omit only that unsuitable decorative backdrop; actual merchant stays.
			continue
		elif identity == "repair_gallery":
			_backdrop(area, "windmill", origin+Vector2(-30,140), 280, Color(.62,.63,.49,.50))
			_backdrop(area, "banner", origin+Vector2(-200,48), 215, Color(.65,.65,.53,.53))
			_backdrop(area, "ivy", origin+Vector2(55,-10), 130, Color(.48,.65,.51,.42))
		elif identity == "creek_well":
			_backdrop(area, "ivy", origin+Vector2(-250,-40), 205, Color(.42,.62,.56,.33))

func _backdrop(area: Dictionary, id: String, foot: Vector2, height: float, tint: Color) -> void:
	if id=="ivy":
		_hanging_ivy(area,foot-Vector2(0,height),height,tint)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Distant_"+str(area.id)+"_"+id
	sprite.texture = PlainsV3Assets.texture("decor.json",id)
	if id == "windmill" and area.identity == "repair_gallery":
		var cropped := (sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		cropped.region = Rect2(cropped.region.position+Vector2(0,210),Vector2(460,380))
		sprite.texture = cropped
	if id == "ruin_arch":
		var cropped := (sprite.texture as AtlasTexture).duplicate() as AtlasTexture
		cropped.region = cropped.region.grow_individual(-12,0,-12,0)
		sprite.texture = cropped
	var scale_value := height/sprite.texture.get_height()
	sprite.scale = Vector2.ONE*scale_value
	sprite.position = foot-Vector2(0,height*.5)
	sprite.modulate = tint
	sprite.set_meta("composition",{"area_id":area.id,"identity":area.identity,"depth":"distant_local_architecture","asset_source":"assets/plains_v3/decor.png","source_sha256":FileAccess.get_sha256("res://assets/plains_v3/decor.png"),"asset_id":id,"collision":false,"standing_edge":false,"atlas_crop_inset_x":12 if id=="ruin_arch" else 0})
	compositions.append(sprite.get_meta("composition"))
	add_child(sprite)


func ivy_surfaces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(_stage): return result
	for module: PlatformingModule in _stage.assembler.modules:
		for index: int in module.definition.platforms.size():
			var body := module.get_node_or_null("Platform"+str(index)) as StaticBody2D
			if body==null or not body.is_inside_tree() or absf(body.global_rotation)>0.001: continue
			var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape==null or shape.disabled or not shape.shape is RectangleShape2D: continue
			result.append({"body":body,"bounds":PlainsLandscapeObserver.shape_bounds(body),"one_way":shape.one_way_collision})
	return result

func fixed_ivy_obstacles(node: Node) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if node is StaticBody2D:
		var body := node as StaticBody2D
		for child: Node in body.get_children():
			if child is CollisionShape2D and not child.disabled and child.shape is RectangleShape2D:
				result.append(child.global_transform*Rect2(-(child.shape as RectangleShape2D).size*.5,(child.shape as RectangleShape2D).size))
	for child: Node in node.get_children(): result.append_array(fixed_ivy_obstacles(child))
	return result

func plan_hanging_ivy(surfaces: Array[Dictionary], obstacles: Array[Rect2], desired: Vector2, height: float) -> Dictionary:
	var texture := PlainsV3Assets.texture("decor.json","ivy")
	var factor := height/texture.get_height()
	var left := IVY_TOP_ANCHOR.x*factor
	var right := (texture.get_width()-IVY_TOP_ANCHOR.x)*factor
	var candidates: Array[Dictionary] = []
	for surface: Dictionary in surfaces:
		var bounds: Rect2 = surface.bounds
		if bounds.size.x<left+right+12.0: continue
		var anchor := Vector2(clampf(desired.x,bounds.position.x+left+6.0,bounds.end.x-right-6.0),bounds.end.y-IVY_BURY)
		var distance := desired.distance_to(anchor)
		if distance<=IVY_MAX_DISTANCE: candidates.append({"surface":surface,"anchor":anchor,"distance":distance})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return str(a.surface.body.get_path())<str(b.surface.body.get_path()) if is_equal_approx(a.distance,b.distance) else float(a.distance)<float(b.distance))
	var rejected: Array[String] = []
	for index: int in mini(IVY_MAX_CANDIDATES,candidates.size()):
		var candidate: Dictionary = candidates[index]
		# Only the first10world is buried/attached. The descending body receives
		# no landing, interaction, enemy, hazard or dynamic-sweep exception.
		var tail := Rect2(candidate.anchor-Vector2(left,-10.0),Vector2(left+right,height-10.0))
		if protected_regions.any(func(region: Rect2) -> bool: return region.intersects(tail)):
			rejected.append("protected_route_or_dynamic_sweep");continue
		if obstacles.any(func(region: Rect2) -> bool: return region.intersects(tail.grow(2.0))):
			rejected.append("actual_fixed_body_blocks_hanging_air");continue
		return {"ok":true,"anchor":candidate.anchor,"surface":candidate.surface,"scale":factor,"tail":tail,"desired":desired}
	return {"ok":false,"reason":"no_actual_static_underside" if candidates.is_empty() else "no_clear_protected_hanging_space","rejected":rejected,"candidate_count":candidates.size()}

func _hanging_ivy(area: Dictionary, desired: Vector2, height: float, tint: Color) -> void:
	var obstacles: Array[Rect2] = []
	if is_instance_valid(_stage): obstacles=fixed_ivy_obstacles(_stage.assembler)
	var planned := plan_hanging_ivy(ivy_surfaces(),obstacles,desired,height)
	if not planned.ok:
		ivy_omitted.append({"area_id":area.id,"asset_id":"ivy","reason":planned.reason,"candidate_count":planned.candidate_count,"rejected":planned.rejected})
		return
	var body: StaticBody2D = planned.surface.body
	var sprite := Sprite2D.new()
	sprite.name="HangingIvy_"+str(area.id)
	sprite.texture=PlainsV3Assets.texture("decor.json","ivy")
	sprite.centered=false
	sprite.modulate=tint
	add_child(sprite)
	sprite.global_rotation=0.0
	sprite.global_scale=Vector2.ONE*float(planned.scale)
	sprite.global_position=planned.anchor-IVY_TOP_ANCHOR*float(planned.scale)
	var metadata := {"area_id":area.id,"identity":area.identity,"depth":"actual_static_underside_background_foliage","asset_source":"assets/plains_v3/decor.png","source_sha256":FileAccess.get_sha256("res://assets/plains_v3/decor.png"),"asset_id":"ivy","collision":false,"standing_edge":false,"attachment_node_path":str(body.get_path()),"actual_support_bounds":PlainsSemanticLandscape.rect_values(planned.surface.bounds),"one_way_source":planned.surface.one_way,"source_anchor":PlainsSemanticLandscape.pair(IVY_TOP_ANCHOR),"anchor_world":PlainsSemanticLandscape.pair(planned.anchor),"uniform_scale":planned.scale,"complete_declared_atlas":true,"attachment_scope":"Measured actual source and real lower-edge intersection; pixel quality remains review"}
	sprite.set_meta("composition",metadata)
	compositions.append(metadata)
	hanging_ivy.append({"sprite":sprite,"body":body,"bounds":planned.surface.bounds,"anchor":planned.anchor,"scale":planned.scale,"atlas_region":(sprite.texture as AtlasTexture).region})

func ivy_attachment_issues() -> Array[String]:
	var issues: Array[String] = []
	for item: Dictionary in hanging_ivy:
		var sprite: Sprite2D = item.sprite
		var body: StaticBody2D = item.body
		if not is_instance_valid(body) or not body.is_inside_tree():
			issues.append("ivy_actual_support_missing");continue
		var bounds := PlainsLandscapeObserver.shape_bounds(body)
		if not bounds.is_equal_approx(item.bounds): issues.append("ivy_actual_support_moved")
		var anchor := sprite.global_transform*IVY_TOP_ANCHOR
		if anchor.distance_to(item.anchor)>0.05 or absf(anchor.y-(bounds.end.y-IVY_BURY))>0.05: issues.append("ivy_head_detached")
		if not sprite.global_scale.is_equal_approx(Vector2.ONE*float(item.scale)): issues.append("ivy_source_stretched")
		if not sprite.texture is AtlasTexture or not (sprite.texture as AtlasTexture).region.is_equal_approx(item.atlas_region) or not (sprite.texture as AtlasTexture).filter_clip: issues.append("ivy_source_changed_or_cropped")
	return issues
