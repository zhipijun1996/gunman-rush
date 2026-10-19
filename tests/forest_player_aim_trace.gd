extends "res://tests/forest_depth_region_trace.gd"
## Adds human-sized aim holds to the existing real regional route driver.
## Target selection is assisted; adapter timing/physics/resources are real.
var aim_seconds := 0.35
var stop_after_legs := 2
var aim_samples: Array[Dictionary] = []
var _aim_kind := ""
var _aim_target: Node2D
var _aim_direction := Vector2.ZERO
var _aim_elapsed := 0.0
var _aim_epoch := -1
var _aim_session := -1
var _space_held := false
var _resting := false

func _physics_process(delta: float) -> void:
	if initialized and not finished and leg_index < itinerary.size() and phase == "align" and player.is_on_floor() and itinerary[leg_index].kind in ["airborne_chain","hanging_chain"]:
		if controller.air_focus_ability.stamina < controller.air_focus_ability.stamina_state.capacity - 0.1:
			if not _resting:
				event("actual_grounded_focus_rest_started")
				_resting = true
			tick += 1; age += 1; before_steps = player.motion_steps
			controller.router.set_move_axis(0)
			jump(false)
			if age > 400: fail("grounded_focus_recovery_timeout")
			return
	if _resting:
		event("actual_grounded_focus_rest_finished")
		_resting = false
	super._physics_process(delta)

func observe() -> void:
	var prior := frames.size()
	super.observe()
	if frames.size() > prior:
		frames[-1].focus = {"current":controller.air_focus_ability.stamina,
			"air_time_used":controller.air_focus_ability.air_time_used,
			"active":controller.air_focus_ability.active,"world_scale":Engine.time_scale}

func complete_leg() -> void:
	super.complete_leg()
	# Seal on the completion tick so the original post-Motor observer captures
	# that frame. Returning before the next tick would skip its finish check.
	if leg_index >= stop_after_legs: finish_pending = true

func _process(delta: float) -> void:
	if _aim_kind.is_empty() or not is_instance_valid(controller): return
	if finished or controller.router.epoch != _aim_epoch or controller.session_id != _aim_session:
		_aim_kind = ""
		return
	_aim_elapsed += delta / Engine.time_scale
	var keyboard := player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
	var motion := InputEventMouseMotion.new()
	motion.position = _aim_pixel()
	keyboard._unhandled_input(motion)
	if _aim_elapsed < aim_seconds: return
	var kind := _aim_kind
	_mouse(false)
	aim_samples.append({"kind":kind,"tick":tick,"leg":leg_index,"held_real_seconds":_aim_elapsed,
		"focus_remaining":controller.air_focus_ability.stamina,
		"focus_air_seconds_used":controller.air_focus_ability.air_time_used,
		"world_scale_at_release":Engine.time_scale,"position":pair(player.global_position),
		"hook_state":String(controller.traversal.state)})
	_aim_kind = ""

func hook(id: String) -> bool:
	var target: Node2D = stage.assembler.hook_targets.get(id)
	if not is_instance_valid(target): fail("human_aim_missing_anchor/"+id); return false
	if not _aim_kind.is_empty(): fail("human_aim_conflicting_hook"); return false
	last_hook = ""
	_aim_target = target
	_begin_aim("hook", Vector2.ZERO)
	return true

func request(kind: StringName, aim := Vector2.ZERO) -> void:
	if kind == &"shoot_release":
		if not _aim_kind.is_empty(): fail("human_aim_conflicting_shot"); return
		_aim_target = null
		_begin_aim("shot", aim)
	else:
		super.request(kind, aim)

func jump(held: bool) -> void:
	if held == _space_held: return
	_space_held = held
	var input := InputEventKey.new()
	input.physical_keycode = KEY_SPACE
	input.pressed = held
	(player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter)._unhandled_input(input)
	requests.append({"tick":tick,"leg":leg_index,"kind":"actual_keyboard_space","held":held})

func _begin_aim(kind: String, direction: Vector2) -> void:
	_aim_kind = kind
	_aim_direction = direction
	_aim_elapsed = 0.0
	_aim_epoch = controller.router.epoch
	_aim_session = controller.session_id
	_mouse(true)

func _aim_pixel() -> Vector2:
	var origin := player.global_position + Vector2(0, -6)
	var world := _aim_target.global_position if _aim_kind == "hook" and is_instance_valid(_aim_target) else origin + _aim_direction * 180.0
	return player.get_canvas_transform() * world

func _mouse(down: bool) -> void:
	var input := InputEventMouseButton.new()
	input.button_index = MOUSE_BUTTON_RIGHT if _aim_kind == "hook" else MOUSE_BUTTON_LEFT
	input.position = _aim_pixel()
	input.pressed = down
	(player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter)._unhandled_input(input)
