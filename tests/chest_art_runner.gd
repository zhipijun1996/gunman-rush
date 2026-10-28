extends SceneTree
## Six real presentation recipes and controlled formal-region claim/reload.
var checks := 0
var failures := 0
var region_completion: Dictionary = {}
var region_phases: Dictionary = {}
var live_apps: Array[DemoApp] = []
var pose_cases: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("CHEST ART FAILURE: "+label)

func check_sprite(sprite: Sprite2D, foot: Vector2, tier: StringName, claimed: bool) -> void:
	var row := ChestArtLibrary.pose(tier,claimed)
	check(not row.is_empty(),"actual sprite has a valid admitted recipe")
	if row.is_empty(): return
	check(sprite.texture == ChestArtLibrary.texture(tier,claimed),"actual sprite selects explicit tier and actual claimed pose")
	check(sprite.position == foot and not sprite.centered,"source pivot is anchored at unchanged caller world foot")
	check(sprite.modulate == Color.WHITE,"claimed art keeps original opaque color")
	check(sprite.material == ChestArtLibrary.world_material(),"actual Sprite2D keeps the REGION_RECT-safe 1wu material")
	check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"actual Sprite2D nearest filter")
	var expected := -Vector2(float(row.foot_pivot_source_px[0]),float(row.foot_pivot_source_px[1]))
	check(sprite.offset == expected and is_equal_approx(sprite.scale.x,sprite.scale.y),"actual source foot and isotropic source aspect preserved")
	pose_cases[String(tier)+("/open" if claimed else "/closed")] = true

func frames(count: int) -> void:
	for unused: int in count:
		await physics_frame
		await process_frame

func release_app(app: DemoApp) -> bool:
	# Also called by the outer owner when an inner coroutine fails to finish.
	live_apps.erase(app)
	paused = false
	app.abandon_run()
	var drained: bool = await load("res://tests/audio_teardown.gd").drain_world(app)
	app.free()
	for unused: int in 3: await process_frame
	return drained

func phase(region: StringName, name: String, ok: bool, label: String) -> void:
	region_phases[String(region)][name] = ok
	check(ok,label)

func formal_region(region: StringName) -> void:
	region_completion[String(region)] = false
	region_phases[String(region)] = {}
	var app := DemoApp.new()
	live_apps.append(app)
	app.meta_persistence_enabled = false
	root.add_child(app)
	# Match the existing forest_bible_integration_runner controlled consumer.
	# A pinned v15 reload fixture is distinct from natural campaign traversal.
	var version := ThornForestRegionGenerator.DEPTH_VERSION if region == &"thorn_forest" else ""
	var layout := ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE if region == &"thorn_forest" else ""
	var entered := app.start_debug_region(region,1,"chest-art-formal-"+String(region),version,layout)
	phase(region,"entry",entered,"actual region enters through existing explicit debug fixture")
	await frames(8)
	var stage := app.stage as PlainsRegionStage
	check(stage != null and stage.assembly_ok and not stage.chests.is_empty(),"actual formal region contains unchanged reward rows")
	if not entered or stage == null or not stage.assembly_ok or stage.chests.is_empty():
		phase(region,"cleanup",await release_app(app),"rejected fixture cleans actual audio")
		return
	if stage is ThornForestRegionStage:
		check(stage.generated.manifest.layout_version == ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE,"controlled forest consumer explicitly uses current v15 layout")
	var before_manifest := JSON.stringify(stage.generated.manifest)
	for actual: Dictionary in stage.chests:
		if stage is ThornForestRegionStage:
			check(is_instance_valid(stage.chest_art_layer) and stage.chest_art_layer.material == ChestArtLibrary.world_material(),"actual forest owns a dedicated world-material chest layer")
			check(stage.chest_art_layer.chests.has(actual) and not actual.has("sprite"),"actual forest uses its existing rows exactly once, without a second chest sprite")
		else:
			check_sprite(actual.sprite,actual.position+Vector2(0,21),StringName(str(actual.tier)),bool(actual.claimed))
	var chest: Dictionary = stage.chests[0]
	var id := str(chest.id)
	app.player.global_position = chest.position+Vector2(-65,0)
	app._region_interact()
	phase(region,"offer",app.reward_modal.opened and not chest.claimed,"real offer opening leaves actual chest closed")
	phase(region,"denied",not app._claim_region_chest(&"missing-invalid-option") and not chest.claimed,"real denied choice leaves actual chest closed")
	var accepted := false
	if app.reward_modal.opened and app._region_offer != null and not app._region_offer.candidates.is_empty():
		var choice := (app._region_offer.candidates[0] as ItemDefinition).stable_id
		accepted = app._claim_region_chest(choice)
		phase(region,"claim",accepted,"real original reward transaction accepts one valid choice")
		stage.capture_state()
		phase(region,"ledger",chest.claimed and stage.region_state.claimed.has(id),"actual accepted transaction owns claimed ledger")
		if not stage is ThornForestRegionStage: check_sprite(chest.sprite,chest.position+Vector2(0,21),StringName(str(chest.tier)),true)
	else:
		phase(region,"claim",false,"actual reward candidates must exist before accepting a choice")
	check(JSON.stringify(stage.generated.manifest) == before_manifest,"art refresh and actual claim do not rewrite generated Manifest")
	if not accepted:
		phase(region,"cleanup",await release_app(app),"unaccepted fixture cleans actual audio")
		return
	# The established forest restore fixture pauses before snapshot/reload so
	# the newly constructed stage cannot capture unbound enemy behavior during
	# App's intentional physics-frame await. Do not modify gameplay to fake this.
	app._pause_for_menu()
	stage.capture_state()
	await app._load_stage()
	stage = app.stage as PlainsRegionStage
	check(stage != null and stage.assembly_ok,"actual reload returns a complete formal stage")
	if stage == null or not stage.assembly_ok:
		phase(region,"reload",false,"actual reload must complete before inspecting restored chests")
		phase(region,"cleanup",await release_app(app),"failed reload cleans actual audio")
		return
	var restored := false
	for actual: Dictionary in stage.chests:
		if str(actual.id) == id:
			restored = bool(actual.claimed)
			if not stage is ThornForestRegionStage: check_sprite(actual.sprite,actual.position+Vector2(0,21),StringName(str(actual.tier)),true)
	phase(region,"reload",restored,"actual stage reload restores accepted claimed state through existing ledger")
	phase(region,"cleanup",await release_app(app),"actual formal application drains audio")
	var complete := true
	for required: String in ["entry","offer","denied","claim","ledger","reload","cleanup"]:
		complete = complete and bool(region_phases[String(region)].get(required,false))
	region_completion[String(region)] = complete

func run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	check(bool(ChestArtLibrary.diagnostics().valid),"admitted configuration validates against immutable original atlas")
	if not bool(ChestArtLibrary.diagnostics().valid):
		check(await audio.shutdown(),"failed configuration drains audio")
		audio.free()
		quit(1)
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ChestArtLibrary.CONFIG_PATH))
	var invalid: Dictionary = config.duplicate(true)
	invalid.tiers.medium.states.open.world_size[0] *= 1.1
	invalid.tiers.medium.states.open.world_size[1] *= 1.1
	check("share one" in ChestArtLibrary.validate_config(invalid),"independently rescaled open pose is rejected without modifying actual data")
	invalid = config.duplicate(true)
	invalid.aliases["unknown"] = "region_top"
	check(not ChestArtLibrary.validate_config(invalid).is_empty(),"unknown tiers cannot be silently promoted through extra aliases")
	for tier: StringName in ChestArtLibrary.TIERS:
		var sprite := Sprite2D.new()
		var foot := Vector2(80.25,200.25)
		var original_factor := -1.0
		for claimed: bool in [false,true,false,true]:
			UnderworldObjects.place_chest(sprite,foot,claimed,tier)
			check_sprite(sprite,foot,tier,claimed)
			if original_factor < 0: original_factor = sprite.scale.x
			check(is_equal_approx(sprite.scale.x,original_factor),"repeated closed/open selection retains exact common pair factor")
		sprite.free()
	check(ChestArtLibrary.texture(&"hard_optional",false) == ChestArtLibrary.texture(&"region_top",false),"explicit legacy resource alias shares only top-tier visuals")
	var bad := Sprite2D.new()
	UnderworldObjects.place_chest(bad,Vector2.ZERO,false,&"unregistered-tier")
	check(bad.texture == null and bool(bad.get_meta("chest_art_managed",false)),"unknown explicit tier fails closed and cannot be replaced by opt-in cosmetic art")
	check("Unknown explicit" in str(ChestArtLibrary.diagnostics().last_error),"unknown tier has a clear diagnostic")
	bad.free()
	await formal_region(&"plains")
	await formal_region(&"thorn_forest")
	# An interrupted inner coroutine must not print success or leak its App.
	while not live_apps.is_empty():
		var unfinished: DemoApp = live_apps.back()
		check(false,"formal region coroutine returned before releasing its owned application")
		check(await release_app(unfinished),"outer owner releases incomplete formal fixture audio")
	for region: String in ["plains","thorn_forest"]:
		check(bool(region_completion.get(region,false)),"required formal region completed all real claim/reload/cleanup phases: "+region)
		for required: String in ["entry","offer","denied","claim","ledger","reload","cleanup"]:
			check(bool(region_phases.get(region,{}).get(required,false)),"required actual formal check completed: "+region+"/"+required)
	for tier: StringName in ChestArtLibrary.TIERS:
		for state: String in ["closed","open"]:
			check(bool(pose_cases.get(String(tier)+"/"+state,false)),"required six-pose sprite check completed: "+String(tier)+"/"+state)
	check(await audio.shutdown(),"actual mixer shutdown completes")
	audio.free()
	ChestArtLibrary.clear_cache()
	print("CHEST ART: %d checks, %d failures"%[checks,failures])
	quit(0 if failures == 0 else 1)
