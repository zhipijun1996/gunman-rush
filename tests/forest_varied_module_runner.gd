extends "res://tests/forest_air_chain_runner.gd"
## A finite local consumer. No formal-world, damage-policy or FUN claim.
var comparison_shots := 0
var comparison_hook := false
var cavity_cell := 0
var ordinary_index := 0
var ordinary_cursor := 1
var ordinary_last_drop := -100
func _initialize() -> void:
	layout = "forked_bough_hh"
	output = "res://build/region_bible_v2/forest-v17-local/capture.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--layout="): layout = arg.trim_prefix("--layout=")
		elif arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func run() -> void:
	room = load("res://experiments/generation/forest_varied_module_golden.gd").new()
	room.layout = layout
	room.grant_hook = variant not in ["noH", "naivejump", "onlyR"]
	root.add_child(room)
	player = room.player
	controller = room.controller
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.traversal.action_changed.connect(action_changed)
	controller.shoot_ability.shot_fired.connect(shot_fired)
	controller.jump_ability.jumped.connect(jumped)
	var driver := Driver.new()
	driver.owner_tree = self
	driver.process_physics_priority = -100
	root.add_child(driver)
	var observer := Observer.new()
	observer.owner_tree = self
	observer.process_physics_priority = 200
	root.add_child(observer)
	while not finished: await process_frame
	driver.set_physics_process(false)
	observer.set_physics_process(false)
	controller.router.clear("varied_local_sealed")
	var data := {"scope":"isolated_real_Router_Motor_receiver_not_world_admission","layout":layout,
		"variant":variant,"manifest":room.manifest,"frames":frames,"events":events,"requests":requests,
		"danger_contacts":danger_contacts,"reached":reached,"recovered":recovered,"failure":failure,
		"manual_motor_step":false,"midroute_injection":false,"formal_damage_policy":false}
	var passed: bool = failure.is_empty() and reached and danger_contacts.is_empty()
	if variant != "intended":
		# Comparisons report their real outcome, rather than demanding failure
		# merely because a proposed chain had more named actions.
		passed = failure.is_empty() and (reached or recovered)
	var clean: bool = await preload("res://tests/audio_teardown.gd").drain_world(room)
	data.audio_released = clean
	data.passed = passed and clean
	driver.free()
	observer.free()
	room.free()
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("FOREST VARIED LOCAL: "+("PASS" if data.passed else "FAIL")+" / "+layout+" / "+variant+" reached="+str(reached)+" ticks="+str(tick)+" failure="+failure)
	quit(0 if data.passed else 1)

func drive() -> void:
	if finished: return
	if str(room.manifest.get("routes",{}).get("main",{}).get("kind",""))=="ordinary_sequence":
		_drive_ordinary_input()
		return
	if variant=="intended" and room.manifest.has("cavity_contract") and phase!="land_crown":
		_drive_cavity_input()
		return
	if variant in ["jump_single_H", "onlyR", "naivejump"] and phase != "land_crown":
		_drive_alternative()
		return
	if phase == "land_crown":
		tick += 1
		age += 1
		steps_before = player.motion_steps
		var goal := Vector2(float(room.manifest.goal[0]),float(room.manifest.goal[1]))
		controller.router.set_move_axis(clampf((goal.x-player.position.x)/20.0,-1.0,1.0))
		var r: Array = room.manifest.platforms.filter(func(p: Dictionary) -> bool: return p.id=="crown")[0].rect
		var full: bool = on_support("crown") and player.position.x-12.0>=float(r[0])-.1 and player.position.x+12.0<=float(r[0])+float(r[2])+.1 and absf(player.position.y+18.0-float(r[1]))<1.0
		stable = stable+1 if full else 0
		if stable >= 12:
			reached = true
			finished = true
		if tick > 1100:
			failure = "bounded_receiver_timeout"
			finished = true
		return
	super.drive()

func _drive_ordinary_input() -> void:
	tick += 1
	age += 1
	steps_before = player.motion_steps
	var steps: Array = room.manifest.routes.main.steps
	if tick>16000 or age>1200:
		failure = "bounded_ordinary_module/"+str(ordinary_index)+"/"+phase
		finished = true
		return
	if not danger_contacts.is_empty():
		failure = "actual_ordinary_body_contact"
		finished = true
		return
	if phase=="settle":
		if age>=12 and on_support("entry"): set_phase("ordinary_align")
		return
	if ordinary_index>=steps.size():
		reached = true
		finished = true
		return
	var step: Dictionary = steps[ordinary_index]
	var target := Vector2(float(step.landing[0]),float(step.landing[1]))
	var support_id := str(step.support_id)
	if str(step.kind)=="walk":
		release_jump()
		controller.router.set_move_axis(clampf((target.x-player.position.x)/12.0,-1.0,1.0))
		stable = stable+1 if _ordinary_at(target,support_id) and absf(player.velocity.x)<1.0 else 0
		if stable>=12: _ordinary_complete()
		return
	if phase=="ordinary_align":
		var takeoff := Vector2(float(step.takeoff[0]),float(step.takeoff[1]))
		release_jump()
		controller.router.set_move_axis(clampf((takeoff.x-player.position.x)/12.0,-1.0,1.0))
		stable = stable+1 if _ordinary_at(takeoff,str(step.from_support_id)) and absf(player.velocity.x)<1.0 else 0
		if stable>=12:
			if step.kind=="drop_through":
				ordinary_cursor = 1
				set_phase("ordinary_drop")
			else:
				jump()
				set_phase("ordinary_jump")
		return
	if phase=="ordinary_jump":
		controller.router.set_move_axis(clampf((target.x-player.position.x)/12.0,-1.0,1.0))
		var r: Array = room.manifest.platforms.filter(func(p: Dictionary) -> bool: return p.id==support_id)[0].rect
		var full_x: bool = player.position.x-12.0>=float(r[0]) and player.position.x+12.0<=float(r[0])+float(r[2])
		var same: bool = str(step.from_support_id)==support_id
		if player.position.y+18.0<float(r[1])-1.0 and full_x and (not same or absf(player.position.x-target.x)<=12.0): release_jump()
		stable = stable+1 if _ordinary_at(target,support_id) and absf(player.velocity.x)<1.0 else 0
		if stable>=12:
			release_jump()
			_ordinary_complete()
		elif age>25 and player.is_on_floor() and not on_support(support_id):
			failure = "ordinary_jump_wrong_support/"+str(ordinary_index)
			finished = true
		return
	if phase=="ordinary_drop":
		var path: Array = step.path
		var mouth := Vector2(float(path[ordinary_cursor][0]),float(path[ordinary_cursor][1]))
		controller.router.set_move_axis(clampf((mouth.x-player.position.x)/12.0,-1.0,1.0))
		if ordinary_cursor>1 and player.is_on_floor() and player.position.y<mouth.y-20.0 and tick-ordinary_last_drop>=20:
			action(&"drop_through")
			ordinary_last_drop = tick
		if ordinary_cursor<path.size()-1:
			if absf(player.position.x-mouth.x)<7.0: ordinary_cursor+=1
			return
		stable = stable+1 if _ordinary_at(target,support_id) and absf(player.velocity.x)<1.0 else 0
		if stable>=12: _ordinary_complete()

func _ordinary_at(at: Vector2,support_id: String) -> bool:
	if not on_support(support_id) or player.position.distance_to(at)>1.0: return false
	var r: Array = room.manifest.platforms.filter(func(p: Dictionary) -> bool: return p.id==support_id)[0].rect
	return player.position.x-12.0>=float(r[0])-.1 and player.position.x+12.0<=float(r[0])+float(r[2])+.1 and absf(player.position.y+18.0-float(r[1]))<1.0

func _ordinary_complete() -> void:
	events.append({"kind":"actual_ordinary_leg_complete","tick":tick,"step":ordinary_index,"position":[player.position.x,player.position.y],"stable_frames":stable})
	ordinary_index+=1
	controller.router.set_move_axis(0.0)
	if ordinary_index>=room.manifest.routes.main.steps.size():
		reached = _ordinary_at(Vector2(float(room.manifest.goal[0]),float(room.manifest.goal[1])),"crown")
		if not reached: failure="ordinary_goal_support_mismatch"
		finished = true
	else: set_phase("ordinary_align")

func _drive_cavity_input() -> void:
	# Same supported two-cell choreography as the retained formal cavity
	# consumer: standing H/R, bay observation, walk-off, side H/R.
	tick += 1
	age += 1
	steps_before = player.motion_steps
	if tick>1100:
		failure = "bounded_cavity_timeout/"+phase
		finished = true
		return
	if not danger_contacts.is_empty():
		failure = "actual_cavity_body_contact"
		finished = true
		return
	if phase == "settle" and age>=12 and on_support("entry"):
		release_jump()
		controller.router.set_move_axis(0.0)
		hook("cavity_ring_a")
		set_phase("cavity_pull")
	elif phase == "cavity_pull":
		controller.router.set_move_axis(0.0)
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]:
			failure = "actual_cavity_hook_miss/"+str(cavity_cell)
			finished = true
			return
		if controller.traversal.state==&"free" and age>20:
			action(&"shoot_release",Vector2.LEFT)
			set_phase("cavity_cross")
	elif phase == "cavity_cross":
		var target: Array = room.manifest.nodes.B.position if cavity_cell==0 else room.manifest.goal
		var support_id := "cavity_bay" if cavity_cell==0 else "crown"
		controller.router.set_move_axis(clampf((float(target[0])-player.position.x)/12.0,-1.0,1.0))
		stable = stable+1 if on_support(support_id) and absf(player.position.x-float(target[0]))<.2 else 0
		if stable>=12:
			if cavity_cell==0:
				cavity_cell = 1
				events.append({"kind":"actual_cavity_bay_observation","tick":tick,"position":[player.position.x,player.position.y],"support":support_id,"grounded":player.is_on_floor(),"stable_frames":stable})
				set_phase("cavity_walkoff")
			else: set_phase("land_crown")
	elif phase == "cavity_walkoff":
		var rect: Array = room.manifest.platforms.filter(func(p: Dictionary) -> bool: return p.id=="cavity_bay")[0].rect
		controller.router.set_move_axis(1.0)
		if not player.is_on_floor() and player.position.x-12.0>=float(rect[0])+float(rect[2]):
			controller.router.set_move_axis(0.0)
			events.append({"kind":"actual_cavity_side_departure","tick":tick,"position":[player.position.x,player.position.y],"grounded":player.is_on_floor()})
			hook("cavity_ring_b")
			set_phase("cavity_pull")

func _drive_alternative() -> void:
	tick += 1
	age += 1
	steps_before = player.motion_steps
	var goal := Vector2(float(room.manifest.goal[0]),float(room.manifest.goal[1]))
	if phase == "settle":
		var entry: Array = room.manifest.platforms.filter(func(p: Dictionary) -> bool: return p.id=="entry")[0].rect
		var takeoff_x := clampf(50.0,float(entry[0])+24.0,float(entry[0])+float(entry[2])-24.0)
		controller.router.set_move_axis(clampf((takeoff_x-player.position.x)/12.0,-1.0,1.0))
		if age >= 12 and on_support("entry") and absf(player.position.x-takeoff_x)<2.0:
			jump()
			set_phase("comparison_flight")
		return
	controller.router.set_move_axis(clampf((goal.x-player.position.x)/20.0,-1.0,1.0))
	if player.normal_velocity.y >= 0.0 or comparison_hook: release_jump()
	if variant == "jump_single_H" and not comparison_hook:
		var target: Dictionary = room.manifest.hook_anchors[-1]
		var point := Vector2(float(target.position[0]),float(target.position[1]))
		var origin := player.position+Vector2(0.0,-6.0)
		if age>=12 and origin.distance_to(point)<=controller.traversal.definition.hook_range-8.0:
			hook(str(target.id))
			comparison_hook = true
	if variant == "onlyR" and comparison_shots<2 and not player.is_on_floor() and age >= 20+comparison_shots*20 and controller.shoot_ability.cooldown_remaining<=0.0 and player.recoil_burst_remaining<=0.0:
		action(&"shoot_release",Vector2.LEFT)
		comparison_shots += 1
	if on_support("crown"):
		set_phase("land_crown")
		return
	if age>60 and (on_support("entry") or on_support("recovery")):
		controller.router.set_move_axis(0.0)
		stable += 1
		if stable>=12:
			recovered = true
			finished = true
	else: stable = 0
	if tick>1100:
		failure = "bounded_alternative_timeout/"+phase
		finished = true
