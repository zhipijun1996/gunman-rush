extends "res://tools/art/plains_actor_capture_base.gd"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL TURN142: ",label)
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://boss_turns_142.json";app.settings_path="user://boss_turns_settings.json"
	root.add_child(app);app.start_new();await settle();app.load_room("P-R14","");await settle()
	app.player.set_physics_process(false);app.controller.set_physics_process(false)
	var keeper:=app.room.encounter as WindkeeperPressureEncounter
	keeper.activate();app.room.battle_started=true;keeper.set_physics_process(false)
	var origin:=keeper.motor.global_position
	keeper.direction=1
	app.player.global_position=origin+Vector2(-240,47)
	keeper._group_plan={"attacks":[&"seeds"],"double_stomp":false,"sweep_high":false}
	keeper._attack_index=0;keeper._begin_attack()
	check(keeper.mode==&"turn" and keeper.direction==1,"backside target enters visible turn")
	verify_turn_articulation(keeper)
	keeper.physics_tick(keeper.clock-.001)
	var before:=keeper.rig_pose()
	keeper.physics_tick(.0011)
	var after:=keeper.rig_pose()
	check(keeper.direction==-1 and keeper.mode==&"seeds_warning","turn accepts opposite facing before attack warning")
	check((before.head_transform as Transform2D).origin.distance_to((after.head_transform as Transform2D).origin)<2,"turn end does not mirror displayed head back across body")
	check((before.core_transform as Transform2D).origin.distance_to((after.core_transform as Transform2D).origin)<2,"core anchor remains continuous at turn completion")
	# Crossing again during the turn may earn a miss, never endless retargeting.
	keeper.direction=1;keeper._pose_from.clear();app.player.global_position=origin+Vector2(-240,47)
	keeper._begin_attack();app.player.global_position=origin+Vector2(240,47)
	keeper.physics_tick(keeper.clock+.001)
	check(keeper.direction==-1 and keeper.mode==&"seeds_warning","player crossing during turn cannot restart endless turn preparation")
	keeper.motor.global_position=origin;keeper.direction=-1
	app.player.global_position=origin+Vector2(-55,47)
	keeper._retreat_ready_age=0;keeper._begin_attack()
	check(keeper.mode==&"retreat_warning","close player triggers readable backward leap preparation")
	var landing:=keeper._hop_target
	check(landing.x>origin.x+100 and absf(landing.y-origin.y)<2,"retreat faces player and locks a real supported landing behind")
	keeper.physics_tick(keeper.clock+.001)
	for i: int in 12:keeper.physics_tick(1.0/60)
	check(keeper.mode==&"retreat" and keeper.motor.global_position.y<origin.y-30,"backward escape actually leaves the floor")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(keeper.combat_snapshot()))
	var mid:=keeper.motor.global_position
	keeper.restore_combat_state(saved)
	check(keeper.mode==&"retreat" and keeper._hop_active and keeper._hop_target.is_equal_approx(landing),"mid-retreat JSON restore keeps locked flight and cooldown")
	for i: int in 25:keeper.physics_tick(1.0/60)
	check(keeper.motor.global_position.distance_to(landing)<2 and keeper.mode==&"seeds_warning","retreat lands and resumes committed group without extra idle")
	app.player.global_position=keeper.motor.global_position+Vector2(-40,47)
	keeper._begin_attack()
	check(keeper.mode!=&"retreat_warning","close chase cannot trigger endless backward hops inside cooldown")
	# Boundary approach is blocked by the whole-body envelope, not shot hull width.
	keeper.motor.global_position=Vector2(keeper.arena.left_x,origin.y);keeper.direction=-1
	keeper._retreat_ready_age=0;app.player.global_position=keeper.motor.global_position+Vector2(-400,47)
	keeper._enter(&"approach",1.1)
	for i: int in 12:keeper.physics_tick(1.0/60)
	check(keeper.mode==&"retreat_warning","blocked approach disengages rather than stalling at arena wall")
	keeper._hop_active=false;keeper._hop_prepared=false
	var visual:=preload("res://game/presentation/actors/art/windkeeper_rig.tscn").instantiate() as PlainsBossRig
	root.add_child(visual)
	for facing: int in [-1,1]:
		keeper.direction=facing;keeper._pose_from.clear()
		for state: StringName in [&"observe",&"approach",&"turn",&"stomp_warning",&"gust",&"seeds"]:
			keeper._enter(state,1);keeper._state_age=.5;keeper._pose_from.clear()
			visual.present(keeper.rig_pose())
			for key: String in ["Torso","Head","Cape","Tail"]:
				var art:=visual.bones[key].get_node("Art") as Sprite2D
				var rect:=art.global_transform*art.get_rect()
				check(rect.position.x>=-keeper._config().wall_clearance and rect.end.x<=keeper._config().wall_clearance,"visible "+key+" remains within wall envelope in "+state)
	var wall:=StaticBody2D.new();wall.collision_layer=1;wall.collision_mask=0
	var wall_shape:=CollisionShape2D.new();var wall_rect:=RectangleShape2D.new();wall_rect.size=Vector2(20,250)
	wall_shape.shape=wall_rect;wall.add_child(wall_shape);keeper.motor.get_parent().add_child(wall)
	wall.global_position=origin+Vector2(165,-40);await ticks(2)
	check(not keeper._landing_body_clear(origin),"raised-platform landing rejects solid wall inside the visible body envelope")
	wall.queue_free();await ticks(2)
	check(keeper._landing_body_clear(origin),"real clear floor remains a valid landing after wall removal")
	# Accepted stage time owns deployment, shaking and cleanup.
	keeper.motor.global_position=origin;keeper._pending_phase=2;keeper._start_phase_transition()
	var screen: WindkeeperPhaseScreen
	for child: Node in keeper.motor.get_node("Presentation").get_children():
		if child is WindkeeperPhaseScreen:screen=child
	check(screen!=null,"formal presentation installs full-screen transition consumer")
	var shapes: Dictionary={}
	for i: int in 7:
		keeper._state_age=keeper._state_duration*float(i)/7;keeper._fight_age=keeper._mill_start_age+keeper._state_age
		var pose:=keeper.rig_pose();visual.present(pose)
		shapes[PlainsBossViewPose.windmill_support(pose).get_rotation()]=true
		var deployment: float=(visual.bones.Rotor.get_node("Art").material as ShaderMaterial).get_shader_parameter("deployment")
		check(is_equal_approx(deployment,float(i)/7),"windmill attachment deployment follows accepted stage progress")
	check(shapes.size()>3,"windmill has multiple visible support unfolding poses")
	screen._process(0)
	check(screen.overlay.visible and screen.overlay.size==root.get_visible_rect().size,"phase effect covers viewport")
	var offset:=app.camera.offset
	paused=true;await ticks(4)
	check(app.camera.offset.is_equal_approx(offset),"pause freezes accepted screen shake")
	keeper.cancel();await ticks(2)
	check(not screen.overlay.visible and app.camera.offset.length()<.01,"cancel while paused removes overlay and exactly its owned camera offset")
	paused=false
	keeper.stage_phase=3;keeper._enter(&"phase_transition",1.8);keeper._state_age=.1
	visual.present(keeper.rig_pose())
	check(is_equal_approx(float((visual.bones.Rotor.get_node("Art").material as ShaderMaterial).get_shader_parameter("deployment")),1.0),"third phase retains fully grown windmill instead of regrowing it")
	visual.queue_free()
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	print("PLAINS BOSS TURN142: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func verify_turn_articulation(keeper: WindkeeperPressureEncounter) -> void:
	var visual:=preload("res://game/presentation/actors/art/windkeeper_rig.tscn").instantiate() as PlainsBossRig
	root.add_child(visual)
	var old_age:=keeper._state_age
	var old_from:=keeper._pose_from
	keeper._pose_from={}
	var connected:=true
	var level_toes:=true
	var solid_skins:=true
	var rotor_continuous:=true
	var prior_angle:=0.0
	for step: int in 41:
		keeper._state_age=keeper._state_duration*float(step)/40
		var pose:=keeper.rig_pose()
		pose.phase=2;pose.mill_age=2.0+float(step)/60
		visual.present(pose)
		for i: int in 4:
			var shin: Bone2D=visual.bones["Lower%d"%i]
			var toe: Bone2D=visual.bones["Foot%d"%i]
			connected=connected and (shin.global_transform*Vector2(0,36)).distance_to(pose.feet[i]-Vector2(0,20))<.01
			level_toes=level_toes and absf(toe.global_transform.y.x)<.001 and toe.global_position.distance_to(pose.feet[i])<.01
		for key: String in ["Torso","Head"]:
			var side:=visual.bones[key].get_node("Art") as Sprite2D
			var front:=visual.bones[key].get_node("Front") as Sprite2D
			solid_skins=solid_skins and side.visible!=front.visible and side.modulate.a==1.0 and front.modulate.a==1.0
		var angle: float=visual.bones.Rotor.global_rotation
		if step>0:rotor_continuous=rotor_continuous and absf(angle_difference(prior_angle,angle))<.35
		prior_angle=angle
	check(connected,"shin ends remain joined to independent ankles throughout actual turn poses")
	check(level_toes,"turning feet remain level and registered with physical foot anchors")
	check(solid_skins,"turn uses one opaque torso/head orientation without transparent ghost bodies")
	check(rotor_continuous,"head turn cannot reflect or reverse accumulated rotor phase")
	keeper._state_age=keeper._state_duration*.49
	var a:=keeper.rig_pose()
	keeper._state_age=keeper._state_duration*.51
	var b:=keeper.rig_pose()
	var planted:=true
	for i: int in 4:planted=planted and (a.feet[i] as Vector2).distance_to(b.feet[i])<.01
	check(planted,"all four planted front-view feet stay fixed while the torso continues its pivot")
	keeper._state_age=old_age;keeper._pose_from=old_from
	visual.queue_free()
