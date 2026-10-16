class_name PlainsConnectedLandscape
extends Node2D
## Complete rooted plants, anchored to actual static stone and clear encounter bands.
## No RNG, collision, camera, actor or gameplay state writes.
const ROOT := "res://assets/production_repair/"
var stage: PlainsRegionStage
var protected_regions: Array[Rect2] = []
var entries: Array[Dictionary] = []
var omitted: Array[Dictionary] = []
var _candidate := false
var _plants: Node2D
var _manifest_hash := ""
var _hard_protected: Array[Rect2] = []
var _plant_nodes:Array[Dictionary]=[]

func configure(source: PlainsRegionStage, blocked: Array[Rect2]) -> void:
	stage=source
	protected_regions=blocked.duplicate()
	_hard_protected=stage.assembler.world_dangers()
	for module:PlatformingModule in stage.assembler.modules:
		for ferry:ModuleMovingPlatformDefinition in module.definition.ferries:
			_hard_protected.append(Rect2(module.position+ferry.envelope().position,ferry.envelope().size).grow(36))
	_manifest_hash=str(source.generated.manifest.manifest_hash)

func _ready() -> void:
	z_as_relative=false
	z_index=0
	_candidate=OS.get_environment("PLAINS_ROOTED_PLANTS")=="1" or OS.get_environment("PLAINS_CONNECTED_LANDSCAPE")=="1"
	_build.call_deferred()

static func read_family(id: String) -> Dictionary:
	var path:=ROOT+id+"/family.json"
	if not FileAccess.file_exists(path):return {}
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:return {}
	var family:Dictionary=value
	if family.get("schema_version")!=1 or family.get("runtime_candidate")!=true:return {}
	var source:=str(family.get("path",""))
	if not source.begins_with(ROOT) or source.contains("..") or not FileAccess.file_exists(source):return {}
	if FileAccess.get_sha256(source)!=str(family.get("sha256","")):return {}
	family=family.duplicate(true)
	family["manifest_path"]=path
	family["manifest_sha256"]=FileAccess.get_sha256(path)
	return family

func _build() -> void:
	if not is_instance_valid(stage) or not is_instance_valid(stage.terrain_art):return
	var home:=Vector2.INF
	for enemy:Dictionary in stage.generated.manifest.enemies:
		if str(enemy.get("behavior_id",""))=="root_bell":
			home=Vector2(enemy.position[0],enemy.position[1]);break
	if not home.is_finite():
		omitted.append({"reason":"no_formal_root_bell_joint_space"})
		set_candidate(_candidate);return
	# The actual encounter observation/escape band remains free of large plants.
	var joint:Dictionary=stage.generated.manifest.get("root_bell_admission",{}).get("physical_facts",{}).get("joint_space",{})
	var keep_clear:Array=joint.get("visual_keep_clear_xywh",[])
	var encounter_clearance:=PlainsSemanticLandscape.values_rect(keep_clear) if keep_clear.size()==4 else Rect2(home+Vector2(-270,-170),Vector2(540,190))
	protected_regions.append(encounter_clearance)
	_hard_protected.append(encounter_clearance)
	var plants:=read_family("rooted_plants_v1")
	if not plants.is_empty():
		_build_plants(plants,home)
		_candidate=_candidate or (bool(plants.get("default_admission",false)) and OS.get_environment("PLAINS_ROOTED_PLANTS")!="0")
	else:omitted.append({"family_id":"rooted_plants_v1","reason":"missing_calibrated_complete_plants"})
	set_candidate(_candidate)

func _build_plants(family: Dictionary, home: Vector2) -> void:
	var texture:=load(str(family.path)) as Texture2D
	if texture==null:return
	_plants=Node2D.new();_plants.name="CompleteRootedPlants";_plants.z_as_relative=false;_plants.z_index=-2;add_child(_plants)
	var composition:=get_parent() as PlainsRegionComposition
	if composition==null or not is_instance_valid(composition.landscape):return
	var sources:=composition.landscape.actual_support_sources()
	var desired:Array[float]=[home.x-390,home.x+450,home.x-610,home.x+610]
	var used:Array[Rect2]=[]
	for index:int in mini(desired.size(),family.get("plants",[]).size()):
		var plant:Dictionary=family.plants[index]
		var region:=PlainsSemanticLandscape.values_rect(plant.region)
		var opaque:=PlainsSemanticLandscape.values_rect(plant.opaque_bounds)
		var anchor:=Vector2(plant.anchor_px[0],plant.anchor_px[1])
		var scale_value:=float(plant.uniform_scale)
		if scale_value<=0 or scale_value>float(plant.get("max_uniform_scale",1.0)):
			omitted.append({"plant_id":plant.id,"reason":"invalid_or_enlarged_scale"});continue
		var obstacles:=_hard_protected.duplicate()
		for prior:Rect2 in used:obstacles.append(prior.grow(30))
		var planned:=plan_rooted_plant(sources,obstacles,desired[index],home.y+20,opaque,anchor,scale_value)
		if planned.is_empty():
			omitted.append({"plant_id":plant.id,"reason":"no_actual_static_ground_with_protected_clearance"});continue
		var source:Dictionary=planned.source
		var support:Rect2=source.bounds
		var foot:Vector2=planned.foot
		var position:Vector2=planned.position
		var bounds:Rect2=planned.bounds
		var root_interval:Array=plant.root_source_interval
		var root_world:=Vector2(foot.x+(float(root_interval[0])-anchor.x)*scale_value,foot.x+(float(root_interval[1])-anchor.x)*scale_value)
		var attachment:=str(source.node_path)
		var actual_root_supports:Array[Dictionary]=[]
		for member:Dictionary in source.members:
			var actual:Rect2=member.bounds
			if actual.end.x>=root_world.x and actual.position.x<=root_world.y and absf(actual.position.y-support.position.y)<0.01:
				actual_root_supports.append({"node_path":str(member.node_path),"bounds":PlainsSemanticLandscape.rect_values(actual),"module_id":member.module_id})
				if foot.x>=actual.position.x and foot.x<=actual.end.x:attachment=str(member.node_path)
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=region;atlas.filter_clip=true
		var sprite:=Sprite2D.new();sprite.name="Rooted_"+str(plant.id);sprite.texture=atlas;sprite.centered=false;sprite.scale=Vector2.ONE*scale_value;_plants.add_child(sprite);sprite.global_position=position
		sprite.modulate=Color(0.78,0.84,0.78,1.0)
		_plant_nodes.append({"sprite":sprite,"anchor_source":anchor,"anchor_world":foot,"scale":scale_value,"source":texture,"region":region,"supports":actual_root_supports})
		entries.append({"kind":"rooted_plant","plant_id":plant.id,"source_sha256":family.sha256,"source_region":plant.region,"world_bounds":PlainsSemanticLandscape.rect_values(bounds),"anchor_world":PlainsSemanticLandscape.pair(foot),"support_bounds":PlainsSemanticLandscape.rect_values(support),"attachment_node_path":attachment,"root_world_interval":[root_world.x,root_world.y],"actual_root_support_members":actual_root_supports,"uniform_scale":scale_value,"depth_factor":0.0,"actual_support":true,"protected_overlap_candidates":protected_regions.filter(func(r:Rect2)->bool:return r.intersects(bounds)).map(func(r:Rect2)->Array:return PlainsSemanticLandscape.rect_values(r)),"root_anchor_semantic":plant.get("anchor_semantic",""),"collision":false,"standing_edge":false})
		used.append(bounds)

static func plan_rooted_plant(sources:Array[Dictionary],obstacles:Array[Rect2],desired_x:float,ground_y:float,opaque:Rect2,anchor:Vector2,scale_value:float)->Dictionary:
	var best:Dictionary={}
	var distance:=INF
	var local_bounds:=Rect2((opaque.position-anchor)*scale_value,opaque.size*scale_value)
	for source:Dictionary in sources:
		var support:Rect2=source.bounds
		if absf(support.position.y-ground_y)>4:continue
		var y:=support.position.y+2
		var allowed:Array[Vector2]=[Vector2(support.position.x-local_bounds.position.x+0.1,support.end.x-local_bounds.end.x-0.1)]
		for obstacle:Rect2 in obstacles:
			if obstacle.end.y<=y+local_bounds.position.y or obstacle.position.y>=y+local_bounds.end.y:continue
			var forbidden:=Vector2(obstacle.position.x-local_bounds.end.x-0.1,obstacle.end.x-local_bounds.position.x+0.1)
			var remaining:Array[Vector2]=[]
			for interval:Vector2 in allowed:
				if forbidden.y<=interval.x or forbidden.x>=interval.y:remaining.append(interval);continue
				if forbidden.x>interval.x:remaining.append(Vector2(interval.x,minf(interval.y,forbidden.x)))
				if forbidden.y<interval.y:remaining.append(Vector2(maxf(interval.x,forbidden.y),interval.y))
			allowed=remaining
		for interval:Vector2 in allowed:
			if interval.y<interval.x:continue
			var x:=clampf(desired_x,interval.x,interval.y)
			if absf(x-desired_x)>distance or absf(x-desired_x)>480:continue
			var foot:=Vector2(x,y)
			var bounds:=Rect2(foot+local_bounds.position,local_bounds.size)
			if obstacles.any(func(r:Rect2)->bool:return r.intersects(bounds)):continue
			distance=absf(x-desired_x)
			best={"source":source,"foot":foot,"position":foot-anchor*scale_value,"bounds":bounds}
	return best

func set_candidate(value: bool) -> void:
	_candidate=value
	visible=value

func actual_issues()->Array[String]:
	var issues:Array[String]=[]
	for item:Dictionary in _plant_nodes:
		var sprite:Sprite2D=item.sprite
		if (sprite.global_transform*(item.anchor_source as Vector2)).distance_to(item.anchor_world)>0.05:issues.append("plant_root_collar_detached")
		if not sprite.global_scale.is_equal_approx(Vector2.ONE*float(item.scale)):issues.append("plant_source_stretched_or_enlarged")
		if sprite.z_index!=0 or _plants.z_index!=-2 or _plants.z_as_relative:issues.append("plant_not_behind_gameplay")
		if not sprite.texture is AtlasTexture:issues.append("plant_complete_atlas_replaced")
		else:
			var atlas:=sprite.texture as AtlasTexture
			if atlas.atlas!=item.source or not atlas.region.is_equal_approx(item.region) or not atlas.filter_clip:issues.append("plant_source_region_or_filter_changed")
		for support:Dictionary in item.supports:
			var body:=get_node_or_null(str(support.node_path)) as Node2D
			if body==null or not PlainsLandscapeObserver.shape_bounds(body).is_equal_approx(PlainsSemanticLandscape.values_rect(support.bounds)):issues.append("plant_actual_root_support_changed")
	return issues

func measured_nodes() -> Dictionary:
	var actual:Array[Dictionary]=[]
	for item:Dictionary in _plant_nodes:
		var sprite:Sprite2D=item.sprite
		var atlas:=sprite.texture as AtlasTexture
		actual.append({"node_path":str(sprite.get_path()),"actual_global_position":PlainsSemanticLandscape.pair(sprite.global_position),"actual_global_scale":PlainsSemanticLandscape.pair(sprite.global_scale),"actual_root_collar_world":PlainsSemanticLandscape.pair(sprite.global_transform*(item.anchor_source as Vector2)),"declared_root_collar_world":PlainsSemanticLandscape.pair(item.anchor_world),"actual_world_bounds":PlainsSemanticLandscape.rect_values(sprite.global_transform*sprite.get_rect()),"actual_source":atlas.atlas.resource_path if atlas!=null and atlas.atlas!=null else "","actual_atlas_region":PlainsSemanticLandscape.rect_values(atlas.region) if atlas!=null else [],"actual_filter_clip":atlas.filter_clip if atlas!=null else false,"actual_visible_in_tree":sprite.is_visible_in_tree(),"measurement_scope":"Actual Sprite2D transform and original AtlasTexture; AABB does not assert opaque occlusion or aesthetic quality."})
	return {"actual_plants":actual,"issues":actual_issues(),"entries":entries.duplicate(true),"omitted":omitted.duplicate(true),"candidate_enabled":_candidate,"manifest_hash":_manifest_hash,"protected_regions":protected_regions.map(func(r:Rect2)->Array:return PlainsSemanticLandscape.rect_values(r)),"scope":"Actual RootBell joint-space rooted plant consumers; complete six-subject family and commercial/device approval remain separate."}

