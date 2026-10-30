extends SceneTree
## R3 formal Boss contracts. Phase/state entry is an explicit fixture; every
## tested damage amount below comes from a real Router -> ShootAbility sweep.
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var boss: BossMotor
var encounter: WindkeeperEncounter
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var contact: DemoContactEmitter
var defeats := 0
var emissions := 0
var trace_roll := false
var roll_frames:Array[Dictionary]=[]

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FAIL: ",label)
func frames(n: int) -> void:
	for i: int in n:
		await physics_frame
		if trace_roll:
			roll_frames.append({"tick":Engine.get_physics_frames(),"player":[player.global_position.x,player.global_position.y],"boss":[boss.global_position.x,boss.global_position.y],"mode":String(encounter.mode),"clock":encounter.clock,"hp":controller.actor_resources.health.current,"vy":player.normal_velocity.y,"jump":controller.jump_ability.used_jumps,"contact":str(encounter.body_contact_rect())})
func clear_fixture() -> void:
	if is_instance_valid(world):
		encounter.cancel()
		check(await load("res://tests/audio_teardown.gd").drain_world(world),"fixture audio drains")
		world.free()
		await frames(2)
func fixture(mini: bool, phase: int = 1, at := Vector2(350,582)) -> void:
	await clear_fixture()
	world=Node2D.new();world.set_meta("underworld_formal_style",true);root.add_child(world)
	var ground:=StaticBody2D.new();ground.position=Vector2(600,650)
	var ground_shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20000,100);ground_shape.shape=rect;ground.add_child(ground_shape);world.add_child(ground)
	player=preload("res://scenes/player/player.tscn").instantiate();player.position=at;world.add_child(player)
	controller=player.get_node("Controller")
	lifetime=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=lifetime;world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	boss=load("res://scenes/bosses/bellstrider.tscn" if mini else "res://scenes/bosses/windkeeper.tscn").instantiate()
	encounter=boss.get_node("Encounter")
	# This direct old-scene fixture retains exact historical v5 timings/36HP;
	# the current factory/App six-move60HP path is covered by pressure tests.
	var definition:WindkeeperDefinition=load("res://resources/bosses/bellstrider.tres" if mini else "res://resources/bosses/legacy/windkeeper_storm_continuous_v5.tres").duplicate(true)
	# Initial-current phase fixtures never submit fake combat damage.
	definition.health_definition.initial_current=(16.0 if phase==1 else 8.0) if mini else (36.0 if phase==1 else 23.0 if phase==2 else 11.0)
	encounter.definition=definition;boss.position=Vector2(650,535);world.add_child(boss)
	encounter.configure_arena(100,1100,player);encounter.set_physics_process(false)
	policy.bind_damageable(&"boss",boss.get_node("Damageable"),encounter.health)
	contact=DemoContactEmitter.new();contact.policy=policy;contact.controller=controller;contact.source_id=&"r3_actual_boss_body";contact.contact_rect_provider=encounter.body_contact_rect;contact.enabled=false;boss.add_child(contact)
	defeats=0;emissions=0
	encounter.defeated.connect(func(_e:BossEncounter)->void:defeats+=1)
	encounter.projectile_created.connect(func(shot:BossProjectile)->void:
		emissions+=1
		shot.hit.connect(func(body:Node2D,id:StringName,amount:float)->void:
			if body!=player:return
			var request:=DamageRequest.new();request.token=lifetime.token();request.actor_epoch=lifetime.actor_epoch;request.health_epoch=controller.actor_resources.health.epoch;request.target_id=&"player";request.source_id=&"r3_actual_boss_projectile";request.event_id=id;request.amount=amount;request.hit_direction=shot.direction;policy.submit(request)))
	await frames(4)
	check(encounter.activate(),"actual formal encounter activates")
	encounter.stage_phase=phase;encounter._enter(&"observe",30);encounter.physics_tick(.001)
	await frames(2)

func shoot_at(point:Vector2,label:String,expected:float=1) -> void:
	var before:=encounter.health.current
	controller.router.request_action(&"shoot_release",(point-player.global_position).normalized())
	await frames(maxi(24,ceili((point-player.global_position).length()/controller.motor.tuning.projectile_speed*60)+12))
	check(is_equal_approx(encounter.health.current,before-expected),label)
	observations.append({"label":label,"phase":encounter.stage_phase,"mode":String(encounter.mode),"before":before,"after":encounter.health.current,"expected":expected,"player_hp":controller.actor_resources.health.current,"tick":Engine.get_physics_frames(),"shape":str(encounter.body_contact_rect())})

func run() -> void:
	var tuning_hash:=FileAccess.get_sha256("res://config/player_tuning.json")
	if "--roll-only" in OS.get_cmdline_user_args():
		await roll_trials()
		await finish()
		return
	for mini:bool in [true,false]:
		for phase:int in ([1,2] if mini else [1,2,3]):
			await fixture(mini,phase)
			check(encounter.continuous_combat(),"formal Definition explicitly enables continuous combat")
			check(boss.collision_mask==0,"Boss body is a damage/hit volume, not an impassable wall")
			var states:Array=[&"observe",&"roll_warning",&"roll",&"neck"] if mini else ([&"observe",&"stomp_warning",&"charge",&"neck"] if phase==1 else [&"blade_warning",&"blades",&"back",&"phase_transition"] if phase==2 else [&"chase",&"pier_warning",&"pier_impact",&"pier_open"])
			for state:StringName in states:
				encounter._enter(state,30);encounter._update_combat_shapes();await frames(2)
				await shoot_at(boss.global_position+Vector2(0,-15),"%s phase %d %s body accepts actual shot"%["mini" if mini else "main",phase,state])
			check(encounter.accepts_core_direction({"hit_direction":Vector2.LEFT,"fired_airborne":false}),"continuous combat never locks direction or rune qualification")
			var snapshot:=encounter.combat_snapshot();var hp:=encounter.health.current
			encounter.restore_combat_state(JSON.parse_string(JSON.stringify(snapshot)))
			check(encounter.health.current==hp and encounter.mode==StringName(snapshot.mode) and boss.collision_layer==4,"JSON reload retains phase/mode/HP and actual shootable body")
			paused=true;var clock:=encounter.clock;var pos:=boss.global_position
			await create_timer(.08,true).timeout
			check(encounter.clock==clock and boss.global_position==pos,"paused encounter does not advance or move")
			paused=false
			encounter._enter(&"intro",10);encounter._update_combat_shapes();await frames(2)
			await shoot_at(boss.global_position,"intro rejects real swept shot",0)
			encounter.cancel();await shoot_at(boss.global_position,"inactive encounter rejects real swept shot",0)
	await roll_trials()
	# Actual Motor approach: the first four input ticks stay just outside the
	# defined chassis; subsequent accepted motion crosses the real side edge.
	await fixture(true,1,Vector2(550,582))
	contact.enabled=true
	var edge_hp:=controller.actor_resources.health.current
	for i:int in 4:
		controller.router.set_move_axis(1);await frames(1)
	check(controller.actor_resources.health.current==edge_hp,"real movement just outside contact edge does not hurt")
	for i:int in 3:
		controller.router.set_move_axis(1);await frames(1)
	check(controller.actor_resources.health.current<edge_hp,"real Motor crossing actual side edge accepts contact damage")
	controller.router.set_move_axis(0)
	# Actual projectile reaches body/core overlap once, then kills once. No raw HP call.
	await fixture(true)
	encounter._enter(&"neck",30);encounter._update_combat_shapes();await frames(2)
	await shoot_at(boss.global_position+encounter.core_offset(),"overlapping real core/body consumes one shot and only one HP")
	for i:int in 15:
		await shoot_at(boss.global_position+Vector2(0,-15),"real projectile lethal chain %d"%i)
	check(encounter.health.terminal and defeats==1 and not encounter.active and boss.collision_layer==0,"real projectile terminal emits one defeat and disables body")
	check(encounter._projectiles.is_empty(),"terminal encounter cancels all owned projectiles")
	await shoot_at(boss.global_position,"dead body rejects later real projectile",0)
	check(defeats==1,"late real projectile cannot emit duplicate defeat")
	check(tuning_hash==FileAccess.get_sha256("res://config/player_tuning.json"),"player physics source unchanged")
	await finish()

func roll_trials()->void:
	# Deliberately collide with a real body, then the same roll with one held jump.
	for jump:bool in [false,true]:
		await fixture(true,1,Vector2(430,582))
		trace_roll=true
		contact.enabled=true;encounter.direction=-1;encounter._enter(&"roll_warning",.85);encounter.set_physics_process(true)
		if jump:
			await frames(68)
			controller.router.set_jump_held(&"r3_roll_jump",true)
			controller.router.set_move_axis(1)
		var before:=controller.actor_resources.health.current
		if jump:
			for n:int in 78:
				controller.router.set_move_axis(1)
				await frames(1)
		else: await frames(150)
		check(controller.actor_resources.health.current==before if jump else controller.actor_resources.health.current<before,"held base jump clears actual full body roll" if jump else "standing in real roll lane takes contact damage")
		check(encounter.mode in [&"neck",&"observe",&"ring_warning"],"roll has bounded travel then recovery")
		controller.router.set_jump_held(&"r3_roll_jump",false)
		trace_roll=false

func finish()->void:
	await clear_fixture()
	DirAccess.make_dir_recursive_absolute("res://build/underworld_r3/boss")
	var f:=FileAccess.open("res://build/underworld_r3/boss/continuous_combat.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"roll_frames":roll_frames,"scope":"actual formal resources and real Router/ShootAbility/body/core physics; state entries explicit fixtures; not complete user normal battle acceptance"},"\t"));f.close()
	print("UNDERWORLD R3 BOSS: %d checks, %d failures"%[checks,failures.size()]);quit(1 if not failures.is_empty() else 0)
