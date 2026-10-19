extends SceneTree
const FIXTURE := preload("res://tests/legacy_plains_presentation_fixture.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("SMOKE FAIL: ",label)
func wait_stage(app: DemoApp, index: int) -> void:
	for unused: int in 120:
		await physics_frame
		await process_frame
		if not app._stage_pending and app.stage is PlainsRegionStage and app.stage.map_index == index: return
func run() -> void:
	var app := DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_plains("level-design-v2-baseline"),"real original waterworks seed starts")
	await wait_stage(app,1)
	app.lifetime.stage_epoch += 1
	app.lifetime.actor_epoch += 1
	app.director.region_map_index = 2
	app.director._enter_stage(2,&"boss")
	app._stage_entered(DemoRunResult.new())
	await wait_stage(app,2)
	var record: Dictionary = FIXTURE.prepare(app,"waterworks")
	check(record.get("pixel_default_before",false),"real target stage starts current pixel")
	check(record.get("no_flag_and_wrong_profile_refused_without_mutation",false),"missing/wrong profile refused")
	check(record.get("installed",false) and record.get("unchanged",false),"waterworks installation preserves actual physics/manifest/tuning")
	var space := app.stage.find_child("CreekWaterworksSpace",true,false) as PlainsVisualSpace
	check(space != null,"actual explicit waterworks consumer exists")
	if space != null:
		check(space.actual_issues().is_empty(),"actual source/attachment issues clean")
		space._update_bank_materials()
		check(space.bank_material_issues().is_empty(),"actual bank material scopes clean")
		var ferry: ModuleMovingPlatform = space.source_module.moving_platforms[0]
		check(ferry.painted_art != null and ferry.painted_art.get_child_count() > 0,"actual ferry has historical shader quads")
		var material := ferry.painted_art.get_child(0).material as ShaderMaterial
		check(material != null and material.get_shader_parameter("body_local_material") == true,"real ferry shader uses body-local coordinates")
		material.set_shader_parameter("well_bank_enabled",true)
		check("moving_ferry_material_incorrectly_graded_as_bank" in space.bank_material_issues(),"original real ferry_graded counterexample detectable")
		material.set_shader_parameter("well_bank_enabled",false)
		check(space.bank_material_issues().is_empty(),"restored ferry material remains clean")
	var audio := get_first_node_in_group(&"game_audio") as GameAudio
	check(audio != null and await audio.shutdown(),"actual audio cleanup")
	app.free()
	app = null
	space = null
	for unused: int in 3:
		await physics_frame
		await process_frame
	var file := FileAccess.open("res://build/integration01/legacy-fixture-waterworks03/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"fixture":record,"scope":"one explicit actual map2 waterworks/ferry smoke only; not original full suites/GPU"})+"\n")
	file.close()
	print("ACTUAL LEGACY WATERWORKS SMOKE: ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
