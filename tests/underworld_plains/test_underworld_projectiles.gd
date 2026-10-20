extends SceneTree
## Real swept collisions and existing controller/economy. No GPU approval claim.
var checks := 0
var failures: Array[String] = []
var fixture: RefCounted
var world: Node2D
var capture := false
var media: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FAIL: ",label)
func snapshot(label: String) -> void:
	if not capture: return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://build/underworld_r3/projectiles/gpu/"+label+".png"
	root.get_texture().get_image().save_png(path)
	media.append(path)
func setup(underworld := true) -> void:
	fixture = preload("res://tests/combat_tests.gd").new()
	fixture.tree = self
	await fixture.fixture(Vector2(80,100))
	world = fixture.world
	world.set_meta("underworld_formal_style",underworld)
	if capture:
		var backdrop := ColorRect.new();backdrop.color=Color("425b51");backdrop.size=Vector2(640,360);backdrop.z_index=-20;world.add_child(backdrop)
		var label := Label.new();label.text="ACTUAL PROJECTILE FIXTURE / NOT FORMAL LEVEL";label.position=Vector2(8,250);world.add_child(label)
func effects(impact: bool) -> int:
	var count := 0
	for child: Node in world.get_children():
		if child is UnderworldProjectileVisual and child.impact == impact and not child.is_queued_for_deletion(): count += 1
	return count
func clear() -> void:
	world.free()
	await process_frame
func player_shot() -> PlayerProjectile:
	fixture.shoot.cooldown_remaining = 0
	check(fixture.shoot.try_fire(Vector2.RIGHT,false),"actual ShootAbility accepts packet")
	var shot: PlayerProjectile = fixture.shoot.get_projectiles().back()
	shot.set_physics_process(false)
	shot.launch_motion = Vector2.ZERO
	return shot
func boss_shot(id: StringName, target: Node2D, at: Vector2, bell := false) -> BossProjectile:
	var shot: BossProjectile = BellstriderBellProjectile.new() if bell else BossProjectile.new()
	var definition: BossDefinition = load("res://resources/bosses/clockwork_guardian.tres")
	shot.configure(definition,id,Vector2.RIGHT,target,null)
	world.add_child(shot)
	shot.global_position = at
	shot.set_physics_process(false)
	return shot
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	if capture:
		root.size=Vector2i(640,360)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/underworld_r3/projectiles/gpu"))
	await setup()
	check(UnderworldProjectileVisual.enabled(world),"actual ancestor enables Underworld")
	var target: StaticBody2D = fixture.body(Rect2(180,82,20,36),&"enemy")
	var receiver := target.get_node("Damageable") as Damageable
	await physics_frame
	var shot := player_shot()
	var baseline := [shot.speed,shot.radius,shot.damage,shot.lifetime]
	var skin := PixelPlainsProjectile.new();skin.projectile=shot;shot.presentation=skin;shot.add_child(skin)
	shot.advance(.02)
	check(is_instance_valid(shot.presentation) and shot.presentation is PixelPlainsProjectile,"real DemoApp skin remains active and delegates Underworld drawing")
	check(effects(false)==1 and effects(true)==0,"accepted launch has one muzzle and no fake impact")
	check([shot.speed,shot.radius,shot.damage,shot.lifetime]==baseline,"presentation leaves projectile tuning unchanged")
	await snapshot("player_flight")
	shot.advance(.2)
	check(shot.spent and receiver.health==receiver.max_health-shot.damage,"true swept player bullet damages once")
	check(effects(true)==1,"physical contact spawns one local spark independent of damage acceptance")
	shot.advance(.1)
	check(receiver.health==receiver.max_health-shot.damage and effects(true)==1,"spent shot cannot repeat damage or VFX")
	await snapshot("player_contact")
	await process_frame
	await process_frame
	check(effects(false)==0,"cancelled/spent source clears muzzle via weak owner")
	for child: Node in world.get_children():
		if child is UnderworldProjectileVisual: child._process(.2)
	await process_frame
	check(effects(true)==0,"contact VFX expires at bounded native lifetime")
	await clear()
	await setup()
	fixture.body(Rect2(120,70,10,60))
	target=fixture.body(Rect2(180,82,20,36),&"enemy");receiver=target.get_node("Damageable")
	await physics_frame
	shot=player_shot();shot.advance(.2)
	check(shot.spent and receiver.health==receiver.max_health,"wall occludes target with presentation enabled")
	check(effects(true)==1,"wall contact is a spark, not an actor damage grant")
	await clear()
	await setup()
	shot=player_shot();shot.weapon_epoch+=1;shot.advance(.01)
	check(shot.spent and effects(true)==0 and effects(false)==0,"obsolete weapon epoch emits no launch/contact")
	await clear()
	await setup()
	shot=player_shot();shot.lifetime=0;shot.advance(.01)
	check(shot.spent and effects(true)==0 and effects(false)==0,"natural lifetime produces no fake launch or hit")
	await clear()
	await setup()
	fixture.body(Rect2(120,82,20,36),&"player")
	target=fixture.body(Rect2(180,82,20,36),&"enemy");receiver=target.get_node("Damageable")
	await physics_frame
	shot=player_shot();shot.advance(.2)
	check(shot.spent and receiver.health==receiver.max_health-shot.damage,"friendly hurtbox cannot hide later enemy or wall")
	await clear()
	await setup()
	shot=player_shot();shot.advance(.01)
	var muzzle: UnderworldProjectileVisual
	for child: Node in world.get_children():
		if child is UnderworldProjectileVisual: muzzle=child
	var age_before := muzzle.age
	paused=true
	for i: int in 3: await process_frame
	check(muzzle.age==age_before and not shot.spent,"pause freezes cosmetic lifetime and actual disabled-step projectile")
	paused=false
	await process_frame
	await process_frame
	check(muzzle.age>age_before,"native effect resumes after pause")
	shot.weapon_epoch+=1;shot.advance(.01)
	await process_frame
	await process_frame
	check(not is_instance_valid(shot) and effects(false)==0 and effects(true)==0,"mid-flight equipment cancellation clears trail/muzzle without explosion")
	await clear()
	await setup(false)
	shot=player_shot();shot.advance(.01)
	check(not UnderworldProjectileVisual.enabled(shot) and effects(false)==0,"legacy context does not install Underworld effects")
	await clear()
	await setup()
	for kind: StringName in [&"bullet",&"blade"]:
		shot=player_shot();shot.art_kind=kind;shot.advance(.01)
		check(shot.art_kind==kind and not shot.spent,"bullet and blade retain distinct live identities")
		shot.dispose()
	await clear()
	await setup()
	var target_body := fixture.motor as Node2D
	var boss := boss_shot(&"test-ring",target_body,Vector2(20,100))
	var hits: Array[StringName] = []
	boss.hit.connect(func(_body: Node2D,id: StringName,_amount: float): hits.append(id))
	await physics_frame
	boss.advance(.01)
	await snapshot("boss_flight")
	boss.advance(.4)
	check(boss.spent and hits.size()==1,"real Boss circle sweeps player exactly once")
	check(effects(true)==1 and boss._visual_trail.size()==2,"Boss true contact and bounded trail exist")
	boss.advance(.1);check(hits.size()==1,"spent boss shot cannot duplicate hit")
	await clear()
	await setup()
	fixture.body(Rect2(45,60,8,80))
	boss=boss_shot(&"wall-ring",fixture.motor,Vector2(20,100))
	hits.clear();boss.hit.connect(func(_body: Node2D,id: StringName,_amount: float): hits.append(id))
	await physics_frame
	boss.advance(.4)
	check(boss.spent and hits.is_empty() and effects(true)==1,"Boss wall blocks player and creates contact only")
	await clear()
	await setup()
	for id: StringName in [&"windblade:1",&"pier-test"]:
		boss=boss_shot(id,fixture.motor,Vector2(20,20));boss.advance(.01)
		check(not boss._visible_attack(),"existing sweep proxy stays owned by actual Boss attack presentation")
	check(effects(false)==0,"invisible sweep proxies never pretend to be flying bullets")
	await clear()
	await setup()
	boss=boss_shot(&"bellstrider_lob",fixture.motor,Vector2(200,20),true)
	var bell := boss as BellstriderBellProjectile
	bell.aim_landing(Vector2(400,60))
	var vy := bell.flight_velocity.y
	bell.advance(.05)
	check(bell.flight_velocity.y>vy and not bell.spent,"actual bell preserves ballistic gravity")
	await snapshot("ballistic_bell")
	check(bell._visual_launched and bell._visual_trail.size()==1,"ballistic bell delegates real path history and source art")
	bell.dispose();check(effects(true)==0,"cancelled ballistic bell does not explode")
	await clear()
	await enemy_cases()
	if capture:
		var out:=FileAccess.open("res://build/underworld_r3/projectiles/gpu/receipt.json",FileAccess.WRITE)
		out.store_string(JSON.stringify({"checks":checks,"failures":failures,"media":media,"scope":"actual consumer fixture; formal level/continuous movie not claimed"},"  "));out.close()
	print("UNDERWORLD_PROJECTILES checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func enemy_cases() -> void:
	for stale: bool in [false,true]:
		await setup()
		var enemy: EnemyMotor=load("res://scenes/enemies/patrol_drone.tscn").instantiate()
		enemy.position=Vector2(20,100);world.add_child(enemy)
		var actor:=enemy.get_node("Actor") as EnemyActor;actor.set_physics_process(false)
		actor.definition=load("res://resources/enemies/plains_sentry.tres")
		var scope:=DemoLifetime.new()
		var policy:=FrameDamagePolicy.new();policy.lifetime=scope;world.add_child(policy);policy.set_physics_process(false)
		policy.register_target(&"player",fixture.controller.actor_resources.health,true)
		var behavior:=EnemyAttackBehavior.new();actor.add_child(behavior)
		behavior.configure(actor,fixture.controller,policy,scope,&"test-sentry",[])
		var seed:=EnemyAttackProjectile.new();seed.configure(behavior,&"seed-1",Vector2.RIGHT)
		world.add_child(seed);seed.global_position=Vector2(20,100);seed.set_physics_process(false)
		await physics_frame
		var hp: float=fixture.controller.actor_resources.health.current
		if stale:scope.invalidate_actor()
		if not stale:
			seed._physics_process(.01)
			await snapshot("enemy_seed_flight")
		seed._physics_process(.4)
		var result:=policy.resolve_batch()
		if stale:
			check(seed.spent and effects(true)==0 and effects(false)==0 and result.is_empty(),"old actor epoch seed cancels without contact, launch or damage")
		else:
			check(seed.spent and result.size()==1 and fixture.controller.actor_resources.health.current==hp-1,"real enemy seed collision submits one accepted policy damage")
			check(result.size()==1 and result[0].request.hit_direction==Vector2.RIGHT,"actual hostile projectile direction reaches accepted damage feedback")
			check(effects(false)==1 and effects(true)==1,"enemy has actual launch and contact VFX")
		await clear()
