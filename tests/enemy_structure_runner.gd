extends SceneTree
## Structural unit fixtures, not combat/animation or user acceptance.
## Real scenes/Definitions are instantiated, while physics is paused throughout.
## State assignments below intentionally exercise adapters, never gameplay pilots.
const PLAINS := {"patrol":"patrol_drone","charger":"plains_charger","diver":"plains_diver","hopper":"plains_hopper","sentry":"plains_sentry","fan_sentry":"plains_fan_sentry","root_bell":"plains_root_bell"}
const FOREST := ["forest_lantern","forest_seed_sentry","forest_bark_beetle","forest_swing_pod","forest_thread_spider","forest_crossbranch","forest_bible_weaver"]
const CANDIDATES := ["candidate_lure_guard","candidate_crosswind_moth"]
const BOSSES := ["clockwork_guardian","bellstrider","windkeeper","thorn_guardian","thorn_queen","rootbell_guardian_v2","thorn_queen_v2","thorn_queen_canopy","windkeeper_storm"]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D
var registry: Script
var factory: Script
var binding: Script
var output := "res://build/enemy_structure/runtime.json"

class ProbeHost extends Node2D:
	var actor: EnemyActor
	var initializes := 0
	var health_events := 0
	func initialized() -> void: initializes += 1
	func changed(_result: ActorResourceResult) -> void: health_events += 1

class ProbeMotion extends RefCounted:
	var advances := 0
	var elapsed := 0.0
	func advance(_actor: EnemyActor, delta: float, _snapshot: Dictionary = {}) -> void:
		advances += 1
		elapsed += delta

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)

func finish_case(id: String, before: int, extra: Dictionary = {}) -> void:
	var row := {"id":id,"passed":failures.size()==before}
	row.merge(extra)
	cases.append(row)

func frames(count: int = 2) -> void:
	for _i: int in count: await process_frame

func add_fixture(motor: EnemyMotor) -> EnemyActor:
	world.add_child(motor)
	var actor := motor.get_node("Actor") as EnemyActor
	actor.set_physics_process(false)
	return actor

func ordinary(behavior: String, profile: String) -> void:
	var before := failures.size()
	var motor: EnemyMotor = factory.call("create_for_behavior", StringName(behavior))
	check(motor != null, behavior+" factory returns actual scene")
	if motor == null:
		finish_case("ordinary/"+behavior+"/"+profile,before)
		return
	if profile=="root_bell":
		motor.get_node("Presentation").free()
		var root_host:=RootBellPresentation.new()
		root_host.name="Presentation"
		root_host.actor=motor.get_node("Actor") as EnemyActor
		motor.add_child(root_host)
	var actor := add_fixture(motor)
	var expected_id: String = PLAINS.get(behavior,behavior)
	var expected_stable: String="graybox_patrol_drone" if behavior=="patrol" else expected_id
	check(String(actor.definition.stable_id)==expected_stable,behavior+" independently listed stable identity (not resource filename)")
	var expected_path := "res://resources/enemies/"+expected_id+".tres"
	var original: EnemyDefinition = load(expected_path)
	check(actor.definition != original and actor.definition.health_definition != original.health_definition,behavior+" mutable instance Definition/health are detached from resource")
	check(actor.definition.behavior_id==StringName(behavior),behavior+" selected behavior retained")
	var created: EnemyAttackBehavior = registry.call("create_behavior",actor.definition)
	if behavior=="patrol":
		check(created==null,"contact patrol intentionally has no attack component")
	else:
		check(created!=null,behavior+" has concrete behavior")
		if created != null:
			actor.add_child(created)
			actor.attack_behavior=created
			created.actor=actor
			created.state=&"idle"
			created.state_time=.137
	var host := motor.get_node("Presentation") as Node2D
	check(not (binding.call("view",host) as Dictionary).is_empty(),behavior+" ready produced a real final binding")
	check((binding.call("view",host) as Dictionary).get("body_theme")==&"scene",behavior+" standalone ready keeps Lab/scene fallback instead of enabling formal fine body")
	if profile=="underworld":
		var installer: Script = load("res://game/presentation/actors/underworld_plains/underworld_actor_installer.gd")
		var installed: Dictionary = installer.call("install",world)
		check(installed.enemies==1,behavior+" actual Underworld installer replaced one renderer")
		host=motor.get_node("Presentation") as Node2D
		var again: Dictionary = installer.call("install",world)
		check(again.enemies==0 and host==motor.get_node("Presentation"),behavior+" second actual install is idempotent")
	elif profile=="forest":
		# The real App installer supplies the body theme after placement. A profile
		# name alone must not accidentally enable formal art in a standalone Lab.
		binding.call("bind_existing",actor,host,&"forest",&"forest_bible")
		check((binding.call("view",host) as Dictionary).get("body_theme")==&"forest_bible",behavior+" explicit formal forest theme is installed")
		binding.call("bind_existing",actor,host,&"forest")
		check((binding.call("view",host) as Dictionary).get("body_theme")==&"forest_bible",behavior+" later default ready-style bind retains explicit formal theme")
	var view: Dictionary = binding.call("view",host)
	check(view.get("actor_id")==actor.get_instance_id() and view.get("species")==actor.definition.stable_id,behavior+" binding points at actual final actor")
	check(view.get("renderer")==host.get_script().resource_path,behavior+" binding records actual final renderer")
	if profile in ["underworld","forest"]: check(view.get("profile")==StringName(profile),behavior+" selected explicit profile survived ready")
	if behavior=="fan_sentry":
		check(actor.definition.aerial and view.get("body_key")==&"aerial" and view.get("scene_body")==&"aerial","fan_sentry aerial body fact preserved independently of generic sentry")
		var original_aerial: bool=actor.definition.aerial
		actor.definition.aerial=false
		var rebound: Dictionary=binding.call("bind_existing",actor,host,StringName(profile))
		check(rebound.get("body_key")==view.get("body_key") and rebound.get("scene_body")==view.get("scene_body"),"changing movement trait cannot silently select different fan art")
		actor.definition.aerial=original_aerial
	var hp := actor.health.current
	var at := motor.global_position
	var snap: Dictionary = actor.call("presentation_state")
	check(snap.get("valid",false) and snap.get("stable_id")==actor.definition.stable_id and snap.get("epoch")==actor.health.epoch,behavior+" snapshot valid current identity/epoch")
	check(snap.is_read_only() and (snap.get("phase_durations",{}) as Dictionary).is_read_only(),behavior+" snapshot and nested timing table are read-only")
	check(snap.get("position")==at and snap.get("terminal")==actor.health.terminal,behavior+" snapshot uses actual Motor and health")
	if created != null:
		check(snap.get("source_phase")==created.state and is_equal_approx(float(snap.get("state_time",-1)),created.state_time),behavior+" raw state and elapsed clock are actual behavior")
		# Test authored ordinary clock translation, not legality of a fabricated fight.
		if behavior in ["charger","diver","hopper","sentry","fan_sentry"]:
			for state: StringName in [&"telegraph",&"attack",&"recovery"]:
				created.state=state
				created.state_time=.071
				var phase_view: Dictionary=actor.call("presentation_state")
				var expected: float=actor.definition.get(String(state)+"_duration")
				check(phase_view.get("source_phase")==state and is_equal_approx(float(phase_view.get("phase_duration",-1)),expected),behavior+" "+String(state)+" duration stays source-owned")
	check(actor.health.current==hp and motor.global_position==at,behavior+" sampling does not write combat or motion")
	check(actor.restore_instance_health(0.0),behavior+" native saved terminal restore accepted")
	var dead: Dictionary=actor.call("presentation_state")
	check(dead.get("terminal",false) and dead.get("epoch")==actor.health.epoch,behavior+" paused saved terminal snapshot is current")
	check(actor.restore_instance_health(actor.definition.health_definition.max_health),behavior+" native live restore accepted")
	check(not (actor.call("presentation_state") as Dictionary).get("terminal",true),behavior+" paused revival snapshot drops prior terminal")
	if behavior=="forest_bark_beetle":
		var shield_receiver:=actor.damageable as ForestBarkDamageable
		host.set("shield_flash",0.0)
		(host.get("lifecycle") as RefCounted).call("dispose")
		shield_receiver.shield_contact.emit({})
		check(host.get("shield_flash")==0.0,"disposed forest renderer no longer receives owned shield callback")
	motor.queue_free()
	await frames()
	finish_case("ordinary/"+behavior+"/"+profile,before,{"definition":expected_path,"renderer":view.get("renderer","")})

func candidate(identity: String, context: String) -> void:
	var before := failures.size()
	var motor: EnemyMotor=factory.call("create_candidate",StringName(identity),StringName(context))
	check(motor!=null,identity+"/"+context+" factory accepts declared development recipe")
	if motor != null:
		var actor:=add_fixture(motor)
		check(String(actor.definition.stable_id)==identity and actor.definition.collision_size==Vector2(32,36),identity+" actual candidate identity and original collision")
		check(actor.definition.patrol_half_width==(120.0 if context=="lab" else 100.0),identity+" intentional Lab/Studio half-width difference retained")
		if identity=="candidate_crosswind_moth": check(actor.definition.patrol_speed==(45.0 if context=="lab" else 0.0),identity+" intentional Lab/Studio speed difference retained")
		var component: EnemyAttackBehavior=registry.call("create_behavior",actor.definition)
		check(component!=null,identity+" candidate selects explicit behavior")
		if component!=null:
			var path: String=component.get_script().resource_path
			check(path.ends_with("prototype_moth_behavior.gd") if identity.ends_with("moth") else path.ends_with("enemy_attack_behavior.gd"),identity+" candidate-specific concrete algorithm")
			component.free()
		motor.queue_free()
		await frames()
	finish_case("candidate/"+identity+"/"+context,before)

func registry_refusals() -> void:
	var before:=failures.size()
	var ids: Array=registry.call("behavior_ids")
	var expected: Array=PLAINS.keys()+FOREST
	check(ids.size()==expected.size(),"finite registry exactly matches independent ordinary roster count")
	for id: String in expected: check(StringName(id) in ids,id+" present in independently enumerated roster")
	check(not registry.call("supports_behavior",&"not_a_monster"),"unknown behavior explicitly unsupported")
	check(registry.call("definition_error",&"charger",&"candidate_crosswind_moth")=="candidate_behavior_mismatch","candidate/algorithm mismatch refused")
	check(factory.call("create_for_behavior",&"not_a_monster")==null,"unknown behavior cannot silently create generic attack")
	for invalid: Dictionary in [{"health":999.0},{"aerial":1},{"initial_direction":0},{"patrol_speed":NAN},{"patrol_half_width":-1.0}]:
		check(factory.call("create_for_behavior",&"charger",invalid)==null,"invalid or unauthorized instance override refused: "+str(invalid.keys()))
	check(factory.call("create_candidate",&"candidate_crosswind_moth",&"unknown")==null,"unknown candidate context refused")
	var cold:=EnemyActor.new()
	check(not (cold.call("presentation_state") as Dictionary).get("valid",true),"uninitialized Actor snapshot explicitly invalid")
	cold.free()
	var boss_factory: Script=load("res://game/bosses/encounter/boss_factory.gd")
	check(boss_factory.call("create",&"unknown_boss")==null,"unknown Boss ID refused")
	check(boss_factory.call("create_recorded","res://scenes/bosses/windkeeper.tscn","res://resources/bosses/thorn_guardian.tres")==null,"cross-family recorded Boss pair refused")
	check(boss_factory.call("create_recorded","res://game/bosses/encounter/boss_encounter.gd","")==null,"non-scene Boss path refused")
	finish_case("registry/refusals",before)

func binding_replacements() -> void:
	var before:=failures.size()
	var motor: EnemyMotor=factory.call("create_for_behavior",&"charger")
	var actor:=add_fixture(motor)
	var original:=motor.get_node("Presentation")
	var position_before:=motor.global_position
	var epoch:=actor.health.epoch
	var pixel: Script=load("res://game/presentation/world/art_foundation/pixel_formal_style_installer.gd")
	var underworld: Script=load("res://game/presentation/actors/underworld_plains/underworld_actor_installer.gd")
	check((pixel.call("install",world) as Dictionary).enemies==1,"Pixel actual install replaces scene renderer")
	var pixel_host:=motor.get_node("Presentation")
	check((pixel.call("install",world) as Dictionary).enemies==0 and pixel_host==motor.get_node("Presentation"),"Pixel reinstall retains exact host")
	check((underworld.call("install",world) as Dictionary).enemies==1,"Underworld replaces Pixel subclass rather than inheriting wrong art")
	var uw_host:=motor.get_node("Presentation")
	check((underworld.call("install",world) as Dictionary).enemies==0 and uw_host==motor.get_node("Presentation"),"Underworld reinstall retains exact host")
	await frames()
	check(not is_instance_valid(original) and not is_instance_valid(pixel_host),"replaced scene/Pixel hosts actually freed")
	check(motor.global_position==position_before and actor.health.epoch==epoch,"renderer installs never reset or move actual actor")
	check((pixel.call("install",world) as Dictionary).enemies==0 and motor.get_node("Presentation")==uw_host,"Pixel installer preserves existing Underworld subclass rather than downgrading art")
	check(not binding.call("can_bind",actor,uw_host,&"unknown"),"unknown profile refused without native error")
	var bare:=Node2D.new()
	check(not binding.call("can_bind",actor,bare,&"scene"),"scriptless host refused before resource access")
	bare.free()
	var other: EnemyMotor=factory.call("create_for_behavior",&"sentry")
	var other_actor:=add_fixture(other)
	check(not binding.call("can_bind",other_actor,uw_host,&"underworld"),"cross-actor host binding refused")
	var saved_behavior: StringName=actor.definition.behavior_id
	actor.definition.behavior_id=&"missing_body_route"
	check(binding.call("binding_error",actor,uw_host,&"underworld")=="unknown_body_route" and not binding.call("can_bind",actor,uw_host,&"underworld"),"unknown body route explicitly refused before rendering")
	actor.definition.behavior_id=saved_behavior
	check(not binding.call("replace",actor,&"unknown"),"unsupported renderer replacement leaves original host")
	check(motor.get_node("Presentation")==uw_host,"rejected profile does not remove renderer")
	other.queue_free()
	motor.queue_free()
	await frames()
	finish_case("binding/replacements",before)

func boss(identity: String) -> void:
	var before:=failures.size()
	var scene_id: String="windkeeper" if identity=="windkeeper_storm" else identity
	var boss_factory: Script=load("res://game/bosses/encounter/boss_factory.gd")
	var motor: BossMotor=boss_factory.call("create",StringName(identity))
	check(motor!=null and not motor.is_inside_tree(),identity+" Boss factory creates unparented real scene")
	if motor==null:
		finish_case("boss/"+identity,before)
		return
	var encounter:=motor.get_node("Encounter") as BossEncounter
	var expected_definition: Resource=load("res://resources/bosses/"+identity+".tres")
	check(encounter.definition==expected_definition,identity+" factory retains exact shared original Definition semantics")
	var recorded: BossMotor=boss_factory.call("create_recorded","res://scenes/bosses/"+scene_id+".tscn","res://resources/bosses/"+identity+".tres")
	check(recorded!=null,identity+" actual recorded scene/Definition pair allowed")
	if recorded!=null: recorded.free()
	world.add_child(motor)
	encounter.set_physics_process(false)
	var at:=motor.global_position
	var hp:=encounter.health.current
	var view: Variant=encounter.call("presentation_state")
	check(view!=null,identity+" real Encounter provides presentation state")
	if view!=null:
		check(view.get("health_epoch")==encounter.health.epoch and view.get("terminal")==encounter.health.terminal,identity+" snapshot health authority preserved")
		check(view.get("position")==at,identity+" snapshot world position comes from actual Motor")
		var axes: Dictionary=view.get("phase_axes")
		check(axes.has("combat"),identity+" combat phase axis explicit")
		var independent_phase: int=encounter.phases.phase if identity=="clockwork_guardian" else int(encounter.get("stage_phase"))
		check(view.get("phase")==independent_phase and int(axes.combat)==independent_phase,identity+" snapshot uses actual phase authority")
		if identity=="thorn_queen_v2": check(int(axes.get("route",-1))==int(encounter.get("route_phase")),identity+" independent route axis not swallowed")
		if identity!="clockwork_guardian":
			var is_queen:=identity in ["thorn_queen_v2","thorn_queen_canopy"]
			var state: StringName=StringName(encounter.get("motion_mode") if is_queen else encounter.get("mode"))
			var clock_value: float=float(encounter.get("motion_clock") if is_queen else encounter.get("clock"))
			check(view.get("raw_mode")==state and is_equal_approx(float(view.get("raw_clock")),clock_value),identity+" raw state and countdown not converted into elapsed time")
			check(view.get("clock_kind")==&"countdown",identity+" countdown clock kind explicit")
		var copied: Dictionary=view.call("as_dictionary")
		copied["terminal"]=not encounter.health.terminal
		var copied_axes: Dictionary=copied.get("phase_axes",{})
		copied_axes["combat"]=-999
		check(encounter.health.current==hp and motor.global_position==at,identity+" detached snapshot mutation cannot write combat")
		check(int((view.get("phase_axes") as Dictionary).combat)==independent_phase,identity+" detached phase-axis mutation cannot poison snapshot")
		check(not contains_object(copied),identity+" state exposes values rather than live mechanism objects")
	var terminal_health:=encounter.definition.health_definition.duplicate(true) as HealthDefinition
	terminal_health.initial_current=0.0
	check(encounter.health.configure(terminal_health),identity+" explicit native terminal restore accepted")
	var restored: Variant=encounter.call("presentation_state")
	check(restored.get("terminal") and restored.get("health_epoch")==encounter.health.epoch,identity+" state reflects paused restored terminal and new epoch immediately")
	var capabilities: Variant=encounter.call("presentation_capabilities")
	check(capabilities is PackedStringArray,identity+" capabilities explicitly enumerable")
	for query: String in ["presentation_bell","presentation_bell_warning","presentation_pursuit_warning","presentation_motion_preview"]:
		var detail: Variant=encounter.call(query)
		check(detail is Dictionary and not contains_object(detail),identity+" "+query+" exports no mutable Node")
	motor.queue_free()
	await frames()
	finish_case("boss/"+identity,before)

func contains_object(value: Variant) -> bool:
	if value is Object: return true
	if value is Dictionary:
		for key: Variant in value:
			if contains_object(key) or contains_object(value[key]): return true
	elif value is Array:
		for item: Variant in value:
			if contains_object(item): return true
	return false

func boss_rebind() -> void:
	var before:=failures.size()
	var boss_factory: Script=load("res://game/bosses/encounter/boss_factory.gd")
	var first: BossMotor=boss_factory.call("create",&"clockwork_guardian")
	var second: BossMotor=boss_factory.call("create",&"windkeeper")
	world.add_child(first)
	world.add_child(second)
	var a:=first.get_node("Encounter") as BossEncounter
	var b:=second.get_node("Encounter") as BossEncounter
	a.set_physics_process(false)
	b.set_physics_process(false)
	var motion:=BossMotionPresentation.new()
	motion.bind(a)
	var accepted:=a.health.apply_damage(ActorResourceRequest.new(&"structure-rebind-a",a.health.epoch,1.0,a.health.get_instance_id()))
	check(accepted.status==ActorResourceResult.Status.APPLIED and motion._hurt_left>0.0,"Boss rebind fixture accepts real nonlethal resource transaction")
	motion.sample(a,.04)
	var age:=motion.mode_age
	var hurt_left:=motion._hurt_left
	motion.bind(a)
	check(motion.mode_age==age and motion._hurt_left==hurt_left,"same Boss bind preserves accepted hurt and current mode age")
	first.position+=Vector2(901.0,137.0)
	motion.synchronize(a)
	check(motion.mode_age==age and motion._hurt_left==hurt_left,"same-epoch complete restore synchronization preserves cue clocks")
	motion.sample(a,.01)
	check(motion.speed==0.0,"complete restore position rebases locomotion rather than manufacturing stride")
	motion.bind(b)
	check(motion._hurt_left==0.0 and motion.mode_age==0.0,"different Boss bind starts clean observation")
	a.health.apply_damage(ActorResourceRequest.new(&"structure-old-owner",a.health.epoch,1.0,a.health.get_instance_id()))
	check(motion._hurt_left==0.0,"old Boss health event cannot reach rebound observer")
	b.health.apply_damage(ActorResourceRequest.new(&"structure-new-owner",b.health.epoch,1.0,b.health.get_instance_id()))
	check(motion._hurt_left>0.0,"new Boss owns rebound observer signals")
	var saved:=b.definition.health_definition.duplicate(true) as HealthDefinition
	saved.initial_current=0.0
	b.health.configure(saved)
	check(motion.death==1.0 and motion._hurt_left==0.0,"new Boss initialize while paused synchronously settles restored terminal")
	motion.dispose()
	motion.dispose()
	var detached_epoch:=motion._epoch
	saved.initial_current=saved.max_health
	b.health.configure(saved)
	check(motion._epoch==detached_epoch and motion.death==1.0,"disposed Boss observer receives no later initialization")
	first.queue_free()
	second.queue_free()
	await frames()
	finish_case("boss-lifecycle/rebind",before)

func lifecycle() -> void:
	var before:=failures.size()
	var source: Script=load("res://game/presentation/actors/presentation/enemy_presentation_lifecycle.gd")
	var life: Variant=source.new()
	var motor: EnemyMotor=factory.call("create_for_behavior",&"patrol")
	var actor:=add_fixture(motor)
	var probe:=ProbeHost.new()
	probe.actor=actor
	motor.add_child(probe)
	var motion:=ProbeMotion.new()
	life.call("bind",actor,probe,Callable(probe,"initialized"),Callable(probe,"changed"),motion)
	var initialized:=probe.initializes
	life.call("bind",actor,probe,Callable(probe,"initialized"),Callable(probe,"changed"),motion)
	check(probe.initializes==initialized,"same lifecycle bind is idempotent")
	check(not life.call("advance",.125) and motion.elapsed==0.0,"paused lifecycle does not advance motion")
	check(actor.restore_instance_health(0.0),"lifecycle paused native terminal restore accepted")
	check(probe.initializes==initialized+1,"paused new epoch initializes immediately exactly once")
	life.call("dispose")
	life.call("dispose")
	var disposed_count:=probe.initializes
	actor.restore_instance_health(actor.definition.health_definition.max_health)
	check(probe.initializes==disposed_count,"disposed lifecycle receives no later health initialization")
	life.call("bind",actor,probe,Callable(probe,"initialized"),Callable(probe,"changed"),motion)
	check(probe.initializes==disposed_count+1,"explicit rebind synchronizes current epoch once")
	paused=false
	actor.set_physics_process(false)
	check(life.call("advance",.125) and is_equal_approx(motion.elapsed,.125),"single explicit live advance ticks owned motion exactly once")
	paused=true
	life.call("dispose")
	motor.queue_free()
	await frames()
	finish_case("lifecycle/rebind",before)

func forest_cache_parity() -> void:
	var before:=failures.size()
	var source: Script=load("res://tests/enemy_forest_cache_contract.gd")
	var probe: RefCounted=source.new()
	var observation: Dictionary=probe.call("run")
	check(int(observation.get("checks",0))>0,"forest cache helper executes nonzero contract checks")
	for label: String in observation.get("failures",[]): check(false,"forest cache: "+label)
	check((observation.get("failures",[]) as Array).is_empty(),"forest cache strict reference parity and invalidation pass")
	check(int(observation.get("compared_cases",0))>=756 and int(observation.get("compared_vertices",0))>=218484,"forest cache independently required parity envelope completed")
	finish_case("forest-cache/parity",before,{"checks":observation.get("checks",0),"compared_cases":observation.get("compared_cases",0),"compared_vertices":observation.get("compared_vertices",0),"scope":observation.get("scope","")})

func run() -> void:
	registry=load("res://game/enemies/enemy_behavior_registry.gd")
	factory=load("res://game/enemies/enemy_factory.gd")
	binding=load("res://game/presentation/actors/presentation/enemy_presentation_binding.gd")
	world=Node2D.new()
	root.add_child(world)
	paused=true
	registry_refusals()
	for behavior: String in PLAINS:
		for profile: String in ["scene","underworld"]: await ordinary(behavior,profile)
	await ordinary("root_bell","root_bell")
	for behavior: String in FOREST: await ordinary(behavior,"forest")
	for identity: String in CANDIDATES:
		for context: String in ["lab","studio"]: await candidate(identity,context)
	await binding_replacements()
	for identity: String in BOSSES: await boss(identity)
	await boss_rebind()
	await lifecycle()
	forest_cache_parity()
	paused=false
	var audio_ok: bool=await preload("res://tests/audio_teardown.gd").drain_world(world)
	check(audio_ok,"owned native test audio actually released")
	world.queue_free()
	await frames()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Native explicit fixtures; no legal combat, render pixels or animation quality inferred","checks":checks,"failures":failures,"cases":cases},"\t"))
	file.close()
	print("ENEMY STRUCTURE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
