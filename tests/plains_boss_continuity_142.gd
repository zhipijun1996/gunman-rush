extends "res://tools/art/capture_plains_enemy_context.gd"
## Fixed-part/bone invariants, signed rolling, actual anchors and broad wind admission.
var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL CONTINUITY142: ",label)
func run() -> void:
	var bell_visual:=preload("res://game/presentation/actors/art/bellstrider_rig.tscn").instantiate() as PlainsBossRig
	root.add_child(bell_visual)
	var wheel: Bone2D=bell_visual.bones.FrontWheel
	var original_textures: Dictionary={}
	for key: String in bell_visual.bones:
		original_textures[key]=(bell_visual.bones[key].get_node("Art") as Sprite2D).texture
	for direction: int in [-1,1]:
		var previous_angle:=0.0
		for step: int in 4:
			var pose:=BellstriderRigPose.sample({"mode":&"roll","direction":direction,"travel":step*7.0*direction,"state_age":.6,"speed":600.0})
			bell_visual.present(pose)
			if step>0:check(absf(angle_difference(previous_angle,wheel.global_rotation)-float(direction)/3.0)<.001,"wheel angle follows signed real displacement / tyre radius")
			previous_angle=wheel.global_rotation
			check(is_equal_approx(wheel.global_scale.length_squared(),2.0),"rolling preserves circular wheel dimensions")
	for mode: StringName in [&"observe",&"roll_warning",&"roll",&"neck",&"ring_warning",&"rings",&"lob_aim",&"lob",&"dead"]:
		var pose:=BellstriderRigPose.sample({"mode":mode,"direction":-1,"state_age":.3,"state_duration":1.0,"death_age":.5,"fight_age":2.0})
		bell_visual.present(pose)
		for key: String in bell_visual.bones:
			check((bell_visual.bones[key].get_node("Art") as Sprite2D).texture==original_textures[key],"fixed part survives action changes without body image/alpha replacement: "+key)
		var cannon:=bell_visual.bones.Cannon.get_node("Art") as Sprite2D
		var painted_muzzle:=cannon.global_transform*Vector2(-47,-24)
		var physical_muzzle: Vector2=pose.launcher_transform*Vector2(25,-3)
		check(painted_muzzle.distance_to(physical_muzzle)<1.0,"fixed cannon opening and real projectile origin coincide")
	for step: int in 21:
		var pose:=BellstriderRigPose.sample({"mode":&"turn","direction":1,"turn_from":1,"turn_target":-1,"state_age":float(step)/20,"state_duration":1.0})
		pose=PlainsBossViewPose.turn(pose,true)
		bell_visual.present(pose)
		check((bell_visual.bones.Chassis as Bone2D).global_transform.x.length()>.65,"carriage retains front-view volume throughout the turn")
		check((bell_visual.bones.Bell as Bone2D).global_position.distance_to(pose.bell_transform.origin)<.01,"turning bell and real weakpoint remain registered")
	bell_visual.queue_free();await ticks(1)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://boss_continuity_142.json";app.settings_path="user://boss_continuity_142_settings.json"
	root.add_child(app);app.start_new();await settle();app.load_room("P-R14","");await settle()
	var encounter:=app.room.encounter as WindkeeperPressureEncounter
	encounter.activate();app.room.battle_started=true;encounter.set_physics_process(false)
	var wind_visual:=preload("res://game/presentation/actors/art/windkeeper_rig.tscn").instantiate() as PlainsBossRig
	root.add_child(wind_visual)
	var body_texture: Texture2D=(wind_visual.bones.Torso.get_node("Art") as Sprite2D).texture
	for phase: int in [1,2]:
		encounter.stage_phase=phase
		for mode: StringName in [&"observe",&"approach",&"stomp_warning",&"stomp",&"lunge",&"sweep",&"seeds",&"gust",&"recover",&"dead"]:
			encounter._enter(mode,1.0)
			for step: int in 5:
				encounter._state_age=float(step)*.18
				var pose:=encounter.rig_pose()
				wind_visual.present(pose)
				var torso: Bone2D=wind_visual.bones.Torso
				check((torso.get_node("Art") as Sprite2D).texture==body_texture and is_equal_approx(torso.global_scale.length_squared(),2.0),"both phases and every attack retain exactly the same body art and scale")
				check((wind_visual.bones.Core as Bone2D).global_position.distance_to(pose.core_transform.origin)<.01,"visible chest core matches actual Damageable anchor")
				check((wind_visual.bones.Rotor as Bone2D).global_position.distance_to(PlainsBossRig.windmill_origin(pose))<.01,"windmill art and volley share one bone hub")
	encounter.direction=1;encounter.locked_direction=-1
	encounter._enter(&"turn",1.0)
	for step: int in 21:
		encounter._state_age=float(step)/20
		var pose:=encounter.rig_pose()
		wind_visual.present(pose)
		check((wind_visual.bones.Torso as Bone2D).global_transform.x.length()>.72,"guardian retains front-view body depth throughout the turn")
		check((wind_visual.bones.Core as Bone2D).global_position.distance_to(pose.core_transform.origin)<.01,"turning chest art and actual Damageable share the same location")
	wind_visual.queue_free();await ticks(1)
	encounter.stage_phase=2
	for direction: int in [-1,1]:
		encounter.locked_direction=direction
		var field:=encounter.wind_field_rect()
		for y: float in [-270,-140,40]:
			var local:=Vector2(direction*220,y)
			check(field.has_point(local),"wind covers upper/middle/near-ground forward space")
			app.player.global_position=encounter.motor.global_position+local
			app.player.clear_local_velocity();encounter._apply_wind(1.0/60)
			check(app.player._local_velocity.x*direction>70,"actual PlayerMotor accepts wind at all three elevations")
		check(not field.has_point(Vector2(-direction*100,-100)),"wind excludes space behind boss")
		check(not field.has_point(Vector2(direction*500,-100)),"wind excludes beyond the configured front edge")
		check(not field.has_point(Vector2(direction*220,-340)),"wind excludes above the configured ceiling")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("PLAINS BOSS CONTINUITY142: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
