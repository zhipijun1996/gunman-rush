extends SceneTree
## Actual scene/controller/input/sole Motor; position writes are fixture initialization only.
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var failures := 0
var checks := 0
var trace: Array[Dictionary] = []
var events: Array[Dictionary] = []
var case_name := ""
var legacy_collision := false
func _initialize() -> void:
	legacy_collision="--legacy-collision" in OS.get_cmdline_user_args()
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	print("GRAPPLE FEEL: ","PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func slab(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new();shape.size=rect.size;collision.shape=shape
	body.add_child(collision);world.add_child(body)
func fixture(start: Vector2, floor_rect: Rect2) -> void:
	if is_instance_valid(world): world.free()
	world=Node2D.new();root.add_child(world)
	slab(floor_rect)
	player=preload("res://scenes/player/player.tscn").instantiate()
	player.position=start;world.add_child(player)
	controller=player.get_node("Controller")
	if legacy_collision:
		controller.traversal.free()
		controller.traversal=load("res://tests/support/grapple_legacy_collision.gd").new()
		controller.add_child(controller.traversal)
		controller.traversal.configure(controller)
	controller.traversal.action_changed.connect(func(state: StringName) -> void: events.append({"case":case_name,"state":String(state),"tip":[controller.traversal.hook_tip.x,controller.traversal.hook_tip.y],"position":[player.position.x,player.position.y]}))
	controller.traversal.grant(&"grapple")
	await frames(3)
func frames(count: int) -> void:
	for i: int in count:
		await physics_frame;await process_frame
		trace.append({"case":case_name,"position":[player.position.x,player.position.y],"state":String(controller.traversal.state),"motor_steps":player.motion_steps})
func anchor(point: Vector2, hanging := false) -> GrappleAnchor:
	var ring := GrappleAnchor.new();ring.position=point
	# Metadata allows this same baseline runner to execute before hang support exists.
	ring.set_meta("grapple_hang",hanging)
	if "hang_enabled" in ring: ring.set("hang_enabled",hanging)
	world.add_child(ring);return ring
func hook(ring: Node2D) -> void:
	controller.router.request_action(&"grapple",(ring.global_position-player.global_position-Vector2(0,-6)).normalized())
func wait_state(wanted: StringName, limit := 100) -> bool:
	for i: int in limit:
		if controller.traversal.state==wanted:return true
		await frames(1)
	return false
func run() -> void:
	case_name="edge_diagonal_down"
	await fixture(Vector2(96,182),Rect2(-200,200,300,30))
	var ring := anchor(Vector2(215,300))
	hook(ring)
	check(await wait_state(&"hook_contact_kick"),"edge diagonal-down slides off support then reaches real target")
	check(events.any(func(event: Dictionary) -> bool: return event["case"]=="edge_diagonal_down" and event.state=="hook_pull"),"diagonal-down hook actually hits target and begins pull")
	check(player.position.x>100,"body actually clears platform edge")
	if legacy_collision:
		write_result();world.free();quit(1 if failures else 0);return
	case_name="solid_wall"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	slab(Rect2(55,40,30,160));ring=anchor(Vector2(150,170))
	hook(ring);await frames(60)
	check(player.position.x<44,"solid wall blocks body and hook without teleport")
	check(controller.traversal.state==&"free","blocked hook returns to controllable state")
	case_name="vertical_kick"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(1,30));hook(ring)
	check(await wait_state(&"hook_contact_kick"),"upper hook reaches actual contact")
	var contact := player.position
	check(await wait_state(&"hook_kick"),"upper hook enters short kick")
	await frames(5)
	check(absf(player.position.x-contact.x)<2,"near-vertical hook kick does not choose unstable lateral direction")
	for aim_x: float in [-70.0,-1.0,70.0]:
		case_name="kick_angle_%s" % aim_x
		await fixture(Vector2(0,182),Rect2(-200,200,500,30))
		ring=anchor(Vector2(aim_x,30));hook(ring)
		check(await wait_state(&"hook_contact_kick"),"angular kick reaches target: %s" % aim_x)
		contact=player.position
		check(await wait_state(&"hook_kick"),"angular kick executes: %s" % aim_x)
		await frames(5)
		var side_travel := player.position.x-contact.x
		check(absf(side_travel)<2 if absf(aim_x)<2 else side_travel*signf(aim_x)<-8,"vertical cone stable and deliberate sidekick retained: %s" % aim_x)
	case_name="hanging_hold_release"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"explicit hanging ring accepts full-body arrival")
	var held := player.position
	var charges := controller.action_resources.shot_charges
	await frames(120)
	check(player.position.distance_to(held)<.2 and controller.traversal.state==&"hook_hang","ring holds for two seconds without gravity drift")
	check(controller.action_resources.shot_charges==charges,"holding does not refill shooting resources")
	controller.router.request_action(&"jump");await frames(3)
	check(controller.traversal.state==&"hook_kick" and player.position.y<held.y,"jump releases ring through existing short kick")
	case_name="hanging_fire"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"fire fixture reaches ring")
	held=player.position
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(3)
	check(controller.traversal.state==&"free" and player.position.x>held.x+10,"accepted shot detaches and applies actual recoil")
	case_name="hanging_target_removed"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"invalidation fixture reaches ring")
	ring.queue_free();await frames(5)
	check(controller.traversal.state==&"free","removed ring releases safely")
	case_name="hanging_cancel"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"cancel fixture reaches ring")
	controller.router.clear("pause");await frames(2)
	check(controller.traversal.state==&"free","input cancellation clears attachment")
	case_name="hanging_rehook"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"relay fixture reaches first ring")
	var second := anchor(Vector2(250,35),true)
	controller.router.aim_mode=&"grapple"
	controller.router.set_aim(controller.router.current_device,(second.position-player.position-Vector2(0,-6)).normalized(),true)
	await frames(2)
	events.append({"case":case_name,"event":"held_guide","active":controller.traversal.guide_active,"valid":controller.traversal.guide_target_valid,"point":[controller.traversal.guide_point.x,controller.traversal.guide_point.y],"aim":[controller.router.aim_direction.x,controller.router.aim_direction.y],"engaged":controller.router.aim_engaged})
	check(controller.traversal.guide_active and controller.traversal.guide_target_valid and controller.traversal.guide_point.distance_to(second.position)<15,"held ring previews next target rather than itself")
	controller.router.aim_mode=&"attack"
	controller.router.set_aim(controller.router.current_device,Vector2.RIGHT,false)
	hook(second);await frames(1)
	check(await wait_state(&"hook_hang") and controller.traversal.hook_target==second,"H from rest ring reaches next actual ring without landing")
	case_name="hanging_rejected_shot"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"empty weapon fixture reaches ring")
	controller.action_resources.shot_charges=0
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(3)
	check(controller.traversal.state==&"hook_hang","rejected shot retains attachment and does not invent recoil")
	case_name="hanging_ability_removed"
	controller.traversal.grant(&"grapple",false);await frames(2)
	check(controller.traversal.state==&"free" and not controller.traversal.hook_enabled,"ability removal releases hanging state")
	case_name="hanging_death"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"death fixture reaches ring")
	controller.die();await frames(2)
	check(controller.traversal.state==&"free" and not controller.active,"death clears attachment before future input")
	case_name="moving_ring_obstruction"
	await fixture(Vector2(0,182),Rect2(-200,200,500,30))
	ring=anchor(Vector2(100,50),true);hook(ring)
	check(await wait_state(&"hook_hang"),"moving fixture reaches ring")
	held=player.position
	# Moving environment fixture, never player relocation. A small shift is followed.
	ring.position.x+=5;await frames(3)
	check(absf(player.position.x-held.x-5)<.2,"moving rest ring carries body through sole Motor")
	slab(Rect2(player.position.x+20,-100,30,300))
	ring.position.x+=100;await frames(10)
	check(controller.traversal.state==&"free" and player.position.x<held.x+30,"obstructed moved ring detaches without crossing wall")
	write_result()
	world.free();quit(1 if failures else 0)
func write_result() -> void:
	print("GRAPPLE FEEL RESULT: %s checks, %s failures" % [checks,failures])
	var output := "res://build/verification/grapple_feel.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"trace":trace,"events":events,"legacy_collision_control":legacy_collision,"real_controller":true,"midroute_position_writes":false},"\t"));file.close()
