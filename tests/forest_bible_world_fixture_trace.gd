extends "res://tests/forest_bible_world_trace.gd"
## Explicit initial-spawn local feedback; never fullspawn or formal route evidence.
var fixture_kind := "connection"
var return_mode := "short"
var fixture_data: Dictionary = {}
func begin() -> void:
	air_chain_case = preload("res://tests/forest_bible_world_air_case.gd").new()
	interwoven_crown_case = preload("res://tests/forest_bible_world_crown_combat_case.gd").new()
	grove_combat_case = preload("res://tests/forest_bible_world_grove_combat_case.gd").new()
	app = preload("res://tests/forest_bible_world_fixture_app.gd").new()
	app.meta_persistence_enabled = false
	add_child(app)
	if not app.start_debug_region(&"thorn_forest",map_index,seed_value,ThornForestRegionGenerator.DEPTH_VERSION,"forest-bible-world-v15"):
		fail("fixture_formal_debug_entry_rejected"); setup_done = true; return
	for unused: int in 8: await get_tree().physics_frame
	fixture_data = app.fixture_data.duplicate(true)
	if not app.fixture_error.is_empty(): fail(app.fixture_error); setup_done = true; return
	stage = app.stage
	if not is_instance_valid(stage) or not stage.assembly_ok: fail("fixture_actual_assembly_failed"); setup_done = true; return
	player = app.player; controller = app.controller
	manifest = stage.generated.manifest.duplicate(true)
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	var route_ids: Array = ["bible_root_mouth_exit"] + ThornForestRegionV2V10._route(manifest,str(manifest.bible_world_contract.actual_receiver),"camp") if fixture_kind == "connection" else ["bible_web_lower_out","bible_web_to_backbranch","bible_backbranch_flight"] + (manifest.routes.bible_backbranch_short_return if return_mode == "short" else manifest.routes.bible_backbranch_return)
	_build_bible_itinerary(route_ids)
	controller.traversal.action_changed.connect(_hook_event)
	controller.jump_ability.jumped.connect(func() -> void: event("jumped"))
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2,serial: int) -> void:
		event("shot_fired",{"aim":pair(aim),"serial":serial}); observe_actual_projectile(serial))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results: event("committed_damage",{"target":String(result.request.target_id),"source":String(result.request.source_id),"amount":result.request.amount,"lethal":result.lethal,"event_id":String(result.request.event_id),"health_after":result.health.current if result.health != null else -1.0}))
	initial = snapshot()
	var observer := Observer.new(); observer.trace = self; observer.process_physics_priority = 1100; add_child(observer)
	initialized = true; setup_done = true
