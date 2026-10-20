extends SceneTree
## Entry/ledger/UI lifecycle fixture; movement and browser acceptance have separate runners.
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
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func check_default_forest_identity(app: Node,map_index: int) -> void:
	check(app.stage is ThornForestRegionStage and is_instance_valid(app.stage.boss),"debug default forest actual stage and Boss exist")
	if not app.stage is ThornForestRegionStage or not is_instance_valid(app.stage.boss): return
	var expected: Dictionary=EXPECTED_FOREST_BOSSES[EXPECTED_PUBLIC_FOREST][map_index]
	var encounter := app.stage.boss.get_node("Encounter") as BossEncounter
	check(app.forest_content_version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.version==EXPECTED_PUBLIC_FOREST and app.stage.generated.manifest.map_index==map_index,"unversioned debug entry uses independently expected public forest version map%s"%map_index)
	check(encounter!=null and encounter.definition!=null and encounter.definition.resource_path==expected.definition,"debug default forest actual Boss Definition matches selected version map%s"%map_index)
	check(app.stage.boss.scene_file_path==expected.scene,"debug default forest actual Boss scene matches selected version map%s"%map_index)
	check(app.stage.generated.manifest.layout_version=="forest-fruit-routes-v14","fresh default uses independently expected fruit-routes layout; historical replay is separately mandatory")
func run() -> void:
	for region: StringName in [&"plains",&"thorn_forest"]:
		for map_index: int in [1,2]:
			var app := DemoApp.new()
			app.meta_persistence_enabled=false
			root.add_child(app)
			check(app.start_debug_region(region,map_index,"debug-lifecycle"),"debug request accepts supported map")
			await frames(10)
			check(is_instance_valid(app.stage) and app.stage.assembly_ok,"debug map actually assembles")
			if region == &"thorn_forest": check(not app._boss_status.visible,"inactive forest boss cannot show a false attack warning during exploration")
			if region == &"thorn_forest": check_default_forest_identity(app,map_index)
			check(app.director.region_map_index==map_index and app.active_region_id==region,"debug local identity matches actual stage")
			check(app.controller.traversal.hook_enabled==(region==&"thorn_forest") and not app.controller.traversal.wall_enabled and not app.controller.traversal.double_enabled,"debug forest grants H only; plains grants no abilities")
			check(app.campaign.completed_regions.is_empty() and app.campaign.debug_entry,"debug entry fabricates no natural completions")
			check(RunManifest.from_snapshot(JSON.parse_string(app.director.manifest.canonical_json()))!=null,"debug manifest roundtrip")
			var snapshot := app.director.manifest.snapshot()
			check(snapshot.stages[0].outputs.debug_entry.natural_progression==false,"debug provenance is explicit")
			check(app.open_region_map() and paused,"map UI pauses forest/plains")
			app.close_region_map()
			check(not paused and app.controller.active,"closing map resumes actual actor")
			app.abandon_run()
			await frames(5)
			check(app.director.state==DemoRunDirector.State.HOME,"debug abandonment returns home")
			if not await load("res://tests/audio_teardown.gd").drain_world(app): failures+=1
			app.free()
	print("FOREST DEBUG: %s assertions / %s failures" % [assertions,failures])
	quit(1 if failures else 0)
