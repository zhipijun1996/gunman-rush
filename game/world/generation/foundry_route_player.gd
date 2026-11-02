class_name FoundryRoutePlayer
extends Node
## Replays input into the same Controller. Poses are audit evidence, never movement.
signal completed(ok: bool, reason: String)
var controller: PlayerController
var frames: Array = []
var cursor := 0
var running := false
var max_error := 0.0
var _expected := Vector2.INF
var _input_nodes: Array[Dictionary] = []

func _ready() -> void:
	# A physics_frame signal step is not equivalent to a Node priority for
	# AnimatableBody platform velocity. Use exactly the validator's entry point.
	get_tree().physics_frame.connect(_on_physics_frame)

func start(actor: PlayerController, recording: Dictionary, manifest: Dictionary) -> bool:
	if recording.get("basis") != FoundryCatalog.basis() or recording.get("manifest_hash") != manifest.get("hash") or not recording.get("frames") is Array or recording.frames.is_empty(): return false
	controller = actor
	frames = recording.frames
	cursor = 0
	max_error = 0.0
	_expected = Vector2.INF
	running = true
	controller.set_physics_process(false)
	controller.router.clear("foundry_replay_start")
	controller.air_focus_ability.stop()
	_lock_inputs(controller.motor)
	return true

func stop() -> void:
	running = false
	for saved: Dictionary in _input_nodes:
		var node: Node = saved.node
		if not is_instance_valid(node): continue
		node.set_process_input(saved.input)
		node.set_process_unhandled_input(saved.unhandled)
		node.set_process(saved.process)
		node.set_physics_process(saved.physics)
	_input_nodes.clear()
	if is_instance_valid(controller):
		controller.router.clear("foundry_replay_stop")
		controller.set_physics_process.call_deferred(true)

func _lock_inputs(node: Node) -> void:
	if node is KeyboardMouseAdapter or node is GamepadAdapter or node is TouchOverlay:
		_input_nodes.append({"node": node, "input": node.is_processing_input(), "unhandled": node.is_processing_unhandled_input(), "process": node.is_processing(), "physics": node.is_physics_processing()})
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
		node.set_process(false)
		node.set_physics_process(false)
	for child: Node in node.get_children(): _lock_inputs(child)

func _on_physics_frame() -> void:
	if not running or get_tree().paused: return
	var delta := Engine.time_scale / float(Engine.physics_ticks_per_second)
	if not is_instance_valid(controller) or not controller.active:
		_finish(false, "actor_unavailable")
		return
	if not controller.router.has_application_focus:
		_finish(false, "application_unfocused")
		return
	if cursor >= frames.size():
		_finish(true, "input_replay_complete")
		return
	var frame: Dictionary = frames[cursor]
	controller.router.set_move_axis(float(frame.axis))
	for action: Dictionary in frame.actions:
		controller.router.request_action(StringName(action.type), Vector2(action.direction[0], action.direction[1]))
	_expected = Vector2(frame.position[0], frame.position[1])
	controller.physics_tick(delta)
	max_error = maxf(max_error, controller.motor.global_position.distance_to(_expected))
	if max_error > 2.0:
		_finish(false, "trajectory_diverged")
		return
	cursor += 1

func _finish(ok: bool, reason: String) -> void:
	stop()
	completed.emit(ok, reason)
