class_name ModuleLab
extends Node2D
## Fixed authoring playground: explicit new attempts, shared damage and input.
signal home_requested

const PLAYER := preload("res://scenes/player/player.tscn")
const MODULES := {
	&"safe_hub": preload("res://scenes/generation/modules/safe_hub.tscn"),
	&"stepped_crossing": preload("res://scenes/generation/modules/stepped_crossing.tscn"),
	&"descending_switchback": preload("res://scenes/generation/modules/descending_switchback.tscn"),
	&"recoil_shaft": preload("res://scenes/generation/modules/recoil_shaft.tscn"),
}
var module_id: StringName = &"safe_hub"
var module: PlatformingModule
var player: PlayerMotor
var controller: PlayerController
var lifetime := DemoLifetime.new()
var policy: FrameDamagePolicy
var segment: SegmentRespawn
var menu: DemoMenu
var input_values: Dictionary = InputProfile.load_default().values.duplicate(true)
var attempt := 0
var elapsed := 0.0
var supply_claimed := false
var finished := false
var ready_for_play := false
var _pending: StringName = &"safe_hub"
var _closed := false
var _active_anchor := -1
var _supply_pending: DemoToken
var _status := "Choose a module. Each selection starts a fresh practice attempt."
var _title: Label
var _detail: Label
var _status_label: Label
var _resource_hud: ActorResourcesHud
var _overlay: TouchOverlay
var _supply_button: Button
var _menu_button: Button

func configure(values: Dictionary) -> bool:
	var candidate := InputProfile.load_default()
	if not candidate.configure(values):
		return false
	input_values = candidate.values.duplicate(true)
	return true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1100
	_make_ui()

func request_module(id: StringName) -> bool:
	if _closed or not MODULES.has(id):
		return false
	if is_instance_valid(controller):
		controller.router.clear("practice_new_attempt")
		controller.active = false
		controller.air_focus_ability.stop()
	lifetime.end()
	_supply_pending = null
	ready_for_play = false
	_pending = id
	get_tree().paused = false
	if menu != null:
		menu.hide_home()
	return true

func restart_module() -> void:
	request_module(module_id)

func _physics_process(delta: float) -> void:
	if not _pending.is_empty():
		var next := _pending
		_pending = &""
		_load_module(next)
		return
	if not ready_for_play or _closed or not lifetime.active:
		return
	elapsed += delta
	if not module.definition.world_bounds.grow(24.0).has_point(module.to_local(player.global_position)):
		var boundary := DamageRequest.new()
		boundary.token = lifetime.token()
		boundary.actor_epoch = lifetime.actor_epoch
		boundary.health_epoch = controller.actor_resources.health.epoch
		boundary.target_id = &"player"
		boundary.source_id = &"practice_world_boundary"
		boundary.event_id = StringName("practice_bounds_%s_%s" % [attempt, lifetime.actor_epoch])
		boundary.kind = DamageRequest.Kind.ENVIRONMENT
		boundary.amount = 1.0
		policy.submit(boundary)
	if player.is_on_floor():
		var anchors := module.world_anchors()
		for index: int in anchors.size():
			if index != _active_anchor and player.global_position.distance_to(anchors[index]) < 42.0 and segment.activate_anchor(StringName("anchor_%s" % index)):
				_active_anchor = index
	if not finished and module.port_accepts(module.definition.exit_port, player):
		finished = true
		_status = "MODULE CLEAR / %.1fs / practice only. Pick another module or Retry." % elapsed
	_commit_supply()

func _load_module(id: StringName) -> void:
	_clear_attempt()
	module_id = id
	attempt += 1
	elapsed = 0.0
	supply_claimed = false
	finished = false
	_active_anchor = -1
	lifetime.active = true
	module = MODULES[id].instantiate() as PlatformingModule
	add_child(module)
	player = PLAYER.instantiate() as PlayerMotor
	player.position = module.world_entry()
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	controller.router.reconfigure(input_values)
	controller.interact_requested.connect(take_supply)
	_overlay = InputSetup.attach(player, controller.router)
	_overlay.hide_reset_button = true
	_overlay.pause_label = "MENU"
	_overlay.pause_requested.connect(toggle_pause)
	var vignette := FocusVignette.new()
	vignette.ability = controller.air_focus_ability
	player.add_child(vignette)
	var guide := DemoAimGuide.new()
	guide.controller = controller
	player.add_child(guide)
	_resource_hud.bind(controller.actor_resources, controller.air_focus_ability)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	policy.environment_return_requested.connect(_environment_return)
	policy.player_fatal.connect(_fatal)
	segment = SegmentRespawn.new()
	segment.configure(controller, lifetime)
	segment.danger_bounds = module.world_dangers()
	var anchors := module.world_anchors()
	for index: int in anchors.size():
		segment.add_anchor(StringName("anchor_%s" % index), anchors[index])
	for index: int in segment.danger_bounds.size():
		var rect := segment.danger_bounds[index]
		var contact := DemoContactEmitter.new()
		contact.policy = policy
		contact.controller = controller
		contact.kind = DamageRequest.Kind.ENVIRONMENT
		contact.source_id = StringName("practice_%s_danger_%s" % [id, index])
		contact.position = rect.get_center()
		contact.half_size = rect.size / 2.0
		module.add_child(contact)
	_status = "Reach the gold EXIT. Teal dots are safe segment starts. Red areas cost health."
	_ready_attempt(lifetime.token())

func _ready_attempt(token: DemoToken) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _closed or not lifetime.accepts(token) or not is_instance_valid(module):
		return
	if not module.definition.supports(player.tuning) or not segment.activate_anchor(&"anchor_0"):
		controller.active = false
		_status = "CONTENT ERROR / incompatible module or unsafe entry. Return Home or Retry."
		push_error(_status)
		return
	_active_anchor = 0
	policy.protect_player()
	ready_for_play = true

func _environment_return() -> void:
	_supply_pending = null
	if segment.return_to_anchor():
		policy.protect_player()
		_status = "SEGMENT RETURN / health and used supply stay spent; the module stays loaded."

func _fatal() -> void:
	_supply_pending = null
	controller.die()
	_status = "PRACTICE ENDED / zero health. Returned Home."
	leave_lab.call_deferred()

func take_supply() -> void:
	if ready_for_play and not _closed and lifetime.active and not get_tree().paused:
		_supply_pending = lifetime.token()

func _commit_supply() -> void:
	var token := _supply_pending
	_supply_pending = null
	if token == null or not lifetime.accepts(token) or supply_claimed or controller.actor_resources.health.terminal:
		return
	if player.global_position.distance_to(module.world_entry()) > 100.0:
		return
	var result := SupplyHealEffect.apply(controller.actor_resources.health, 2.0, StringName("practice_supply_%s" % attempt))
	if result.accepted():
		supply_claimed = true
		_status = "SUPPLY USED / restores current HP once; segment return does not refill it."

func toggle_pause() -> void:
	if _closed or not ready_for_play:
		return
	if get_tree().paused:
		menu.close_panel()
	else:
		menu.show_pause("MODULE LAB / %s\nAttempt %s / fixed geometry\nNew module or Retry starts a fresh practice attempt.\nSegment return preserves health, focus and used supply." % [module_id, attempt])

func _pause() -> void:
	if is_instance_valid(controller):
		controller.router.clear("practice_menu")
		controller.air_focus_ability.stop()
	_supply_pending = null
	get_tree().paused = true

func _resume() -> void:
	if not _closed:
		controller.router.clear("practice_resume")
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

func leave_lab() -> void:
	if _closed:
		return
	_closed = true
	ready_for_play = false
	lifetime.end()
	if is_instance_valid(controller):
		controller.router.clear("practice_home")
		controller.air_focus_ability.stop()
		controller.active = false
	_supply_pending = null
	get_tree().paused = false
	home_requested.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and menu.visible_panel.is_empty():
		toggle_pause()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(controller):
		return
	_title.text = "MODULE LAB / %s / ATTEMPT %s" % [String(module_id).to_upper().replace("_", " "), attempt]
	_detail.text = "JUMPS %s | AIR SHOTS %s | %.1fs | %s" % [controller.motor.tuning.max_jumps, controller.action_resources.shot_charges, elapsed, "CLEAR" if finished else "REACH EXIT"]
	_status_label.text = _status
	_menu_button.visible = not _overlay.enabled
	_supply_button.disabled = not ready_for_play or supply_claimed or player.global_position.distance_to(module.world_entry()) > 100.0
	_supply_button.text = "SUPPLY USED" if supply_claimed else "SUPPLY +2 HP"

func _clear_attempt() -> void:
	_resource_hud.unbind()
	for node: Node in [policy, player, module]:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	policy = null
	player = null
	controller = null
	module = null

func _make_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 3
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var panel := Panel.new()
	panel.position = Vector2(12, 8)
	panel.size = Vector2(1060, 147)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.10, 0.94)
	style.border_color = Color("38596a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	_title = _label(canvas, Vector2(22, 15), 23)
	_detail = _label(canvas, Vector2(22, 44), 15)
	_resource_hud = ActorResourcesHud.new()
	canvas.add_child(_resource_hud)
	_status_label = _label(canvas, Vector2(22, 122), 14)
	var names := {&"safe_hub": "SAFE HUB", &"stepped_crossing": "STEPPED CROSSING", &"descending_switchback": "DESCENDING", &"recoil_shaft": "RECOIL SHAFT"}
	var x := 22.0
	for id: StringName in MODULES:
		var selected := id
		_button(canvas, Vector2(x, 163), Vector2(235, 42), names[id], func() -> void: request_module(selected))
		x += 247.0
	_button(canvas, Vector2(1080, 163), Vector2(180, 42), "RETRY MODULE", restart_module)
	_menu_button = _button(canvas, Vector2(1150, 75), Vector2(115, 48), "MENU", toggle_pause)
	_supply_button = _button(canvas, Vector2(1080, 218), Vector2(180, 42), "SUPPLY +2 HP", take_supply)
	menu = DemoMenu.new()
	add_child(menu)
	menu.set_input_values(input_values)
	menu.menu_opened.connect(_pause)
	menu.requested_resume.connect(_resume)
	menu.requested_home.connect(leave_lab)
	menu.settings_changed.connect(apply_settings)

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
	button.pressed.connect(action)
	parent.add_child(button)
	return button
