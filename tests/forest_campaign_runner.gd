extends SceneTree
## Explicit settlement/transition fixture. No direct result call is traversal proof.
# Independent v2 playtest-default expectation; no commercial admission claim.
const EXPECTED_PUBLIC_FOREST := "thorn-forest-region-v2"
const EXPECTED_FOREST_BOSSES := {
	"thorn-forest-region-v1": {
		1: {"definition":"res://resources/bosses/thorn_guardian.tres","scene":"res://scenes/bosses/thorn_guardian.tscn"},
		2: {"definition":"res://resources/bosses/thorn_queen.tres","scene":"res://scenes/bosses/thorn_queen.tscn"}},
	"thorn-forest-region-v2": {
		1: {"definition":"res://resources/bosses/rootbell_guardian_v2.tres","scene":"res://scenes/bosses/rootbell_guardian_v2.tscn"},
		2: {"definition":"res://resources/bosses/thorn_queen_canopy.tres","scene":"res://scenes/bosses/thorn_queen_canopy.tscn"}}
}
var assertions := 0
var failures := 0
var pointer_events: Array[Dictionary] = []
var callback_counts := {"reward":0,"ability":0,"region":0}
var app: DemoApp
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func defeat_fixture() -> bool:
	var region := app.stage as PlainsRegionStage
	app.player.reset_at(region.boss_arena.get_center())
	await frames(3)
	if not app._boss_started: return false
	var boss := region.boss.get_node("Encounter") as BossEncounter
	var request := DamageRequest.new()
	request.token=app.lifetime.token()
	request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=boss.health.epoch
	request.target_id=&"boss"
	request.source_id=&"explicit_settlement_fixture"
	request.event_id=app._next_id("fixture_defeat")
	request.amount=boss.health.current
	if not app.policy.submit(request): return false
	await frames(65)
	return app.director.stage_complete
func gate_fixture() -> bool:
	app.player.reset_at(app.stage.reward_position)
	await frames(2)
	if app.exit_modal.opened: return app._confirm_generated_exit()
	return app._enter_generated_exit(&"boss_home")
func pointer_click(owner: Node, prefix: String) -> bool:
	for i: int in 4: await process_frame
	for button: Button in owner.find_children("*","Button",true,false):
		if not button.visible or button.disabled or not button.text.begins_with(prefix): continue
		var point := button.get_global_rect().get_center()
		for pressed: bool in [true,false]:
			var event := InputEventMouseButton.new()
			event.position=point
			event.global_position=point
			event.button_index=MOUSE_BUTTON_LEFT
			event.pressed=pressed
			pointer_events.append({"button":button.text,"pressed":pressed,"point":[point.x,point.y],"rect":[button.global_position.x,button.global_position.y,button.size.x,button.size.y]})
			root.push_input(event,true)
			await process_frame
		return true
	return false
func check_default_forest_identity(map_index: int) -> void:
	check_region_presentation(&"thorn_forest")
	check(app.stage is ThornForestRegionStage and is_instance_valid(app.stage.boss),"default forest actual stage and Boss exist")
	if not app.stage is ThornForestRegionStage or not is_instance_valid(app.stage.boss): return
	var expected: Dictionary=EXPECTED_FOREST_BOSSES[EXPECTED_PUBLIC_FOREST][map_index]
	var encounter := app.stage.boss.get_node("Encounter") as BossEncounter
	check(app.forest_content_version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.map_index==map_index,"natural region selection retains independently expected public forest version map%s"%map_index)
	check(encounter!=null and encounter.definition!=null and encounter.definition.resource_path==expected.definition,"natural default forest actual Boss Definition matches selected version map%s"%map_index)
	check(app.stage.boss.scene_file_path==expected.scene,"natural default forest actual Boss scene matches selected version map%s"%map_index)
	check(app.stage.generated.manifest.layout_version=="forest-fruit-routes-v14","fresh default uses independently expected fruit-routes layout; historical replay is separately mandatory")
func check_region_presentation(region: StringName) -> void:
	# Reuse actual consumers, not a second region transition implementation.
	# Existing Boss/reward reset_at fixtures remain explicit settlement evidence.
	var errors: Array[String] = load("res://tests/parallel_region_presentation_tests.gd").presentation_errors(app,region)
	check(errors.is_empty(),"actual shared presentation: %s" % [errors])
func run() -> void:
	app=DemoApp.new()
	app.meta_persistence_enabled=false
	root.add_child(app)
	app.reward_modal.item_selected.connect(func(_id: StringName) -> void: callback_counts.reward+=1)
	app.progression_modal.ability_selected.connect(func(_id: StringName) -> void: callback_counts.ability+=1)
	app.progression_modal.region_selected.connect(func(_id: StringName) -> void: callback_counts.region+=1)
	check(app.start_plains("campaign-integration"),"formal campaign starts plains map1")
	await frames(12)
	check(app.stage != null and app.stage.assembly_ok and app.director.region_map_index==1,"formal first map assembled")
	check_region_presentation(&"plains")
	if not is_instance_valid(app.stage) or not app.stage.assembly_ok: await finish(); return
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"schema1 Plains manifest roundtrip")
	check(await defeat_fixture(),"explicit Plains mini settlement fixture")
	check(await gate_fixture(),"formal mini gate accepts")
	await frames(12)
	check(app.director.region_map_index==2 and app.director.stage_index==2,"formal Plains map2 follows map1")
	check_region_presentation(&"plains")
	app.wallet.grant(31,&"fixture_initial_coins")
	var actor_id := app.player.get_instance_id()
	var health := app.controller.actor_resources.health
	check(await defeat_fixture(),"explicit policy fixture opens gold reward")
	check(await gate_fixture() and app.reward_modal.opened,"GOLD item remains separate panel")
	check(await pointer_click(app.reward_modal,"选择 / PICK") and app.progression_modal.opened,"actual mouse GOLD button settles before core choice")
	check(callback_counts.reward==1 and app.build.count_item(&"power_gold")==1,"one actual mouse reward callback and one gold instance")
	check(not app._claim_modal_item(&"power_gold") and app.build.count_item(&"power_gold")==1,"replayed settled gold cannot stack or submit again")
	check(not app.controller.traversal.hook_enabled,"gold item does not itself grant H")
	var old_token := app.lifetime.token()
	app._select_core_ability(&"wall_climb")
	check(not app.controller.traversal.wall_enabled,"unbuilt Canyon choice is rejected by owner")
	check(await pointer_click(app.progression_modal,"H / GRAPPLE"),"actual mouse selects H button")
	check(app.controller.traversal.hook_enabled and app.campaign.abilities==[&"grapple"],"formal core choice actually grants H")
	check(await pointer_click(app.progression_modal,"ENTER / THORN FOREST"),"actual mouse selects Forest button")
	await frames(12)
	check(callback_counts.ability==1 and callback_counts.region==1,"actual ability and region callbacks fire exactly once")
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok and app.active_region_id==&"thorn_forest","formal cross-region assembles forest")
	check_default_forest_identity(1)
	check(app.player.get_instance_id()==actor_id and app.controller.actor_resources.health==health and app.wallet.balance>=31,"same actor health coins persist across region")
	check(app.build.item_ids().has(&"power_gold") and app.controller.traversal.hook_enabled and not app.controller.traversal.wall_enabled and not app.controller.traversal.double_enabled,"build and H persist; no extra S2 abilities")
	check(not app.lifetime.accepts(old_token),"old region token rejected after crossing")
	write_fixture_evidence("res://build/forest_playable/progression/cross_region_manifest.json",app.director.manifest.canonical_json())
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"cross-region schema2 replay validates")
	check(RunManifest.from_snapshot(app.director.manifest.snapshot())!=null,"native campaign capability ledger roundtrip")
	var stale_snapshot := app.director.manifest.snapshot()
	stale_snapshot.stages.back().outputs.capability_snapshot.abilities=[]
	check(RunManifest.from_snapshot(stale_snapshot)==null,"forest without H provenance rejects")
	var malformed := app.director.manifest.snapshot()
	malformed.stages.back().outputs.capability_snapshot="invalid"
	check(RunManifest.from_snapshot(malformed)==null,"malformed capability rejected without runtime error")
	var fractional := app.director.manifest.snapshot()
	fractional.stages.back().outputs.region_map.map_index=1.5
	check(RunManifest.from_snapshot(fractional)==null,"fractional map identity cannot truncate to valid map")
	var forged_boss := app.director.manifest.snapshot()
	forged_boss.stages.back().outputs.boss_layout.health=1
	check(RunManifest.from_snapshot(forged_boss)==null,"boss definition identity cannot be forged")
	check(await defeat_fixture(),"forest mini policy fixture completes")
	check(await gate_fixture(),"forest mini gate accepts")
	await frames(12)
	check(app.stage is ThornForestRegionStage and app.director.region_map_index==2 and app.director.stage_index==4,"formal four maps preserve distinct global entries")
	check_default_forest_identity(2)
	check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"forest second map replay validates")
	check(await defeat_fixture(),"forest final fixture completes")
	check(await gate_fixture() and await pointer_click(app.reward_modal,"选择 / PICK"),"actual mouse claims independent forest gold reward")
	check(await pointer_click(app.progression_modal,"D / DOUBLE JUMP"),"actual mouse selects legal D reward")
	check(app.controller.traversal.double_enabled and app.campaign.phase==RunCampaignProgression.Phase.BOUNDARY,"forest awards legal missing D and explicit S3 boundary")
	check(await pointer_click(app.progression_modal,"END THIS RUN"),"actual mouse confirms explicit end boundary")
	await frames(5)
	check(app.director.state==DemoRunDirector.State.HOME and app.wallet.balance==0 and app.build.item_ids().is_empty() and app.campaign.abilities.is_empty(),"boundary ends run and clears coins/build/abilities")
	var presentation_home_errors: Array[String] = load("res://tests/parallel_region_presentation_tests.gd").home_errors(app)
	check(presentation_home_errors.is_empty(),"campaign Home has no stale presentation owner: %s" % [presentation_home_errors])
	await finish()
func finish() -> void:
	write_fixture_evidence("res://build/forest_playable/progression/campaign_pointer_events.json",JSON.stringify({"scope":"Godot real Viewport mouse press/release into actual Button; boss outcomes explicit fixtures; no OS/Web pointer claim","events":pointer_events,"callbacks":callback_counts,"assertions":assertions,"failures":failures}))
	paused=false
	if is_instance_valid(app):
		if not await load("res://tests/audio_teardown.gd").drain_world(app): failures += 1
		app.free()
	print("FOREST CAMPAIGN: %s assertions / %s failures" % [assertions,failures])
	quit(1 if failures else 0)

func write_fixture_evidence(path: String, content: String) -> void:
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	check(directory_error==OK,"fixture evidence output directory is available")
	if directory_error!=OK: return
	var output := FileAccess.open(path,FileAccess.WRITE)
	check(output!=null,"fixture evidence output file opens")
	if output==null: return
	output.store_string(content)
	output.close()
