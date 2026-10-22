extends SceneTree
## Adaptive native Router pilot. Only the scene's initial construction positions
## actors. No resource grants, manual Motor steps or in-flight relocation.
var demo: Node
var trace: Array[Dictionary] = []
var commands: Array[Dictionary] = []
var variant := "A"
var strategy := "intended"
var output := "res://build/plains_golden_01/m1/motor-a.json"
var state := "approach"
var state_age := 0
var shot := false
var jump_started := false
var jump_age := 0
var controller: PlayerController

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280,720)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="): variant = arg.trim_prefix("--candidate=")
		if arg.begins_with("--strategy="): strategy = arg.trim_prefix("--strategy=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	demo = preload("res://scenes/dev/plains_golden_01.tscn").instantiate()
	root.add_child(demo)
	for frame: int in 4: await physics_frame
	if demo.candidate != variant:
		await demo.launch(variant)
	for frame: int in 4: await physics_frame
	controller = demo.controller
	controller.motor.get_node("KeyboardMouseAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	controller.motor.get_node("GamepadAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	var failed := ""
	for frame: int in 1500:
		if not controller.active:
			failed = "player_died"
			break
		state_age += 1
		if jump_started: jump_age += 1
		var p := controller.motor.position
		var grounded := controller.motor.is_on_floor()
		var axis := 0.0
		if state == "approach":
			axis = 1.0
			if p.x >= 288:
				if variant == "A" and strategy == "intended":
					jump(); change("cross")
				else: change("low_descent")
		elif state == "cross":
			axis = 1.0
			if p.x > 394 and not shot:
				fire(demo.latch.bell_position-p)
				shot = true
			if grounded and p.x>570: change("to_reward")
		elif state == "low_descent":
			axis = 1.0 if p.x < 464 else 0.0
			if grounded and p.x>=444 and p.y>530:
				jump(); change("low_step")
		elif state == "low_step":
			axis = 1.0 if p.x<530 else 0.0
			if grounded and p.x>=508 and p.y<500:
				jump(); change("low_receiver")
		elif state == "low_receiver":
			axis = 1.0 if p.x < 660 else 0.0
			if grounded and p.x>590 and p.y<410:
				if strategy == "main_low": change("main_low")
				elif variant == "B": change("b_cheap_shot" if strategy == "cheap" else "b_launch")
				else: change("a_cheap_shot")
		elif state == "main_low":
			axis = 1.0
			if demo.reached_finish: change("done")
		elif state == "a_cheap_shot":
			# Observe whether the recovery ledge can cheaply open the same bell.
			if not shot: fire(demo.latch.bell_position-p); shot = true
			if state_age>50: change("to_reward")
		elif state == "b_cheap_shot":
			if not shot: fire(demo.latch.bell_position-p); shot = true
			if state_age>30:
				shot = false
				change("b_launch")
		elif state == "b_launch":
			axis = 1.0 if p.x<660 else -1.0 if p.x>670 else 0.0
			if grounded and p.y>410 and p.x>530:
				jump()
			if state_age>12 and grounded and p.x>=650 and p.x<=680 and p.y<410:
				jump(); change("b_recoil")
		elif state == "b_recoil":
			if not shot and p.y<334:
				fire(demo.latch.bell_position-p); shot = true
			axis = -1.0 if shot else 0.0
			if grounded and p.y<310:
				change("b_reward")
		elif state == "b_reward":
			axis = -1.0 if p.x>386 else 0.0
			if p.x<430:
				controller.router.request_action(&"interact")
				if demo.claimed: change("return")
		elif state == "to_reward":
			axis = 1.0
			if grounded and p.x>=824 and p.x<890: jump()
			if p.x>1060:
				controller.router.request_action(&"interact")
				if demo.claimed: change("return")
		elif state == "return":
			axis = -1.0
			if variant == "A" and grounded and p.x<640 and p.x>560: jump()
			if variant == "A" and grounded and p.y>490 and p.x<560: jump()
			if p.x<210 and grounded:
				change("done")
		elif state == "done": break
		controller.router.set_move_axis(axis)
		if jump_started and jump_age>9:
			controller.router.set_jump_held(&"keyboard_mouse",false)
			jump_started = false
		await physics_frame
		var snap: Dictionary = demo.snapshot()
		snap.erase("events")
		snap["pilot_state"] = state
		trace.append(snap)
		if state_age>400:
			failed = "state_stalled:"+state
			break
	controller.router.set_move_axis(0)
	var final: Dictionary = demo.snapshot()
	var success: bool = state == "done" and (final.main_route_reached if strategy == "main_low" else final.bell_open and final.cache_claimed)
	var result := {"candidate":variant,"strategy":strategy,"success":success,"failure":failed,"final":final,"frames":trace,"commands":commands,"initial_fixture_spawn_override":false,"actor_teleport_by_driver":false,"resource_injection":false,"controller_manual_step":false,"enemy_disable":false,"scope":"isolated candidate Router journey, not formal campaign admission"}
	controller.router.clear("test_end")
	controller.air_focus_ability.stop()
	controller.shoot_ability.clear_projectiles()
	demo.latch.cancel()
	demo.lifetime.end()
	result["audio_drained"] = await load("res://tests/audio_teardown.gd").drain_world(demo)
	demo.free()
	for frame: int in 6: await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PLAINS_GOLDEN_MOTOR candidate=%s success=%s state=%s failure=%s" % [variant,success,state,failed])
	quit(0 if success and result.audio_drained else 1)

func change(next: String) -> void:
	state = next
	state_age = 0

func jump() -> void:
	controller.router.set_jump_held(&"keyboard_mouse",true)
	jump_started = true
	jump_age = 0
	commands.append({"tick":demo.ticks,"action":"jump","position":[controller.motor.position.x,controller.motor.position.y]})

func fire(direction: Vector2) -> void:
	if strategy == "no_shot":
		commands.append({"tick":demo.ticks,"action":"ablated_shoot_release"})
		return
	controller.router.set_aim(&"keyboard_mouse",direction,false)
	controller.router.request_action(&"shoot_release",direction)
	commands.append({"tick":demo.ticks,"action":"shoot_release","direction":[direction.x,direction.y]})
