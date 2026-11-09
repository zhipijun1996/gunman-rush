extends "res://tools/art/plains_actor_capture_base.gd"
## Formal rooms/components; positions, selected attacks and owner ticks are explicit fixtures.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL ACTION142: ",label)

func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://boss_actions_142.json";app.settings_path="user://boss_actions_142_settings.json"
	root.add_child(app);app.start_new();await settle();load_fixture("P-R11","");await settle()
	app.player.set_physics_process(false);app.controller.set_physics_process(false)
	var bell := app.room.encounter as BellstriderEncounter
	bell.activate();app.room.battle_started=true;bell.set_physics_process(false)
	bell.direction=1
	bell._face_then(&"roll_warning",bell._config().roll_warning_seconds,-1)
	check(bell.mode==&"turn" and bell.direction==1,"turn begins from existing direction without instant mirror")
	var observed: Dictionary={}
	for i: int in 10:
		bell.physics_tick(bell._config().combo_turn_seconds/20)
		var pose:=bell.rig_pose()
		observed[snappedf(pose.turn_yaw,.01)]=true
		check(pose.mode==&"turn" and pose.direction==1 and pose.turn_yaw<1.0,"turn advances continuous articulated yaw in the original facing basis")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(bell.combat_snapshot()))
	var before:=bell.rig_pose()
	bell.restore_combat_state(saved)
	var after:=bell.rig_pose()
	check(is_equal_approx(after.turn_yaw,before.turn_yaw) and after.body_transform.is_equal_approx(before.body_transform),"mid-turn JSON restore preserves pose and facing")
	bell.physics_tick(bell.clock+.001)
	print("TURN END ",bell.mode," face=",bell.direction," observations=",observed," active=",bell.active)
	check(bell.direction==-1 and bell.mode==&"roll_warning" and observed.size()>=4,"turn completes before the committed warning, with multiple distinct volume poses")
	# Select the side with actual free travel; test real accelerated Motor displacement.
	bell.direction=1 if bell.arena.travel_limit(bell.motor.global_position.x,1)>bell.arena.travel_limit(bell.motor.global_position.x,-1) else -1
	app.player.global_position=bell.motor.global_position-Vector2(bell.direction*400,-47)
	bell._group={"kind":&"roll","phase":1,"return_roll":false,"count":1,"direction":bell.direction}
	bell._roll_age=0;bell._enter(&"roll",bell._config().roll_max_seconds)
	var start:=bell.motor.global_position;var peak:=0.0
	for i: int in 30:
		bell.physics_tick(1.0/60)
		peak=maxf(peak,absf(bell.motor.velocity.x))
		await physics_frame
	print("CHARGE peak=",peak," distance=",bell.motor.global_position.distance_to(start)," mode=",bell.mode)
	check(peak>=590 and bell.motor.global_position.distance_to(start)>180,"fast charge reaches configured speed and physically crosses the arena")
	load_fixture("P-R14","");await settle()
	app.player.set_physics_process(false);app.controller.set_physics_process(false)
	var keeper:=app.room.encounter as WindkeeperPressureEncounter
	keeper.activate();app.room.battle_started=true;keeper.set_physics_process(false);keeper.stage_phase=1;keeper.direction=-1
	app.player.global_position=keeper.motor.global_position+Vector2(-390,47)
	keeper._group_plan={"attacks":[&"stomp"],"double_stomp":false,"sweep_high":false}
	keeper._attack_index=0;keeper._preparation_index=-1;keeper._begin_attack()
	print("WIND START ",keeper.mode," active=",keeper.active," group=",keeper._group_plan)
	check(keeper.mode==&"approach","phase-one distant stomp first enters real approach")
	start=keeper.motor.global_position
	for i: int in 100:
		keeper.physics_tick(1.0/60)
		await physics_frame
		if keeper.mode==&"stomp_warning":break
	print("APPROACH END ",keeper.mode," distance=",keeper.motor.global_position.distance_to(start)," dx=",absf(keeper.motor.global_position.x-app.player.global_position.x))
	check(keeper.mode==&"stomp_warning" and keeper.motor.global_position.distance_to(start)>150,"phase one walks toward player before telegraphing melee")
	check(absf(keeper.motor.global_position.x-app.player.global_position.x)<keeper._config().close_range+8,"stomp preparation reaches configured near distance")
	# Observe actual windmill volleys and real effect ownership, no fake hit signals.
	keeper.stage_phase=2;keeper._group_plan={"attacks":[&"gust"],"double_stomp":false};keeper._attack_index=0
	keeper.locked_direction=-1;keeper.locked_target=app.player.global_position
	keeper._enter(&"gust_warning",keeper._config().normal_warning_seconds)
	var volleys: Array[Dictionary]=[]
	keeper.presentation_event.connect(func(event: Dictionary)->void:
		if event.get("event")==&"windkeeper_seeds_release":volleys.append(event.duplicate(true)))
	keeper._release_attack()
	for i: int in 21:
		keeper.physics_tick(1.0/60);await physics_frame
	check(volleys.size()==1 and keeper._gust_volleys==1,"windmill first volley occurs during active gust")
	var frame:=keeper.rig_pose()
	var hub:=keeper.motor.to_global(PlainsBossRig.windmill_origin(frame))
	check((volleys[0].point as Vector2).distance_to(hub)<50,"gust projectiles leave the measured head windmill")
	var wind_saved:=keeper.combat_snapshot()
	keeper.restore_combat_state(wind_saved)
	check(keeper._gust_volleys==1,"restoring active gust does not replay its already emitted volley")
	for i: int in 55:
		keeper.physics_tick(1.0/60);await physics_frame
	check(volleys.size()==2 and keeper.mode==&"recover","exactly two advertised wind volleys, then final recovery")
	var count:=volleys.size()
	for i: int in 20:
		keeper.physics_tick(1.0/60);await physics_frame
	check(volleys.size()==count,"recovery releases no extra projectile")
	var fx:=PlainsBossEffects.spawn(keeper.motor.get_parent(),keeper,keeper.motor.global_position,&"wind")
	await ticks(2);paused=true
	var age:=fx.age;await ticks(6)
	check(fx.age==age,"painted impact animation freezes during game pause")
	paused=false;keeper.cancel();await ticks(2)
	check(not is_instance_valid(fx),"attack cancellation clears owned impact effects")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
	check(get_nodes_in_group(&"plains_boss_effects").is_empty(),"room teardown leaves no orphaned effects")
	print("PLAINS BOSS ACTION142: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
