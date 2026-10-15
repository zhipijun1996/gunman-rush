class_name PlainsSemanticLandscape
extends Node2D
## Semantic, finite, source-bound landscape. Reads actual world geometry.
## No collision, RNG consumption, scene camera, resource or gameplay authority.
const FAMILY_ROOT := "res://assets/region_production_v3/spaces/"
const DEPTH: Shader = preload("res://shaders/plains_environment_depth.gdshader")
const PILOT_FAMILIES := ["windmill_repair_workshop_complete_v1", "bank_shoulder_wide_v1", "clock_regulator_court_v1"]
const VERSION := "plains-directed-clock-woodland-layers-v2"
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
	_build_woodland_layers()
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
	elif family_id=="clock_regulator_court_v1":
		result["anchor_mode"] = "grounded"
		result["recession"] = 0.32
		result["saturation"] = 0.48
	else: return {}
	result["pilot_overrides"] = {"world_width":result.world_width,"layer":result.get("layer","middle"),"depth_factor":result.get("depth_factor",0.0),"reason":"Bounded formal-game candidate; source canonical and original failed numeric requirements retained in family manifest"}
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
			sources.append({"bounds":shape, "node_path":str(body.get_path()), "platform_index":index,"members":[{"bounds":shape,"node_path":str(body.get_path()),"module_id":str(module.definition.module_id)}]})
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
		areas = areas.filter(func(a: Dictionary) -> bool: return int(a.get("row",-1))==1 and int(a.get("col",0))>=1 and str(a.get("spatial_intent",""))=="open_meadow_landing")
	var sources := actual_support_sources()
	if candidate.identity == "clock_court":
		# Only the actual long remote-bell corridor has the intended low court
		# foundation. Junction one-way slabs and unrelated floating islands do not.
		sources = sources.filter(func(source: Dictionary) -> bool:
			return source.members.any(func(member: Dictionary) -> bool: return member.get("module_id","")=="plains_remote_bell"))
		var actual_areas: Array = []
		for source: Dictionary in sources:
			var floor_rect: Rect2 = source.bounds
			var nearest: Dictionary = {}
			var best := INF
			for area: Dictionary in areas:
				var origin := Vector2(area.position[0],area.position[1])
				var distance := origin.distance_squared_to(floor_rect.get_center())
				if distance<best: nearest=area;best=distance
			if not nearest.is_empty():
				var actual := nearest.duplicate(true)
				actual["position"] = [floor_rect.get_center().x,floor_rect.position.y-18.0]
				actual_areas.append(actual)
		areas=actual_areas
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
	sprite.name = "Landscape_"+str(family.get("layer_id",family.family_id))
	sprite.centered = false
	if family.has("atlas_region"):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = values_rect(family.atlas_region)
		atlas.filter_clip = true
		texture = atlas
	sprite.texture = texture
	sprite.scale = Vector2.ONE*float(planned.scale)
	sprite.z_index = int(family.get("z_offset",0))
	sprite.modulate = Color(0.86,0.91,0.86,1.0)
	var material := ShaderMaterial.new()
	material.shader = DEPTH
	material.set_shader_parameter("saturation",float(family.get("saturation",0.60)))
	material.set_shader_parameter("recession",float(family.get("recession",0.20)))
	sprite.material = material
	sprite.set_meta("visual_semantics", {"family_id":family.family_id,"layer":family.get("layer","middle"),"semantic":"self_rooted_distant_woodland" if family.has("atlas_region") else "rooted_architecture" if family.identity in ["repair_gallery","clock_court"] else "rooted_bedrock","spatial_use":family.spatial_use,"candidate":true,"static_pixel_admission":"unverified"})
	add_child(sprite)
	sprite.global_position = planned.base_position
	planned["sprite"] = sprite
	planned["texture_size"] = texture.get_size()
	entries.append(planned)

func replaces_area(area_id: String) -> bool:
	return entries.any(func(e: Dictionary) -> bool: return str(e.area_id)==area_id and str(e.family.get("anchor_mode","grounded"))=="grounded")

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
		if str(family.get("layer_id",family.family_id)) in families: issues.append("duplicate_family_pilot")
		families.append(str(family.get("layer_id",family.family_id)))
		if not is_instance_valid(sprite) or not sprite.visible: issues.append("actual_pilot_not_visible"); continue
		if actual_texture_path(sprite.texture)!=str(family.path) or FileAccess.get_sha256(str(family.path))!=str(family.sha256): issues.append("actual_source_differs_from_family")
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
		if sprite.texture is AtlasTexture:
			var atlas := sprite.texture as AtlasTexture
			if not atlas.filter_clip or not atlas.region.is_equal_approx(values_rect(family.atlas_region)): issues.append("actual_atlas_region_or_filter_changed")
		if float(entry.depth_factor)==0.0 and (sprite.global_transform*(entry.anchor_source as Vector2)).distance_to(entry.anchor_world)>0.05: issues.append("actual_grounded_root_moved")
	return issues

func measured_nodes() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var sprite: Sprite2D = entry.sprite
		var family: Dictionary = entry.family
		var actual_opaque := sprite.global_transform*values_rect(family.opaque_source_bounds)
		var actual_overlaps: Array[Array] = []
		for region: Rect2 in protected_regions:
			if region.intersects(actual_opaque): actual_overlaps.append(rect_values(region))
		var members: Array[Dictionary]=[]
		for member: Dictionary in entry.support_members:
			members.append({"node_path":member.node_path,"world_bounds":rect_values(member.bounds)})
		nodes.append({"node_path":str(sprite.get_path()),"world_bounds":rect_values(sprite.global_transform*sprite.get_rect()),"opaque_source_bounds_world":rect_values(sprite.global_transform*values_rect(family.opaque_source_bounds)),"layer":family.get("layer","middle"),"semantic":sprite.get_meta("visual_semantics").semantic,"spatial_use":family.spatial_use,"attachment_node_path":entry.attachment_node_path,"actual_support":rect_values(entry.support),"actual_support_members":members,"support_measurement":"Complete distant root slope in original Atlas region; no gameplay support claimed" if family.has("atlas_region") else "Contiguous same-top union of the listed real static RectangleShape2D bodies; no gaps bridged","root_world":pair(sprite.global_transform*(entry.anchor_source as Vector2)),"declared_anchor_world":pair(entry.anchor_world),"actual_global_position":pair(sprite.global_position),"actual_global_scale":pair(sprite.global_scale),"effective_z_index":effective_z(sprite),"visible":sprite.visible,"visible_in_tree":sprite.is_visible_in_tree(),"texture_path":actual_texture_path(sprite.texture),"texture_sha256":FileAccess.get_sha256(actual_texture_path(sprite.texture)),"actual_atlas_region":rect_values((sprite.texture as AtlasTexture).region) if sprite.texture is AtlasTexture else [],"atlas_filter_clip":(sprite.texture as AtlasTexture).filter_clip if sprite.texture is AtlasTexture else false,"depth_factor":entry.depth_factor,"last_camera_center":pair(_last_camera),"trial_world_width":family.world_width,"pilot_overrides":family.get("pilot_overrides",{}),"canonical_source_world_width":family.canonical_source_world_width,"original_spec_result":family.get("original_spec_result","unknown"),"protected_overlap_candidates":actual_overlaps,"asset_family":{"id":family.family_id,"version":family.get("version","source-bound-v1"),"intended_use":family.spatial_use,"acceptance":"static_pilot_not_visual_approved"},"measurement_note":"Actual Node transforms/source/root. AABB overlap/visibility does not establish opaque pixel coverage or visual approval."})
	return nodes

static func actual_texture_path(texture: Texture2D) -> String:
	return (texture as AtlasTexture).atlas.resource_path if texture is AtlasTexture else texture.resource_path

func _build_woodland_layers() -> void:
	const FAMILY_ID := "woodland_two_depth_ridges_v1"
	var path := FAMILY_ROOT+FAMILY_ID+"/family.json"
	if not FileAccess.file_exists(path):
		omitted.append({"family_id":FAMILY_ID,"reason":"missing_frozen_source"})
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return
	var source: Dictionary = parsed
	var source_path := "res://"+str(source.get("path",""))
	if not source_path.begins_with(FAMILY_ROOT+FAMILY_ID+"/") or FileAccess.get_sha256(source_path)!=str(source.get("sha256","")):
		omitted.append({"family_id":FAMILY_ID,"reason":"wrong_actual_source"})
		return
	var camp_id := str(stage.generated.manifest.merchant_id)
	var areas: Array = stage.generated.manifest.areas
	var camp: Dictionary = {}
	for area: Dictionary in areas:
		if str(area.id)==camp_id: camp=area; break
	var chosen_a: Dictionary = {}
	var chosen_b: Dictionary = {}
	var selected_edge := ""
	var best := INF
	var best_after_camp := false
	for edge: Dictionary in stage.generated.manifest.connections:
		if str(edge.get("kind",""))!="horizontal": continue
		var a: Dictionary = {};var b: Dictionary = {}
		for area: Dictionary in areas:
			if str(area.id)==str(edge.a): a=area
			if str(area.id)==str(edge.b): b=area
		if a.is_empty() or b.is_empty(): continue
		if str(a.get("identity","")) not in ["windmill_plateau","repair_gallery"] or str(b.get("identity","")) not in ["windmill_plateau","repair_gallery"]: continue
		if int(a.get("row",-1))!=1 or int(b.get("row",-1))!=1 or mini(int(a.get("col",0)),int(b.get("col",0)))<1: continue
		var midpoint := (float(a.position[0])+float(b.position[0]))*.5
		var distance := absf(midpoint-float(camp.position[0]))
		# Prefer the outgoing/rejoining meadow after camp, then nearest real
		# corridor before camp. Never fabricate a missing horizontal passage.
		var after_camp := midpoint>=float(camp.position[0])
		if chosen_a.is_empty() or (after_camp and not best_after_camp) or (after_camp==best_after_camp and distance<best):
			best=distance;best_after_camp=after_camp;chosen_a=a;chosen_b=b;selected_edge=str(edge.id)
	if chosen_a.is_empty():
		omitted.append({"family_id":FAMILY_ID,"reason":"no_actual_non_tutorial_main_meadow_corridor"})
		return
	var reference := (Vector2(chosen_a.position[0],chosen_a.position[1])+Vector2(chosen_b.position[0],chosen_b.position[1]))*.5
	for layer: Dictionary in source.get("layers",[]):
		var family := source.duplicate(true)
		family.merge(layer,true)
		family["family_id"] = FAMILY_ID
		family["layer_id"] = str(layer.id)
		family["path"] = source_path
		family["family_manifest"] = path
		family["family_sha256"] = FileAccess.get_sha256(path)
		family["opaque_source_bounds"] = layer.opaque_region_local_bounds
		family["atlas_region"] = layer.region
		family["anchor_mode"] = "self_rooted_distant"
		family["foundation_source_interval"] = [0,0]
		family["canonical_source_world_width"] = layer.world_width
		family["original_spec_result"] = source.original_contract_status
		family["recession"] = 0.52 if layer.layer=="far" else 0.32
		family["saturation"] = 0.34 if layer.layer=="far" else 0.48
		family["z_offset"] = -40 if layer.layer=="far" else -25
		family["pilot_overrides"] = {"alternate_role":"bounded_self_rooted_distant_grove_trial_only","world_width":layer.world_width,"uniform_scale":true,"original_contract_status":source.original_contract_status,"original_failures":source.original_contract_failures,"source_region_unchanged":true,"original80px_gap_not_approved":true,"no_batch_promotion":true,"actual_corridor":selected_edge,"anchor_selection":"Single real non-tutorial main-meadow corridor nearest merchant, prefer outgoing; not a manufactured camp connection"}
		var issues := contract_issues(family)
		if not issues.is_empty():
			omitted.append({"family_id":FAMILY_ID,"layer_id":layer.id,"reason":"invalid_alternate_role_contract","issues":issues})
			continue
		var opaque := values_rect(family.opaque_source_bounds)
		var factor := float(family.world_width)/opaque.size.x
		var anchor := Vector2(family.anchor_px[0],family.anchor_px[1])
		var root_point := reference+Vector2(0,float(layer.root_slope_world_y_candidate))
		var base := root_point-anchor*factor
		var bounds := Rect2(base+opaque.position*factor,opaque.size*factor)
		var overlap: Array[Array] = []
		for region: Rect2 in protected_regions:
			if region.intersects(bounds): overlap.append(rect_values(region))
		_create_pilot({"family":family,"area_id":str(chosen_b.id),"identity":"windmill_plateau","base_position":base,"anchor_world":root_point,"anchor_source":anchor,"scale":factor,"support":Rect2(),"support_members":[],"attachment_node_path":"","protected_overlap_candidates":overlap,"bounds":bounds,"depth_factor":float(layer.depth_factor),"parallax_reference":reference})

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
