class_name PlainsSemanticLandscape
extends Node2D
## One pilot per independently produced family. Reads actual world geometry.
## No collision, RNG consumption, scene camera, resource or gameplay authority.
const FAMILY_ROOT := "res://assets/region_production_v3/spaces/"
const DEPTH: Shader = preload("res://shaders/plains_environment_depth.gdshader")
const PILOT_FAMILIES := ["windmill_repair_workshop_complete_v1", "bank_shoulder_wide_v1"]
const VERSION := "plains-directed-space-static-pilot-v1"
var stage: PlainsRegionStage
var supports: Array[Rect2] = []
var protected_regions: Array[Rect2] = []
var entries: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var source_manifest_hash := ""
var _last_camera := Vector2.INF

func configure(source: PlainsRegionStage, slabs: Array[Rect2], blocked: Array[Rect2]) -> void:
	stage = source
	supports = slabs.duplicate()
	protected_regions = blocked.duplicate()
	source_manifest_hash = str(source.generated.manifest.manifest_hash)

func _ready() -> void:
	# Scenery(-10) + Composition(-5) + this(8) => -7, behind terrain(-1).
	z_index = 8
	for family_id: String in PILOT_FAMILIES:
		var family := read_family(family_id)
		if family.is_empty():
			omitted.append({"family_id":family_id, "reason":"family_missing_or_not_integrable"})
			continue
		var planned := plan_pilot(family)
		if not planned.is_empty(): _create_pilot(planned)
	omitted.append({"identity":"clock_court", "reason":"no_independently_admitted_clock_family"})
	_update_parallax()
	set_process(not entries.is_empty())

static func read_family(family_id: String) -> Dictionary:
	var path := FAMILY_ROOT + family_id + "/family.json"
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {}
	var family: Dictionary = parsed
	# Source provenance stays intact. These two bounded trials are separate
	# from canonical production dimensions and original-spec failures.
	var result := family.duplicate(true)
	result["canonical_source_world_width"] = family.get("world_width",0.0)
	if family_id=="windmill_repair_workshop_complete_v1":
		# The camp junction is deliberately one-way. Its adjacent real stone
		# approach has a 320-wide connected union in map1; retain the full house
		# at this honest local scale rather than inventing a foundation there.
		result["world_width"] = 330.0
		result["anchor_mode"] = "grounded"
		result["layer"] = "middle"
		result["recession"] = 0.20
	elif family_id=="bank_shoulder_wide_v1":
		result["identity"] = "windmill_plateau"
		result["anchor_mode"] = "grounded"
		result["layer"] = "middle"
		result["recession"] = 0.40
		result["saturation"] = 0.43
		var opaque: Array = family.get("opaque_source_bounds",[])
		if opaque.size()!=4: return {}
		result["foundation_source_interval"] = [opaque[0],float(opaque[0])+float(opaque[2])]
	else: return {}
	var source := str(result.get("path",""))
	result["path"] = source if source.begins_with("res://") else "res://"+source
	result["family_id"] = family_id
	result["family_manifest"] = path
	result["family_sha256"] = FileAccess.get_sha256(path)
	return result

static func contract_issues(candidate: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	for key: String in ["path", "sha256", "identity", "spatial_use", "opaque_source_bounds", "anchor_px", "world_width", "foundation_source_interval"]:
		if not candidate.has(key): issues.append("missing_"+key)
	if not issues.is_empty(): return issues
	var path := str(candidate.path)
	if not path.begins_with(FAMILY_ROOT) or path.contains("..") or not FileAccess.file_exists(path):
		issues.append("source_outside_delivered_family")
	elif FileAccess.get_sha256(path) != str(candidate.sha256):
		issues.append("actual_source_sha_differs_from_contract")
	if candidate.opaque_source_bounds.size()!=4 or candidate.anchor_px.size()!=2 or candidate.foundation_source_interval.size()!=2:
		issues.append("invalid_source_anchor_shape")
	if float(candidate.world_width)<=0.0 or float(candidate.world_width)>1600.0: issues.append("invalid_pilot_world_scale")
	if str(candidate.identity) not in ["windmill_plateau", "repair_gallery", "clock_court", "creek_well"]: issues.append("unknown_formal_identity")
	if float(candidate.get("depth_factor",0.0))!=0.0 and str(candidate.get("anchor_mode","grounded"))=="grounded":
		issues.append("grounded_foundation_cannot_parallax")
	return issues

func actual_support_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for module: PlatformingModule in stage.assembler.modules:
		for index: int in module.definition.platforms.size():
			if index in module.definition.one_way_platform_indices or index in module.floating_solid_indices: continue
			var body := module.get_node_or_null("Platform"+str(index)) as Node2D
			if body == null: continue
			var shape: Rect2 = module.global_transform * module.definition.platforms[index]
			sources.append({"bounds":shape, "node_path":str(body.get_path()), "platform_index":index,"members":[{"bounds":shape,"node_path":str(body.get_path())}]})
	# A foundation may bridge authoring seams only when real static solids
	# actually meet at the same standing height. Never bridge a physical gap.
	sources.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ra: Rect2=a.bounds; var rb: Rect2=b.bounds
		return ra.position.x<rb.position.x if is_equal_approx(ra.position.y,rb.position.y) else ra.position.y<rb.position.y)
	var unions: Array[Dictionary] = []
	for source: Dictionary in sources:
		if not unions.is_empty():
			var prior: Dictionary=unions[-1]
			var a: Rect2=prior.bounds; var b: Rect2=source.bounds
			if is_equal_approx(a.position.y,b.position.y) and b.position.x<=a.end.x+0.01:
				prior["bounds"]=Rect2(a.position,Vector2(maxf(a.end.x,b.end.x)-a.position.x,minf(a.size.y,b.size.y)))
				prior.members.append_array(source.members)
				continue
		unions.append(source)
	return unions

func plan_pilot(candidate: Dictionary) -> Dictionary:
	var issues := contract_issues(candidate)
	if not issues.is_empty():
		omitted.append({"family_id":candidate.get("family_id",""),"reason":"invalid_family_runtime_contract","issues":issues})
		return {}
	var areas: Array = stage.generated.manifest.areas.filter(func(a: Dictionary) -> bool: return str(a.get("identity",""))==str(candidate.identity))
	areas.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("col",0))<int(b.get("col",0)))
	if candidate.identity == "windmill_plateau":
		# First main-route observation, not the tutorial or a random high-reward island.
		areas = areas.filter(func(a: Dictionary) -> bool: return str(a.id)=="area_1_1")
	var sources := actual_support_sources()
	var opaque := values_rect(candidate.opaque_source_bounds)
	var factor := float(candidate.world_width)/opaque.size.x
	var footing: Array = candidate.foundation_source_interval
	var foot_width := (float(footing[1])-float(footing[0]))*factor
	for area: Dictionary in areas:
		var origin := Vector2(area.position[0],area.position[1])
		var options: Array[Dictionary] = sources.filter(func(s: Dictionary) -> bool:
			var rect: Rect2=s.bounds
			return absf(rect.position.y-origin.y-18.0)<80.0 and rect.size.x>=foot_width+8.0 and rect.grow(380.0).has_point(origin))
		options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a.bounds as Rect2).get_center().distance_squared_to(origin)<(b.bounds as Rect2).get_center().distance_squared_to(origin))
		for source: Dictionary in options:
			var support: Rect2 = source.bounds
			var anchor_source := Vector2(candidate.anchor_px[0],candidate.anchor_px[1])
			var center := clampf(origin.x, support.position.x+foot_width*.5+4.0,support.end.x-foot_width*.5-4.0)
			var base_x := center-(float(footing[0])+float(footing[1]))*.5*factor
			var attachment := Vector2(base_x+anchor_source.x*factor, support.position.y+float(candidate.get("foundation_overlap",3.0)))
			var base := attachment-anchor_source*factor
			var bounds := Rect2(base+opaque.position*factor,opaque.size*factor)
			var overlaps: Array[Array] = []
			for region: Rect2 in protected_regions:
				if region.intersects(bounds): overlaps.append(rect_values(region))
			# Middle/far scenery may sit behind the actor. Near-layer overlap is
			# forbidden; all other overlap remains explicit for alpha pixel review.
			if str(candidate.get("layer","middle"))=="near" and not overlaps.is_empty(): continue
			return {"family":candidate.duplicate(true),"area_id":str(area.id),"identity":str(area.identity),"base_position":base,"anchor_world":attachment,"anchor_source":anchor_source,"scale":factor,"support":support,"support_members":source.members.duplicate(true),"attachment_node_path":source.node_path,"protected_overlap_candidates":overlaps,"bounds":bounds,"depth_factor":float(candidate.get("depth_factor",0.0)),"parallax_reference":origin}
	var nearby: Array[Dictionary] = []
	for area: Dictionary in areas:
		var origin := Vector2(area.position[0],area.position[1])
		for source: Dictionary in sources:
			var slab: Rect2=source.bounds
			if absf(slab.position.y-origin.y)<100.0 and absf(slab.get_center().x-origin.x)<1800.0:
				nearby.append({"area_id":area.id,"area_position":pair(origin),"support":rect_values(slab),"node_path":source.node_path})
	omitted.append({"family_id":candidate.family_id,"identity":candidate.identity,"reason":"no_actual_static_foundation_with_required_clearance","nearby_actual_static_supports":nearby})
	return {}

func _create_pilot(planned: Dictionary) -> void:
	var family: Dictionary = planned.family
	var texture := load(str(family.path)) as Texture2D
	if texture == null:
		omitted.append({"family_id":family.family_id,"reason":"actual_texture_load_failed"})
		return
	var sprite := Sprite2D.new()
	sprite.name = "Pilot_"+str(family.family_id)
	sprite.centered = false
	sprite.texture = texture
	sprite.scale = Vector2.ONE*float(planned.scale)
	sprite.modulate = Color(0.86,0.91,0.86,1.0)
	var material := ShaderMaterial.new()
	material.shader = DEPTH
	material.set_shader_parameter("saturation",float(family.get("saturation",0.60)))
	material.set_shader_parameter("recession",float(family.get("recession",0.20)))
	sprite.material = material
	sprite.set_meta("visual_semantics", {"family_id":family.family_id,"layer":family.get("layer","middle"),"semantic":"rooted_architecture" if family.identity=="repair_gallery" else "rooted_bedrock","spatial_use":family.spatial_use,"candidate":true,"static_pixel_admission":"unverified"})
	add_child(sprite)
	sprite.global_position = planned.base_position
	planned["sprite"] = sprite
	planned["texture_size"] = texture.get_size()
	entries.append(planned)

func replaces_area(area_id: String) -> bool:
	return entries.any(func(e: Dictionary) -> bool: return str(e.area_id)==area_id)

func _process(_delta: float) -> void:
	_update_parallax()

func _update_parallax() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	var center := camera.get_screen_center_position()
	if center==_last_camera: return
	_last_camera = center
	for entry: Dictionary in entries:
		var sprite: Sprite2D = entry.sprite
		sprite.global_position = (entry.base_position as Vector2)+(center-(entry.parallax_reference as Vector2))*float(entry.depth_factor)

func actual_issues() -> Array[String]:
	var issues: Array[String] = []
	if str(stage.generated.manifest.manifest_hash)!=source_manifest_hash: issues.append("formal_manifest_changed")
	var families: Array[String] = []
	for entry: Dictionary in entries:
		var sprite: Sprite2D = entry.sprite
		var family: Dictionary = entry.family
		if str(family.family_id) in families: issues.append("duplicate_family_pilot")
		families.append(str(family.family_id))
		if not is_instance_valid(sprite) or not sprite.visible: issues.append("actual_pilot_not_visible"); continue
		if sprite.texture.resource_path!=str(family.path) or FileAccess.get_sha256(str(family.path))!=str(family.sha256): issues.append("actual_source_differs_from_family")
		var expected: Vector2=entry.base_position
		if _last_camera.is_finite(): expected+=(_last_camera-(entry.parallax_reference as Vector2))*float(entry.depth_factor)
		if sprite.global_position.distance_to(expected)>0.05: issues.append("actual_pilot_detached_from_anchor")
		if not sprite.scale.is_equal_approx(Vector2.ONE*float(entry.scale)): issues.append("actual_pilot_nonuniform_or_wrong_scale")
		for member: Dictionary in entry.support_members:
			var body := get_node_or_null(str(member.node_path)) as Node2D
			if body==null:
				issues.append("actual_foundation_missing")
				continue
			var shape := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape==null or not shape.shape is RectangleShape2D:
				issues.append("actual_foundation_shape_missing")
			else:
				var size := (shape.shape as RectangleShape2D).size
				var actual := shape.global_transform*Rect2(-size*.5,size)
				if not actual.is_equal_approx(member.bounds): issues.append("actual_foundation_geometry_changed")
		if effective_z(sprite)>=-1: issues.append("actual_pilot_not_behind_gameplay")
		if float(entry.depth_factor)==0.0 and (sprite.global_transform*(entry.anchor_source as Vector2)).distance_to(entry.anchor_world)>0.05: issues.append("actual_grounded_root_moved")
	return issues

func measured_nodes() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var sprite: Sprite2D = entry.sprite
		var family: Dictionary = entry.family
		var members: Array[Dictionary]=[]
		for member: Dictionary in entry.support_members:
			members.append({"node_path":member.node_path,"world_bounds":rect_values(member.bounds)})
		nodes.append({"node_path":str(sprite.get_path()),"world_bounds":rect_values(sprite.global_transform*sprite.get_rect()),"opaque_source_bounds_world":rect_values(sprite.global_transform*values_rect(family.opaque_source_bounds)),"layer":family.get("layer","middle"),"semantic":sprite.get_meta("visual_semantics").semantic,"spatial_use":family.spatial_use,"attachment_node_path":entry.attachment_node_path,"actual_support":rect_values(entry.support),"actual_support_members":members,"support_measurement":"Contiguous same-top union of the listed real static RectangleShape2D bodies; no gaps bridged","root_world":pair(sprite.global_transform*(entry.anchor_source as Vector2)),"declared_anchor_world":pair(entry.anchor_world),"actual_global_position":pair(sprite.global_position),"actual_global_scale":pair(sprite.global_scale),"effective_z_index":effective_z(sprite),"visible":sprite.visible,"visible_in_tree":sprite.is_visible_in_tree(),"texture_path":sprite.texture.resource_path,"texture_sha256":FileAccess.get_sha256(sprite.texture.resource_path),"depth_factor":entry.depth_factor,"last_camera_center":pair(_last_camera),"trial_world_width":family.world_width,"canonical_source_world_width":family.canonical_source_world_width,"original_spec_result":family.get("original_spec_result","unknown"),"protected_overlap_candidates":entry.protected_overlap_candidates,"asset_family":{"id":family.family_id,"version":family.get("version","source-bound-v1"),"intended_use":family.spatial_use,"acceptance":"static_pilot_not_visual_approved"},"measurement_note":"Actual Node transforms/source/root. AABB overlap/visibility does not establish opaque pixel coverage or visual approval."})
	return nodes

static func effective_z(item: CanvasItem) -> int:
	var total := item.z_index
	var child: CanvasItem = item
	var parent: Node = item.get_parent()
	while child.z_as_relative and parent is CanvasItem:
		child = parent as CanvasItem
		total += child.z_index
		parent = parent.get_parent()
	return total

static func values_rect(values: Array) -> Rect2:
	return Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))

static func rect_values(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

static func pair(value: Vector2) -> Array:
	return [value.x,value.y]
