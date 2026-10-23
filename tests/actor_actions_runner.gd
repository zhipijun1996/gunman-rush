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
	# Original action/weapon budgets bind D079 explicitly; current time-only
	# energy is separately exercised by demo-ui-time-energy in this Harness.
	motor.tuning.max_air_shots = 2
	controller.action_resources.reset()
	controller.enable_shot_energy(preload("res://resources/player/plains_shot_energy.tres"))
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
	await hook360_contract()
	DirAccess.make_dir_recursive_absolute("res://build/actor_actions")
	for hz: int in [30,60,120]:
		await traversal_rework_contract(hz)
		await refill_contract(hz)
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
	body(Rect2(280,-3000,45,3700),true)
	controller.traversal.grant(&"wall_climb")
	controller.traversal.grant(&"double_jump")
	controller.traversal.grant(&"grapple")
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
	check(controller.jump_ability.used_jumps==1 and not controller.traversal.hook_used,"real repeated wall kicks restore extra jump and hook without gifting ground jump")
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
	# Keep the real approach inside the shortened 231px hook budget.
	anchor.position=Vector2(310,494)
	world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick()
	var saw_pull := false
	var saw_kick := false
	var pull_peak := motor.position.x
	var launch_delta := Vector2.ZERO
	var charges := controller.action_resources.shot_charges
	for i: int in 55:
		await tick()
		saw_pull = saw_pull or controller.traversal.state==&"hook_pull"
		saw_kick = saw_kick or controller.traversal.state==&"hook_kick"
		pull_peak=maxf(pull_peak,motor.position.x)
		if controller.traversal.state==&"hook_kick" and launch_delta==Vector2.ZERO:launch_delta=motor.velocity
	check(saw_pull and saw_kick and pull_peak>260 and launch_delta.x<0 and launch_delta.y<0 and absf(launch_delta.x-launch_delta.y)<.1,"real hook reaches target then kicks 45 degrees toward incoming left side")
	check(controller.action_resources.shot_charges==charges,"hook does not refill air ammo")
	await fixture()
	controller.traversal.grant(&"grapple")
	body(Rect2(240,250,30,450))
	anchor=GrappleAnchor.new();anchor.position=Vector2(310,494);world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick(40)
	check(motor.position.x<220 and controller.traversal.state==&"free","solid obstruction fails hook safely")
	check(not controller.traversal.request_hook(Vector2.INF),"invalid hook direction rejected")
	controller.traversal.grant(&"grapple",false)
	check(not controller.traversal.request_hook(Vector2.RIGHT),"ungranted ability rejects action")
	await fixture(Vector2(100,500))
	body(Rect2(130,-500,30,1200))
	controller.shoot_ability.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
	controller.router.request_action(&"shoot_release",Vector2.LEFT)
	await tick(22)
	check(events.size()==1,"a wall blocking recoil cancels remaining rounds")
	await fixture(Vector2(118,500))
	body(Rect2(130,-500,30,1200))
	controller.shoot_ability.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await tick(22)
	check(events.size()==3,"parallel wall contact does not falsely cancel vertical recoil")
	controller.traversal.wall_enabled=true
	controller.traversal.state=&"wall_attach"
	motor.wall_slide_limit=75
	controller.shoot_ability.cooldown_remaining=0
	controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"))
	controller.traversal.state=&"wall_attach"
	motor.wall_slide_limit=75
	check(controller.shoot_ability.try_fire(Vector2.UP,false),"wall-shot combo accepts actual attack")
	check(controller.traversal.state==&"free" and motor.wall_slide_limit<0,"accepted shot releases adhesion and shows weapon recovery")
	# Regression: a hook accepted while standing must not be cancelled by the
	# preceding floor contact before its first pull step.
	await fixture(Vector2(100,682))
	controller.traversal.grant(&"grapple")
	await tick(3)
	anchor=GrappleAnchor.new();anchor.position=Vector2(310,676);world.add_child(anchor)
	await physics_frame
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	var grounded_kick := false
	var grounded_peak := motor.position.x
	for i: int in 55:
		await tick()
		grounded_kick=grounded_kick or controller.traversal.state==&"hook_kick"
		grounded_peak=maxf(grounded_peak,motor.position.x)
	check(grounded_kick and grounded_peak>260,"grounded hook reaches target despite prior floor contact")
	await fixture()
	var packet := controller.shoot_ability
	packet.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await tick()
	controller.actor_resources.health.apply_damage(ActorResourceRequest.new(&"interrupt",controller.actor_resources.health.epoch,1,controller.actor_resources.health.get_instance_id()))
	await tick(20)
	check(events.size()==1,"committed hurt interrupts pending machine-gun rounds")
	var malformed := WeaponDefinition.new()
	malformed.interval = INF
	check(not packet.equip(malformed),"malformed weapon is rejected without mutation")
	controller.router.request_action(&"shoot_release",Vector2.DOWN)
	packet.equip(preload("res://resources/weapons/pulse_gun.tres"))
	check(controller.router._queue.is_empty(),"equipment cancels old pending gesture")
	packet.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
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
	check(actions.is_empty() and controller.router.aim_mode==&"grapple" and controller.router.aim_engaged,"gamepad LB holds grapple aim without casting or primary")
	pad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false)
	actions=controller.router.consume_actions(10001)
	check(actions.size()==1 and actions[0].type==&"grapple","gamepad LB release submits hook without primary")
	controller.router.clear("test")
	var overlay := TouchOverlay.new();overlay.router=controller.router;overlay.aim_origin=motor;world.add_child(overlay);overlay.set_enabled(true)
	var press := InputEventScreenTouch.new();press.index=4;press.pressed=true;press.position=overlay.hook_center
	overlay.handle_touch(press)
	actions=controller.router.consume_actions(10002)
	check(actions.is_empty(),"hook stick press only captures aim")
	var drag := InputEventScreenDrag.new();drag.index=4;drag.position=press.position+Vector2(overlay.hook_radius,0)
	overlay.handle_touch(drag)
	check(controller.router.consume_actions(10003).is_empty(),"hook stick drag never fires primary or hook")
	press.pressed=false;press.position=drag.position;overlay.handle_touch(press)
	actions=controller.router.consume_actions(10004)
	check(actions.size()==1 and actions[0].type==&"grapple" and actions[0].direction.is_equal_approx(Vector2.RIGHT),"hook stick release submits exactly one aimed hook")
	press.pressed=true;press.position=overlay.hook_center;overlay.handle_touch(press)
	drag.position=press.position+Vector2(overlay.hook_radius,0);overlay.handle_touch(drag)
	controller.router.clear("pause")
	press.pressed=false;press.position=drag.position;overlay.handle_touch(press)
	check(controller.router.consume_actions(10005).is_empty(),"cancelled hook touch release never shoots")
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
	check(file != null,"actual inventory evidence file opens in a clean workspace")
	if file != null:
		file.store_string(JSON.stringify(inventory,"\t"));file.close()
	studio.leave();studio.queue_free()
	await process_frame
	await process_frame
	var nodes_after := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	check(nodes_after<=3,"Studio teardown returns live node count to root baseline")
	print("ACTOR ACTIONS: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func refill_contract(hz: int) -> void:
	Engine.physics_ticks_per_second = hz
	dt = 1.0/hz
	await fixture(Vector2(100,682))
	await tick(3)
	controller.traversal.grant(&"double_jump")
	controller.traversal.grant(&"grapple")
	controller.router.request_action(&"jump")
	await tick()
	controller.router.request_action(&"jump_release")
	await tick()
	controller.router.request_action(&"jump")
	await tick()
	check(controller.jump_ability.used_jumps == 2,"refill setup spends actual ground and air jump")
	controller.router.request_action(&"grapple",Vector2.LEFT)
	await tick(ceili(.34/dt))
	check(controller.traversal.hook_used and controller.jump_ability.used_jumps == 2,"miss spends hook and never restores air jump")
	check(not controller.traversal.request_hook(Vector2.RIGHT),"second airborne hook after miss rejected")
	controller.router.clear("pause")
	check(controller.traversal.hook_used,"pause preserves spent hook")
	# A real swept projectile commits enemy HP, not a fabricated hit callback.
	var enemy := Area2D.new()
	# The shot recoils left by 154px before the rightward hook; keep the
	# same real projectile -> refill -> hook chain inside the new 231px range.
	enemy.position = motor.position + Vector2(70,0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new(); rect.size = Vector2(30,600); shape.shape = rect
	enemy.add_child(shape)
	var receiver := Damageable.new(); receiver.name="Damageable"; receiver.faction=&"enemy"; receiver.max_health=10
	enemy.add_child(receiver); enemy.add_to_group(&"grapple_target"); world.add_child(enemy)
	await physics_frame
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await tick(ceili(.18/dt))
	check(receiver.health < 10,"actual airborne bullet damage commits")
	check(controller.jump_ability.used_jumps == 1 and not controller.traversal.hook_used,"committed airborne enemy hit restores D and H at %sHz" % hz)
	controller.router.request_action(&"jump")
	await tick()
	check(controller.jump_ability.used_jumps == 2 and (motor.get_node("CourierVisual") as CourierVisual).state == &"double_jump","restored jump immediately plays wings")
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick()
	check(controller.traversal.busy() and controller.traversal.hook_used,"restored hook can be fired again")
	# The existing hit receipt must not refill newly spent actions twice.
	controller.on_projectile_hit(controller.session_id,controller.shoot_ability.packet_id,true,1)
	check(controller.traversal.hook_used and controller.jump_ability.used_jumps == 2,"duplicate committed shot cannot mint another refill")
	var contact_seen := false
	var launch_seen := false
	var contact_origin := Vector2.ZERO
	for i: int in ceili(1.2/dt):
		await tick()
		if controller.traversal.state == &"hook_contact_kick":
			contact_seen = true
			contact_origin = motor.position
			check(controller.traversal.hook_used and controller.jump_ability.used_jumps == 2,"contact kick does not refill before launch")
		if controller.traversal.state == &"hook_kick":
			launch_seen = true
			break
	check(contact_seen and launch_seen,"real pull shows contact kick before diagonal launch")
	check(motor.position.x < contact_origin.x and motor.position.y < contact_origin.y,"hook boost exits toward incoming side and upward through Motor")
	check(not controller.traversal.hook_used and controller.jump_ability.used_jumps == 1,"completed real pull-kick restores both capacities")
	check(controller.traversal.state in [&"hook_kick",&"free"],"pull ends in kick recovery")
	# Separate boundary probes are not presented as an input-driven route.
	controller.traversal.hook_used=true; controller.jump_ability.used_jumps=2
	controller.on_projectile_hit(controller.session_id-1,900,true,900)
	controller.on_projectile_hit(controller.session_id,901,false,901)
	controller.on_projectile_hit(controller.session_id,902,true,902,false)
	check(controller.traversal.hook_used and controller.jump_ability.used_jumps==2,"stale/ground-fired/non-enemy callbacks cannot restore")
	controller.traversal.grant(&"double_jump",false)
	controller.on_projectile_hit(controller.session_id,903,true,903)
	check(controller.jump_ability.used_jumps==2,"hit cannot grant an unequipped double jump")
	controller.traversal.grant(&"double_jump")
	controller.traversal.hook_used=true
	controller.traversal.grant(&"wall_climb")
	controller.traversal.state=&"wall_attach"; controller.traversal.wall_ready=true; controller.traversal.wall_normal=-1
	check(controller.traversal.wall_jump(),"boundary probe accepts eligible wall kick")
	check(not controller.traversal.hook_used and controller.jump_ability.used_jumps==1,"accepted wall kick restores both capacities")
	controller.traversal.hook_used=true; controller.jump_ability.used_jumps=2
	check(not controller.traversal.wall_jump(),"repeat kick without recontact rejected")
	check(controller.traversal.hook_used and controller.jump_ability.used_jumps==2,"rejected kick cannot refill")
	controller.router.clear("focus_lost")
	check(controller.traversal.hook_used,"focus cancellation preserves hook budget")
	controller.reset_at(Vector2(100,500))
	check(not controller.traversal.hook_used,"new actor session clears hook budget")

	controller.router.request_action(&"grapple",Vector2.LEFT)
	await tick()
	check(controller.traversal.hook_used,"new flight consumes hook normally")
	await tick(ceili(1.1/dt))
	check(motor.is_on_floor() and not controller.traversal.hook_used,"real landing restores hook after a miss")

func traversal_rework_contract(hz: int) -> void:
	Engine.physics_ticks_per_second = hz
	dt = 1.0/hz
	await fixture(Vector2(260,650))
	body(Rect2(280,-3000,45,3700),true)
	controller.traversal.grant(&"wall_climb")
	controller.router.set_move_axis(1)
	await tick(ceili(.15/dt))
	check(controller.traversal.state == &"wall_attach","real collision accepts full-body wall cling at %sHz" % hz)
	var visual := motor.get_node("CourierVisual") as CourierVisual
	visual.wall_surface_x=visual.to_local(controller.traversal.wall_point).x
	visual.clear_transition();visual.set_state(&"wall_attach");visual._process(dt)
	var animation: Dictionary = visual._action_catalog.states.wall_attach
	var frame: Dictionary = animation.frames[0]
	var contact: Array = frame.wall_contact
	var surface := visual.to_global(visual.body.transform * Vector2(contact[0],contact[1]))
	check(absf(surface.x-280) < .5,"painted wall contact aligns with actual wall surface")
	var start := motor.position
	controller.router.request_action(&"jump")
	await tick()
	controller.router.set_move_axis(0)
	var peak := motor.position.y
	for i: int in ceili(.5/dt):
		await tick()
		peak=minf(peak,motor.position.y)
	check(start.y-peak >= 145 and start.y-peak <= 185,"wall jump actual height 145..185px at %sHz (measured %.2f)" % [hz,start.y-peak])
	check(motor.position.x < start.x-20,"wall jump actually detaches away from wall")
	await fixture(Vector2(100,-500))
	controller.traversal.grant(&"grapple")
	controller.traversal.grant(&"double_jump")
	controller.jump_ability.used_jumps=2
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	await tick()
	var saw_extension := false
	var saw_retraction := false
	var reach := 0.0
	for i: int in ceili(1.1/dt):
		await tick()
		if controller.traversal.state in [&"hook_fly",&"hook_miss"]:
			saw_extension=true
			reach=maxf(reach,controller.traversal.hook_start.distance_to(controller.traversal.hook_tip))
		if controller.traversal.state == &"hook_retract": saw_retraction=true
	check(saw_extension and saw_retraction,"empty hook has separate extension and return stages")
	check(reach <= controller.traversal.definition.hook_range+.01 and reach >= controller.traversal.definition.hook_range-1,"empty hook reaches finite configured range")
	check(controller.traversal.state == &"free" and controller.jump_ability.used_jumps==2,"empty hook returns without granting an air jump")

func hook360_contract() -> void:
	for index: int in 8:
		await fixture(Vector2(100,200))
		controller.traversal.grant(&"grapple")
		var direction := Vector2.RIGHT.rotated(index*PI/4.0)
		var target := Area2D.new();target.position=motor.position+Vector2(0,-6)+direction*200
		var shape := CollisionShape2D.new();var rect := RectangleShape2D.new();rect.size=Vector2(30,30);shape.shape=rect;target.add_child(shape)
		var receiver := Damageable.new();receiver.name="Damageable";receiver.faction=&"enemy";receiver.max_health=10;target.add_child(receiver)
		target.add_to_group(&"grapple_target");world.add_child(target)
		await physics_frame
		controller.router.request_action(&"grapple",direction);await tick()
		check(controller.traversal.hook_direction.dot(direction)>.9999,"360 hook preserves aim %s degrees" % (index*45))
		var pulled := false;var launched := false
		for i: int in 65:
			await tick()
			if controller.traversal.state == &"hook_pull":
				pulled=true
				check(controller.traversal.protects_contact(target),"hooked target body contact protected during pull")
				check(not controller.traversal.protects_contact(world),"other target/root cannot inherit contact protection")
			if controller.traversal.state == &"hook_kick":launched=true
		check(pulled and launched and receiver.health==9,"actual all-angle hook hits, pulls and kicks target once")
		check(not controller.traversal.protects_contact(target),"target protection expires after finite recovery")
		controller.traversal.cancel()
		check(not controller.traversal.protects_contact(target),"cancel clears target contact protection")
