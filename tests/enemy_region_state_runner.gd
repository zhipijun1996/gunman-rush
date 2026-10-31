extends SceneTree
## Real Actor/Behavior instances with explicit state fixtures, not a combat pilot.
## The old plains and forest wire records remain different on purpose.
const AUDIO := preload("res://tests/audio_teardown.gd")
const PLAINS_KEYS := ["health","position","state","state_time","cooldown","serial","locked_direction","attack_goal","attack_origin","home","direction"]
const FOREST_KEYS := ["health","position","state","state_time","cooldown","serial","home","direction"]
var checks := 0
var failures := 0
var world: Node2D
var controller: PlayerController
var lifetime := DemoLifetime.new()
var policy: FrameDamagePolicy

class OrderedDepthBehavior extends EnemyAttackBehavior:
	var observed: Dictionary = {}
	var calls := 0
	func restore_depth_state(saved: Dictionary) -> bool:
		calls += 1
		observed = {"state":String(state),"time":state_time,"cooldown":cooldown,"serial":_serial,"home":home,"locked":locked_direction,"goal":attack_goal,"origin":attack_origin,"direction":actor.brain.direction}
		return bool(saved.get("accept",false))

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func make_actor(behavior: StringName) -> EnemyActor:
	var body := EnemyFactory.create_for_behavior(behavior)
	world.add_child(body)
	var actor := body.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	actor.bind_encounter(controller,policy,lifetime,StringName("state_fixture_%s" % body.get_instance_id()),[])
	return actor

func schema_and_isolation() -> void:
	var actor := make_actor(&"charger")
	var peer := make_actor(&"charger")
	actor.motor.position = Vector2(13,-7)
	actor.brain.direction = -1
	var attack := actor.attack_behavior
	attack.state = &"attack"
	attack.state_time = .25
	attack.cooldown = .75
	attack._serial = 9
	attack.home = Vector2(5,6)
	attack.locked_direction = Vector2(-1,0)
	attack.attack_goal = Vector2(70,80)
	attack.attack_origin = Vector2(30,40)
	var expected := {"health":actor.health.current,"position":[13.0,-7.0],"state":"attack","state_time":.25,"cooldown":.75,"serial":9,"locked_direction":[-1.0,0.0],"attack_goal":[70.0,80.0],"attack_origin":[30.0,40.0],"home":[5.0,6.0],"direction":-1}
	var health_epoch := actor.health.epoch
	var actor_epoch := lifetime.actor_epoch
	var snapshot := actor.region_snapshot()
	check(snapshot.keys()==PLAINS_KEYS,"plains record retains every original field in original order")
	check(snapshot.keys().all(func(key: Variant) -> bool: return typeof(key)==TYPE_STRING),"all original plains literal keys remain String, not StringName")
	check(JSON.stringify(snapshot)==JSON.stringify(expected),"plains values match the explicit original wire record")
	check(actor.motor.global_position!=actor.motor.position and snapshot.position==[13.0,-7.0],"translated parent cannot replace saved local Motor coordinates with world coordinates")
	var forest := actor.region_snapshot(false,true)
	check(forest.keys()==FOREST_KEYS and not forest.has("depth_state"),"forest ordinary schema omits attack vectors and absent depth methods")
	check(forest.keys().all(func(key: Variant) -> bool: return typeof(key)==TYPE_STRING),"all original forest outer literal keys remain String")
	check(actor.health.epoch==health_epoch and lifetime.actor_epoch==actor_epoch and attack.state_time==.25 and attack._serial==9,"snapshot does not advance phase, attack serial, health or target epoch")
	var peer_before := peer.region_snapshot()
	snapshot.position[0]=999
	snapshot.home[0]=999
	check(actor.motor.position==Vector2(13,-7) and attack.home==Vector2(5,6),"snapshot vectors are detached value arrays")
	check(peer.region_snapshot()==peer_before and peer.definition!=actor.definition and peer.health!=actor.health,"one actor snapshot cannot mutate another actual entity instance")
	var patrol := make_actor(&"patrol")
	patrol.motor.position=Vector2(4,8)
	patrol.brain.direction=-1
	var absent := patrol.region_snapshot()
	check(patrol.attack_behavior==null and absent.keys()==PLAINS_KEYS,"patrol keeps the original no-behavior schema")
	check(absent.state=="idle" and absent.state_time==0.0 and absent.cooldown==0.0 and absent.serial==0 and absent.locked_direction==[1,0],"no-behavior timing and locked-direction defaults remain exact")
	check(absent.attack_goal==[4.0,8.0] and absent.attack_origin==[4.0,8.0] and absent.home==[4.0,8.0] and absent.direction==-1,"no-behavior geometry defaults use its own local position and facing")
	var before_peer_health := peer.health.current
	check(actor.restore_instance_health(0.0) and actor.health.terminal,"existing health authority still restores terminal actors")
	check(actor.region_snapshot().health==0.0 and peer.health.current==before_peer_health,"terminal snapshot and health restore remain instance-local")
	var terminal_epoch := actor.health.epoch
	check(not actor.restore_instance_health(-1.0) and not actor.restore_instance_health(INF) and actor.health.epoch==terminal_epoch,"invalid restored health remains rejected without changing its epoch")

func restore_order_and_failure() -> void:
	var actor := make_actor(&"patrol")
	var behavior := OrderedDepthBehavior.new()
	actor.add_child(behavior)
	actor.attack_behavior=behavior
	behavior.configure(actor,controller,policy,lifetime,&"ordered_fixture",[])
	var observed_expected := {"state":"telegraph","time":.125,"cooldown":.375,"serial":7,"home":Vector2(1,2),"locked":Vector2(-1,0),"goal":Vector2(20,30),"origin":Vector2(10,15),"direction":-1}
	var saved := {"state":"telegraph","state_time":.125,"cooldown":.375,"serial":7,"home":[1,2],"locked_direction":[-1,0],"attack_goal":[20,30],"attack_origin":[10,15],"direction":-1,"depth_state":{"accept":true}}
	var original_health := actor.health.current
	var original_position := actor.motor.position
	check(behavior.restore_region_state(saved),"common restore forwards accepted depth result")
	check(behavior.calls==1 and behavior.observed==observed_expected,"depth validation observes all original outer assignments before it runs")
	check(actor.health.current==original_health and actor.motor.position==original_position,"behavior restore cannot replace Actor/Stage health and position ownership")
	saved.state="recovery"
	saved.depth_state.accept=false
	check(not behavior.restore_region_state(saved) and behavior.calls==2,"depth rejection propagates to the existing App abort path")
	check(behavior.state==&"recovery" and behavior.observed.state=="recovery","failed depth validation retains original prior outer assignments rather than inventing rollback semantics")
	check(behavior.restore_region_state({}) and behavior.calls==2,"absent depth preserves legacy accepted restore without calling a missing extension")
	check(behavior.state==&"idle" and behavior.state_time==0.0 and behavior.cooldown==0.0 and behavior._serial==0 and actor.brain.direction==1,"missing common scalars preserve original defaults")
	check(behavior.home==Vector2(1,2) and behavior.locked_direction==Vector2(-1,0) and behavior.attack_goal==Vector2(20,30) and behavior.attack_origin==Vector2(10,15),"missing optional vectors preserve prior authored values")

func crossbranch_depth_authority() -> void:
	var actor := make_actor(&"forest_crossbranch")
	var migration := actor.attack_behavior as ForestCrossbranchBehavior
	var shores: Array[Dictionary] = [{"id":"a","rect":Rect2(0,100,200,20),"position":Vector2(50,84)},{"id":"b","rect":Rect2(300,200,200,20),"position":Vector2(350,184)}]
	check(migration.configure_shores(shores,false),"actual migration binds two authored shores before restore")
	migration.state_time=.2
	migration.cooldown=.7
	migration._serial=6
	migration.home=Vector2(2,3)
	actor.brain.direction=-1
	var saved := actor.region_snapshot(false,true)
	check(saved.keys()==FOREST_KEYS+[&"depth_state"],"forest appends species depth after its unchanged outer schema")
	check(saved.keys().slice(0,8).all(func(key: Variant) -> bool: return typeof(key)==TYPE_STRING) and typeof(saved.keys()[-1])==TYPE_STRING_NAME,"forest preserves eight original String keys followed by its original dot-appended StringName extension")
	var depth_before := migration.depth_snapshot()
	saved.state="attack"
	saved.state_time=99.0
	saved.cooldown=99.0
	saved.serial=99
	saved.home=[99,99]
	saved.direction=1
	saved.locked_direction=[99,99]
	var health_epoch := actor.health.epoch
	lifetime.actor_epoch+=1
	check(migration.restore_region_state(saved),"Crossbranch restores its valid physical depth record despite ignored generic fields")
	check(migration.depth_snapshot()==depth_before and migration.state==&"rest" and migration.state_time==.2,"Crossbranch depth is sole phase/flight authority")
	check(migration.cooldown==.7 and migration._serial==6 and migration.home==Vector2(2,3) and actor.brain.direction==-1 and migration.locked_direction==Vector2.RIGHT,"Crossbranch preserves all formerly skipped generic fields")
	check(migration._actor_epoch==lifetime.actor_epoch and actor.health.epoch==health_epoch,"restored target epoch rebinds without replacing the health epoch")
	var invalid := saved.duplicate(true)
	invalid.depth_state.shores[0].id="foreign"
	check(not migration.restore_region_state(invalid) and migration.depth_snapshot()==depth_before,"foreign authored shore is rejected before physical depth mutation")
	check(migration.restore_region_state({}) and migration.depth_snapshot()==depth_before,"missing depth keeps the method's historical no-op; App remains responsible for required-field rejection")

func weaver_cross_checks() -> void:
	var actor := make_actor(&"forest_bible_weaver")
	var weaver := actor.attack_behavior as ForestBibleWeaverBehavior
	check(weaver.configure_strands([{"id":"upper","start":[0,0],"end":[100,0]},{"id":"lower","start":[0,80],"end":[100,80]}]),"actual Weaver binds authored strands before restore")
	weaver.state=&"idle"
	weaver.state_time=.125
	weaver.cooldown=.5
	weaver._serial=3
	var saved := actor.region_snapshot(false,true)
	weaver.state=&"recovery"
	weaver.state_time=1.0
	weaver.cooldown=2.0
	weaver._serial=8
	check(weaver.restore_region_state(saved),"actual Weaver validates matching outer and depth fields after common restore")
	check(weaver.state==&"idle" and weaver.state_time==.125 and weaver._serial==3,"actual Weaver restored the recorded common phase rather than previous live state")
	var bad := saved.duplicate(true)
	bad.depth_state.serial=4
	check(not weaver.restore_region_state(bad),"mismatched Weaver outer/depth serial retains its original rejection")
	bad=saved.duplicate(true)
	bad.depth_state.strands[0].end=[120,0]
	check(not weaver.restore_region_state(bad),"saved Weaver geometry cannot replace the actual authored strand")
	check(saved.depth_state.strands[0].end==[100.0,0.0] and weaver.strand_rows[0].end==[100.0,0.0],"tampered record does not mutate original snapshot or authored species geometry")

func candidate_registry_authority() -> void:
	for identity: StringName in [&"candidate_lure_guard",&"candidate_crosswind_moth"]:
		var expected: StringName = &"charger" if identity==&"candidate_lure_guard" else &"sentry"
		check(EnemyBehaviorRegistry.candidate_behavior(identity)==expected,"existing registry owns candidate behavior: "+String(identity))
		for context: StringName in [&"lab",&"studio",&"review"]:
			var recipe := EnemyFactory.candidate_recipe(identity,context)
			var definition := EnemyFactory.candidate_definition(identity,context)
			check(recipe.behavior==expected and recipe.definition_path==EnemyBehaviorRegistry.definition_path(expected) and recipe.scene_path==EnemyBehaviorRegistry.scene_path(expected),"candidate recipe resolves original authoritative construction: "+String(identity)+"/"+String(context))
			check(definition!=null and definition.behavior_id==expected and definition.stable_id==identity,"candidate actual Definition retains identity and validation")
			check(definition.patrol_half_width==(100.0 if context==&"studio" else 120.0),"Lab/review and Studio keep their different original widths")
	check(EnemyFactory.candidate_definition(&"candidate_crosswind_moth",&"studio").patrol_speed==0.0 and EnemyFactory.candidate_definition(&"candidate_crosswind_moth",&"lab").patrol_speed==45.0,"candidate mapping reuse does not normalize Studio and Lab motion")
	check(EnemyBehaviorRegistry.candidate_behavior(&"unknown").is_empty() and EnemyFactory.candidate_recipe(&"unknown").is_empty() and EnemyFactory.candidate_recipe(&"candidate_lure_guard",&"unknown").is_empty(),"unknown identity/context retain explicit refusal")

func run() -> void:
	world=Node2D.new()
	world.position=Vector2(500,600)
	root.add_child(world)
	paused=true
	var player := preload("res://scenes/player/player.tscn").instantiate() as PlayerMotor
	world.add_child(player)
	controller=player.get_node("Controller") as PlayerController
	policy=FrameDamagePolicy.new()
	policy.lifetime=lifetime
	world.add_child(policy)
	schema_and_isolation()
	restore_order_and_failure()
	crossbranch_depth_authority()
	weaver_cross_checks()
	candidate_registry_authority()
	controller.active=false
	paused=false
	check(await AUDIO.drain_world(world),"actual fixture audio releases before teardown")
	world.free()
	await process_frame
	if "--prove-failure" in OS.get_cmdline_user_args(): check(false,"intentional state-contract failure")
	print("ENEMY REGION STATE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
