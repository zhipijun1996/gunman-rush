extends SceneTree
## Real DemoApp consumer and deliberate live-Node counterexamples.
## No traversal, pixels, performance, audio, device or aesthetic acceptance.
var assertions := 0
var failures := 0
var output := ""
var rows: Array[Dictionary] = []
var camera_samples: Array[Dictionary] = []
var _ivy_actual_seen := 0
var _ivy_counterexample_done := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("DIRECTED SPACE FAIL: ",label)

func find_landscape(node: Node) -> PlainsSemanticLandscape:
	if node is PlainsSemanticLandscape: return node as PlainsSemanticLandscape
	for child: Node in node.get_children():
		var found := find_landscape(child)
		if found!=null: return found
	return null

func forbidden_descendant(node: Node) -> bool:
	for child: Node in node.get_children():
		if child is CollisionObject2D or child is CollisionShape2D or child is Camera2D: return true
		if forbidden_descendant(child): return true
	return false

func wait_stage(app: DemoApp) -> void:
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: return

func check_live(app: DemoApp, map_index: int, seed_value: String, thorough: bool) -> void:
	var stage := app.stage as PlainsRegionStage
	check(_fixture_identity_matches(app, map_index, seed_value), "actual stage/map/manifest seed+difficulty matches requested fixture")
	var before := JSON.stringify(stage.generated.manifest)
	var landscape := find_landscape(stage)
	check(landscape!=null,"formal map has actual directed consumer")
	if landscape==null: return
	check(not forbidden_descendant(landscape),"presentation contains no collision/camera/gameplay authority")
	check(landscape.entries.size()>=3,"actual workshop, shoulder and clock exist on this formal seed")
	check(landscape.actual_issues().is_empty(),"real roots, sources, scales and depths are valid: "+str(landscape.actual_issues()))
	var background := app.get_node_or_null("PlainsBackground") as PlainsBackground
	check(background!=null and background.region_layers,"actual formal consumer keeps extreme-far backdrop with independent world layers")
	if "--legacy-panorama-contract" in OS.get_cmdline_user_args():
		# Original assertion retained for the explicitly disabled new consumer.
		check(background.panels.size()==1 and background.panels[0].texture==PlainsBackground.PANORAMA,"admitted world-scale pano retains coverage outside grove pilot")
	else:
		check(background.shared_environment_enabled and background.panels.size()==2,"actual shared consumer has independent sky and geology")
		check(background.panels[0].texture==PlainsBackground.TEXTURES[0] and background.panels[1].texture==PlainsBackground.RIDGE,"actual sources have distinct semantic duties")
		var zero:=PlainsBackground.shared_projection(Vector2(1280,720),Vector2.ZERO,Rect2(-6000,-4000,16000,10000))
		var shifted:=PlainsBackground.shared_projection(Vector2(1280,720),Vector2(1000,-500),Rect2(-6000,-4000,16000,10000))
		check((shifted[0].position-zero[0].position).distance_to(Vector2(-8,2))<0.01,"sky actual projection responds to both camera axes")
		check((shifted[1].position-zero[1].position).distance_to(Vector2(-70,9))<0.01,"ridge uses distinct linear parallax without saturation")
	check(stage.find_child("CreekWaterworksSpace",true,false)==null,"rejected waterworks absent from actual default")
	var observer := stage.find_child("ActualLandscapeObserver",true,false) as PlainsLandscapeObserver
	check(observer!=null,"actual default read-only capture observer exists")
	if observer!=null:
		var measured := observer.measure()
		check(measured.nodes.size()==landscape.entries.size() and measured.issues.is_empty(),"observer measures actual new consumer and diagnostics")
		check(not measured.protected_world_bounds.is_empty(),"actual standing/moving/player protection measured")
	var architecture_entry: Dictionary=landscape.entries[0]
	var architecture_material := (architecture_entry.sprite as Sprite2D).material as ShaderMaterial
	architecture_material.set_shader_parameter("wind_amount",0.1)
	check("non_foliage_wind_forbidden" in landscape.actual_issues(),"actual forbidden whole-building wind counterexample rejected")
	architecture_material.set_shader_parameter("wind_amount",0.0)
	var woods := landscape.entries.filter(func(e: Dictionary) -> bool: return str(e.family.family_id)=="woodland_two_depth_ridges_v1")
	check(woods.size()==2 or landscape.omitted.any(func(o: Dictionary) -> bool: return o.get("family_id","")=="woodland_two_depth_ridges_v1"),"two real cutouts or explicit family omission")
	# Semantic invariant independent of any movie route or bot strategy:
	# an existing post-camp meadow connection wins over a pre-camp connection.
	var camp: Dictionary = {}
	for area: Dictionary in stage.generated.manifest.areas:
		if str(area.id)==str(stage.generated.manifest.merchant_id): camp=area;break
	var has_outgoing := false
	for edge: Dictionary in stage.generated.manifest.connections:
		if str(edge.get("kind",""))!="horizontal": continue
		var endpoints: Array = stage.generated.manifest.areas.filter(func(a: Dictionary) -> bool: return str(a.id) in [str(edge.a),str(edge.b)])
		if endpoints.size()!=2: continue
		if not endpoints.all(func(a: Dictionary) -> bool: return int(a.get("row",-1))==1 and int(a.get("col",0))>=1 and str(a.get("identity","")) in ["windmill_plateau","repair_gallery"]): continue
		if (float(endpoints[0].position[0])+float(endpoints[1].position[0]))*.5>=float(camp.position[0]): has_outgoing=true
	if has_outgoing and not woods.is_empty():
		check(float(woods[0].anchor_world.x)>=float(camp.position[0]),"actual outgoing meadow identity takes semantic priority over pre-camp distance")
	var seen: Array[String] = []
	for entry: Dictionary in landscape.entries:
		var family: Dictionary=entry.family
		var sprite: Sprite2D=entry.sprite
		check(str(family.get("layer_id",family.family_id)) not in seen,"no duplicate semantic landscape layer")
		seen.append(str(family.get("layer_id",family.family_id)))
		if str(family.family_id)=="woodland_two_depth_ridges_v1":
			check(sprite.texture is AtlasTexture and (sprite.texture as AtlasTexture).filter_clip,"actual cutout isolates authored region")
			check(float(entry.depth_factor)>0.0,"actual independent woodland depth")
		else:
			check(sprite.texture is Texture2D and not sprite.texture is AtlasTexture,"complete architecture and rock source retains roof and roots")
			check(float(entry.depth_factor)==0.0,"grounded family remains world anchored")
		if family.get("anchor_mode","grounded")=="grounded": check(landscape.replaces_area(str(entry.area_id)),"actual visible replacement owns only its area")
		check(entry.protected_overlap_candidates is Array,"protected gameplay candidates preserved for pixel review")
		if not thorough: continue
		var position := sprite.global_position
		sprite.global_position+=Vector2(0,-100)
		check("actual_pilot_detached_from_anchor" in landscape.actual_issues(),"actual detached-root counterexample rejected")
		sprite.global_position=position
		var scale := sprite.scale
		sprite.scale.x*=1.2
		check("actual_pilot_nonuniform_or_wrong_scale" in landscape.actual_issues(),"actual nonuniform stretching rejected")
		sprite.scale=scale
		var z := sprite.z_index
		sprite.z_index=100
		check("actual_pilot_not_behind_gameplay" in landscape.actual_issues(),"actual front-of-gameplay depth rejected")
		sprite.z_index=z
		var texture := sprite.texture
		sprite.texture=preload("res://assets/plains_v8/painted_limestone_material.png")
		check("actual_source_differs_from_family" in landscape.actual_issues(),"actual wrong-source counterexample rejected")
		sprite.texture=texture
		if not entry.support_members.is_empty():
			var body := landscape.get_node(str(entry.attachment_node_path)) as Node2D
			var body_position := body.position
			body.position.y+=64.0
			check("actual_foundation_geometry_changed" in landscape.actual_issues(),"actual supporting-body displacement rejected")
			body.position=body_position
		if sprite.texture is AtlasTexture:
			var atlas := sprite.texture as AtlasTexture
			var region := atlas.region
			atlas.region=region.grow(8)
			check("actual_atlas_region_or_filter_changed" in landscape.actual_issues(),"actual neighboring cutout intrusion rejected")
			atlas.region=region
			atlas.filter_clip=false
			check("actual_atlas_region_or_filter_changed" in landscape.actual_issues(),"actual unsafe filtering rejected")
			atlas.filter_clip=true
		check(landscape.actual_issues().is_empty(),"restored real consumer clean after mutations")
		var malformed := family.duplicate(true)
		malformed["depth_factor"]=0.2
		if family.get("anchor_mode","grounded")=="grounded": check("grounded_foundation_cannot_parallax" in PlainsSemanticLandscape.contract_issues(malformed),"grounded artwork cannot be floated with camera")
	if thorough: check_camera_response(landscape)
	# A translated visual parent must not detach world-rooted artwork.
	var parent := Node2D.new()
	parent.position=Vector2(240,-90)
	parent.z_index=-15
	stage.add_child(parent)
	var translated := PlainsSemanticLandscape.new()
	translated.configure(stage,landscape.supports,landscape.protected_regions)
	parent.add_child(translated)
	# Both independent consumers must read the same current Camera2D pose.
	# process_frame resumes before Node._process; without this, far layers
	# compare adjacent camera samples rather than parent transforms.
	landscape._update_parallax()
	translated._update_parallax()
	check(translated.entries.size()==landscape.entries.size(),"translated parent retains actual family coverage")
	check(translated.actual_issues().is_empty(),"translated parent preserves actual root/world transforms")
	for index: int in mini(translated.entries.size(),landscape.entries.size()):
		var a: Sprite2D=translated.entries[index].sprite
		var b: Sprite2D=landscape.entries[index].sprite
		check(a.global_position.is_equal_approx(b.global_position),"translated-parent world placement remains identical")
	parent.free()
	rows.append({"root_seed":seed_value,"map_index":map_index,"actual_map_index":stage.map_index,"actual_manifest_seed":stage.generated.manifest.seed,"actual_manifest_difficulty":stage.generated.manifest.difficulty,"manifest_hash":stage.generated.manifest.manifest_hash,"family":stage.generated.manifest.family,"nodes":landscape.measured_nodes(),"omitted":landscape.omitted,"issues":landscape.actual_issues()})
	check(JSON.stringify(stage.generated.manifest)==before,"all display/mutation checks preserve exact formal Manifest")

func check_camera_response(landscape: PlainsSemanticLandscape) -> void:
	var camera := root.get_viewport().get_camera_2d()
	if camera==null: return
	# Stage-ready can precede the first Node._process. Establish the first
	# finite actual camera sample before taking any displacement difference.
	landscape._update_parallax()
	check(landscape._last_camera.is_finite(),"camera response starts from a finite live camera sample")
	var original := camera.global_position
	var positions: Array[Vector2] = []
	for entry: Dictionary in landscape.entries: positions.append((entry.sprite as Sprite2D).global_position)
	camera.global_position += Vector2(160,-120)
	camera.force_update_scroll()
	var previous_center := landscape._last_camera
	landscape._update_parallax()
	var shift := landscape._last_camera-previous_center
	check(shift.length()>1,"real Camera2D transform advanced for isolated response test")
	for index: int in landscape.entries.size():
		var entry: Dictionary=landscape.entries[index]
		var actual := (entry.sprite as Sprite2D).global_position-positions[index]
		var expected := shift*float(entry.depth_factor)
		var error := actual.distance_to(expected)
		camera_samples.append({"family_id":entry.family.family_id,"layer_id":entry.family.get("layer_id",""),"camera_shift":PlainsSemanticLandscape.pair(shift),"actual_node_shift":PlainsSemanticLandscape.pair(actual),"expected_node_shift":PlainsSemanticLandscape.pair(expected),"absolute_error_world":error,"tolerance_world":0.02,"scope":"Isolated actual Camera2D pose perturbation, not autonomous route traversal"})
		check(error<=0.02,"actual horizontal and vertical camera response within0.02world float precision")
	camera.global_position=original
	camera.force_update_scroll()
	landscape._update_parallax()

func run_legacy() -> void:
	var seeds: Array[String]=["level-design-v2-baseline","level-design-v2-baseline/01","level-design-v2-baseline/02","level-design-v2-baseline/03","level-design-v2-baseline/04","level-design-v2-baseline/05","level-design-v2-baseline/06","level-design-v2-baseline/07","level-design-v2-baseline/08","level-design-v2-baseline/09"]
	if "--single-seed" in OS.get_cmdline_user_args(): seeds.resize(1)
	for seed_value: String in seeds:
		var app := DemoApp.new()
		app.meta_persistence_enabled=false
		root.add_child(app)
		check(app.start_plains(seed_value),"real formal seed starts")
		await wait_stage(app)
		check(app.stage is PlainsRegionStage,"map1 uses formal stage")
		if app.stage is PlainsRegionStage: check_live(app,1,seed_value,seed_value==seeds[0])
		app.lifetime.stage_epoch+=1
		app.lifetime.actor_epoch+=1
		_sync_fixture_map_index(app, 2)
		app.director._enter_stage(2,&"boss")
		app._stage_entered(DemoRunResult.new())
		await wait_stage(app)
		check(app.stage is PlainsRegionStage,"map2 uses formal stage")
		if app.stage is PlainsRegionStage: check_live(app,2,seed_value,seed_value==seeds[0])
		app.free()
		await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false,"intentional guard counterexample")
	var report := {"assertions":assertions,"failures":failures,"rows":rows,"camera_response_samples":camera_samples,"scope":"Actual10root x2map cosmetic consumer/isolated camera response and live Node counterexamples only; gameplay traversal/pixels/audio/device/aesthetics unverified"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report)+"\n")
		file.close()
	print("DIRECTED SPACE: %s assertions, %s failures"%[assertions,failures])
	quit(0 if failures==0 else 1)


func run() -> void:
	if OS.get_environment("PLAINS_LEGACY_WOODLAND_FIXTURE")=="1":
		await run_legacy()
	else:
		await run_default()

func woodland_source_nodes(node: Node) -> Array[String]:
	var found: Array[String] = []
	if node is Sprite2D:
		var texture := (node as Sprite2D).texture
		if texture!=null and PlainsSemanticLandscape.actual_texture_path(texture).contains("/woodland_two_depth_ridges_v1/"):
			found.append(str(node.get_path()))
	for child: Node in node.get_children(): found.append_array(woodland_source_nodes(child))
	return found

func stopped_woodland_issues(landscape: PlainsSemanticLandscape) -> Array[String]:
	var issues: Array[String] = []
	if landscape.entries.any(func(e: Dictionary) -> bool: return str(e.family.family_id)=="woodland_two_depth_ridges_v1"):
		issues.append("unqualified_woodland_entry_present")
	if not woodland_source_nodes(landscape).is_empty(): issues.append("unqualified_woodland_runtime_sprite_present")
	var omitted := landscape.omitted.filter(func(o: Dictionary) -> bool: return o.get("family_id","")=="woodland_two_depth_ridges_v1")
	if omitted.size()!=1 or omitted[0].get("reason","")!="default_consumer_stopped_exposed_source_cut":
		issues.append("woodland_stop_reason_missing_or_wrong")
	return issues

func expected_highland_slot(landscape: PlainsSemanticLandscape) -> bool:
	var family := PlainsSemanticLandscape.read_family("windmill_highland_v1")
	if not PlainsSemanticLandscape.contract_issues(family).is_empty(): return false
	var foot: Array = family.foundation_source_interval
	var width := (float(foot[1])-float(foot[0]))*float(family.world_width)/float(family.opaque_source_bounds[2])
	for entry: Dictionary in landscape.entries:
		if entry.family.family_id!="bank_shoulder_wide_v1": continue
		var support: Rect2 = entry.support
		var occupied: Rect2 = entry.bounds
		if minf(support.end.x,occupied.position.x-16.0)-support.position.x>=width+24.0: return true
	return false

func check_default(app: DemoApp, map_index: int, seed_value: String, thorough: bool) -> void:
	var stage := app.stage as PlainsRegionStage
	check(_fixture_identity_matches(app, map_index, seed_value), "actual stage/map/manifest seed+difficulty matches requested fixture")
	var before := JSON.stringify(stage.generated.manifest)
	var landscape := find_landscape(stage)
	check(landscape!=null,"default formal map has actual landscape consumer")
	if landscape==null: return
	check(not forbidden_descendant(landscape),"default display owns no collision/camera/gameplay authority")
	check(landscape.actual_issues().is_empty(),"default actual sources, roots and scales retain technical validity")
	check(stopped_woodland_issues(landscape).is_empty(),"default stops exposed-cut woodland with exact omission reason and no actual source sprites")
	var composition := landscape.get_parent() as PlainsRegionComposition
	check_ivy_attachments(composition)
	for family_id: String in ["windmill_repair_workshop_complete_v1","bank_shoulder_wide_v1","clock_regulator_court_v1"]:
		var preserved := landscape.entries.filter(func(e: Dictionary) -> bool: return str(e.family.family_id)==family_id)
		check(preserved.size()==1,"default preserves actual qualified limited consumer "+family_id)
		if preserved.size()==1:
			var entry: Dictionary = preserved[0]
			var sprite: Sprite2D = entry.sprite
			check(PlainsSemanticLandscape.actual_texture_path(sprite.texture)==str(entry.family.path),"retained actual Sprite2D uses the complete declared source "+family_id)
			check(float(entry.depth_factor)==0.0 and PlainsSemanticLandscape.effective_z(sprite)<0,"retained grounded source remains anchored behind gameplay "+family_id)
			check(not entry.support_members.is_empty(),"retained source owns measured real static support members "+family_id)
	var highlands := landscape.entries.filter(func(e: Dictionary) -> bool: return str(e.family.family_id)=="windmill_highland_v1")
	var omitted_highland := landscape.omitted.filter(func(o: Dictionary) -> bool: return o.get("family_id","")=="windmill_highland_v1")
	var slot := expected_highland_slot(landscape)
	check(OS.get_environment("PLAINS_HIGHLAND_PILOT")!="0","default suite actually enables the limited highland consumer")
	check(highlands.size()==(1 if slot else 0),"default limited highland follows measured free actual support availability")
	if slot:
		check(omitted_highland.is_empty(),"available highland support is consumed without contradictory omission")
		check(highlands[0].family.pilot_overrides.get("alternate_consumer","")=="complete146_world_highland_tower","default uses distinct complete146-world technical preview role")
	else:
		check(omitted_highland.size()==1 and omitted_highland[0].get("reason","")=="no_free_actual_highland_support_segment","unavailable highland has precise physical-support omission")
	var observer := stage.find_child("ActualLandscapeObserver",true,false) as PlainsLandscapeObserver
	check(observer!=null,"default actual read-only observer remains installed")
	if observer!=null:
		var measured := observer.measure()
		check(measured.nodes.size()==landscape.entries.size() and measured.issues.is_empty(),"default observer accounts for actual stopped and retained consumers")
	if thorough:
		var omission: Dictionary = landscape.omitted.filter(func(o: Dictionary) -> bool: return o.get("family_id","")=="woodland_two_depth_ridges_v1")[0]
		var old_reason: String = omission.reason
		omission.reason="unexplained_omission"
		check("woodland_stop_reason_missing_or_wrong" in stopped_woodland_issues(landscape),"actual wrong omission-reason counterexample is refused")
		omission.reason=old_reason
		var rogue := Sprite2D.new()
		rogue.texture=load("res://assets/region_production_v3/spaces/woodland_two_depth_ridges_v1/source.png") as Texture2D
		landscape.add_child(rogue)
		check("unqualified_woodland_runtime_sprite_present" in stopped_woodland_issues(landscape),"actual unregistered rejected-source Sprite2D counterexample is refused")
		rogue.free()
		check(stopped_woodland_issues(landscape).is_empty(),"restored default stop contract remains clean")
	check(JSON.stringify(stage.generated.manifest)==before,"default cosmetic consumer checks preserve exact formal Manifest")
	rows.append({"root_seed":seed_value,"map_index":map_index,"actual_map_index":stage.map_index,"actual_manifest_seed":stage.generated.manifest.seed,"actual_manifest_difficulty":stage.generated.manifest.difficulty,"manifest_hash":stage.generated.manifest.manifest_hash,"nodes":landscape.measured_nodes(),"omitted":landscape.omitted,"issues":landscape.actual_issues(),"expected_highland_slot":slot,"ivy_attachments":composition.compositions.filter(func(c: Dictionary) -> bool: return c.get("asset_id","")=="ivy"),"ivy_omitted":composition.ivy_omitted})

func run_default() -> void:
	var seeds: Array[String]=["level-design-v2-baseline","level-design-v2-baseline/01","level-design-v2-baseline/02","level-design-v2-baseline/03","level-design-v2-baseline/04","level-design-v2-baseline/05","level-design-v2-baseline/06","level-design-v2-baseline/07","level-design-v2-baseline/08","level-design-v2-baseline/09"]
	if "--single-seed" in OS.get_cmdline_user_args(): seeds.resize(1)
	for seed_value: String in seeds:
		var app := DemoApp.new()
		app.meta_persistence_enabled=false
		root.add_child(app)
		check(app.start_plains(seed_value),"default real formal seed starts")
		await wait_stage(app)
		check(app.stage is PlainsRegionStage,"default map1 uses formal stage")
		if app.stage is PlainsRegionStage: check_default(app,1,seed_value,seed_value==seeds[0])
		app.lifetime.stage_epoch+=1
		app.lifetime.actor_epoch+=1
		_sync_fixture_map_index(app, 2)
		app.director._enter_stage(2,&"boss")
		app._stage_entered(DemoRunResult.new())
		await wait_stage(app)
		check(app.stage is PlainsRegionStage,"default map2 uses formal stage")
		if app.stage is PlainsRegionStage: check_default(app,2,seed_value,seed_value==seeds[0])
		app.free()
		await process_frame
	if "--single-seed" not in OS.get_cmdline_user_args():
		check(_ivy_actual_seen>0,"actual20map candidate selection retains supported ivy rather than globally disabling it")
		check(_ivy_counterexample_done,"actual supported ivy detach and removed-support counterexamples exercised")
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false,"intentional default guard counterexample")
	var report := {"consumer_mode":"default_stopped_woodland_with_limited_highland","assertions":assertions,"failures":failures,"rows":rows,"scope":"Actual default10root x2map consumer stop/support checks and live counterexamples; no visual/commercial/route acceptance"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report)+"\n")
		file.close()
	print("DIRECTED SPACE: %s assertions, %s failures"%[assertions,failures])
	quit(0 if failures==0 else 1)


func check_ivy_attachments(composition: PlainsRegionComposition) -> void:
	check(composition!=null,"default uses actual composition hanging-foliage consumer")
	if composition==null: return
	check(composition.ivy_attachment_issues().is_empty(),"actual ivy heads attach to recorded unchanged static geometry and complete source")
	_ivy_actual_seen+=composition.hanging_ivy.size()
	for omitted: Dictionary in composition.ivy_omitted:
		check(omitted.reason in ["no_actual_static_underside","no_clear_protected_hanging_space"],"actual rejected ivy has a precise support/clearance reason")
	if composition.hanging_ivy.is_empty() or _ivy_counterexample_done: return
	var item: Dictionary = composition.hanging_ivy[0]
	var sprite: Sprite2D = item.sprite
	var position := sprite.global_position
	sprite.global_position+=Vector2(0,32)
	check("ivy_head_detached" in composition.ivy_attachment_issues(),"actual detached hanging head is diagnosed")
	sprite.global_position=position
	var surfaces := composition.ivy_surfaces()
	var removed: Array[Dictionary] = []
	for surface: Dictionary in surfaces:
		var body: StaticBody2D=surface.body
		removed.append({"body":body,"parent":body.get_parent(),"index":body.get_index()})
	for record: Dictionary in removed: record.parent.remove_child(record.body)
	check(composition.ivy_surfaces().is_empty(),"actual static PlatformN sources removed for no-support counterexample")
	check("ivy_actual_support_missing" in composition.ivy_attachment_issues(),"actual missing support cannot retain an apparently valid attachment")
	var no_solids: Array[Rect2] = []
	var no_support := composition.plan_hanging_ivy(composition.ivy_surfaces(),no_solids,item.anchor,130.0)
	check(not no_support.ok and no_support.reason=="no_actual_static_underside","actual source-free scene yields explicit omission rather than floating ivy")
	for record: Dictionary in removed:
		record.parent.add_child(record.body)
		record.parent.move_child(record.body,record.index)
	check(composition.ivy_attachment_issues().is_empty(),"restored actual support/head contract is clean")
	_ivy_counterexample_done=true


# Test-only independent-stage fixture; no natural campaign transition is claimed.
func _sync_fixture_map_index(app: DemoApp, index: int) -> void:
	for entry: Dictionary in app.director.get_property_list():
		if str(entry.get("name", "")) == "region_map_index":
			app.director.set("region_map_index", index)
			return

func _fixture_identity_matches(app: DemoApp, index: int, root_seed: String) -> bool:
	var actual := app.stage as PlainsRegionStage
	if actual == null or not actual.assembly_ok: return false
	var manifest: Dictionary = actual.generated.manifest
	return actual.map_index == index and manifest.get("region", "") == "plains" and manifest.get("seed", "") == PlainsRegionCampaign.seed_for(root_seed, index) and manifest.get("difficulty", "") == ("intro" if index == 1 else "advanced")
