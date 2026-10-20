extends Node
const OLD_HASH := "e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
var reporter: WeakRef
# Data validation and the actual world use the same Scripts without a static
# dependency from this scene consumer back into the complete Manifest graph.
func data_script(path: String) -> Script:
	return load(path) as Script
func check(ok: bool,label: String) -> void:reporter.get_ref().check(ok,label)
func frames(n: int) -> void:
	for i: int in n:await get_tree().physics_frame;await get_tree().process_frame
func run(region: String,map_index: int) -> void:
	var label := region+"/map%s" % map_index
	var root_seed := "aim-save-compat"
	var expected: Dictionary
	if region=="thorn_forest":
		expected=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/forest_recorded_layouts/v11_corpus_map%s.json" % map_index))
		root_seed=str(expected.seed).split("/thorn_forest/")[0]
	else:
		var generator =data_script("res://scripts/generation/plains_region_generator.gd").new();generator.root_bell_mode="v3"
		expected=generator.generate_before_focus_15(data_script("res://scripts/run/plains_region_campaign.gd").seed_for(root_seed,map_index),data_script("res://scripts/player/player_tuning.gd").load_default(),false,"","intro" if map_index==1 else "advanced").manifest
	var state =data_script("res://scripts/run/plains_region_state.gd").new()
	check(state.bind_map(expected.manifest_hash),label+" initialize exact historical map hash")
	state.claimed["historical_claim"]=true
	state.opened["historical_open"]=true
	state.mechanisms["historical_switch"]={"open":true}
	var encoded_state: Dictionary=JSON.parse_string(JSON.stringify(state.snapshot()))
	var restored =data_script("res://scripts/run/plains_region_state.gd").new()
	check(restored.restore(encoded_state,expected.manifest_hash),label+" serialized map state restores")
	var app:=DemoApp.new();app.meta_persistence_enabled=false
	get_tree().root.add_child(app)
	check(app.start_debug_region(StringName(region),map_index,root_seed),label+" actual debug loader starts")
	check(app.build.add_item(&"saved_item",load("res://resources/items/damage_blue.tres")),label+" legitimate item applied through BuildState before load")
	app.region_states[1]=restored
	await frames(10)
	check(app.stage is PlainsRegionStage and app.stage.assembly_ok,label+" actual historical saved stage assembles")
	if not app.stage is PlainsRegionStage or not app.stage.assembly_ok:
		await dispose(app);return
	var actual: Dictionary=app.stage.generated.manifest
	check(data_script("res://scripts/generation/random_stage_generator.gd").new()._same_data(actual,expected),label+" exact historical full manifest hash seed geometry retained")
	check(app.region_state==restored and restored.claimed.has("historical_claim") and restored.opened.has("historical_open") and restored.mechanisms.get("historical_switch")=={"open":true},label+" saved state identity and claims retained")
	check(app.controller.motor.tuning.focus_time_scale==0.15,label+" actual restored runtime focus is fifteen percent")
	var fresh: Dictionary=JSON.parse_string(app.director.manifest.canonical_json())
	check(fresh.stages[0].outputs.stage_tuning.focus_time_scale==0.15 and data_script("res://scripts/run/run_manifest.gd").from_snapshot(fresh)!=null,label+" freshly recorded historical map runs at .15 and validates")
	var historical:=fresh.duplicate(true)
	historical.stages[0].outputs.stage_tuning.focus_time_scale=0.2
	var canonical_before:=JSON.stringify(historical,"",true)
	var decoded =data_script("res://scripts/run/run_manifest.gd").from_snapshot(historical)
	check(decoded!=null,label+" original twenty percent stage tuning accepted only for known historical hash")
	check(JSON.stringify(historical,"",true)==canonical_before and decoded!=null and decoded.canonical_json()==canonical_before,label+" replay leaves entire historical metadata unchanged")
	for mutation: String in ["focus","physics","hash","items","missing","extra","current_hash_old_focus"]:
		var bad:=historical.duplicate(true)
		var output: Dictionary=bad.stages[0].outputs
		match mutation:
			"focus":output.stage_tuning.focus_time_scale=0.19
			"physics":output.stage_tuning.gravity+=1
			"hash":output.generated_layout.player_tuning_hash="a".repeat(64);output.generated_layout.manifest_hash=data_script("res://scripts/generation/random_stage_generator.gd").new()._manifest_hash(output.generated_layout)
			"items":output.capability_snapshot.items=["missing_item"]
			"missing":output.stage_tuning.erase("focus_time_scale")
			"extra":output.stage_tuning.unknown_physics=1
			"current_hash_old_focus":output.generated_layout.player_tuning_hash=FileAccess.get_sha256("res://config/player_tuning.json");output.generated_layout.manifest_hash=data_script("res://scripts/generation/random_stage_generator.gd").new()._manifest_hash(output.generated_layout)
		check(data_script("res://scripts/run/run_manifest.gd").from_snapshot(bad)==null,label+" tampering rejects "+mutation)
	var actor:=app.stage.enemies[0].get_node("Actor") as EnemyActor
	var saved_health:=actor.health.current-1.0
	check(saved_health>0 and actor.restore_instance_health(saved_health),label+" prepare actual nondefault enemy health")
	app.stage.capture_state()
	var actors_before: Dictionary =restored.actors.duplicate(true)
	var health:=app.controller.actor_resources.health
	check(health.apply_damage(ActorResourceRequest.new(&"save_fixture_damage",health.epoch,1.0,health.get_instance_id())).accepted(),label+" nondefault player health prepared by real resource transaction")
	var items_before:=app.build.item_ids()
	var damage_before: float=app.controller.motor.tuning.projectile_damage
	var hp: float=app.controller.actor_resources.health.current
	var energy: float=app.controller.actor_resources.stamina.current
	await app._load_stage()
	var reloaded:=app.stage.enemies[0].get_node("Actor") as EnemyActor
	check(reloaded!=actor and reloaded.health.current==saved_health and restored.actors==actors_before,label+" second actual reload preserves enemy health and all actor records")
	check(app.controller.motor.tuning.focus_time_scale==0.15 and app.controller.actor_resources.health.current==hp and app.controller.actor_resources.stamina.current==energy,label+" actual reload retains resources and current focus")
	check(app.build.item_ids()==items_before and items_before==[&"damage_blue"] and app.controller.motor.tuning.projectile_damage==damage_before,label+" actual reload preserves earned item provenance and modified value")
	reporter.get_ref().cases.append({"region":region,"map":map_index,"seed":expected.seed,"historical_hash":expected.manifest_hash,"historical_snapshot":historical,"current_snapshot":fresh,"state_before":encoded_state,"state_after":restored.snapshot(),"runtime_focus":app.controller.motor.tuning.focus_time_scale})
	await dispose(app)
func invalid_state(region: String,kind: String) -> void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false
	get_tree().root.add_child(app)
	var state =data_script("res://scripts/run/plains_region_state.gd").new()
	state.manifest_hash="0".repeat(64) if kind=="zero" else FileAccess.get_sha256("res://config/player_tuning.json") if kind=="config_sha" else "foreign/"+"a".repeat(64)
	state.claimed["must_not_clear"]=true
	var original_hash: String =state.manifest_hash
	check(app.start_debug_region(StringName(region),1,"invalid-save-state"),region+" invalid saved state request starts "+kind)
	app.region_states[1]=state
	await frames(10)
	check(app.director.state==DemoRunDirector.State.HOME,region+" actual loader fails closed on invalid map hash "+kind)
	check(state.manifest_hash==original_hash and state.claimed.has("must_not_clear"),region+" rejected map retains original evidence ledger "+kind)
	await dispose(app)
func dispose(app: DemoApp) -> void:
	var owners := {}
	for label: String in ["app","menu","stage","player","controller"]:
		var value: Object = app if label=="app" else app.get(label)
		owners[label] = weakref(value) if is_instance_valid(value) else null
		value = null
	app.abandon_run();await frames(4)
	check(await load("res://tests/audio_teardown.gd").drain_world(app),"actual owned audio drains")
	app.free();await frames(2)
	var released := {}
	for label: String in owners:
		var reference: WeakRef = owners[label]
		released[label] = reference == null or reference.get_ref() == null
		if not released[label]:check(false,"actual owned "+label+" released after existing teardown")
	reporter.get_ref().owner_observations.append({"kind":"actual_app_teardown","released":released})
