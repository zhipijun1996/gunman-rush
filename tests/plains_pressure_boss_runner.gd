extends SceneTree
## New attacks use real physics/shot/damage; positions below are explicit fixtures.
var assertions:=0
var failures:=0
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var boss: BossMotor
var encounter: WindkeeperEncounter
var life: DemoLifetime
var policy: FrameDamagePolicy
var created: Array[Dictionary]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures+=1;printerr("FAIL: "+message)
func frames(n: int) -> void:
	for i: int in n: await physics_frame
func fixture(mini: bool, at: Vector2=Vector2(350,582)) -> void:
	if is_instance_valid(world): world.free()
	world=Node2D.new();root.add_child(world)
	var module:=preload("res://scenes/generation/modules/plains_boss_arena.tscn").instantiate()
	world.add_child(module)
	player=preload("res://scenes/player/player.tscn").instantiate();player.position=at;world.add_child(player)
	controller=player.get_node("Controller")
	life=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	boss=load("res://scenes/bosses/bellstrider.tscn" if mini else "res://scenes/bosses/windkeeper.tscn").instantiate()
	if not mini: (boss.get_node("Encounter") as BossEncounter).definition=preload("res://resources/bosses/windkeeper_storm.tres")
	boss.position=Vector2(560,535);world.add_child(boss)
	encounter=boss.get_node("Encounter");encounter.configure_arena(125,995,player)
	policy.bind_damageable(&"boss",boss.get_node("Damageable"),encounter.health)
	created.clear()
	encounter.projectile_created.connect(func(shot: BossProjectile) -> void:
		created.append({"id":String(shot.event_id),"aim":shot.direction})
		shot.hit.connect(func(body: Node2D,event: StringName,amount: float) -> void:
			if body!=player: return
			var request:=DamageRequest.new();request.token=life.token();request.actor_epoch=life.actor_epoch
			request.health_epoch=controller.actor_resources.health.epoch;request.target_id=&"player";request.source_id=&"boss_fixture"
			request.event_id=event;request.amount=amount;policy.submit(request))
	)
	await frames(3)
	check(encounter.activate(),"actual redesigned Boss activates")
func run() -> void:
	await fixture(true)
	check(encounter is BellstriderEncounter and encounter.health.capacity==16,"mini is independent machine with sixteen HP")
	encounter._enter(&"neck",2)
	await frames(2)
	var hp:=encounter.health.current
	check(controller.shoot_ability.try_fire(boss.position+encounter.core_offset()-player.position,true),"ordinary real shot aims at machine core")
	await frames(25)
	check(encounter.health.current==hp-1,"redesigned actual core accepts one real shot")
	var mini:=encounter as BellstriderEncounter
	mini.pattern_index=2;mini.locked_point=Vector2(350,582);mini.volley=1
	mini._enter(&"lob",.5)
	var data: Dictionary=JSON.parse_string(JSON.stringify(mini.combat_snapshot()))
	mini.pattern_index=0;mini.volley=0;mini.restore_combat_state(data)
	check(mini.pattern_index==2 and mini.volley==1 and mini.locked_point==Vector2(350,582),"JSON restoration retains attack order and committed landing")
	mini.cancel_pending_attacks()
	check(mini.mode==&"observe" and mini._projectiles.is_empty(),"return cancels obsolete bell attacks")
	await fixture(true,Vector2(390,582))
	encounter._enter(&"ring_warning",.01)
	await frames(90)
	check(controller.actor_resources.health.current<5,"real ring wave damages grounded target")
	await fixture(true,Vector2(390,582))
	encounter._enter(&"ring_warning",.01)
	controller.router.set_jump_held(&"ring_dodge",true)
	await frames(70)
	check(controller.actor_resources.health.current==5,"unchanged one held jump clears ring wave")
	check(controller.motor.tuning.max_jumps==1 and controller.motor.tuning.max_air_shots==2,"mini dodge preserves original action budget")
	await fixture(true)
	mini=encounter as BellstriderEncounter
	mini.direction=-1;mini._enter(&"roll_warning",.01)
	await frames(100)
	check(boss.position.x<400 and mini.mode==&"neck" and mini.core_open,"physical rolling dash travels then exposes core")
	check(absf((boss.get_node("Presentation") as BellstriderPresentation).wheel_angle)>1,"wheel animation follows actual movement")
	await fixture(true)
	mini=encounter as BellstriderEncounter
	mini.health.apply_damage(ActorResourceRequest.new(&"half",mini.health.epoch,8,mini.health.get_instance_id()))
	mini._enter(&"ring_warning",.01)
	await frames(58)
	check(mini.stage_phase==2 and created.size()==4,"half-health ring pattern adds a separately timed second pair")
	mini.cancel_pending_attacks()
	mini.locked_point=Vector2(350,582);mini._enter(&"lob_warning",.01)
	await frames(2)
	mini._prune_attacks()
	check(mini._projectiles.any(func(p: BossProjectile): return p is BellstriderBellProjectile),"lob is a real swept ballistic bell, not a placeholder marker")
	var bell: BellstriderBellProjectile
	for p: BossProjectile in mini._projectiles:
		if p is BellstriderBellProjectile: bell=p;break
	var vy:=bell.flight_velocity.y
	await frames(12)
	check(not is_instance_valid(bell) or bell.flight_velocity.y>vy,"bell trajectory genuinely curves under gravity")
	await fixture(false)
	check(encounter.health.capacity==36 and (encounter.definition as WindkeeperDefinition).storm_profile,"formal main Boss has thirty-six HP and enhanced profile")
	encounter.health.apply_damage(ActorResourceRequest.new(&"second",encounter.health.epoch,13,encounter.health.get_instance_id()))
	await frames(80)
	check(encounter.stage_phase==2,"main Boss uses actual second threshold")
	encounter._enter(&"blade_warning",.1)
	var locked:=encounter._locked_aim
	controller.router.set_move_axis(-1)
	await frames(10)
	controller.router.set_move_axis(0)
	check(encounter._locked_aim==locked and created.size()==3,"phaseII warning locks aim and emits three-angle fan without retarget")
	var saved:=encounter.combat_snapshot()
	encounter.restore_combat_state(saved)
	var count:=created.size();await frames(3)
	check(created.size()==count,"restoring an emitted fan does not duplicate attacks")
	encounter.cancel_pending_attacks()
	check(player._local_duration==0 and encounter._projectiles.is_empty(),"main cancellation clears current and fan consumers")
	encounter.health.apply_damage(ActorResourceRequest.new(&"third",encounter.health.epoch,11,encounter.health.get_instance_id()))
	await frames(2)
	check(encounter.stage_phase==3,"third threshold preserves separate broken-bridge stage")
	encounter._enter(&"pier_warning",.01)
	await frames(18)
	check(encounter.mode==&"pier_open" and created.size()>=count+3,"phaseIII impact opens core and emits different two-angle counter-fire")
	world.free();await process_frame
	print("PLAINS PRESSURE BOSS: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
