class_name RuntimeMapSlice
extends Node2D
## Explicit development entrance. Ordinary App/Provider selection is unchanged.
@export_enum("seam", "adjacent", "carrier") var spawn_binding := "seam"
@export var diagnostics_enabled := false
signal preview_exit_requested
var _observation_ticks := 0
var session := RunSession.new()
var stage: RuntimeMapSliceStage
var policy: FrameDamagePolicy
var ready_ok := false
var error := ""
var closed := false
var close_finished := false
var close_result := false
var load_token: DemoToken
var request: LevelRequest
var camera: Camera2D
var _label: Label

func _ready() -> void:
	var audio := PlayerWeaponFeelAudioV2.new()
	audio.name = "GameAudio"
	add_child(audio)
	if not RunComposition.create_player(self,session,HomeWeaponSelection.new()):
		error = "Formal player composition failed"
		return
	if not RunComposition.configure_capabilities(session.controller,true,false):
		error = "Player capability setup failed"
		return
	session.receipt_prefix = "mapgen-host-v2-slice"
	session.create_run_services(&"plains",false)
	session.create_item_services(false)
	# Existing flow owns epochs and its original run-route choices. Source
	# selection starts only after the same player and services are assembled.
	if not session.flow.start("930001",RunProfile.development()).accepted():
		error = "Run lifecycle start failed"
		return
	load_token = session.lifetime.token()
	request = LevelRequest.new()
	request.root_seed = "930001"
	request.region_id = &"plains"
	request.tuning = session.player.tuning
	request.capabilities = {"grapple":session.controller.traversal.hook_enabled,"weapon_id":str(session.controller.shoot_ability.weapon.id),"collision_half_extents":[12,18]}
	_start_source()

func _start_source() -> void:
	_install_plan(_load_source())

func _load_source() -> LevelBuildResult:
	return RuntimeMapFrozenSource.load_level(request,spawn_binding)

func _close_source() -> void:
	pass

func _approve_install() -> bool:
	return true

func _install_plan(built: LevelBuildResult) -> bool:
	if not built.accepted():
		error = built.error
		return false
	session.select_map_state(1)
	stage = RuntimeMapSliceStage.new()
	stage.name = "RuntimeMapSliceStage"
	stage.plan = built.plan
	stage.state = session.region_state
	add_child(stage)
	if not stage.assembly_ok:
		error = stage.error
		return false
	policy = FrameDamagePolicy.new()
	policy.lifetime = session.lifetime
	add_child(policy)
	policy.register_target(&"player",session.controller.actor_resources.health,true)
	policy.register_player_controller(session.controller)
	stage.bind_damage(session.controller,policy,session.lifetime)
	# This is the initial host-bound spawn, never a seam transition/teleport.
	session.controller.return_to_segment(built.plan.spawn)
	var body := PlayerPresentationRuntime.make_body(session.player,session.controller,"PixelPlainsActor")
	session.player.add_child(body)
	session.player.get_node("CourierVisual").hide()
	session.player.get_node("PlayerFeedback").hide()
	session.player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	PlayerPresentationRuntime.attach(session.player)
	UnderworldPresentation.attach(stage,stage,session.player)
	InputSetup.attach(session.player,session.controller.router)
	camera = Camera2D.new()
	camera.position = built.plan.spawn
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12,12)
	_label.text = "MAPGEN V2 / LOADING SLICE ONLY\nM16 + M18 + M21 / arrows or A,D / ESC exit\nNo full-map, enemy, reward or Boss certification"
	layer.add_child(_label)
	var record := {"schema":"mapgen/runtime-map/v2","map_hash":built.plan.map_hash,"identity":built.plan.get_meta("runtime_map_v2_identity").duplicate(true),"seed":built.plan.seed,"instances":RuntimeMapFrozenSource.IDS.duplicate(),"spawn_binding":spawn_binding,"scope":"loading_slice"}
	if not session.flow.manifest.record_output(1,&"mapgen_v2_loading_slice",record):
		error = "Existing run record refused slice identity"
		return false
	if not _approve_install():
		return false
	ready_ok = true
	_observe("loaded")
	return true

func _physics_process(_delta: float) -> void:
	if ready_ok and not closed:
		stage.observe_player(session.player.global_position)
		camera.position = session.player.global_position
		_observation_ticks += 1
		if _observation_ticks % 30 == 0: _observe("physics")

func _unhandled_input(event: InputEvent) -> void:
	if not closed and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		request_exit()

func request_exit() -> void:
	if not get_signal_connection_list("preview_exit_requested").is_empty():
		preview_exit_requested.emit()
	else:
		await close_slice()
		get_tree().quit()

func _observe(event: String) -> void:
	if not diagnostics_enabled or not ready_ok or not is_instance_valid(stage): return
	var ferry: ModuleMovingPlatform = stage.assembler.modules[0].moving_platforms[0]
	var point := session.player.global_position
	var carrier := ferry.global_position
	print("MAPGEN_HOST_V2 ",JSON.stringify({"event":event,"host_load_identity":stage.plan.map_hash,"player":[point.x,point.y],"carrier":[carrier.x,carrier.y],"grounded":session.player.is_on_floor()}))

func close_preview() -> bool:
	return await close_slice()

func accepts_result(token: DemoToken) -> bool:
	return not closed and session.lifetime.accepts(token)

func reload_slice() -> bool:
	if not ready_ok or closed: return false
	var saved := stage.capture_state()
	var built := _load_source()
	if not built.accepted():
		error = built.error
		return false
	var restored := PlainsRegionState.new()
	# Compare the saved identity with the newly admitted content BEFORE
	# invalidating the old world or replacing any current services/nodes.
	if not restored.restore(saved,built.plan.map_hash):
		error = "Saved host load identity differs from current content/bindings"
		return false
	# Same-map reload follows the existing App's actor invalidation/cancel
	# boundary. It never resets the player, resources, wallet or run services.
	session.controller.router.clear("mapgen_slice_reload")
	session.controller.shoot_ability.clear_projectiles()
	session.lifetime.invalidate_actor()
	remove_child(stage)
	stage.queue_free()
	session.region_state = restored
	session.region_states[1] = restored
	stage = RuntimeMapSliceStage.new()
	stage.plan = built.plan
	stage.state = restored
	add_child(stage)
	if not stage.assembly_ok:
		ready_ok = false
		error = stage.error
		return false
	stage.bind_damage(session.controller,policy,session.lifetime)
	UnderworldPresentation.attach(stage,stage,session.player)
	load_token = session.lifetime.token()
	return true

func close_slice() -> bool:
	if closed:
		while not close_finished: await get_tree().process_frame
		return close_result
	closed = true
	_close_source()
	ready_ok = false
	if is_instance_valid(stage): stage.capture_state()
	if is_instance_valid(session.controller):
		session.controller.router.clear("mapgen_slice_exit")
		session.controller.active = false
		session.controller.shoot_ability.clear_projectiles()
	session.lifetime.end()
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null
	if session.build != null: session.clear_run_services()
	close_result = await WorldAudioLifecycle.drain_world(self)
	close_finished = true
	if diagnostics_enabled: print("MAPGEN_HOST_V2 ",JSON.stringify({"event":"closed","audio_released":close_result,"lifetime_active":session.lifetime.active,"stage_detached":stage==null}))
	return close_result

func _exit_tree() -> void:
	# Also invalidate a request if the scene is removed without the exit button.
	_close_source()
	session.lifetime.end()
