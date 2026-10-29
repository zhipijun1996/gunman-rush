extends SceneTree
## Explicit native lifecycle fixtures. Real factories/receivers/support are used;
## AI is disabled for controlled timing, never claimed as combat or pixel review.
const BEHAVIORS: Array[StringName] = [&"patrol",&"charger",&"diver",&"hopper",&"sentry",&"fan_sentry",&"root_bell"]
const FLOOR_Y := 400.0
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var world: Node2D
var fixture: Node2D
var floor_body: StaticBody2D
var motor: EnemyMotor
var actor: EnemyActor
var host: Node2D
var output := "res://build/plains_revision_01/native/runtime.json"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func frames(count: int = 1) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func packet(id: String, amount: float) -> Dictionary:
	return {"event_id":id,"amount":amount,"source_faction":&"player","source_actor_id":-1,"target_actor_id":actor.damageable.actor_id,"target_epoch":actor.damageable.damage_epoch,"hit_point":motor.global_position,"hit_direction":Vector2.RIGHT}

func setup(kind: StringName, air: bool, chain: String) -> void:
	fixture = Node2D.new()
	world.add_child(fixture)
	floor_body = StaticBody2D.new()
	floor_body.position = Vector2(500,FLOOR_Y+20)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000,40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	fixture.add_child(floor_body)
	motor = EnemyFactory.create_for_behavior(kind)
	check(motor != null,String(kind)+" actual factory creates scene")
	if motor == null: return
	actor = motor.get_node("Actor") as EnemyActor
	motor.position = Vector2(500,FLOOR_Y-actor.definition.collision_size.y*.5-(170.0 if air else 0.0))
	if chain == "root_bell":
		motor.get_node("Presentation").free()
		var root_host := RootBellPresentation.new()
		root_host.actor = actor
		root_host.name = "Presentation"
		motor.add_child(root_host)
	fixture.add_child(motor)
	# This fixture tests accepted presentation/lifecycle behavior, not AI routing.
	actor.set_physics_process(false)
	actor.brain.enabled = false
	if chain == "underworld":
		var install: Dictionary = load("res://scripts/underworld_plains/underworld_actor_installer.gd").install(fixture)
		check(int(install.enemies)==1,String(kind)+" actual formal installer replaces one body")
	host = motor.get_node("Presentation") as Node2D
	if kind != &"patrol":
		var behavior := EnemyBehaviorRegistry.create_behavior(actor.definition)
		actor.add_child(behavior)
		actor.attack_behavior = behavior
		behavior.actor = actor
		# A declared phase fixture, to exercise real cancel on accepted death.
		behavior.state = &"telegraph"
		behavior.state_time = actor.definition.telegraph_duration*.6
	await frames(3)

func check_geometry(rig: PlainsRevisionSkin, label: String) -> void:
	var neutral := {"clock":.4,"stride":.6,"travel":.8,"hurt":0.0,"load":0.0,"strike":0.0,"recovery":0.0,"turn":0.0,"dead":false,"death":0.0,"air":false,"vertical":0.0}
	var loaded: Dictionary = neutral.duplicate()
	loaded.load = 1.0
	var struck: Dictionary = neutral.duplicate()
	struck.strike = 1.0
	var ended: Dictionary = neutral.duplicate()
	ended.dead = true
	ended.death = 1.0
	var later: Dictionary = ended.duplicate()
	later.clock = 200.0
	later.stride = 100.0
	later.air = true
	later.vertical = -180.0
	later.death_clock = 90.0
	var valid := true
	var stable := true
	var supported := true
	var load_difference := 0.0
	var strike_difference := 0.0
	var death_difference := 0.0
	for y: int in 11:
		for x: int in 11:
			var uv := Vector2(float(x)/10,float(y)/10)
			var point := rig.bounds.position+uv*rig.bounds.size
			var live := rig.deform(point,uv,neutral)
			var dead := rig.deform(point,uv,ended)
			valid = valid and live.is_finite() and dead.is_finite()
			stable = stable and dead.is_equal_approx(rig.deform(point,uv,later))
			supported = supported and dead.y<=0.0001
			load_difference += live.distance_to(rig.deform(point,uv,loaded))
			strike_difference += live.distance_to(rig.deform(point,uv,struck))
			death_difference += live.distance_to(dead)
	check(valid,label+" all sampled live/dead bone coordinates remain finite")
	check(stable,label+" final corpse joints ignore future clock/stride/air velocity")
	check(supported,label+" final corpse sampled geometry never penetrates support plane")
	check(death_difference>5.0,label+" death changes actual body geometry")
	# Captured limbs can be in any attack/hurt/turn phase at the lethal receipt.
	# Death must begin at that exact picture rather than resetting to neutral.
	var handoff_continuous := true
	for variant: int in 3:
		var captured: Dictionary = neutral.duplicate()
		captured.load = [.8,.1,.0][variant]
		captured.strike = [.0,.9,.2][variant]
		captured.hurt = [.7,.2,.5][variant]
		captured.turn = [.6,.0,1.0][variant]
		captured.recovery = [.0,.7,.1][variant]
		captured.stride = float(variant)*1.7+.4
		captured.air = variant==2
		captured.vertical = -170.0 if variant==2 else 0.0
		var lethal_pose: Dictionary = captured.duplicate()
		lethal_pose.dead = true
		lethal_pose.death = 0.0
		for y: int in 7:
			for x: int in 7:
				var uv := Vector2(float(x)/6,float(y)/6)
				var point := rig.bounds.position+uv*rig.bounds.size
				handoff_continuous = handoff_continuous and rig.deform(point,uv,captured).is_equal_approx(rig.deform(point,uv,lethal_pose))
	check(handoff_continuous,label+" lethal death=0 preserves every sampled captured load/strike/hurt/turn/air joint")
	if rig.kind == &"root_bell":
		# A real opaque clapper-rim pixel from the unchanged neutral mother.
		# Root/support settlement alone did not catch the visually floating bell.
		var rim_uv := Vector2(394.0/453.0,218.0/376.0)
		var rim := rig.deform(rig.bounds.position+rim_uv*rig.bounds.size,rim_uv,ended)
		var mother := rig.texture.get_image()
		check(mother.get_pixel(394,218).a>=0.5 and rim.y>=-1.0 and rim.y<=0.0,label+" actual opaque bell rim rests within one world pixel of support after collapse")
	if rig.kind != &"patrol":
		check(load_difference>1.0 and strike_difference>1.0,label+" load and release produce distinct body geometry")

func lifecycle_case(kind: StringName, air: bool = false, chain: String = "underworld") -> void:
	var label := String(kind)+"/"+chain+("/air" if air else "/ground")
	var failure_before := failures.size()
	await setup(kind,air,chain)
	if motor == null: return
	if kind in [&"charger",&"fan_sentry"]:
		# Actual physics sweeps at the core and the former oversized top edge,
		# with the unchanged real player-projectile radius. This is a geometry
		# fixture, not a claim to a naturally aimed combat shot.
		var bullet: Node = load("res://scripts/combat/player_projectile.gd").new()
		var circle := CircleShape2D.new()
		circle.radius = float(bullet.get("radius"))
		bullet.free()
		var probe := PhysicsShapeQueryParameters2D.new()
		probe.shape = circle
		probe.collision_mask = 4
		probe.margin = 0.0
		var space := motor.get_world_2d().direct_space_state
		for face: int in [-1,1]:
			probe.transform = Transform2D(0.0,motor.global_position+Vector2(-100.0*face,0))
			probe.motion = Vector2(200.0*face,0)
			var core := space.cast_motion(probe)
			check(core[0]<1.0,label+" real player-radius sweep hits core from side "+str(face))
			probe.transform.origin.y += -13.0 if kind==&"fan_sentry" else -18.0
			var outside := space.cast_motion(probe)
			check(is_equal_approx(outside[0],1.0),label+" real player-radius sweep clears former oversized top edge from side "+str(face))
	if kind == &"charger":
		for face: int in [-1,1]:
			var before_move := motor.global_position
			check(motor.move_attack(Vector2(float(face),0),true,1.0/60.0) and is_equal_approx(motor.global_position.x,before_move.x+float(face)),label+" resized body still charges on real support from side "+str(face))
	if kind == &"charger":
		var before_ledge := motor.global_position
		check(not motor.move_attack(Vector2(600,0),true,1.0/60.0) and motor.global_position.is_equal_approx(before_ledge),label+" real unsupported charge is refused without moving through a ledge")
	var motion := host.get("body_motion") as PlainsMotion02
	var sample: EnemyFeedback01 = host.get("feedback_sample") if chain != "root_bell" else (host.get("revision_visual") as PlainsRevisionVisual).sample
	var remains := EnemyPresentationBinding.remains(host)
	check(sample!=null and remains!=null,label+" actual host owns accepted sample and stage remains")
	if sample == null or remains == null:
		fixture.queue_free()
		await frames(2)
		return
	var visual := host.get("revision_visual") as PlainsRevisionVisual
	if kind == &"diver":
		check(visual==null and host.get("feedback_frames") is EnemyFeedback01Frames,label+" diver retains authored size/palette/frame body")
	else:
		check(visual!=null and visual.visible and visual.rig.kind==kind,label+" correct authored rig is actually visible")
		if visual != null:
			check(visual.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and visual.material is ShaderMaterial,label+" body owns nearest world-grid material")
			check_geometry(visual.rig,label)
	var context := packet(label+"/hurt",minf(1.0,actor.health.current*.4))
	check(actor.damageable.receive_damage(context),label+" real receiver accepts nonlethal damage")
	check(sample.accepted_hit_count==1 and sample.hurt_remaining>0,label+" accepted hurt starts exactly once")
	check(not actor.damageable.receive_damage(context) and sample.accepted_hit_count==1,label+" duplicate packet cannot restart hurt")
	var obsolete := packet(label+"/old_epoch",.25)
	obsolete.target_epoch = actor.health.epoch-1
	check(not actor.damageable.receive_damage(obsolete),label+" old epoch is rejected by actual receiver")
	# A single call to the production lifecycle must own one sample decrement.
	host.set_process(false)
	var hurt_before := sample.hurt_remaining
	var clock_before := motion.clock
	var lifecycle: EnemyPresentationLifecycle = host.get("lifecycle")
	check(lifecycle.advance(.031),label+" production lifecycle accepts one explicit native tick")
	check(is_equal_approx(sample.hurt_remaining,maxf(0.0,hurt_before-.031)) and is_equal_approx(motion.clock,clock_before+.031),label+" one lifecycle tick advances sample/motion exactly once")
	paused = true
	var paused_hurt := sample.hurt_remaining
	var paused_clock := motion.clock
	await frames(3)
	check(sample.hurt_remaining==paused_hurt and motion.clock==paused_clock,label+" pause freezes accepted hurt and locomotion")
	check(actor.restore_instance_health(actor.health.capacity),label+" real restore consumer starts new epoch")
	check(sample.hurt_remaining==0.0 and sample.flash_strength()==0.0 and motion.clock==0.0,label+" paused epoch reset clears old hurt and gait")
	paused = false
	host.set_process(true)
	if actor.attack_behavior != null:
		actor.attack_behavior.state = &"telegraph"
		actor.attack_behavior.state_time = .2
	await frames(2)
	var at_death := motor.global_position
	var lethal := packet(label+"/lethal",actor.health.current)
	check(actor.damageable.receive_damage(lethal) and actor.health.terminal,label+" accepted lethal receiver transaction reaches terminal")
	check(remains.active and remains.accepted_starts==1 and sample.accepted_death_count==1,label+" accepted lethal handoff starts one visible body")
	check(motor.collision_layer==0 and motor.collision_mask==0 and not actor.is_physics_processing(),label+" lethal disables damaging body collision and Actor processing")
	if actor.attack_behavior != null:
		check(actor.attack_behavior.state==&"recovery",label+" actual death cancels telegraph/attack state")
	check(not actor.damageable.receive_damage(lethal) and remains.accepted_starts==1,label+" replay cannot start another death")
	var remained_air := false
	var landed := false
	var stable_visible := false
	for frame: int in 250:
		await frames()
		if air and frame<8:
			remained_air = remained_air or (not remains.settled and remains.phase==&"falling")
		if remains.settled and remains.visible:
			landed = landed or remains.support_node()==floor_body
			stable_visible = true
		if frame==20:
			paused = true
			var age_before := remains.age
			var position_before := remains.global_position
			await frames(3)
			check(remains.age==age_before and remains.global_position==position_before,label+" pause freezes falling/settling body")
			paused = false
	check(motor.global_position==at_death,label+" cosmetic fall and collapse never move terminal Actor")
	check(landed and stable_visible,label+" corpse really settles on fixture support before exit")
	if air: check(remained_air,label+" airborne lethal body falls before claiming settlement")
	var persistent := kind in [&"charger",&"diver"]
	if persistent:
		check(remains.active and remains.visible and remains.settled and remains.frame_index==7,label+" persistent corpse remains settled and visible after exit interval")
		var pose_at_rest := remains.global_position
		await frames(30)
		check(remains.global_position==pose_at_rest and remains.accepted_starts==1,label+" persistent settled body stays still without replay")
	else:
		check(not remains.active and not remains.visible and remains.phase==&"faded",label+" transient body fades only after settled hold")
	var starts := remains.accepted_starts
	check(actor.restore_instance_health(0.0),label+" real dead-save restore accepts terminal state")
	await frames(3)
	check(remains.restored and remains.accepted_starts==starts and remains.age==0.0,label+" saved death restores without replaying accepted animation")
	if not persistent: check(not remains.active and not remains.visible,label+" transient saved death stays hidden")
	var reference: WeakRef = weakref(remains)
	cases.append({"case":label,"passed":failures.size()==failure_before,"accepted_deaths":sample.accepted_death_count,"body_policy":"persistent" if persistent else "hold_then_fade","fixture":"actual factory/installer/receiver; fixed initial ground/air; Actor AI disabled; no combat/GPU claim"})
	remains = null
	visual = null
	fixture.queue_free()
	await frames(3)
	check(reference.get_ref()==null,label+" unloading actual host releases stage-owned remains")

func run() -> void:
	world = Node2D.new()
	root.add_child(world)
	world.add_child(GameAudio.new())
	for kind: StringName in BEHAVIORS: await lifecycle_case(kind)
	await lifecycle_case(&"hopper",true)
	await lifecycle_case(&"fan_sentry",true)
	await lifecycle_case(&"root_bell",false,"root_bell")
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"actual test audio backend releases within original teardown bound")
	world.queue_free()
	await frames(2)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"task":"PLAINS-MONSTER-REVISION-01","scope":"explicit native actual factory/presentation/receiver/support lifecycle fixtures; not combat/pixel/device acceptance","checks":checks,"failures":failures,"cases":cases},"\t"))
	file.close()
	print("PLAINS REVISION 01: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
