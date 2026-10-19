extends "res://tests/forest_directional_golden_runner.gd"
## Inherits scheduled Router actions and the real Motor observer, never a replayed position.
var program_index := 0
var program_started := -1
var first_hook_delay := 1
func _initialize() -> void:
	layout = "arch_four"
	output = "res://build/forest_feedback/air_chain01/capture.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="): variant = arg.trim_prefix("--variant=")
		elif arg.begins_with("--layout="): layout = arg.trim_prefix("--layout=")
		elif arg.begins_with("--launch-delay="): first_hook_delay = int(arg.trim_prefix("--launch-delay="))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	room=load("res://scripts/demo/forest_air_chain_golden.gd").new()
	room.layout=layout
	room.grant_hook=variant not in ["noH","naivejump","onlyR"]
	root.add_child(room)
	player=room.player;controller=room.controller
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.traversal.action_changed.connect(action_changed)
	controller.shoot_ability.shot_fired.connect(shot_fired)
	controller.jump_ability.jumped.connect(jumped)
	var driver:=Driver.new();driver.owner_tree=self;driver.process_physics_priority=-100;root.add_child(driver)
	var observer:=Observer.new();observer.owner_tree=self;observer.process_physics_priority=200;root.add_child(observer)
	while not finished:await process_frame
	if layout != "arch_four" and reached and recovered: returned = true
	driver.set_physics_process(false);observer.set_physics_process(false)
	controller.router.clear("golden_capture_complete")
	var data: Dictionary={"source_scope":"development_golden_not_formal_region_admission","variant":variant,"manifest":room.manifest,"frames":frames,"events":events,"requests":requests,"danger_contacts":danger_contacts,"reached":reached,"returned":returned,"recovered":recovered,"failure":failure,"manual_motor_step":false,"midroute_injection":false,"engine":Engine.get_version_info().string,"layout":layout,"first_hook_delay":first_hook_delay}
	var expected: bool = reached and returned and danger_contacts.is_empty() if variant in ["intended","skipLowerH"] else not reached and recovered
	if variant == "skipLastH": expected = (reached and returned and danger_contacts.is_empty()) or (not reached and recovered)
	data["passed"]=expected
	var audio_ok: bool=await preload("res://tests/audio_teardown.gd").drain_world(room)
	data["audio_released"]=audio_ok
	driver.free();observer.free();room.free()
	await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	print("FOREST AIR CHAIN: %s passed=%s reached=%s returned=%s recovered=%s contacts=%s ticks=%s"%[variant,expected,reached,returned,recovered,danger_contacts.size(),tick])
	quit(0 if expected and audio_ok else 1)

func drive() -> void:
	if layout == "arch_four":
		if phase == "side_wait" and controller.traversal.state == &"hook_kick": release_jump()
		if variant == "skipR" and phase == "side_wait" and controller.traversal.state == &"free" and age > 20:
			hook("arch_exit_ring")
			set_phase("arch_wait")
		if variant == "skipR" and controller.traversal.state in [&"hook_miss",&"hook_retract"] and phase in ["arch_wait","crown_wait"]:
			set_phase("catch")
		super.drive()
		if phase == "launch" and age == first_hook_delay and variant in ["intended","noH","skipR"]:
			hook("side_ring")
			set_phase("side_wait")
		return
	if finished: return
	tick += 1
	age += 1
	steps_before = player.motion_steps
	if layout=="hollow_spiral" and variant=="skipLowerH":
		if phase=="settle" and age==12:
			jump();set_phase("spiral_alt_launch")
		elif phase=="spiral_alt_launch" and age==24:
			action(&"shoot_release",Vector2.DOWN);release_jump();set_phase("spiral_alt_recoil")
		elif phase=="spiral_alt_recoil" and age>=9 and player.recoil_burst_remaining<=0:
			program_index=1;_next_program_action()
		if phase in ["settle","spiral_alt_launch","spiral_alt_recoil"]:return
	if layout=="hollow_spiral" and variant in ["onlyR","naivejump"]:
		if phase=="settle" and age==12:
			jump();set_phase("spiral_ordinary")
		elif phase=="spiral_ordinary":
			controller.router.set_move_axis(clampf((float(room.manifest.goal[0])-player.position.x)/20,-1,1))
			# Full held jump followed by two straight-up bursts at their real
			# apexes is a stronger vertical alternative than removing H inputs.
			if variant=="onlyR" and age==24: action(&"shoot_release",Vector2.DOWN)
			if variant=="onlyR" and age==42: action(&"shoot_release",Vector2.DOWN)
			if age==43 or (variant=="naivejump" and age==24):release_jump()
			if age>70 and on_support("entry"):
				controller.router.set_move_axis(0);recovered=true;finished=true
			elif age>70 and on_support("recovery"):set_phase("recover_walk")
		if phase in ["settle","spiral_ordinary"]:return
	if layout=="hollow_spiral" and phase=="land_crown" and age>15 and on_support("entry"):
		controller.router.set_move_axis(0);set_phase("catch")
	if tick > 1100:
		failure = "bounded_route_timeout/"+phase
		finished = true
		return
	if layout in ["bridge_five","hollow_spiral"] and not reached and on_support("recovery") and phase not in ["recover_walk","recover_step","recover_entry"]:
		release_jump()
		controller.router.clear("bridge_real_root_recovery")
		set_phase("recover_walk")
	if layout in ["bridge_five","hollow_spiral"] and phase == "catch" and on_support("entry"):
		var entry_rect: Array = room.manifest.platforms[0].rect
		var full_entry: bool = player.is_on_floor() and player.position.x-12 >= float(entry_rect[0])-.1 and player.position.x+12 <= float(entry_rect[0])+float(entry_rect[2])+.1 and absf(player.position.y+18-float(entry_rect[1]))<1
		stable = stable+1 if full_entry else 0
		if stable >= 12:
			recovered = true
			finished = true
		return
	if phase == "settle" and age == 12:
		jump()
		set_phase("two_launch")
	elif phase == "two_launch":
		if age == 6: release_jump()
		if age == (first_hook_delay if str(room.manifest.action_program[0].action) == "H" else 7):
			program_index = 0
			if layout == "bridge_five" and variant in ["onlyR","naivejump"]:
				controller.router.set_move_axis(1)
				set_phase("bridge_ordinary")
			else:
				_next_program_action()
	elif phase == "bridge_ordinary":
		controller.router.set_move_axis(1)
		if variant == "onlyR" and age == 9: action(&"shoot_release",Vector2.LEFT)
		if variant == "onlyR" and age == 25: action(&"shoot_release",Vector2(-.8,.6).normalized())
	elif phase == "program_wait":
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]:
			release_jump()
			set_phase("catch")
		elif controller.traversal.state == &"free" and player.recoil_burst_remaining <= 0 and age >= (9 if str(room.manifest.action_program[program_index].action) == "R" else 20):
			var expected_action: Dictionary = room.manifest.action_program[program_index]
			if str(expected_action.action) == "H" and variant != "noH":
				var contacts: Array = events.filter(func(e: Dictionary) -> bool: return int(e.tick)>=program_started and e.kind=="hook_contact_kick")
				if contacts.size()!=1 or str(contacts[0].get("target",""))!=str(expected_action.anchor):
					failure = "program_H_wrong_or_missing_target/"+str(program_index)+"/"+str(expected_action.anchor)
					finished = true
					return
			release_jump()
			program_index += 1
			_next_program_action()
	elif phase == "land_crown":
		controller.router.set_move_axis(clampf((float(room.manifest.goal[0])-player.position.x)/20,-1,1))
		stable = stable+1 if on_support("crown") else 0
		if stable >= 12:
			reached = true
			controller.router.set_move_axis(1)
			set_phase("bank_return")
	elif phase == "bank_return":
		var crown_row: Dictionary = room.manifest.platforms.filter(func(row: Dictionary) -> bool:return row.id=="crown")[0]
		var clear_x: float = float(crown_row.rect[0])+float(crown_row.rect[2])+36.0
		if layout == "bridge_five": clear_x = float(room.manifest.return.drop_outside_x)
		controller.router.set_move_axis(1 if player.position.x < clear_x else 0)
		if on_support("recovery") and (layout != "bridge_five" or player.position.x >= clear_x-5):
			controller.router.set_move_axis(0)
			set_phase("recover_walk")
	elif layout == "bridge_five" and phase == "recover_entry":
		# The shared-tree port starts at -50 rather than the old -220 shore.
		# A real diagonal shot on the second recovery jump crosses that offset.
		controller.router.set_move_axis(1 if player.position.x < 20 else 0)
		if age == 7: action(&"shoot_release",Vector2(-.8,.6).normalized())
		if age == 12: release_jump()
		stable = stable+1 if on_support("entry") else 0
		if stable >= 12:
			recovered = true
			finished = true
	else:
		# Only use the original recovery driver. Its tick increment is balanced.
		tick -= 1
		age -= 1
		super.drive()
func _next_program_action() -> void:
	if program_index >= room.manifest.action_program.size():
		set_phase("land_crown")
		return
	var row: Dictionary = room.manifest.action_program[program_index]
	if layout in ["bridge_five","hollow_spiral"] and variant == "skipLastH" and program_index == room.manifest.action_program.size()-1:
		program_index += 1
		_next_program_action()
		return
	program_started = tick
	if layout in ["bridge_five","hollow_spiral"] and variant == "skipR" and row.action == "R":
		program_index += 1
		_next_program_action()
		return
	if row.action == "H": hook(row.anchor)
	else: action(&"shoot_release",Vector2(row.direction[0],row.direction[1]))
	set_phase("program_wait")
func observe() -> void:
	super.observe()
	if not frames.is_empty():
		frames[-1]["health"] = controller.actor_resources.health.current
		frames[-1]["program_index"] = program_index

func action_changed(state: StringName) -> void:
	super.action_changed(state)
	if not events.is_empty():
		events[-1]["hook_tip"] = [controller.traversal.hook_tip.x,controller.traversal.hook_tip.y]
		events[-1]["hook_used_at_event"] = controller.traversal.hook_used
