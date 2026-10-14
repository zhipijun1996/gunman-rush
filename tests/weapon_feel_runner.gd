extends "res://tests/all_weapons_runner.gd"
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/weapon_feel")
	await distance_and_instant()
	await boundary_angles()
	await laser_accumulation()
	await delayed_blink()
	await blade_flight()
	await cancel_lifecycle()
	world.free();await process_frame
	print("WEAPON FEEL: %s assertions, %s failures" % [checks,failures]);quit(1 if failures else 0)
func equip_id(id: String) -> void:
	check(controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % id)),"equip %s" % id)
	controller.router.activate_device(&"gamepad")
func distance_and_instant() -> void:
	for ground: bool in [false,true]:
		var results: Array[float]=[]
		for id: String in ["pulse_gun","recoil_bomb","shadow_shuriken","remote_boomerang"]:
			await fixture(Vector2(100,682 if ground else 200));await tick(3)
			equip_id(id)
			var start := motor.position
			var target := enemy(start+Vector2(95,0));await physics_frame
			var hp := target.health
			controller.router.request_action(&"shoot_release",Vector2.RIGHT)
			await tick()
			if id=="recoil_bomb":
				check(target.health<hp,"Lv1 bomb real damage on release tick")
				check(controller.shoot_ability.behavior().current_entities().is_empty(),"instant bomb leaves no fuse entity")
				check(not controller.shoot_ability.behavior()._fx.is_empty(),"accepted blast has feedback")
			await tick(15)
			results.append(start.x-motor.position.x)
		for distance: float in results:check(absf(distance-results[0])<.1,"Lv1 + boomerang base distance equal ground=%s" % ground)
	for hz: int in [30,60,120]:
		Engine.physics_ticks_per_second=hz;dt=1.0/hz
		await fixture(Vector2(100,200));await tick()
		equip_id("shadow_shuriken")
		motor.normal_velocity=Vector2(330,500);motor.apply_impulse(Vector2(100,300))
		var records: Array[Dictionary]=[]
		motor.weapon_blinked.connect(func(start: Vector2,finish: Vector2)->void:records.append({"start":start,"finish":finish,"normal":motor.normal_velocity,"recoil":motor.recoil_velocity}))
		controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(ceili(.12/dt))
		check(records.size()==1,"single instant commit at %sHz" % hz)
		if records.size()==1:
			check(absf(records[0].start.distance_to(records[0].finish)-motor.tuning.shot_burst_speed*motor.tuning.shot_burst_duration)<.1,"instant exact shared distance")
			check(records[0].normal==Vector2.ZERO and records[0].recoil==Vector2.ZERO,"instant cancels every velocity")
		await fixture(Vector2(100,200));await tick();equip_id("shadow_shuriken")
		body(Rect2(40,0,15,700));controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(ceili(.15/dt))
		check(motor.position.x>=67,"blink clips full body at near wall")
	Engine.physics_ticks_per_second=60;dt=1.0/60
func boundary_angles() -> void:
	for aim: Vector2 in [Vector2(1,-1).normalized(),Vector2(-1,-.3).normalized()]:
		var distances: Array[float]=[]
		for id: String in ["pulse_gun","shadow_shuriken","recoil_bomb","remote_boomerang"]:
			await fixture(Vector2(100,682));await tick(3);equip_id(id)
			var x := motor.position.x
			controller.router.request_action(&"shoot_release",aim);await tick(18)
			distances.append(absf(motor.position.x-x))
		for distance: float in distances:check(absf(distance-distances[0])<.3,"ground diagonal boundary shares slide distance")
func laser_accumulation() -> void:
	var results: Array[float]=[]
	for hz: int in [30,60,120]:
		Engine.physics_ticks_per_second=hz;dt=1.0/hz
		await fixture(Vector2(100,200));await tick();equip_id("sustained_laser")
		controller.router.set_aim(&"gamepad",Vector2.DOWN,true)
		await tick()
		await tick(ceili(.2/dt));var first := -motor.recoil_velocity.y
		await tick(ceili(.2/dt));var second := -motor.recoil_velocity.y
		check(second>first*1.8,"held beam accelerates, no recoil decay %sHz" % hz)
		check(absf(second-2*first)<1,"constant cumulative acceleration")
		results.append(second)
		controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);await tick(ceili(.1/dt))
		check(motor.recoil_velocity.x < -70,"turn beam adds new reverse direction")
		var before := motor.recoil_velocity.length()
		controller.router.set_aim(&"gamepad",Vector2.RIGHT,false);await tick()
		check(before>0 and motor.recoil_velocity==Vector2.ZERO,"release immediately clears beam drive")
		await tick(ceili(.15/dt))
		check(controller.shoot_ability.behavior().phase==&"idle" and motor.recoil_velocity==Vector2.ZERO,"release ends accumulation without residual drive")
	for value: float in results:check(absf(value-results[0])<1,"beam curve stable across Hz")
	Engine.physics_ticks_per_second=60;dt=1.0/60
func delayed_blink() -> void:
	await fixture(Vector2(100,200));await tick();equip_id("fan_shuriken")
	var records: Array[Dictionary]=[]
	motor.weapon_blinked.connect(func(start: Vector2,finish: Vector2)->void:records.append({"tick":controller._tick,"delta":finish-start}))
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
	check(records.size()==1,"fan first flash before delay")
	controller.router.set_aim(&"gamepad",Vector2.LEFT,true);controller.router.set_move_axis(1);await tick(8)
	check(records.size()==1,"visible interval permits reposition")
	await tick(12)
	check(records.size()==2,"fan delayed second flash occurs once")
	if records.size()==2:
		check((records[1].tick-records[0].tick)*dt>=.29,"second flash delay >= contract")
		check(records[0].delta.x<0 and records[1].delta.x>0,"second flash follows adjusted aim")
func blade_flight() -> void:
	await fixture(Vector2(100,682));await tick(3);equip_id("remote_boomerang")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
	var items := controller.shoot_ability.behavior().current_entities()
	check(items.size()==1,"one real blade outbound")
	if items.is_empty():return
	var blade := items[0];var transitions: Array[StringName]=[]
	controller.shoot_ability.behavior().entity_transition.connect(func(_item: WeaponEntity,state: StringName)->void:transitions.append(state))
	var p := blade.global_position;await tick(10)
	check(absf(blade.global_position.distance_to(p)-300*dt*10)<1,"slow outbound speed real path")
	for i: int in 160:
		if blade.phase==&"auto_return":break
		await tick()
	check(blade.phase==&"auto_return" and blade.start_point.distance_to(blade.global_position)>660,"far range changes to automatic return")
	p=blade.global_position;await tick(10)
	check(absf(blade.global_position.distance_to(p)-300*dt*10)<1,"automatic return same slow speed")
	check(not blade.manual_recall,"natural return has no manual boost")
	var start := motor.position
	controller.router.request_action(&"weapon_context");await tick()
	check(blade.spent and transitions.has(&"returning") and transitions.has(&"caught"),"manual recall sweeps and catches in same accepted tick")
	check(motor.position.x<start.x-5,"manual catch causes actual second reverse burst")
	await fixture(Vector2(100,682));await tick(3);equip_id("remote_boomerang")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
	blade=controller.shoot_ability.behavior().current_entities()[0]
	await tick(300)
	check((not is_instance_valid(blade) or blade.spent) and motor.recoil_burst_remaining==0,"natural slow catch retires blade without second boost")
	await fixture(Vector2(100,682));await tick(3);equip_id("remote_boomerang")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(20)
	blade=controller.shoot_ability.behavior().current_entities()[0]
	body(Rect2(100,0,10,700));await physics_frame
	controller.router.request_action(&"weapon_context");await tick()
	check(blade.spent and motor.recoil_burst_remaining==0,"instant recall cannot cross new intervening wall or grant catch")
	await fixture(Vector2(100,150));await tick();equip_id("remote_boomerang")
	controller.router.set_aim(&"gamepad",Vector2.RIGHT,true);controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
	blade=controller.shoot_ability.behavior().current_entities()[0]
	var y := blade.global_position.y
	controller.router.set_aim(&"gamepad",Vector2.UP,true);await tick(10)
	check(blade.global_position.y<y-40,"air right stick genuinely redirects blade")
	var focus := controller.air_focus_ability;focus.enabled=true
	focus.advance(2.1,false,true,true,true,controller.shoot_ability.weapon.steering_focus_drain_ratio)
	check(focus.active and Engine.time_scale<1 and focus.stamina>0,"controlled blade slow time continues past standard cap")
	focus.advance(.1,false,false,true,true,.25)
	check(not focus.active and Engine.time_scale==1,"releasing aim ends slow time")
	focus.stop();focus.enabled=false
func cancel_lifecycle() -> void:
	await fixture(Vector2(100,200));await tick();equip_id("fan_shuriken")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(8)
	var count := [0];motor.weapon_blinked.connect(func(_a: Vector2,_b: Vector2)->void:count[0]+=1)
	controller.router.clear("pause");await tick(30)
	check(count[0]==0,"pause cancellation suppresses pending second flash")
	await fixture(Vector2(100,200));await tick();equip_id("shadow_shuriken")
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick()
	controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"));var x := motor.position.x;await tick(10)
	check(absf(motor.position.x-x)<.1,"equipment suppresses old windup blink")

	await fixture(Vector2(100,200));await tick();equip_id("shadow_shuriken")
	var behavior := controller.shoot_ability.behavior()
	check(behavior.begin(Vector2.RIGHT,false),"pending blink accepted through runtime")
	behavior.advance(controller.shoot_ability.weapon.throw_windup+.01)
	controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"));x=motor.position.x;await tick()
	check(absf(motor.position.x-x)<.1,"queued Motor blink cannot survive equipment epoch")
