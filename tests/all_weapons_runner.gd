extends "res://tests/actor_actions_runner.gd"
const IDS := ["pulse_gun","shadow_shuriken","recoil_bomb","triple_machine_gun","sustained_laser","fan_shuriken","remote_boomerang","magnetic_mine","collapse_singularity","machine_storm","laser_cannon","blade_bloom","moon_boomerang","magnetic_storm","star_collapse"]
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/weapons")
	for id: String in IDS:
		await fixture(Vector2(100,682));await tick(3)
		var def := load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
		check(def!=null and def.is_valid(),"valid distinct weapon %s" % id)
		check(controller.shoot_ability.equip(def),"single equipped weapon %s" % id)
		var target := enemy(Vector2(280,670))
		await physics_frame
		if def.mode in [WeaponDefinition.Mode.BOMB,WeaponDefinition.Mode.SINGULARITY]:
			controller.router.set_move_axis(1);await tick(20);controller.router.set_move_axis(0)
		var start := motor.position
		controller.router.activate_device(&"gamepad")
		controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
		if def.mode!=WeaponDefinition.Mode.LASER:controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await tick(20)
		if def.mode==WeaponDefinition.Mode.BOOMERANG:
			for attempt: int in 30:
				if target.health<100:break
				await tick()
			var items := controller.shoot_ability.behavior().current_entities()
			check(items.size()==1,"one controlled blade only")
			controller.router.request_action(&"weapon_context")
			await tick(20)
		elif def.mode==WeaponDefinition.Mode.MINE:
			var items := controller.shoot_ability.behavior().current_entities()
			check(items.size()==1 and items[0].phase==&"attached","mine attaches to real allowed enemy surface")
			controller.router.request_action(&"weapon_context");await tick(5)
		elif def.mode==WeaponDefinition.Mode.SINGULARITY:
			await tick(15)
		elif def.mode==WeaponDefinition.Mode.LASER:
			controller.router.set_aim(&"gamepad",Vector2.RIGHT,false);await tick(5)
		check(target.health<100,"%s actually commits damage" % id)
		check(motor.position.distance_to(start)>5 or def.mode==WeaponDefinition.Mode.MINE,"%s actual Motor displacement" % id)
		check(controller.combat_energy.current>0,"%s earns independent combat energy only from damage" % id)
		if def.tier==3:
			# Explicit initialized resource boundary; this is not earned-energy evidence.
			controller.shoot_ability.reset();controller.shoot_ability.cooldown_remaining=0
			if def.mode==WeaponDefinition.Mode.BOOMERANG:
				controller.router.set_move_axis(1);await tick(30);controller.router.set_move_axis(0)
			var health_before_skill := target.health
			controller.combat_energy.current=def.skill_cost
			controller.action_resources.reset()
			controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
			check(controller.shoot_ability.behavior().begin(Vector2.RIGHT,true,true),"Lv3 skill accepted once %s" % id)
			check(controller.combat_energy.current==0,"skill atomically consumes shared combat pool %s" % id)
			check(not controller.shoot_ability.behavior().begin(Vector2.RIGHT,true,true),"skill duplicate/insufficient resource rejected")
			await tick(35)
			if def.mode==WeaponDefinition.Mode.BOOMERANG:
				for attempt: int in 40:
					if target.health<health_before_skill:break
					await tick()
			controller.router.request_action(&"weapon_context");await tick(20)
			check(target.health<health_before_skill,"Lv3 skill commits additional real combat damage %s" % id)
			check(controller.combat_energy.current==0,"skill damage cannot refill its own cost %s" % id)
		var live := controller.shoot_ability.behavior().current_entities()
		controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"))
		check(controller.shoot_ability.behavior().current_entities().is_empty(),"equipment removes old physical entities")
		for item: WeaponEntity in live:check(not is_instance_valid(item) or item.spent,"old entity retired")
	await primary_equivalence()
	await beam_and_failures()
	await launch_clearance_and_skill_impact()
	await contact_protection_hp()
	await collision_and_resources()
	world.free();await process_frame
	print("ALL WEAPONS: %s assertions, %s failures" % [checks,failures]);quit(1 if failures else 0)
func enemy(point: Vector2) -> Damageable:
	var node := Area2D.new();node.position=point;node.collision_layer=2
	var shape := CollisionShape2D.new();var rectangle := RectangleShape2D.new();rectangle.size=Vector2(40,220);shape.shape=rectangle;node.add_child(shape)
	var target := Damageable.new();target.name="Damageable";target.faction=&"enemy";target.max_health=100;node.add_child(target);node.add_to_group(&"grapple_target");world.add_child(node);return target
func collision_and_resources() -> void:
	await fixture(Vector2(100,500));await tick()
	controller.shoot_ability.equip(preload("res://resources/weapons/fan_shuriken.tres"));body(Rect2(30,0,25,700))
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(20)
	check(motor.position.x>=67,"flash uses full player collision and cannot cross wall")
	check(controller.combat_energy.current==0,"empty blade attack never generates combat energy")
	var state := CombatEnergyState.new()
	state.committed_hit("real/1",10);state.committed_hit("real/1",10);state.committed_hit("real/1",11);state.committed_hit("real/1",12)
	check(state.current==state.definition.packet_gain_limit,"packet/target gains bounded and duplicate receipts ignored")
	check(not state.consume("too_much",60) and state.current==state.definition.packet_gain_limit,"insufficient atomic spend does not alter balance")
	state.committed_hit("skill/1",99,true);check(state.current==state.definition.packet_gain_limit,"skill cannot fund itself")

func primary_equivalence() -> void:
	var pairs := [["triple_machine_gun","machine_storm"],["sustained_laser","laser_cannon"],["fan_shuriken","blade_bloom"],["remote_boomerang","moon_boomerang"],["magnetic_mine","magnetic_storm"],["collapse_singularity","star_collapse"]]
	for pair: Array in pairs:
		var outputs: Array[Dictionary]=[]
		for id: String in pair:
			await fixture(Vector2(100,682));await tick(3)
			var def := load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
			controller.shoot_ability.equip(def)
			var target := enemy(Vector2(225,670));await physics_frame
			controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
			if def.mode!=WeaponDefinition.Mode.LASER:controller.router.request_action(&"shoot_release",Vector2.RIGHT)
			await tick(35)
			controller.router.set_aim(&"gamepad",Vector2.RIGHT,false)
			if def.mode in [WeaponDefinition.Mode.MINE,WeaponDefinition.Mode.BOOMERANG]:controller.router.request_action(&"weapon_context")
			await tick(20)
			outputs.append({"position":motor.position,"health":target.health,"shots":controller.action_resources.shot_charges,"energy":controller.actor_resources.stamina.current,"combat":controller.combat_energy.current})
		check(outputs[0].position.distance_to(outputs[1].position)<.2,"Lv3 primary preserves exact Lv2 movement %s" % pair[0])
		check(outputs[0].health==outputs[1].health and outputs[0].shots==outputs[1].shots,"Lv3 primary preserves damage and action budget %s" % pair[0])
		check(absf(outputs[0].energy-outputs[1].energy)<.1 and outputs[0].combat==outputs[1].combat,"Lv3 primary preserves independent costs/rewards %s" % pair[0])
func beam_and_failures() -> void:
	for hz: int in [30,60,120]:
		Engine.physics_ticks_per_second=hz;dt=1.0/hz
		await fixture(Vector2(100,682));await tick(3)
		controller.shoot_ability.equip(preload("res://resources/weapons/sustained_laser.tres"))
		controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.DOWN,true)
		var origin := motor.position
		await tick(ceili(.8/dt))
		check(motor.position.y<origin.y-15,"continuous downward beam really lifts at %sHz" % hz)
		var def := controller.shoot_ability.weapon
		await tick(ceili((def.beam_duration+.3)/dt))
		check(controller.shoot_ability.behavior().phase==&"idle","beam maximum hold ends and requires release")
		check(controller.combat_energy.current==0,"beam shooting terrain never gains combat currency")
	Engine.physics_ticks_per_second=60;dt=1.0/60
	await fixture(Vector2(100,682));await tick(3)
	controller.shoot_ability.equip(preload("res://resources/weapons/magnetic_mine.tres"))
	var target := enemy(Vector2(400,670));await physics_frame
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(35)
	var before := motor.position
	controller.router.request_action(&"weapon_context");await tick(5)
	check(motor.position.distance_to(before)<.1 and target.health<100,"distant mine damages enemy without remote player push")
	await fixture(Vector2(100,500));await tick()
	controller.shoot_ability.equip(preload("res://resources/weapons/collapse_singularity.tres"))
	controller.traversal.grant(&"grapple");controller.traversal.grant(&"double_jump")
	var start := motor.position
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(10)
	check(motor.position.distance_to(start)<.1,"singularity holds physical player at committed own position")
	controller.router.request_action(&"jump");controller.router.request_action(&"grapple",Vector2.UP)
	controller.router.set_move_axis(1);await tick(5)
	check(controller.traversal.state==&"free" and motor.position.distance_to(start)<.1,"hold rejects jump/hook/move without teleporting")
func contact_protection_hp() -> void:
	await fixture(Vector2(100,200))
	controller.traversal.grant(&"grapple")
	var target := enemy(Vector2(300,200));await physics_frame
	var policy := FrameDamagePolicy.new();policy.lifetime=DemoLifetime.new();world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	var contact := DemoContactEmitter.new();contact.policy=policy;contact.controller=controller;contact.half_size=Vector2(20,110);target.get_parent().add_child(contact)
	var hp := controller.actor_resources.health.current
	controller.router.request_action(&"grapple",Vector2.RIGHT)
	var protection_seen := false
	for i: int in 50:
		await tick()
		protection_seen=protection_seen or controller.traversal.protects_contact(target.get_parent())
	check(protection_seen and controller.actor_resources.health.current==hp,"real target swept body contact during hook cannot hurt player")
	var other := Node2D.new();other.position=motor.position;world.add_child(other)
	var other_contact := DemoContactEmitter.new();other_contact.policy=policy;other_contact.controller=controller;other.add_child(other_contact)
	await tick(3)
	check(controller.actor_resources.health.current<hp,"another monster contact remains damaging")

func launch_clearance_and_skill_impact() -> void:
	for id: String in ["shadow_shuriken","remote_boomerang","magnetic_mine","sustained_laser"]:
		await fixture(Vector2(100,500));await tick()
		body(Rect2(112,0,16,700))
		var target := enemy(Vector2(150,500));await physics_frame
		controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % id))
		controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.RIGHT,true)
		if id!="sustained_laser":controller.router.request_action(&"shoot_release",Vector2.RIGHT)
		await tick(20)
		if id=="magnetic_mine":
			var values := controller.shoot_ability.behavior().current_entities()
			check(values.is_empty() and target.health==100,"air mine immediately explodes on near side, never spawns through wall")
		else:check(target.health==100,"%s cannot spawn or shoot through adjacent wall" % id)
	await fixture(Vector2(100,682));await tick(3)
	body(Rect2(112,0,16,700));var blocked_target := enemy(Vector2(150,670));await physics_frame
	controller.shoot_ability.equip(preload("res://resources/weapons/magnetic_mine.tres"))
	controller.router.request_action(&"shoot_release",Vector2.RIGHT);await tick(10)
	var grounded_mines := controller.shoot_ability.behavior().current_entities()
	check(grounded_mines.size()==1 and grounded_mines[0].phase==&"attached" and grounded_mines[0].global_position.x<=112.1,"ground near-wall mine still attaches on near side")
	controller.router.request_action(&"weapon_context");await tick(3)
	check(blocked_target.health==100,"ground blast cannot cross intervening wall")
	await fixture(Vector2(100,682));await tick(3)
	var motor_enemy: EnemyMotor=preload("res://game/enemies/scenes/patrol_drone.tscn").instantiate()
	var actor: EnemyActor=motor_enemy.get_node("Actor")
	actor.definition=preload("res://resources/enemies/patrol_drone.tres").duplicate(true)
	actor.definition.health_definition.max_health=100;actor.definition.health_definition.initial_current=100
	actor.definition.patrol_speed=0;actor.definition.patrol_half_width=0
	motor_enemy.position=Vector2(250,682);world.add_child(motor_enemy);await physics_frame
	controller.shoot_ability.equip(preload("res://resources/weapons/blade_bloom.tres"))
	controller.combat_energy.current=60
	controller.router.activate_device(&"gamepad");controller.router.set_aim(&"gamepad",Vector2.RIGHT)
	controller.router.request_action(&"weapon_skill",Vector2.RIGHT)
	await tick(35)
	check(actor.health.current<100 and motor_enemy.position.x>250,"real skill damage causes bounded lightweight enemy knockback")
	var cooldown := actor._stagger_cooldown
	actor.apply_skill_impact(Vector2.RIGHT,.12,.45,500,.1)
	check(actor._stagger_cooldown<=cooldown+.001,"repeated skill hits cannot restart interrupt within cooldown")
