extends SceneTree
const FIXTURE := preload("res://tests/legacy_plains_presentation_fixture.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("SMOKE FAIL: ",label)
func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline/08"),"real original first terrain seed starts")
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage: break
	check(FIXTURE.pixel_default(app),"actual initial stage remains formal pixel")
	var record: Dictionary = FIXTURE.prepare(app,"terrain_family")
	check(record.get("pixel_default_before",false),"default pixel captured before fixture")
	check(record.get("no_flag_and_wrong_profile_refused_without_mutation",false),"missing/wrong profile truly refused")
	check(record.get("installed",false) and record.get("unchanged",false),"actual physics/manifest/tuning unchanged on real install")
	var stage := app.stage as PlainsRegionStage
	check(stage.terrain_art.art.has_meta("family_entries"),"actual historical terrain factory consumed")
	check(not stage.terrain_art.art.get_meta("family_entries",[]).is_empty(),"real representative source entries exist")
	check(PlainsTerrainFamilySampler.actual_issues(stage.terrain_art.art).is_empty(),"original real source/Atlas/boundary diagnostics clean")
	var convex := ConvexPolygonShape2D.new()
	convex.points = PackedVector2Array([Vector2(0,0),Vector2(10,0),Vector2(10,10)])
	var signature: Dictionary = FIXTURE._shape_geometry(convex)
	var bounds: Rect2 = convex.get_rect()
	convex.points = PackedVector2Array([Vector2(0,0),Vector2(0,10),Vector2(10,10)])
	check(convex.get_rect() == bounds and FIXTURE._shape_geometry(convex) != signature,"same-AABB changed convex points changes signature")
	var audio := get_first_node_in_group(&"game_audio") as GameAudio
	check(audio != null and await audio.shutdown(),"real audio cleanup")
	app.free()
	app = null
	convex = null
	for unused: int in 3:
		await physics_frame
		await process_frame
	var file := FileAccess.open("res://build/integration01/legacy-fixture-typed02/first-stage-native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"fixture":record,"scope":"first actual terrain map1 only; original four suites, routes, GPU and independent review not executed"})+"\n")
	file.close()
	print("FIRST ACTUAL LEGACY FIXTURE SMOKE: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
