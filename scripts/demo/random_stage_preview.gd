class_name RandomStagePreview
extends Node2D
## Standalone generated practice. No RunState, rewards or permanent progression.
signal home_requested
signal completed
const PLAYER := preload("res://scenes/player/player.tscn")
var input_values: Dictionary = InputProfile.load_default().values.duplicate(true)
var seed_text := "rush-preview"
var manifest: Dictionary = {}
var stage: RandomStageAssembler
var player: PlayerMotor
var controller: PlayerController
var camera: StageCameraRig
var lifetime := DemoLifetime.new()
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var menu: DemoMenu
var attempt := 0
var elapsed := 0.0
var finished := false
var ready_for_play := false
var current_module := 0
var _closed := false
var _pending_seed := "rush-preview"
var _active_anchor := -1
var _seed_nonce := 0
var _overview := false
var _overview_button: Button
var _status := "Preparing a complete generated practice stage."
var _title: Label
var _detail: Label
var _status_label: Label
var _seed_edit: LineEdit
var _resources: ActorResourcesHud
var _overlay: TouchOverlay
var _menu_button: Button
var _route_progress: ProgressBar
var _goal_visual: Node2D

func configure(values: Dictionary, requested_seed: String = "rush-preview") -> bool:
	var candidate := InputProfile.load_default()
	if not candidate.configure(values):
		return false
	input_values = candidate.values.duplicate(true)
	seed_text = requested_seed.strip_edges().substr(0, 80)
	if seed_text.is_empty():
		seed_text = "rush-preview"
	_pending_seed = seed_text
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1100
	_goal_visual = Node2D.new()
	_goal_visual.z_index = 100
	_goal_visual.draw.connect(_draw_goal)
	add_child(_goal_visual)
	_make_ui()

func request_seed(value: String) -> bool:
	if _closed:
		return false
	var next := value.strip_edges().substr(0, 80)
	if next.is_empty():
		next = "rush-preview"
	if is_instance_valid(controller):
		controller.router.clear("random_preview_new_attempt")
		controller.air_focus_ability.stop()
		controller.active = false
	lifetime.end()
	ready_for_play = false
	_pending_seed = next
	get_tree().paused = false
	if menu != null:
		menu.hide_home()
	return true

func retry_same_seed() -> void:
	request_seed(seed_text)

func new_seed() -> void:
	_seed_nonce += 1
	request_seed("%s-%s-%s" % [Time.get_ticks_msec(), attempt, _seed_nonce])

func _physics_process(delta: float) -> void:
	if not _pending_seed.is_empty():
		var next := _pending_seed
		_pending_seed = ""
		_load_stage(next)
		return
	if not ready_for_play or _closed or not lifetime.active:
		return
	elapsed += delta
	var observed_module := stage.module_index_at(player.global_position)
	if observed_module >= 0:
		current_module = observed_module
	if not stage.bounds.grow(32.0).has_point(player.global_position):
		var request := DamageRequest.new()
		request.token = lifetime.token()
		request.actor_epoch = lifetime.actor_epoch
		request.health_epoch = controller.actor_resources.health.epoch
		request.target_id = &"player"
		request.source_id = &"random_preview_boundary"
		request.event_id = StringName("bounds_%s_%s" % [attempt, lifetime.actor_epoch])
		request.kind = DamageRequest.Kind.ENVIRONMENT
		request.amount = 1.0
		policy.submit(request)
	if player.is_on_floor():
		var anchors := stage.world_anchors()
		for index: int in anchors.size():
			if index != _active_anchor and player.global_position.distance_to(anchors[index]) < 42.0 and segment.activate_anchor(StringName("anchor_%s" % index)):
				_active_anchor = index
	var last: PlatformingModule = stage.modules.back()
	if not finished and last.port_accepts(last.definition.exit_port, player):
		finished = true
		_status = "STAGE CLEAR / %.1fs. Same seed retries this map; New seed generates another." % elapsed
		completed.emit()

func _load_stage(value: String) -> void:
	_clear_attempt()
	seed_text = value
	_seed_edit.release_focus()
	_seed_edit.text = value
	attempt += 1
	elapsed = 0.0
	finished = false
	_active_anchor = -1
	current_module = 0
	_overview = false
	_overview_button.text = "MAP OVERVIEW"
	var tuning := PlayerTuning.load_default()
	var generated := RandomStageGenerator.new().generate(seed_text.hash(), tuning, 14)
	if not bool(generated.get("ok", false)):
		_status = "GENERATION FAILED / " + String(generated.get("error", "unknown"))
		return
	manifest = generated.manifest.duplicate(true)
	stage = RandomStageAssembler.new()
	add_child(stage)
	var assembly := stage.build(manifest, tuning)
	if not bool(assembly.get("ok", false)):
		_status = "ASSEMBLY FAILED / content rejected. Retry or return Home."
		return
	lifetime.active = true
	player = PLAYER.instantiate() as PlayerMotor
	player.position = stage.world_entry()
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.router.reconfigure(input_values)
	_overlay = InputSetup.attach(player, controller.router)
	_overlay.hide_reset_button = true
	_overlay.pause_label = "MENU"
	_overlay.pause_requested.connect(toggle_pause)
	var vignette := FocusVignette.new()
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var aim_guide := DemoAimGuide.new()
	aim_guide.controller = controller
	player.add_child(aim_guide)
	_resources.bind(controller.actor_resources, controller.air_focus_ability)
	camera = StageCameraRig.new()
	add_child(camera)
	camera.configure(player, stage.bounds)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.environment_return_requested.connect(_environment_return)
	policy.player_fatal.connect(_fatal)
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.danger_bounds = stage.world_dangers()
	var anchors := stage.world_anchors()
	for index: int in anchors.size():
		segment.add_anchor(StringName("anchor_%s" % index), anchors[index])
	var dangers := stage.world_static_dangers()
	for index: int in dangers.size():
		var contact := DemoContactEmitter.new()
		contact.policy = policy
		contact.controller = controller
		contact.kind = DamageRequest.Kind.ENVIRONMENT
		contact.source_id = StringName("preview_%s_danger_%s" % [attempt, index])
		contact.position = dangers[index].get_center()
		contact.half_size = dangers[index].size / 2.0
		stage.add_child(contact)
	stage.setup_damage(controller, policy, lifetime)
	_status = "Follow the platforms to the golden finish beacon. Safe ground records your return point."
	_goal_visual.queue_redraw()
	_ready_attempt(lifetime.token())

func _ready_attempt(token: DemoToken) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _closed or not lifetime.accepts(token) or not is_instance_valid(stage):
		return
	if not segment.activate_anchor(&"anchor_0"):
		controller.active = false
		_status = "CONTENT ERROR / unsafe entry. Return Home or regenerate."
		push_error(_status)
		return
	_active_anchor = 0
	policy.protect_player()
	camera.make_current()
	camera.force_update_scroll()
	ready_for_play = true

func _environment_return() -> void:
	if segment.return_to_anchor():
		policy.protect_player()
		camera.configure(player, stage.bounds)
		_status = "SEGMENT RETURN / HP stays spent. Map, hazard clocks and action resources are preserved."

func _fatal() -> void:
	lifetime.end()
	controller.die()
	ready_for_play = false
	_status = "PRACTICE ENDED / zero health. Returning Home."
	leave_preview.call_deferred()

func toggle_overview() -> void:
	if not ready_for_play or _closed:
		return
	_overview = not _overview
	controller.router.clear("random_preview_overview")
	controller.air_focus_ability.stop()
	if _overview:
		get_tree().paused = true
		camera.make_current()
		var usable := Vector2(1200, 460)
		var scale_value := minf(usable.x / stage.bounds.size.x, usable.y / stage.bounds.size.y)
		camera.zoom = Vector2.ONE * minf(1.0, scale_value)
		camera.global_position = stage.bounds.get_center() - Vector2(0, 55.0 / camera.zoom.y)
		camera.force_update_scroll()
	else:
		camera.zoom = Vector2.ONE
		camera.configure(player, stage.bounds)
		get_tree().paused = false
	_overview_button.text = "BACK TO PLAY" if _overview else "MAP OVERVIEW"

func toggle_pause() -> void:
	if _overview:
		toggle_overview()
	if _closed:
		return
	if get_tree().paused:
		menu.close_panel()
	else:
		menu.show_pause("RANDOM STAGE PREVIEW\nSeed: %s\n%s connected modules / fixed player physics\nNo items, coins or permanent rewards in this practice." % [seed_text, stage.modules.size() if is_instance_valid(stage) else 0])

func _pause() -> void:
	if is_instance_valid(controller):
		controller.router.clear("random_preview_menu")
		controller.air_focus_ability.stop()
	get_tree().paused = true

func _resume() -> void:
	if not _closed:
		if is_instance_valid(controller):
			controller.router.clear("random_preview_resume")
		get_tree().paused = false

func apply_settings(patch: Dictionary) -> bool:
	var candidate := InputProfile.load_default()
	if not candidate.configure(input_values) or not candidate.configure(patch):
		return false
	if is_instance_valid(controller) and not controller.router.reconfigure(candidate.values):
		return false
	input_values = candidate.values.duplicate(true)
	menu.set_input_values(input_values)
	if is_instance_valid(_overlay):
		_overlay.update_layout()
	return true

func leave_preview() -> void:
	if _closed:
		return
	_closed = true
	ready_for_play = false
	lifetime.end()
	if is_instance_valid(controller):
		controller.router.clear("random_preview_home")
		controller.air_focus_ability.stop()
		controller.active = false
	get_tree().paused = false
	home_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and menu.visible_panel.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_title.text = "RANDOM STAGE / SEED %s" % seed_text
	_status_label.text = _status
	if not is_instance_valid(controller):
		return
	_detail.text = "ROUTE %s/%s | %.1fs | %s | WORLD X %.0f / CAMERA X %.0f" % [current_module + 1, stage.modules.size(), elapsed, "CLEAR" if finished else "FINISH AHEAD", player.global_position.x, camera.global_position.x]
	_menu_button.visible = not _overlay.enabled
	var start := stage.world_entry().x
	var end := stage.world_exit().x
	_route_progress.value = 100.0 if finished else clampf((player.global_position.x - start) / maxf(1.0, end - start) * 100.0, 0.0, 100.0)

func _clear_attempt() -> void:
	_resources.unbind()
	for node: Node in [camera, policy, player, stage]:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	camera = null
	policy = null
	player = null
	controller = null
	stage = null
	segment = null
	manifest = {}
	_goal_visual.queue_redraw()

func _make_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 3
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var panel := Panel.new()
	panel.position = Vector2(12, 8)
	panel.size = Vector2(1058, 132)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.10, 0.9)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	_title = _label(canvas, Vector2(22, 12), 19)
	_title.size.x = 1030
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail = _label(canvas, Vector2(22, 36), 14)
	_resources = ActorResourcesHud.new()
	_resources.position = Vector2(0, -18)
	canvas.add_child(_resources)
	_route_progress = ProgressBar.new()
	_route_progress.position = Vector2(400, 96)
	_route_progress.size = Vector2(645, 8)
	_route_progress.show_percentage = false
	_route_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var route_track := StyleBoxFlat.new()
	route_track.bg_color = Color("27333f")
	route_track.set_corner_radius_all(4)
	var route_fill := StyleBoxFlat.new()
	route_fill.bg_color = Color("d4b57b")
	route_fill.set_corner_radius_all(4)
	_route_progress.add_theme_stylebox_override("background", route_track)
	_route_progress.add_theme_stylebox_override("fill", route_fill)
	canvas.add_child(_route_progress)
	_status_label = _label(canvas, Vector2(22, 114), 12)
	_seed_edit = LineEdit.new()
	_seed_edit.position = Vector2(1080, 8)
	_seed_edit.size = Vector2(90, 34)
	_seed_edit.max_length = 80
	_seed_edit.placeholder_text = "Map seed"
	_seed_edit.text_submitted.connect(func(value: String) -> void:
		_seed_edit.release_focus()
		request_seed(value)
	)
	_seed_edit.focus_entered.connect(func() -> void:
		if is_instance_valid(controller):
			controller.router.clear("preview_seed_edit")
			controller.air_focus_ability.stop()
			controller.active = false
	)
	_seed_edit.focus_exited.connect(func() -> void:
		if is_instance_valid(controller):
			controller.router.clear("preview_seed_edit_done")
			controller.active = ready_for_play and not _closed
	)
	canvas.add_child(_seed_edit)
	_button(canvas, Vector2(1080, 72), Vector2(184, 32), "GENERATE SEED", func() -> void: request_seed(_seed_edit.text))
	_button(canvas, Vector2(1080, 110), Vector2(184, 32), "RETRY SAME SEED", retry_same_seed)
	_button(canvas, Vector2(1080, 148), Vector2(184, 32), "NEW SEED", new_seed)
	_overview_button = _button(canvas, Vector2(1080, 186), Vector2(184, 32), "MAP OVERVIEW", toggle_overview)
	_menu_button = _button(canvas, Vector2(1140, 226), Vector2(124, 42), "MENU", toggle_pause)
	menu = DemoMenu.new()
	add_child(menu)
	menu.set_input_values(input_values)
	menu.menu_opened.connect(_pause)
	menu.requested_resume.connect(_resume)
	menu.requested_home.connect(leave_preview)
	menu.settings_changed.connect(apply_settings)

func _draw_goal() -> void:
	# A single level goal is visible; authoring ports and module boundaries are not.
	if not is_instance_valid(stage):
		return
	var finish := stage.world_exit()
	var foot := finish + Vector2(0, 18)
	_goal_visual.draw_line(foot, foot - Vector2(0, 92), Color("f6d896"), 4.0)
	_goal_visual.draw_colored_polygon(PackedVector2Array([foot - Vector2(0, 88), foot + Vector2(38, -74), foot - Vector2(0, 60)]), Color("e7b45d"))
	_goal_visual.draw_circle(finish - Vector2(0, 60), 12.0, Color(1.0, 0.83, 0.40, 0.18))

func _label(parent: Node, location: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = location
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, location: Vector2, dimensions: Vector2, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.position = location
	button.size = dimensions
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _exit_tree() -> void:
	lifetime.end()
	if is_instance_valid(controller):
		if controller.is_inside_tree():
			controller.router.clear("random_preview_destroyed")
		controller.air_focus_ability.stop()
		controller.active = false
