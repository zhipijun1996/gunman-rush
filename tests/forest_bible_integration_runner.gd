extends SceneTree
## Real v15 App/stage restore boundaries; no traversal or tamper-proof save claim.
const AUDIO := preload("res://tests/audio_teardown.gd")
const WEAVER_ID := "bible_double_window_weaver"
var assertions := 0
var failures := 0
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var output := "res://build/region_bible_v2/ecology/integration"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1
	checks.append({"label":label,"passed":ok})
	print("FOREST BIBLE INTEGRATION CHECK: ","PASS " if ok else "FAIL ",label)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func find_weaver(stage: ThornForestRegionStage) -> EnemyActor:
	for index: int in stage.enemy_manifest.size():
		if stage.enemy_manifest[index].id == WEAVER_ID:
			return stage.enemies[index].get_node("Actor") as EnemyActor
	return null

func consume_state(generated: Dictionary, tuning: PlayerTuning, saved: Dictionary) -> ThornForestRegionStage:
	var state := PlainsRegionState.new()
	check(state.restore(saved,str(generated.manifest.manifest_hash)),"detached region envelope restored for actual stage consumer")
	var stage := ThornForestRegionStage.new()
	stage.region_state = state
	stage.map_index = 1
	stage.configure_generated(generated.duplicate(true),tuning)
	root.add_child(stage)
	return stage

func release_stage(stage: ThornForestRegionStage) -> void:
	var receipt := AUDIO.stop_fallback_voices(stage)
	stage.free()
	check(await AUDIO.wait_fallback_release(receipt),"temporary actual stage releases owned audio")

func outer_refusal_cases(generated: Dictionary, tuning: PlayerTuning, saved: Dictionary) -> void:
	var control := consume_state(generated,tuning,saved)
	check(control.assembly_ok and find_weaver(control) != null,"unmodified outer record passes same actual assembler and stage guards")
	cases.append({"id":"outer_positive_control","accepted":control.assembly_ok,"manifest_hash":generated.manifest.manifest_hash})
	await release_stage(control)
	var mutations: Array[Dictionary] = []
	for field: String in ["health","position","state","state_time","cooldown","serial","home","direction","depth_state"]:
		var error := "Recorded rooted actor phase rejected"
		if field in ["position","depth_state"]: error = "Recorded migration actor shape rejected"
		elif field == "health": error = "Recorded migration actor number rejected"
		elif field in ["state_time","cooldown"]: error = "Recorded rooted actor phase number rejected"
		mutations.append({"id":"missing_"+field,"field":field,"remove":true,"error":error})
	for mutation: Dictionary in [{"id":"serial_fraction","field":"serial","value":1.25},{"id":"serial_string","field":"serial","value":"1"}]:
		mutation.error = "Recorded rooted actor phase rejected"
		mutations.append(mutation)
	for field: String in ["state_time","cooldown"]:
		mutations.append({"id":field+"_string","field":field,"value":"0.1","error":"Recorded rooted actor phase number rejected"})
	for mutation: Dictionary in mutations:
		var edited := saved.duplicate(true)
		var actor_record: Dictionary = edited.actors[WEAVER_ID]
		if mutation.get("remove",false): actor_record.erase(mutation.field)
		else: actor_record[mutation.field] = mutation.value
		# Keep the exact expected engine refusal in the native log. The CLI admits
		# only these lines, once each, alongside the complete passing ledger.
		print("FOREST BIBLE EXPECTED REFUSAL: ",mutation.id," / ",mutation.error)
		var stage := consume_state(generated,tuning,edited)
		var rejected := not stage.assembly_ok
		check(rejected,"actual stage refuses outer "+str(mutation.id)+" before App coercion")
		cases.append({"id":mutation.id,"rejected":rejected,"expected_error":mutation.error})
		await release_stage(stage)

func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",1,"forest-bible-integration",ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE),"actual debug entry explicitly pins v15")
	await frames(8)
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok,"actual DemoApp assembles v15 stage")
	if app.stage is ThornForestRegionStage and app.stage.assembly_ok:
		var stage := app.stage as ThornForestRegionStage
		var actor := find_weaver(stage)
		check(actor != null and actor.attack_behavior is ForestBibleWeaverBehavior,"actual scene lookup and shared EnemyActor dispatch instantiate new behavior")
		if actor != null and actor.attack_behavior is ForestBibleWeaverBehavior:
			app._pause_for_menu()
			var weaver := actor.attack_behavior as ForestBibleWeaverBehavior
			var row: Dictionary = stage.enemy_manifest.filter(func(value: Dictionary) -> bool: return value.id == WEAVER_ID)[0]
			check(stage.generated.manifest.layout_version == ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE,"actual manifest remains v15")
			check(actor.motor.scene_file_path == "res://game/enemies/species/scenes/forest_bible_weaver.tscn" and actor.definition.behavior_id == &"forest_bible_weaver","actual scene and definition identity agree")
			check(weaver.line_configured and weaver.strand_rows == row.web_strands and weaver.strand_rows.size() == 2,"type-first App configure uses both authored strands without legacy line fallback")
			var configured := weaver.depth_snapshot()
			cases.append({"id":"app_configure","layout":stage.generated.manifest.layout_version,"scene":actor.motor.scene_file_path,"behavior":str(actor.definition.behavior_id),"strands":weaver.strand_rows.duplicate(true),"configured":weaver.line_configured})
			stage.capture_state()
			var saved := app.region_state.snapshot()
			var generated := stage.generated.duplicate(true)
			check(saved.actors[WEAVER_ID].depth_state == configured,"actual stage capture binds outer record to new depth state")
			await outer_refusal_cases(generated,app.controller.motor.tuning,saved)
			var old_stage_id := stage.get_instance_id()
			await app._load_stage()
			var restored_stage := app.stage as ThornForestRegionStage
			var restored_actor := find_weaver(restored_stage) if restored_stage != null else null
			check(restored_stage != null and restored_stage.assembly_ok and restored_stage.get_instance_id() != old_stage_id,"real App unload and reload creates another assembled v15 stage")
			check(restored_actor != null and restored_actor.attack_behavior is ForestBibleWeaverBehavior,"real reload redispatches new behavior")
			var retained := restored_actor != null and restored_actor.attack_behavior is ForestBibleWeaverBehavior and (restored_actor.attack_behavior as ForestBibleWeaverBehavior).depth_snapshot() == configured
			check(retained,"real App reload retains geometry selection clocks serial and dedup exactly")
			cases.append({"id":"app_reload","retained":retained})
	paused = false
	app.abandon_run()
	await frames(4)
	check(app.director.state == DemoRunDirector.State.HOME,"integration cleanup returns real App HOME")
	check(await AUDIO.drain_world(app),"integration App audio actually drained")
	app.free()
	await frames(2)
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	if file == null:
		push_error("Forest Bible integration capture could not be written")
		quit(1)
		return
	file.store_string(JSON.stringify({"scope":"actual v15 App dispatch/configure/reload and stage outer-field refusal; no traversal or empty-actors integrity claim","assertions":assertions,"failures":failures,"checks":checks,"cases":cases},"  "))
	file.close()
	print("FOREST BIBLE INTEGRATION: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
