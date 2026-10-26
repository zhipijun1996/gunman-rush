extends SceneTree

const GEAR := preload("res://tests/gear_inventory_support.gd")
## Actual App UI fixture. One explicit pose before the first Motor step; no route proof.
const AUDIO := preload("res://tests/audio_teardown.gd")
const PRODUCER := preload("res://scripts/generation/thorn_forest_region_v2_v15.gd")
const BADGE := "forest_old_badge"
var assertions := 0
var failures := 0
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var clicks: Array[Dictionary] = []
var seed_candidates: Array[Dictionary] = []
var staged: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var output := "res://build/region_bible_v2/discoveries/app"
var selected_seed := ""

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1
	checks.append({"label":label,"passed":ok})
	print("FOREST BIBLE APP DISCOVERY CHECK: ","PASS " if ok else "FAIL ",label)

func frames(count: int = 3) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func choose_fixture_seed() -> String:
	# Bounded geometry precondition selection, before any App/input assertion.
	# A failure after selection is retained; this is never a retry-on-failure loop.
	for index: int in 16:
		var root_seed: String = "forest-depth-hollow-%02d" % index
		var manifest: Dictionary = PRODUCER.new()._candidate(root_seed+"/thorn_forest/map_2",2)
		var west: bool = bool(manifest.choices.get("west_reward",false))
		seed_candidates.append({"seed":root_seed,"west_reward":west,"manifest_hash":manifest.manifest_hash})
		if west: return root_seed
	return ""

func button_text(scope: Node, value: String) -> Button:
	for node: Node in scope.find_children("*","Button",true,false):
		var button: Button = node as Button
		if button.text == value and button.is_visible_in_tree(): return button
	return null

func click(button: Button, label: String) -> bool:
	await frames()
	check(is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled,"visible enabled native button / "+label)
	if not is_instance_valid(button): return false
	var point: Vector2 = button.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"button center lies in actual viewport / "+label)
	var presses: Array = []
	button.pressed.connect(func() -> void: presses.append(Engine.get_process_frames()))
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	Input.parse_input_event(move)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await frames(2)
	check(presses.size() == 1,"real viewport press/release reaches exactly one intended button / "+label)
	clicks.append({"label":label,"point":[point.x,point.y],"pressed_count":presses.size()})
	return presses.size() == 1

func key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)

func setup_app(label: String) -> DemoApp:
	var app: DemoApp = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",2,selected_seed,ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE),"actual App pins v15 map2 / "+label)
	if is_instance_valid(app.player): app.player.process_mode = Node.PROCESS_MODE_DISABLED
	for index: int in 120:
		if not app._stage_pending: break
		await frames(1)
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok and not app._stage_pending,"actual App stage ready / "+label)
	if not app.stage is ThornForestRegionStage: return app
	var stage: ThornForestRegionStage = app.stage as ThornForestRegionStage
	var rows: Array = stage.generated.manifest.forest_discoveries.filter(func(row: Dictionary) -> bool: return row.id == BADGE)
	check(stage.generated.manifest.choices.get("west_reward",false) and rows.size() == 1,"actual generated west-reward badge precondition / "+label)
	if rows.size() != 1: return app
	var row: Dictionary = rows[0]
	var point: Vector2 = Vector2(row.position[0],row.position[1])
	var colocated: bool = stage.chests.any(func(chest: Dictionary) -> bool: return chest.position == point and not chest.claimed)
	check(colocated,"actual existing cache and new discovery are colocated / "+label)
	var steps: int = app.player.motion_steps
	check(steps == 0,"UI staging occurs before first PlayerMotor step / "+label)
	app.player.global_position = point
	app._run_camera.snap_to_target()
	app._run_camera.force_update_scroll()
	staged.append({"case":label,"map":2,"seed":selected_seed,"manifest_hash":stage.generated.manifest.manifest_hash,"position":[point.x,point.y],"prior_motor_steps":steps,"purpose":"UI staging only; no approach or route evidence"})
	app.controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, serial: int) -> void: shots.append({"case":label,"serial":serial}))
	app.player.process_mode = Node.PROCESS_MODE_PAUSABLE
	await frames(5)
	check(stage.discoveries != null and stage.discoveries.nearby(app.player.global_position) == BADGE and stage.nearby_chest(app.player.global_position) >= 0,"both actual interaction predicates hold after normal Motor resumes / "+label)
	check(button_text(app._actions,"OPEN CACHE / CHOOSE REWARD") != null and button_text(app._actions,"查看发现物") != null,"actual root shows separate cache and discovery buttons / "+label)
	return app

func claim_badge(app: DemoApp, label: String) -> bool:
	var stage: ThornForestRegionStage = app.stage as ThornForestRegionStage
	var reader: ForestBibleDiscoveries = stage.discoveries
	var before: float = app.controller.actor_resources.health.capacity
	await click(button_text(app._actions,"查看发现物"),label+"/read")
	check(reader.is_open() and paused and not app.reward_modal.opened,"discovery button opens actual paused reader / "+label)
	if not reader.is_open(): return false
	await click(reader._confirm,label+"/confirm")
	var accepted: bool = stage.region_state.claimed.get(BADGE,false) == true and app.build.count_item(&"forest_old_badge") == 1 and app.controller.actor_resources.health.capacity == before
	check(accepted and not reader.is_open() and not paused,"actual queued reader commits one backpack badge without auto-applying / "+label)
	if accepted:
		app.toggle_pause()
		check(paused and GEAR.equip_all(app.build) and app.controller.actor_resources.health.capacity == before + 2.0,"paused equipment command applies the claimed real badge effect / "+label)
		app.menu.close_panel()
	return accepted

func claim_cache(app: DemoApp, label: String) -> bool:
	var stage: ThornForestRegionStage = app.stage as ThornForestRegionStage
	var index: int = stage.nearby_chest(app.player.global_position)
	check(index >= 0,"actual cache remains reachable / "+label)
	if index < 0: return false
	var chest: Dictionary = stage.chests[index]
	var before: int = app.wallet.balance
	await click(button_text(app._actions,"OPEN CACHE / CHOOSE REWARD"),label+"/cache")
	check(app.reward_modal.opened and paused and not stage.discoveries.is_open(),"cache button opens actual reward page instead of reader / "+label)
	if not app.reward_modal.opened: return false
	var choice: ResourceRewardChoice
	for candidate: ItemDefinition in app._region_offer.candidates:
		if candidate is ResourceRewardChoice and (candidate as ResourceRewardChoice).resource_kind == "coin": choice = candidate
	check(choice != null,"actual cache exposes a coin resource choice / "+label)
	if choice == null: return false
	var amount: int = choice.amount
	await click(button_text(app.reward_modal._root,"选择 / PICK "+choice.display_name),label+"/pick_coin")
	var accepted: bool = stage.region_state.claimed.get(chest.id,false) == true and chest.claimed and app.wallet.balance == before+amount
	check(accepted and not paused and not app.reward_modal.opened,"actual cache selection commits its unique wallet grant / "+label)
	return accepted

func dispose(app: DemoApp) -> void:
	if app.lifetime.active: app.abandon_run()
	paused = false
	await frames(4)
	check(app.director.state == DemoRunDirector.State.HOME,"actual App returns HOME during teardown")
	check(await AUDIO.drain_world(app),"actual App audio drained")
	app.free()
	await frames(2)

func order_case(read_first: bool) -> void:
	var label: String = "read_then_cache" if read_first else "cache_then_read"
	var app: DemoApp = await setup_app(label)
	var accepted: bool = false
	if app.stage is ThornForestRegionStage and app.stage.assembly_ok:
		var first: bool
		var second: bool
		if read_first:
			first = await claim_badge(app,label)
			second = await claim_cache(app,label)
		else:
			first = await claim_cache(app,label)
			second = await claim_badge(app,label)
		accepted = first and second
		var reader: ForestBibleDiscoveries = (app.stage as ThornForestRegionStage).discoveries
		var capacity: float = app.controller.actor_resources.health.capacity
		var balance: int = app.wallet.balance
		await click(button_text(app._actions,"查看发现物"),label+"/repeat")
		check(reader.is_open() and reader.is_claimed(BADGE),"claimed discovery remains separately readable / "+label)
		await key(KEY_ESCAPE,true)
		await key(KEY_ESCAPE,false)
		check(not reader.is_open() and not paused and app.menu.visible_panel.is_empty(),"Escape closes reader without opening pause menu / "+label)
		await key(KEY_W,true)
		check(reader.is_open() and paused,"first W after reader close reaches actual discovery interaction / "+label)
		await key(KEY_W,false)
		await key(KEY_ESCAPE,true)
		await key(KEY_ESCAPE,false)
		await key(KEY_W,true)
		check(reader.is_open() and paused,"first W after a covered W release also works / "+label)
		await key(KEY_W,false)
		await key(KEY_ESCAPE,true)
		await key(KEY_ESCAPE,false)
		check(app.wallet.balance == balance and app.controller.actor_resources.health.capacity == capacity and app.build.count_item(&"forest_old_badge") == 1,"repeat reading and Escape never duplicate actual rewards / "+label)
	cases.append({"id":label,"accepted_both":accepted})
	await dispose(app)

func fatal_confirm_case() -> void:
	var app: DemoApp = await setup_app("fatal_confirm")
	var committed: Array[Dictionary] = []
	var outcomes: Array[Dictionary] = []
	var enqueue: Array[Dictionary] = []
	var state: PlainsRegionState = app.region_state
	if app.stage is ThornForestRegionStage and app.stage.assembly_ok:
		# Wait out the ordinary production spawn protection; never modify its clock.
		await frames(45)
		var reader: ForestBibleDiscoveries = (app.stage as ThornForestRegionStage).discoveries
		reader.acquired.connect(func(receipt: Dictionary) -> void: committed.append(receipt.duplicate(true)))
		app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
			for result: DamageResult in results:
				if result.request.event_id == &"forest_app_fixture_fatal": outcomes.append({"event_id":str(result.request.event_id),"lethal":result.lethal,"health":result.health.current,"tick":Engine.get_physics_frames()}))
		await click(button_text(app._actions,"查看发现物"),"fatal_confirm/read")
		check(reader.is_open() and paused,"fatal control begins from a real reader page")
		reader.confirm_requested.connect(func() -> void:
			var request: DamageRequest = DamageRequest.new()
			request.token = app.lifetime.token()
			request.event_id = &"forest_app_fixture_fatal"
			request.source_id = &"fixture_synthetic_same_frame_contact"
			request.target_id = &"player"
			request.kind = DamageRequest.Kind.ENVIRONMENT
			request.amount = 999.0
			request.actor_epoch = app.lifetime.actor_epoch
			request.health_epoch = app.controller.actor_resources.health.epoch
			enqueue.append({"process_frame":Engine.get_process_frames(),"queued_claims":app._queued_actions.size(),"damage_accepted":app.policy.submit(request)}))
		if reader.is_open(): await click(reader._confirm,"fatal_confirm/confirm")
		await frames(5)
	var denied: bool = enqueue.size() == 1 and enqueue[0].damage_accepted and enqueue[0].queued_claims == 1 and outcomes.size() == 1 and outcomes[0].lethal and outcomes[0].health == 0 and committed.is_empty() and not state.claimed.has(BADGE)
	check(denied,"same-confirmation damage batch ends run before actual queued discovery acquisition")
	check(app.director.state == DemoRunDirector.State.HOME and not app.lifetime.active,"fatal confirmation cleans up to HOME")
	cases.append({"id":"fatal_confirm","denied":denied,"enqueue":enqueue,"outcomes":outcomes,"acquired":committed,"damage_scope":"synthetic request via original FrameDamagePolicy, not real-enemy battle evidence"})
	await dispose(app)

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	selected_seed = choose_fixture_seed()
	check(not selected_seed.is_empty(),"bounded preflight finds the actual colocation geometry before UI cases")
	if not selected_seed.is_empty():
		await order_case(true)
		await order_case(false)
		await fatal_confirm_case()
	check(shots.is_empty(),"reader and reward UI mouse/key events do not emit gameplay shots")
	DirAccess.make_dir_recursive_absolute(output)
	var file: FileAccess = FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	if file == null:
		push_error("Forest Bible App discovery capture could not be written")
		quit(1)
		return
	file.store_string(JSON.stringify({"scope":"actual v15 DemoApp UI staging only, no Motor route/art/device admission","assertions":assertions,"failures":failures,"checks":checks,"cases":cases,"clicks":clicks,"seed_candidates":seed_candidates,"staged":staged,"shots":shots,"viewport":[1280,720],"position_staging":true,"resource_injection":false,"synthetic_damage_order_control":true},"  "))
	file.close()
	print("FOREST BIBLE APP DISCOVERIES: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
