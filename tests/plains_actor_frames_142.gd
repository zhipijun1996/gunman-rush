extends SceneTree
## Actual final binding and accepted health lifecycle for every plains species.
## Attack phase/clock values below are explicit presentation fixtures, not AI runs.
var checks := 0
var failures := 0
var app: FixedWorldApp
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ",label)
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy: return
	check(false,"actual room load completes")
func run() -> void:
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_actor_frames_142_test.json"
	app.settings_path="user://plains_actor_frames_142_settings.json"
	root.add_child(app);app.start_new();await settle()
	app.load_room("P-R10", "");await settle()
	app.controller.active=false;app.set_physics_process(false)
	for actor: EnemyActor in app.room.enemies.values(): actor.set_physics_process(false)
	for kind: StringName in [&"patrol",&"charger",&"hopper",&"sentry",&"fan_sentry",&"root_bell",&"diver"]:
		var body := EnemyFactory.create_for_behavior(kind)
		var actor := body.get_node("Actor") as EnemyActor
		actor.set_meta(&"world_persistent_corpse",true)
		body.position=Vector2(1000,1344-actor.definition.collision_size.y*.5)
		app.room.add_child(body)
		EnemyPresentationBinding.replace(actor,&"underworld")
		actor.bind_encounter(app.controller,app.policy,app.lifetime,StringName("animation_"+String(kind)),[])
		actor.set_physics_process(false)
		var host := body.get_node("Presentation") as UnderworldEnemy
		var visual := host.revision_visual
		check(visual!=null and visual.authored_frames, "%s uses final authored renderer" % kind)
		var skin := visual.rig as PlainsActorSkin
		check(skin.motion_animation.columns==8,"%s has eight distinct painted idle/movement poses" % kind)
		check(skin.animation.clips==["idle","move","anticipation","attack","recovery","hurt","death"], "%s owns every requested action" % kind)
		if actor.attack_behavior!=null:
			for phase: StringName in [&"telegraph",&"attack",&"recovery"]:
				actor.attack_behavior.state=phase
				var duration: float=actor.definition.telegraph_duration if phase==&"telegraph" else actor.definition.attack_duration if phase==&"attack" else actor.definition.recovery_duration
				for index: int in 4:
					actor.attack_behavior.state_time=(float(index)+.1)/4*duration
					EnemyPresentationBinding.synchronize(actor)
					var selected:=skin.frame_selection(visual.pose)
					var expected:=&"anticipation" if phase==&"telegraph" else phase
					check(selected.clip==expected and skin.animation.frame_index(selected.clip,selected.progress)%4==index,"%s %s consumes exact owner phase %d" % [kind,phase,index])
		else:
			check(kind==&"patrol","contact patrol does not acquire artificial attack AI")
		var hit := {"event_id":"art142_hit_"+String(kind),"amount":.5,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":actor.damageable.actor_id,"target_epoch":actor.health.epoch,"hit_point":body.global_position}
		check(actor.damageable.receive_damage(hit),"%s accepts real nonlethal Damageable transaction" % kind)
		await ticks(1)
		check(skin.frame_selection(visual.pose).clip==&"hurt","%s accepted hit selects hurt" % kind)
		paused=true
		var before:=host.feedback_sample.hurt_remaining
		await ticks(5)
		check(is_equal_approx(before,host.feedback_sample.hurt_remaining),"%s hurt freezes while paused" % kind)
		paused=false
		await ticks(20)
		check(skin.frame_selection(visual.pose).clip!=&"hurt","%s returns from hurt to current phase" % kind)
		hit.event_id="art142_death_"+String(kind);hit.amount=actor.health.current
		check(actor.damageable.receive_damage(hit),"%s accepts lethal Damageable transaction" % kind)
		await ticks(95)
		var remains:=visual.remains
		check(actor.health.terminal and not visual.visible and remains.accepted_starts==1,"%s death takes over once and hides live body" % kind)
		check(remains.get("_rig")==skin and remains.frame_index==7 and remains.visible,"%s settles using this species death sheet" % kind)
		var starts:=remains.accepted_starts
		actor.restore_instance_health(0);EnemyPresentationBinding.synchronize(actor)
		await ticks(3)
		check(remains.accepted_starts==starts and remains.restored and host.feedback_sample.flash_strength()==0,"%s terminal restore has no fresh hurt or death" % kind)
		body.queue_free();await ticks(3)
		check(not is_instance_valid(remains),"%s room ownership releases remains" % kind)
	# Initial airborne placement is explicit. Lethal damage, gravity, pause and
	# collision queries are production components, never manually advanced.
	for kind: StringName in [&"diver",&"hopper"]:
		var body:=EnemyFactory.create_for_behavior(kind)
		var actor:=body.get_node("Actor") as EnemyActor
		actor.set_meta(&"world_persistent_corpse",true)
		body.position=Vector2(1000,1100)
		app.room.add_child(body)
		EnemyPresentationBinding.replace(actor,&"underworld")
		actor.bind_encounter(app.controller,app.policy,app.lifetime,StringName("fall_"+String(kind)),[])
		actor.set_physics_process(false)
		await ticks(2)
		var host:=body.get_node("Presentation") as UnderworldEnemy
		var remains:=host.revision_visual.remains
		var hit:={"event_id":"air_death_"+String(kind),"amount":actor.health.current,"source_faction":&"player","source_actor_id":app.player.get_instance_id(),"target_actor_id":actor.damageable.actor_id,"target_epoch":actor.health.epoch,"hit_point":body.global_position}
		check(actor.damageable.receive_damage(hit),"airborne %s accepts lethal damage" % kind)
		var initial_y:=remains.global_position.y
		await ticks(18)
		check(remains.phase==&"falling" and remains.global_position.y>initial_y+5 and remains.frame_index==4,"airborne %s drops without playing grounded collapse" % kind)
		paused=true
		var stopped:=remains.global_position
		await ticks(6)
		check(remains.global_position==stopped,"airborne %s corpse freezes on pause" % kind)
		paused=false
		await ticks(140)
		check(remains.settled and remains.support_node()!=null and absf(remains.global_position.y-1344)<2,"airborne %s lands on measured real room terrain" % kind)
		body.queue_free();await ticks(2)
	for kind: StringName in [&"bellstrider",&"windkeeper"]:
		for phase: int in [1,2]:
			var actions:= ["roll","rings","lob"] if kind==&"bellstrider" else ["stomp","lunge","sweep","gust","seeds","platform"]
			for action: String in actions:
				var data: Dictionary={"mode":StringName(action),"phase":phase,"state_age":.1,"state_duration":1.0,"direction":-1,"death_age":0.0,"bell_hit_age":99.0}
				var frame:=PlainsBossFrames.sample(kind,data,{})
				check(frame.clip==&"attack","%s phase%d %s has authored attack" % [kind,phase,action])
				var animation: PlainsActorAnimation=frame.animation
				check(animation.columns==9 and String(frame.sheet).ends_with("_flow"),"%s %s consumes nine-pose flow" % [kind,action])
				var pixels:=animation.atlas.get_image()
				for pair: Array in [[&"anticipation",&"attack"],[&"attack",&"recovery"]]:
					check(pixels.get_region(animation.region(pair[0],1.0)).get_data()==pixels.get_region(animation.region(pair[1],0.0)).get_data(),"%s %s preserves exact action endpoint" % [kind,action])
				var recovery_data:=data.duplicate()
				recovery_data.mode=&"neck" if kind==&"bellstrider" else &"recover"
				recovery_data.recovery_from=action.replace("rings","ring")
				recovery_data.state_age=.8;recovery_data.state_duration=2.0
				check(PlainsBossFrames.sample(kind,recovery_data,{}).progress==1.0,"long recovery settles then holds without stretching four poses")
				var core:=PlainsBossFrames.core_transform(frame)
				check(core.origin.is_equal_approx(frame.origin+animation.core_point(frame.clip,frame.progress)*Vector2(-1,1)),"core follows displayed mirrored frame")
				if action in ["lob","seeds"]:
					check(animation.muzzle_points.size()==animation.columns*animation.clips.size(),"projectile releases have measured mouth anchors")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("PLAINS ACTOR FRAMES142: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
