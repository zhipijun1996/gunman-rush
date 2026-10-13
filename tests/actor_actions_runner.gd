extends SceneTree
var checks := 0
var failures := 0
var world: Node2D
var motor: PlayerMotor
var controller: PlayerController
var dt := 1.0/60
var events: Array[Dictionary] = []
func _initialize() -> void:
	if "--negative-probe" in OS.get_cmdline_user_args():
		print("ACTOR ACTIONS: 1 assertions, 1 failures")
		quit(1)
		return
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)
func fixture(at: Vector2 = Vector2(100,500)) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	body(Rect2(-500,700,2000,100))
	motor = preload("res://scenes/player/player.tscn").instantiate()
	motor.position = at
	world.add_child(motor)
	controller = motor.get_node("Controller")
	controller.set_physics_process(false)
	controller.enable_shot_energy()
	controller.air_focus_ability.enabled = false
	events.clear()
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, serial: int) -> void: events.append({"direction":direction,"serial":serial,"position":motor.position}))
	await physics_frame
func body(rect: Rect2, climbable: bool = false) -> StaticBody2D:
	var obstacle := StaticBody2D.new()
	obstacle.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	obstacle.add_child(shape)
	if climbable: obstacle.add_to_group(&"wall_climbable")
	world.add_child(obstacle)
	return obstacle
func tick(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		var before := motor.motion_steps
		controller.physics_tick(dt)
		check(motor.motion_steps == before+1,"sole Motor exactly once each tick")
func run() -> void:
	for hz: int in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		dt = 1.0/hz
		await fixture()
		var shot := controller.shoot_ability
		check(shot.equip(preload("res://resources/weapons/triple_machine_gun.tres")),"single equipped Lv2 definition")
		var energy := controller.actor_resources.stamina.current
		var charges := controller.action_resources.shot_charges
		controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await tick()
		var first_projectile := shot.get_projectiles()[0]
		check((first_projectile.global_position+first_projectile.launch_motion).is_equal_approx(shot.last_muzzle),"projectile and flash share accepted muzzle snapshot")
		controller.router.set_aim(&"keyboard_mouse",Vector2.LEFT)
		await tick(ceili(.13/dt))
		controller.router.set_aim(&"keyboard_mouse",Vector2.RIGHT)
		await tick(ceili(.16/dt))
		check(events.size()==3,"one packet produces three actual rounds at %sHz" % hz)
		if events.size()==3:
			check(events[0].direction==Vector2.DOWN and events[1].direction==Vector2.LEFT and events[2].direction==Vector2.RIGHT,"later rounds sample latest valid aim")
		check(controller.action_resources.shot_charges==charges-1,"one packet one air qualification")
		check(is_equal_approx(controller.actor_resources.stamina.current,energy-controller.shot_energy.shot_energy_cost),"one packet one shooting energy cost")
		check(motor.position.distance_to(Vector2(100,500))>20,"actual recoil displacement with empty world")
		var after := controller.actor_resources.stamina.current
		controller.on_projectile_hit(controller.session_id,shot.packet_id,true)
		controller.on_projectile_hit(controller.session_id,shot.packet_id,true)
		check(controller.actor_resources.stamina.current <= after+controller.shot_energy.hit_energy_recovery+.001,"packet hit returns capped once")
		await fixture()
		shot = controller.shoot_ability
		shot.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
		controller.router.request_action(&"shoot_release",Vector2.DOWN)
		await tick()
		controller.router.clear("pause")
		await tick(ceili(.3/dt))
		check(events.size()==1 and shot.rounds_remaining==0,"cancel prevents later rounds at everyHz")
	Engine.physics_ticks_per_second=60
	dt=1.0/60
	await fixture(Vector2(260,650))
	body(Rect2(280,-500,45,1200),true)
	controller.traversal.grant(&"wall_climb")
	controller.router.set_move_axis(1)
	await tick(20)
	controller.router.request_action(&"jump")
	await tick(12)
	var kicks := 0
	var low := motor.position.y
	for i: int in 190:
		if controller.traversal.state==&"wall_attach":
			controller.router.request_action(&"jump")
			kicks+=1
		await tick()
		low=minf(low,motor.position.y)
		check(motor.position.x <= 268.1,"wall climb body never tunnels through wall")
	var readiness := controller.traversal.wall_ready
	var separation := controller.traversal._separated
	controller.router.clear("pause")
	check(controller.traversal.wall_ready==readiness and controller.traversal._separated==separation,"pause does not mint a wall reattach token")
	check(kicks>=3 and low<400,"same-wall detach and reattach repeatedly climbs")
	check(controller.jump_ability.used_jumps==1,"wall reattach does not reset normal jump qualification")
	check(controller.action_resources.shot_charges==2,"wall reattach does not refill or add air shots")
	await fixture(Vector2(100,682))
	await tick(3)
	controller.traversal.grant(&"double_jump")
	controller.router.request_action(&"jump")
	await tick()
	controller.router.request_action(&"jump_release")
	await tick(12)
	controller.router.request_action(&"jump")
	await tick()
	check(controller.jump_ability.used_jumps==2 and motor.normal_velocity.y<0,"real second jump accepted")
	var visual := motor.get_node("CourierVisual") as CourierVisual
	check(visual.state==&"double_jump","accepted second jump triggers feather-wing animation")
	controller.router.request_action(&"jump")
	await tick()
	check(controller.jump_ability.used_jumps==2,"third jump rejected")
	controller.motor.tuning.max_jumps=3
	controller.traversal.grant(&"double_jump",false)
	check(controller.motor.tuning.max_jumps==3 and controller.jump_ability.maximum_jumps()==3,"double-jump revocation preserves other jump sources")
	await fixture()
	controller.traversal.grant(&"grapple")
	var anchor := GrappleAnchor.new()
	anchor.position=Vector2(400,494)
	world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick()
	var saw_pull := false
	var saw_kick := false
	var charges := controller.action_resources.shot_charges
	for i: int in 55:
		await tick()
		saw_pull = saw_pull or controller.traversal.state==&"hook_pull"
		saw_kick = saw_kick or controller.traversal.state==&"hook_kick"
	check(saw_pull and saw_kick and motor.position.x>350,"real hook flight pull contact and forward kick")
	check(controller.action_resources.shot_charges==charges,"hook does not refill air ammo")
	await fixture()
	controller.traversal.grant(&"grapple")
	body(Rect2(240,250,30,450))
	anchor=GrappleAnchor.new();anchor.position=Vector2(400,494);world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick(40)
	check(motor.position.x<220 and controller.traversal.state==&"free","solid obstruction fails hook safely")
	check(not controller.traversal.request_hook(Vector2.INF),"invalid hook direction rejected")
	controller.traversal.grant(&"grapple",false)
	check(not controller.traversal.request_hook(Vector2.RIGHT),"ungranted ability rejects action")
	# Regression: a hook accepted while standing must not be cancelled by the
	# preceding floor contact before its first pull step.
	await fixture(Vector2(100,682))
	controller.traversal.grant(&"grapple")
	await tick(3)
	anchor=GrappleAnchor.new();anchor.position=Vector2(400,676);world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	var grounded_kick := false
	for i: int in 55:
		await tick()
		grounded_kick=grounded_kick or controller.traversal.state==&"hook_kick"
	check(grounded_kick and motor.position.x>350,"grounded hook starts a real pull despite prior floor contact")
	await fixture()
	var packet := controller.shoot_ability
	packet.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await tick()
	controller.actor_resources.health.apply_damage(ActorResourceRequest.new(&"interrupt",controller.actor_resources.health.epoch,1,controller.actor_resources.health.get_instance_id()))
	await tick(20)
	check(events.size()==1,"committed hurt interrupts pending machine-gun rounds")
	packet.cooldown_remaining=0
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await tick()
	controller.die()
	await physics_frame
	check(packet.rounds_remaining==0 and packet.get_projectiles().is_empty(),"death cancels packet and actual projectiles")
	await fixture()
	# Adapter-level touch/gamepad cancel and no primary action from hook gesture.
	controller.router.grapple_available=true
	var pad := GamepadAdapter.new();pad.router=controller.router;world.add_child(pad);pad.set_physics_process(false)
	pad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,true)
	var actions := controller.router.consume_actions(10000)
	check(actions.size()==1 and actions[0].type==&"grapple","gamepad LB submits hook without primary")
	controller.router.clear("test")
	var overlay := TouchOverlay.new();overlay.router=controller.router;overlay.aim_origin=motor;world.add_child(overlay);overlay.set_enabled(true)
	var press := InputEventScreenTouch.new();press.index=4;press.pressed=true;press.position=overlay.hook_center
	overlay.handle_touch(press)
	actions=controller.router.consume_actions(10001)
	check(actions.size()==1 and actions[0].type==&"grapple","touch hook capture submits one independent action")
	controller.router.clear("pause")
	press.pressed=false;overlay.handle_touch(press)
	check(controller.router.consume_actions(10002).is_empty(),"cancelled hook touch release never shoots")
	# Extended frames stay transparent and anchored in both reflections.
	visual=motor.get_node("CourierVisual")
	for state: String in visual._action_catalog.states:
		for facing: float in [-1.0,1.0]:
			visual.clear_transition();visual.set_state(StringName(state));visual.set_facing(facing)
			for i: int in 8:
				visual._process(1.0/60)
				check(visual.body.texture is AtlasTexture and (visual.body.texture as AtlasTexture).filter_clip,"extended atlas clips texture boundary")
			check(visual.body.texture.get_image().get_pixel(0,0).a<.1,"new animation cell transparent margin")
	world.free()
	await process_frame
	var studio := preload("res://scenes/demo/action_studio.tscn").instantiate() as ActionStudio
	root.add_child(studio)
	await physics_frame
	check(studio.actors.size()==8 and studio.bosses.size()==3,"actual inventory covers eight enemy variants and three Boss consumers")
	var inventory: Array = [{"id":"Courier","scene":"res://scenes/player/player.tscn","consumer":str(studio.player.get_path())}]
	for actor: EnemyActor in studio.actors:
		inventory.append({"id":str(actor.definition.stable_id),"scene":"res://scenes/enemies/patrol_drone.tscn","consumer":str(actor.motor.get_path()),"presentation":actor.motor.get_node("Presentation").get_script().resource_path})
	for boss: BossEncounter in studio.bosses:
		inventory.append({"id":str(boss.definition.stable_id),"consumer":str(boss.motor.get_path()),"presentation":boss.motor.get_node("Presentation").get_script().resource_path})
	var file := FileAccess.open("res://build/actor_actions/runtime_inventory.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(inventory,"\t"));file.close()
	studio.leave();studio.queue_free()
	await process_frame
	await process_frame
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	check(nodes_after<=3,"Studio teardown returns live node count to root baseline")
	print("ACTOR ACTIONS: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
