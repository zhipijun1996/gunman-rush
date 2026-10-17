extends Node2D
## Limited opt-in second-space experiment over unchanged formal static union.
const CATALOG := "res://resources/visual_development/painted_terrain_candidate.json"
var facts: Dictionary={}
var _hidden: Array[CanvasItem]=[]
var _old_background: CanvasLayer
var _meadow: Sprite2D
var _camera_origin := Vector2.ZERO

func install(stage: PlainsRegionStage) -> void:
	var data := PlainsTerrainFamilySampler.inventory(stage)
	var groups := PlainsTerrainFamilySampler.groups(data.rooted)
	var spawn := stage.spawn
	groups.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.bounds.get_center().distance_to(spawn)<b.bounds.get_center().distance_to(spawn))
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var spec: Dictionary=catalog.terrain.grammar.duplicate(true)
	spec.source_x_offsets={};spec.face_patches=[]
	spec["visible_underside"]=catalog.formal_second_space.visible_underside.duplicate(true)
	var sources: Array=[spec.texture,spec.visible_underside.texture,spec.ends.left.texture,spec.ends.right.texture]
	for path: String in sources:
		if not ResourceLoader.exists(path) or load(path)==null:
			facts={"status":"refused_baseline_preserved","reason":"required_source_missing","source":path};return
	var design: Dictionary={"solid_polygons":[],"top_polylines":[]}
	var selected: Array[Dictionary]=[]
	var refused: Array[Dictionary]=[]
	var pending_hide: Array[CanvasItem]=[]
	var source_x := 40.0
	var source_width := float(load(str(spec.texture)).get_width())
	for group: Dictionary in groups:
		var tops: Array[Vector4]=[]
		for edge: Vector4 in group.faces:
			if edge.z>edge.x:tops.append(edge)
		var reason := ""
		if selected.size()>=2:reason="limited_second_space_budget"
		elif tops.size()!=1:reason="multiple_top_runs_or_holes_not_supported"
		elif source_x+(tops[0].z-tops[0].x)*float(spec.source_pixels_per_world_unit)>source_width:reason="finite_source_exhausted"
		elif group.bounds.size.y<float(spec.lip_world_depth):reason="bank_thinner_than_painted_lip"
		var outline := _outline(group.faces)
		if reason.is_empty() and outline.is_empty():reason="non_simple_or_disconnected_boundary"
		if not reason.is_empty():
			refused.append({"bounds":_rect(group.bounds),"reason":reason});continue
		var key := "formal_bank_%s"%selected.size()
		var top := tops[0]
		design.solid_polygons.append({"id":key+"_shore","points":outline})
		design.top_polylines.append({"id":key+"_grass","points":[[top.x,top.y],[top.z,top.w]]})
		spec.source_x_offsets[key+"_shore"]=source_x
		selected.append({"bounds":_rect(group.bounds),"source_span":[source_x,source_x+(top.z-top.x)*float(spec.source_pixels_per_world_unit)],"parts":group.parts.size(),"outline":outline})
		source_x+=(top.z-top.x)*float(spec.source_pixels_per_world_unit)+16
		# Original quads are canonical union pieces. Hide only this disconnected
		# union's pieces; suspended solids, one-way bridges and hazards stay live.
		for child: Node in stage.terrain_art.art.get_children():
			if child is ColorRect and group.bounds.encloses(Rect2(child.position,child.size)):
				pending_hide.append(child)
	var grammar := load("res://scripts/art/painted_terrain_grammar.gd").new() as Node2D
	grammar.call("configure",design,spec)
	add_child(grammar)
	var measurement: Dictionary=grammar.call("measured_nodes")
	if not candidate_complete(measurement,selected.size()) or selected.size()!=2:
		grammar.free();facts={"status":"refused_baseline_preserved","reason":"candidate_bank_coverage_incomplete","measurement":measurement};return
	for child: CanvasItem in pending_hide:child.hide();_hidden.append(child)
	facts={"status":"candidate_installed_not_art_admitted","scope":"two nearest supported formal rooted unions only; other terrain stays baseline","catalog_path":CATALOG,"catalog_sha256":FileAccess.get_sha256(CATALOG),"selected":selected,"omitted":refused,"suspended_preserved":data.floating.size(),"one_way_preserved":data.one_way.size(),"hidden_original_quads":_hidden.size(),"collision_changed":false,"grammar":measurement,"visible_underside":spec.visible_underside}
	stage.set_meta("visual_language_sample_path",CATALOG)
	var presentation := load("res://scripts/art/visual_language_sample.gd").new() as Node2D
	presentation.call("configure",stage,{"presentation_scope":"formal_second_space"})
	stage.add_child(presentation)
	facts["actors"]=presentation.call("measured_nodes")
	_background(stage,catalog)

func _background(stage: PlainsRegionStage, catalog: Dictionary) -> void:
	_old_background=stage.get_parent().get_node_or_null("PlainsBackground") as CanvasLayer
	if _old_background!=null:_old_background.hide()
	var layer := CanvasLayer.new();layer.layer=-95;add_child(layer)
	var sky := ColorRect.new();sky.size=Vector2(1280,720);sky.color=Color(str(catalog.sky_color));sky.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(sky)
	_meadow=Sprite2D.new();_meadow.centered=false
	_meadow.texture=load(str(catalog.formal_second_space.background.texture)) as Texture2D
	_meadow.position=Vector2((1280-_meadow.texture.get_width())*.5,0)
	layer.add_child(_meadow)
	var camera := get_viewport().get_camera_2d()
	if camera!=null:_camera_origin=camera.global_position
	facts["background"]={"source":_meadow.texture.resource_path,"scope":"existing finite distant meadow with bounded parallax; no physical support or interaction","screen_scale":1.0}

func _process(_delta: float) -> void:
	if not is_instance_valid(_meadow):return
	var camera := get_viewport().get_camera_2d()
	if camera==null:return
	var displacement := camera.global_position-_camera_origin
	_meadow.position=Vector2((1280-_meadow.texture.get_width())*.5-clampf(displacement.x*.08,-120,120),-clampf(displacement.y*.04,-24,24))

func _exit_tree() -> void:
	if is_instance_valid(_old_background):_old_background.show()

func measured_nodes() -> Dictionary:return facts.duplicate(true)

func candidate_complete(measurement: Dictionary, count: int) -> bool:
	if count<1 or measurement.get("banks",[]).size()!=count:return false
	for bank: Dictionary in measurement.banks:
		if not bank.get("coverage",{}).get("all_samples_match_actual_solid",false):return false
	return true

func _rect(rect: Rect2) -> Array:return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _outline(faces: PackedVector4Array) -> Array:
	if faces.is_empty():return []
	var remaining := Array(faces)
	var first: Vector4=remaining.pop_front()
	var result: Array=[[first.x,first.y]]
	var cursor := Vector2(first.z,first.w)
	while not remaining.is_empty():
		var found := false
		for i: int in remaining.size():
			var edge: Vector4=remaining[i]
			if cursor==Vector2(edge.x,edge.y):
				result.append([edge.x,edge.y]);cursor=Vector2(edge.z,edge.w);remaining.remove_at(i);found=true;break
		if not found:return []
	return result if cursor==Vector2(first.x,first.y) else []
