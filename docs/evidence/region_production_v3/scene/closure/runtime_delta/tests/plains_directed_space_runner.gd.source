extends SceneTree
## Real DemoApp consumer and deliberate live-Node counterexamples.
## No traversal, pixels, performance, audio, device or aesthetic acceptance.
var assertions := 0
var failures := 0
var output := ""
var rows: Array[Dictionary] = []

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

func check_live(app: DemoApp, map_index: int) -> void:
	var stage := app.stage as PlainsRegionStage
	var before := JSON.stringify(stage.generated.manifest)
	var landscape := find_landscape(stage)
	check(landscape!=null,"formal map has actual directed consumer")
	if landscape==null: return
	check(not forbidden_descendant(landscape),"presentation contains no collision/camera/gameplay authority")
	check(landscape.entries.size()==2,"two independent delivered family pilots exist; missing art cannot be filled by props")
	check(landscape.actual_issues().is_empty(),"real roots, sources, scales and depths are valid: "+str(landscape.actual_issues()))
	check(landscape.omitted.any(func(o: Dictionary) -> bool: return str(o.get("identity",""))=="clock_court"),"missing third family explicitly remains uncovered")
	var seen: Array[String] = []
	for entry: Dictionary in landscape.entries:
		var family: Dictionary=entry.family
		var sprite: Sprite2D=entry.sprite
		check(str(family.family_id) not in seen,"at most one visible pilot per family")
		seen.append(str(family.family_id))
		check(sprite.texture is Texture2D and not sprite.texture is AtlasTexture,"complete actual source texture retains roof and roots")
		check(float(entry.depth_factor)==0.0,"current family roots remain world anchored")
		check(landscape.replaces_area(str(entry.area_id)),"actual visible replacement owns only its area")
		check(entry.protected_overlap_candidates is Array,"protected gameplay candidates preserved for pixel review")
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
		var body := landscape.get_node(str(entry.attachment_node_path)) as Node2D
		var body_position := body.position
		body.position.y+=64.0
		check("actual_foundation_geometry_changed" in landscape.actual_issues(),"actual supporting-body displacement rejected")
		body.position=body_position
		check(landscape.actual_issues().is_empty(),"restored real consumer clean after mutations")
		var malformed := family.duplicate(true)
		malformed["depth_factor"]=0.2
		check("grounded_foundation_cannot_parallax" in PlainsSemanticLandscape.contract_issues(malformed),"grounded artwork cannot be floated with camera")
	# A translated visual parent must not detach world-rooted artwork.
	var parent := Node2D.new()
	parent.position=Vector2(240,-90)
	parent.z_index=-15
	stage.add_child(parent)
	var translated := PlainsSemanticLandscape.new()
	translated.configure(stage,landscape.supports,landscape.protected_regions)
	parent.add_child(translated)
	check(translated.entries.size()==landscape.entries.size(),"translated parent retains actual family coverage")
	check(translated.actual_issues().is_empty(),"translated parent preserves actual root/world transforms")
	for index: int in mini(translated.entries.size(),landscape.entries.size()):
		var a: Sprite2D=translated.entries[index].sprite
		var b: Sprite2D=landscape.entries[index].sprite
		check(a.global_position.is_equal_approx(b.global_position),"translated-parent world placement remains identical")
	parent.free()
	rows.append({"map_index":map_index,"manifest_hash":stage.generated.manifest.manifest_hash,"family":stage.generated.manifest.family,"nodes":landscape.measured_nodes(),"omitted":landscape.omitted,"issues":landscape.actual_issues()})
	check(JSON.stringify(stage.generated.manifest)==before,"all display/mutation checks preserve exact formal Manifest")

func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline"),"real formal baseline starts")
	await wait_stage(app)
	check(app.stage is PlainsRegionStage,"map1 uses formal stage")
	if app.stage is PlainsRegionStage: check_live(app,1)
	app.lifetime.stage_epoch+=1
	app.lifetime.actor_epoch+=1
	app.director._enter_stage(2,&"boss")
	app._stage_entered(DemoRunResult.new())
	await wait_stage(app)
	check(app.stage is PlainsRegionStage,"map2 uses formal stage")
	if app.stage is PlainsRegionStage: check_live(app,2)
	app.free()
	await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false,"intentional guard counterexample")
	var report := {"assertions":assertions,"failures":failures,"rows":rows,"scope":"Actual formal two-map cosmetic consumer and live Node counterexamples only; traversal/pixels/dynamic/audio/device/aesthetics unverified"}
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report)+"\n")
		file.close()
	print("DIRECTED SPACE: %s assertions, %s failures"%[assertions,failures])
	quit(0 if failures==0 else 1)
