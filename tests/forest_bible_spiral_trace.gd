extends "res://tests/forest_bible_world_trace.gd"
## One F08 journey. All rewards use real visible Reader buttons and App queue.
var local_fixture := false
var fixture_data: Dictionary = {}
var core_evidence: Dictionary = {}
var core_modal_frames: Array[Dictionary] = []
var _core_state := "bank"
var _core_ui_age := 0
var _core_done := false
var _core_actor_epoch := -1
var _core_damage_before := 0.0
var _core_count_before := 0
var _core_actual_receipt: Dictionary = {}

func begin() -> void:
	if not local_fixture:
		await super.begin()
	else:
		air_chain_case = preload("res://tests/forest_bible_world_air_case.gd").new()
		interwoven_crown_case = preload("res://tests/forest_bible_world_crown_combat_case.gd").new()
		grove_combat_case = preload("res://tests/forest_bible_world_grove_combat_case.gd").new()
		app = preload("res://tests/forest_bible_spiral_fixture_app.gd").new()
		app.meta_persistence_enabled = false
		add_child(app)
		if not app.start_debug_region(&"thorn_forest",2,seed_value,ThornForestRegionGenerator.DEPTH_VERSION,"forest-bible-world-v15"):
			fail("spiral_fixture_formal_debug_entry_rejected"); setup_done = true; return
		for unused: int in 8: await get_tree().physics_frame
		fixture_data = app.fixture_data.duplicate(true)
		if not app.fixture_error.is_empty(): fail(app.fixture_error); setup_done = true; return
		stage = app.stage
		if not is_instance_valid(stage) or not stage.assembly_ok: fail("spiral_fixture_actual_assembly_failed"); setup_done = true; return
		player = app.player; controller = app.controller
		manifest = stage.generated.manifest.duplicate(true)
		player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
		_build_bible_itinerary(["interwoven_deep_ascent"] + manifest.routes.bible_spiral_return)
		controller.traversal.action_changed.connect(_hook_event)
		controller.jump_ability.jumped.connect(func() -> void: event("jumped"))
		controller.shoot_ability.shot_fired.connect(func(aim: Vector2,serial: int) -> void:
			event("shot_fired",{"aim":pair(aim),"serial":serial}); observe_actual_projectile(serial))
		app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
			for result: DamageResult in results: event("committed_damage",{"target":String(result.request.target_id),"source":String(result.request.source_id),"amount":result.request.amount,"lethal":result.lethal,"event_id":String(result.request.event_id),"health_after":result.health.current if result.health != null else -1.0}))
		initial = snapshot()
		var observer := Observer.new(); observer.trace = self; observer.process_physics_priority = 1100; add_child(observer)
		initialized = true; setup_done = true
	if not initialized or not failures.is_empty(): return
	if stage.discoveries == null: fail("spiral_actual_reader_missing"); return
	stage.discoveries.acquired.connect(func(receipt: Dictionary) -> void:
		if str(receipt.get("id","")) == "forest_spiral_core": _core_actual_receipt = receipt.duplicate(true))

func _physics_process(delta: float) -> void:
	if initialized and not finished and (not is_instance_valid(player) or not is_instance_valid(controller) or not is_instance_valid(stage)):
		fail("spiral_actual_actor_or_stage_unloaded"); return
	if initialized and not finished and leg_index < itinerary.size() and bool(itinerary[leg_index].get("bible_spiral_reader",false)) and not _core_done:
		if get_tree().paused: return
		tick += 1; age += 1; before_steps = player.motion_steps
		if tick > 18000 or tick-leg_started > 1800: fail("spiral_reader_original_route_budget"); return
		if not app.lifetime.active or controller.actor_resources.health.terminal: fail("spiral_reader_run_ended"); return
		if not _aim_kind.is_empty(): fail("spiral_reader_pending_air_intent"); return
		jump(false)
		if _core_state == "bank":
			# x400..430 is on the solid root, west of thread start470 with
			# full 24x36 body and 8px line radius clearance. No NPC is changed.
			var bank := point(itinerary[leg_index].landing)
			controller.router.set_move_axis(clampf((bank.x-player.global_position.x)/12.0,-1.0,1.0))
			stable = stable+1 if at_destination(bank,"hollow__inner_root") else 0
			if stable >= 12:
				controller.router.set_move_axis(0)
				if stage.discoveries.nearby(player.global_position) != "forest_spiral_core": fail("spiral_actual_nearby_predicate_missing"); return
				_core_actor_epoch = int(app.lifetime.actor_epoch)
				_core_damage_before = player.tuning.projectile_damage
				_core_count_before = app.build.count_item(&"forest_spiral_core")
				_core_state = "open"; _core_ui_age = 0
				event("spiral_actual_reader_bank",{"position":pair(player.global_position),"supports":supports(),"core_distance":player.global_position.distance_to(Vector2(460,802))})
		else:
			controller.router.set_move_axis(0)
			if int(app.lifetime.actor_epoch) != _core_actor_epoch: fail("spiral_reader_actor_epoch_changed")
		return
	super._physics_process(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if not initialized or finished or _core_done or _core_state == "bank": return
	_core_ui_age += 1
	if _core_ui_age > 90: fail("spiral_actual_reader_pointer_budget/"+_core_state); return
	if not app.lifetime.active or int(app.lifetime.actor_epoch) != _core_actor_epoch or controller.actor_resources.health.terminal:
		fail("spiral_reader_lifetime_changed"); return
	if get_tree().paused:
		core_modal_frames.append({"tick":tick,"motion_steps":player.motion_steps,"state":_core_state,"process_frame":Engine.get_process_frames(),"paused":get_tree().paused,"position":pair(player.global_position),"actor_epoch":app.lifetime.actor_epoch,"stage_epoch":app.lifetime.stage_epoch})
		movie_stamp(core_modal_frames[-1])
	if _core_state == "open":
		if _core_ui_age == 4:
			var button: Button
			for node: Node in app._actions.find_children("*","Button",true,false):
				var candidate := node as Button
				if candidate != null and candidate.text == "查看发现物" and candidate.is_visible_in_tree(): button = candidate; break
			_core_pointer(button,true)
		elif _core_ui_age == 5: _core_pointer(modal_button,false)
		if stage.discoveries.is_open(): _core_state = "confirm"; _core_ui_age = 0
	elif _core_state == "confirm":
		if not stage.discoveries.is_open() or not get_tree().paused: fail("spiral_reader_did_not_pause_visible_page"); return
		if _core_ui_age == 4: _core_pointer(stage.discoveries._confirm,true)
		elif _core_ui_age == 5:
			_core_pointer(modal_button,false)
			_core_state = "commit"; _core_ui_age = 0
	elif _core_state == "commit" and stage.region_state.claimed.get("forest_spiral_core",false):
		var count_after: int = app.build.count_item(&"forest_spiral_core")
		var damage_after: float = player.tuning.projectile_damage
		if stage.discoveries.is_open() or get_tree().paused or count_after != _core_count_before+1 or not is_equal_approx(damage_after,_core_damage_before+1.5) or _core_actual_receipt.get("item") != "forest_spiral_core":
			fail("spiral_actual_queued_item_effect_missing"); return
		core_evidence = {"id":"forest_spiral_core","position":pair(player.global_position),"actual_receipt":_core_actual_receipt.duplicate(true),"item_count_before":_core_count_before,"item_count_after":count_after,"projectile_damage_before":_core_damage_before,"projectile_damage_after":damage_after,"claim_via_real_Reader_buttons_and_App_postdamage_queue":true,"direct_claim_or_grant":false}
		event("spiral_actual_queued_item_accepted",core_evidence)
		_core_done = true; _core_state = "done"

func _core_pointer(button: Button, pressed: bool) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
		fail("spiral_actual_visible_button_missing/"+_core_state); return
	modal_button = button; modal_point = button.get_global_rect().get_center()
	if not get_viewport().get_visible_rect().has_point(modal_point): fail("spiral_actual_button_outside_viewport"); return
	send_pointer(pressed)
