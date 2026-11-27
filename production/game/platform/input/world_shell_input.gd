extends Node
## One menu handler remains active while gameplay is paused. GUI modals get first
## refusal. In play, the east face button is reserved for focus healing.
const MAP_GESTURE := preload("res://game/platform/input/gamepad_map_input.gd")
var shell: Node
var world: WorldGameHost
var map_gesture := MAP_GESTURE.new()
var previous_go_back := true
var menu_device: StringName

static func mount(owner_shell: Node) -> Node:
	var input := new()
	input.name = "WorldShellInput"
	input.shell = owner_shell
	input.process_mode = Node.PROCESS_MODE_ALWAYS
	owner_shell.add_child(input)
	return input

func _ready() -> void:
	preload("res://game/presentation/ui/demo_ui_01/menu_input.gd").ensure_actions()
	previous_go_back = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	shell.page_changed.connect(_page_changed)
	_page_changed(shell.page)

func _exit_tree() -> void:
	get_tree().quit_on_go_back = previous_go_back

func _page_changed(_page: StringName) -> void:
	var active_world := shell.get("world") as WorldGameHost
	if is_instance_valid(world) and world!=active_world and world.room_changed.is_connected(_room_changed):
		world.room_changed.disconnect(_room_changed)
	world = active_world
	if not is_instance_valid(world): return
	if not world.room_changed.is_connected(_room_changed): world.room_changed.connect(_room_changed)
	_room_changed("")

func _room_changed(_room: String) -> void:
	map_gesture = MAP_GESTURE.new()
	if world.active==null or world.active.touch_controls==null: return
	var controls := world.active.touch_controls
	if not controls.pause_requested.is_connected(_pause_touch): controls.pause_requested.connect(_pause_touch)

func _pause_touch() -> void:
	if shell.page==&"play" and not get_tree().paused: shell.open_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(shell) and is_inside_tree():
		if shell.page == &"title" and OS.has_feature("android"):
			get_tree().quit()
		else:
			shell.handle_back()

func _input(event: InputEvent) -> void:
	# Remember the last intentional UI device even when a focused native Button
	# consumes the event before the gameplay router receives it.
	if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>.45:
		menu_device=&"gamepad"
	elif event is InputEventScreenTouch and event.pressed:
		menu_device=&"touch"
	elif event is InputEventKey and event.pressed or event is InputEventMouseButton and event.pressed and event.device!=InputEvent.DEVICE_ID_EMULATION:
		menu_device=&"keyboard_mouse"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		shell.handle_back()
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_START or (event.button_index==JOY_BUTTON_B and (shell.page!=&"play" or get_tree().paused)):
			get_viewport().set_input_as_handled()
			shell.handle_back()
			return
	if shell.page!=&"play" or not is_instance_valid(world) or world.active==null or not is_instance_valid(world.route_map): return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	var router := world.active.controller.router
	var profile := router.profile
	var trigger := InputProfile.binding_down(profile.gamepad_binding(event.device,"jump_trigger"),event.device,event)>float(profile.values.gamepad_jump_trigger_release_threshold)
	if not map_gesture.requested(event,profile,router.epoch,trigger): return
	if world.route_map.visible:
		world.route_map.close()
	elif not get_tree().paused and not world.crossing:
		world.route_map.open()
	else: return
	get_viewport().set_input_as_handled()
