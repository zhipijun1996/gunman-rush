extends SceneTree
## Separate historical-resource defect regression; not architecture equivalence.
const AUDIO := preload("res://tests/audio_teardown.gd")
const HISTORICAL_SHA := "1afd5e34d497e3850d794b028fd5fe5407d3722fcd451d862f4c14a67ca98fc0"
const CURRENT_SHA := "39513bce9f2d604514a88838d733db24b723ce965402ce5579e8260f5a83a232"
var assertions := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		push_error("FOREST V11 DEFINITION: "+label)

func frames(count: int) -> void:
	for _index: int in count: await physics_frame

func check_motor(motor: EnemyMotor, expected: Vector2, label: String) -> void:
	check(motor!=null,label+": actual factory returns a Motor")
	if motor==null: return
	var actor := motor.get_node("Actor") as EnemyActor
	var shape := (motor.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(actor.definition.collision_size==expected and shape!=null and shape.size==expected,label+": actual Definition and installed collision agree")

func run() -> void:
	var registry := ThornForestRegionGenerator.new()
	var tuning := PlayerTuning.load_default()
	var legacy_path := EnemyBehaviorRegistry.definition_path(&"charger",HISTORICAL_SHA)
	check(not legacy_path.is_empty() and FileAccess.get_sha256(legacy_path)==HISTORICAL_SHA,"retained historical resource has original exact bytes")
	check(FileAccess.get_sha256(EnemyBehaviorRegistry.definition_path(&"charger"))==CURRENT_SHA,"current registry default retains PR122 exact bytes")
	check(EnemyBehaviorRegistry.definition_path(&"charger","unknown").is_empty() and EnemyFactory.definition_for_behavior(&"charger",{},"unknown")==null and EnemyFactory.create_for_behavior(&"charger",{},"unknown")==null,"unknown revision cannot fall back to current Definition")
	check(EnemyFactory.definition_for_behavior(&"sentry",{},HISTORICAL_SHA)==null,"historical charger revision cannot select another behavior")
	var invalid_source := ThornForestRegionV2V10.new()
	invalid_source.charger_definition_revision="unknown"
	check(not invalid_source.generate("unknown-revision",tuning,1,{"grapple":true,"abilities":["grapple"]}).ok,"unknown explicit generation revision rejects before content production")
	for map_index: int in [1,2]:
		var path := "res://tests/fixtures/forest_recorded_layouts/v11_corpus_map%s.json" % map_index
		var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var capabilities := {"grapple":true,"abilities":["grapple"],"forest_layout_version":ThornForestRegionGenerator.DEPTH_LAYOUT_EXPEDITION}
		var rebuilt := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,original.seed,tuning,map_index,capabilities)
		check(rebuilt.ok and RandomStageGenerator.new()._same_data(original,rebuilt.get("manifest",{})),"entire original v11 fixture and hash reproduced map%s" % map_index)
		check(registry.validate(original,tuning),"original v11 fixture passes strict version validator map%s" % map_index)
		var repeated := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,original.seed,tuning,map_index,capabilities)
		check(rebuilt.ok and repeated.ok and JSON.stringify(rebuilt.manifest)==JSON.stringify(repeated.manifest),"repeated v11 generation keeps all RNG and serialized ordering map%s" % map_index)
		if not rebuilt.ok: continue
		var adapted := LegacyRegionPlanAdapter.generated(rebuilt,tuning,map_index,true)
		check(adapted.accepted(),"original v11 output enters the real LevelPlan adapter")
		if not adapted.accepted(): continue
		for row: Dictionary in adapted.plan.actors:
			if row.behavior_id!=&"charger": continue
			check(row.get("definition_revision")==HISTORICAL_SHA,"v11 charger placement resolves its recorded Definition revision")
			row.definition_revision="unknown"
			check(not adapted.plan.validation_error().is_empty() and LevelRuntime.create_actor(row)==null,"unknown plan revision rejected by validator and actual factory consumer")
			row.definition_revision=HISTORICAL_SHA
	var world := Node2D.new()
	root.add_child(world)
	var current := EnemyFactory.create_for_behavior(&"charger")
	var historical := EnemyFactory.create_for_behavior(&"charger",{},HISTORICAL_SHA)
	if current!=null: world.add_child(current)
	if historical!=null: world.add_child(historical)
	check_motor(current,Vector2(28,28),"current factory")
	check_motor(historical,Vector2(28,32),"explicit historical factory")
	world.free()
	var app := DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	await frames(2)
	check(app.start_debug_region(&"thorn_forest",1,"forest-depth-hollow-00",ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_EXPEDITION),"actual historical v11 departure accepted")
	for _attempt: int in 90:
		await physics_frame
		if is_instance_valid(app.stage) and not app._stage_pending and is_instance_valid(app.policy): break
	var stage := app.stage as ThornForestRegionStage
	check(stage!=null and stage.assembly_ok,"actual v11 App assembles without rewriting recorded content")
	var found := false
	if stage!=null:
		check(stage.generated.manifest.manifest_hash=="90c82712ddc732a0545e951dc30785b1dde3efa2be56b8ce847252c47000d0f9","actual v11 App binds exact old map hash")
		for index: int in stage.enemies.size():
			if stage.enemy_manifest[index].behavior_id!="charger": continue
			found=true
			check_motor(stage.enemies[index],Vector2(28,32),"real v11 Stage charger")
	check(found,"original map1 charger is present in real Stage")
	app.abandon_run()
	await frames(8)
	check(app.start_debug_region(&"thorn_forest",1,"forest-depth-hollow-00"),"actual current forest departure accepted")
	for _attempt: int in 90:
		await physics_frame
		if is_instance_valid(app.stage) and not app._stage_pending and is_instance_valid(app.policy): break
	stage=app.stage as ThornForestRegionStage
	check(stage!=null and stage.assembly_ok and stage.generated.manifest.layout_version==ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT,"current forest retains selected v15 layout")
	if stage!=null:
		for row: Dictionary in stage.level_plan.actors:
			check(not row.has("definition_revision"),"current forest does not inherit historical revision selection")
		var current_actor := EnemyFactory.create_for_behavior(&"charger")
		stage.add_child(current_actor)
		check_motor(current_actor,Vector2(28,28),"current forest host default factory")
	app.abandon_run()
	await frames(8)
	check(await AUDIO.drain_world(app),"actual App audio drains")
	app.free()
	await frames(2)
	print("FOREST V11 DEFINITION: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures==0 else 1)
