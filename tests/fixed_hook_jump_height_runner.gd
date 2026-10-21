extends SceneTree
## Real Router -> Controller -> JumpAbility -> sole Motor. Position writes only
## initialise each fixture; the grapple and every ascent are actually simulated.
const PLAYER := preload("res://scenes/player/player.tscn")
const DT := 1.0 / 60.0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var checks := 0
var failures := 0
var jump_events := 0
var case_name := ""
var trace: Array[Dictionary] = []
var peaks: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("FIXED HOOK JUMP: %s %s" % ["PASS" if ok else "FAIL", label])

func fixture() -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0,420)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1600,40)
	collision.shape = rectangle
	floor_body.add_child(collision)
	world.add_child(floor_body)
	player = PLAYER.instantiate()
	player.position = Vector2(0,382)
	world.add_child(player)
	controller = player.get_node("Controller")
	controller.set_physics_process(false)
	jump_events = 0
	controller.jump_ability.jumped.connect(func() -> void: jump_events += 1)
	await physics_frame
	await ticks(3)

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame
		var before := player.motion_steps
		controller.physics_tick(DT)
		if player.motion_steps != before+1:
			check(false,"each actual tick has exactly one Motor move")
		trace.append({"case":case_name,"position":[player.position.x,player.position.y],
			"velocity":[player.normal_velocity.x,player.normal_velocity.y],
			"hook":String(controller.traversal.state),"jump_events":jump_events,
			"hook_target_id":controller.traversal.hook_target.get_instance_id() if is_instance_valid(controller.traversal.hook_target) else 0,
			"hook_target_name":String(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else "",
			"hook_start":[controller.traversal.hook_start.x,controller.traversal.hook_start.y],
			"hook_tip":[controller.traversal.hook_tip.x,controller.traversal.hook_tip.y],
			"used_jumps":controller.jump_ability.used_jumps,
			"shot_charges":controller.action_resources.shot_charges,
			"grounded":player.is_on_floor(),"motor_step_delta":player.motion_steps-before})

func anchor(hanging := true) -> GrappleAnchor:
	var target := GrappleAnchor.new()
	target.name = "InitialHeldAnchor" if hanging else "AutomaticContactAnchor"
	target.position = Vector2(100,200)
	target.hang_enabled = hanging
	world.add_child(target)
	return target

func reach_anchor(hanging := true) -> GrappleAnchor:
	controller.traversal.grant(&"grapple")
	var target := anchor(hanging)
	await physics_frame
	controller.router.request_action(&"grapple",(target.global_position-player.global_position-Vector2(0,-6)).normalized())
	var wanted: StringName = &"hook_hang" if hanging else &"hook_contact_kick"
	for i: int in 90:
		await ticks(1)
		if controller.traversal.state == wanted: break
	check(controller.traversal.state == wanted,"actual hook reaches %s" % wanted)
	return target

func measure(held_ticks: int, from_anchor: bool) -> float:
	case_name = ("anchor" if from_anchor else "reference_second_jump")+"_%s" % held_ticks
	await fixture()
	if from_anchor:
		await reach_anchor()
		check(not controller.traversal.double_enabled and controller.jump_ability.maximum_jumps()==1,"anchor departure does not grant D or increase jump capacity")
	else:
		# Reference fixture explicitly owns D. It supplies the real second ascent,
		# rather than predicting height from duplicated gravity/speed constants.
		controller.traversal.grant(&"double_jump")
		await ticks(1)
		controller.router.request_action(&"jump")
		for i: int in 90:
			await ticks(1)
			if not player.is_on_floor() and player.normal_velocity.y>=0.0: break
		check(not player.is_on_floor() and controller.jump_ability.used_jumps==1,"reference consumes one real grounded jump before second launch")
	var origin := player.position.y
	var minimum := origin
	var shots := controller.action_resources.shot_charges
	var energy := controller.actor_resources.stamina.current
	var events_before := jump_events
	controller.router.request_action(&"jump")
	if held_ticks == 0: controller.router.request_action(&"jump_release")
	for tick: int in 90:
		if tick==held_ticks and held_ticks>0: controller.router.request_action(&"jump_release")
		await ticks(1)
		minimum = minf(minimum,player.position.y)
		if tick>1 and player.normal_velocity.y>=0.0: break
	check(jump_events==events_before+1,"one accepted input launches one actual ascent")
	check(controller.action_resources.shot_charges==shots and controller.actor_resources.stamina.current==energy,"departure does not refill or spend shooting resources")
	var height := origin-minimum
	peaks.append({"case":case_name,"height":height,"held_ticks":held_ticks,"speed_source":"config/player_tuning.json jump_speeds[1]"})
	return height

func run() -> void:
	var short_height := 0.0
	var long_height := 0.0
	for held: int in [0,30]:
		var reference := await measure(held,false)
		var actual := await measure(held,true)
		check(absf(actual-reference)<0.05,"fixed-anchor %s-tick hold matches real second-jump apex (actual %.3f reference %.3f)" % [held,actual,reference])
		if held==0: short_height=actual
		else: long_height=actual
	check(long_height>short_height+20.0,"hold and release retain useful variable-jump height difference")

	case_name = "no_free_repeat_and_landing"
	await fixture()
	await reach_anchor()
	var shots := controller.action_resources.shot_charges
	controller.router.request_action(&"jump")
	await ticks(2)
	check(controller.traversal.state==&"hook_kick" and player.recoil_burst_remaining==0.0,"release pose uses real gravity ascent, not short weapon burst")
	var accepted := jump_events
	controller.router.request_action(&"jump")
	await ticks(2)
	check(jump_events==accepted and controller.jump_ability.used_jumps==1,"repeat jump without a new fixed contact cannot grant another ascent")
	check(not controller.traversal.release_hang_for_jump(),"released anchor cannot launch a second time")
	check(controller.action_resources.shot_charges==shots,"repeat input does not refill shots")
	for i: int in 120:
		await ticks(1)
		if player.is_on_floor(): break
	check(player.is_on_floor() and controller.jump_ability.used_jumps==0 and not controller.traversal.hook_used,"ordinary landing restores ordinary jump and H qualification")
	controller.router.request_action(&"jump")
	await ticks(1)
	check(jump_events==accepted+1 and controller.jump_ability.used_jumps==1,"fresh grounded jump works after anchor departure and landing")

	case_name = "release_and_rehook"
	await fixture()
	await reach_anchor()
	controller.router.request_action(&"jump")
	await ticks(2)
	var next := GrappleAnchor.new()
	next.name = "SecondHeldAnchor"
	next.position = player.position+Vector2(110,-40)
	next.hang_enabled = true
	world.add_child(next)
	await physics_frame
	var next_direction := (next.position-player.position-Vector2(0,-6)).normalized()
	var now := Time.get_ticks_usec()/1000000.0
	for invalid: Dictionary in [
		{"timestamp":now-InputRouter.MAX_AGE_SECONDS*2.0},
		{"timestamp":now+1.0},
		{"timestamp":now,"epoch":controller.router.epoch+1},
		{"timestamp":now,"sequence":controller.router.sequence+1}]:
		check(not controller.traversal.request_hook(next_direction,invalid) and controller.traversal.state==&"hook_kick","manual anchor departure rejects stale/future/other-epoch/other-sequence H envelope %s" % invalid)
	controller.router.request_action(&"grapple",next_direction)
	await ticks(1)
	check(controller.traversal.state==&"hook_cast" and not player.is_on_floor(),"H after manual anchor jump begins immediately without the automatic-kick tail delay")
	for i: int in 90:
		await ticks(1)
		if controller.traversal.state==&"hook_hang" and controller.traversal.hook_target==next: break
	var received_next := controller.traversal.state==&"hook_hang" and controller.traversal.hook_target==next and not player.is_on_floor()
	check(received_next,"new H input after release reaches next actual fixed target")
	var repeat_origin := player.position.y
	var events_before_departure := jump_events
	if received_next:
		controller.router.request_action(&"jump")
		await ticks(2)
	check(received_next and jump_events==events_before_departure+1 and controller.traversal.hook_target==next and controller.traversal.state==&"hook_kick" and not player.is_on_floor() and player.position.y<repeat_origin and player.recoil_burst_remaining==0.0,"the second fixed target supplies its own airborne jump departure; grounded jumps cannot substitute")
	controller.router.clear("pause")
	var previous := player.normal_velocity.y
	await ticks(1)
	check(received_next and controller.traversal.state==&"free" and is_equal_approx(player.normal_velocity.y,previous+player.tuning.gravity*DT),"pause cancellation clears held ascent without reviving old jump")

	case_name = "existing_D_qualification"
	await fixture()
	controller.traversal.grant(&"double_jump")
	await reach_anchor()
	controller.router.request_action(&"jump")
	await ticks(2)
	check(controller.jump_ability.maximum_jumps()==2 and controller.jump_ability.used_jumps==1,"anchor departure preserves previously granted D instead of increasing capacity")
	controller.router.request_action(&"jump")
	await ticks(1)
	check(controller.jump_ability.used_jumps==2 and jump_events==2,"previously granted D remains usable once after anchor departure")
	controller.router.request_action(&"jump")
	await ticks(1)
	check(controller.jump_ability.used_jumps==2 and jump_events==2,"anchor departure does not grant a third jump")

	case_name = "disabled_jump"
	await fixture()
	await reach_anchor()
	controller.jump_ability.enabled=false
	controller.router.request_action(&"jump")
	await ticks(1)
	check(controller.traversal.state==&"hook_hang" and jump_events==0,"disabled jump cannot use anchor departure as a bypass")

	case_name = "legacy_automatic_contact"
	await fixture()
	await reach_anchor(false)
	var contact := player.position
	for i: int in 15:
		await ticks(1)
		if controller.traversal.state==&"hook_kick": break
	check(controller.traversal.state==&"hook_kick" and player.recoil_burst_remaining>0.0,"ordinary non-held target retains automatic short contact burst")
	check(jump_events==0,"automatic contact never invokes the new anchor jump")
	await ticks(5)
	check(player.position.y<contact.y and player.position.y>contact.y-40.0,"automatic target keeps its small kick rather than double-jump height")

	var output := "res://build/verification/fixed-hook-jump-height.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"peaks":peaks,"trace":trace,"real_router_controller_motor":true,"midroute_player_position_writes":false},"\t"))
	file.close()
	world.free()
	print("FIXED HOOK JUMP RESULT: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
