extends SceneTree
## Terrain probes below preserve the existing comparison driver algorithm.
## Production scripts are loaded at runtime to keep this observer one-way.
## Disclosed review chapters on a verified original plains shore. Real App,
## AI after the .8s idle observation, Router, projectiles, damage and rewards.
const CHAPTER_BEHAVIORS: Array[StringName] = [&"patrol", &"charger", &"diver", &"hopper", &"sentry", &"fan_sentry", &"root_bell"]
const IDLE_HOLD_FRAMES := 48
const CASE_MIN_FRAMES := 420
const CASE_MAX_FRAMES := 1080
const STARTUP_FRAME_BUDGET := 3600
var trace_path := ""
var seed_label := "plains-revision-01-scale"
var app: Node2D
var heading: Label
var detail: Label
var frames: Array[Dictionary] = []
var failures: Array[String] = []
var frame := 0
var ready := false
var busy := false
var finished := false
var original_spawn := Vector2.ZERO
var stand := Vector2.ZERO
var floor_y := 0.0
var support: Dictionary = {}
var source_before: Dictionary = {}
var git_before: Dictionary = {}
var original_camera_zoom := Vector2.ONE
var stand_search: Array[Dictionary] = []
var selected_behaviors: Array[StringName] = []
var chapter := -1
var chapter_frame := 0
var chapter_rows: Array[Dictionary] = []
var sample_motor: CharacterBody2D
var sample_actor: Node
var sample_id := ""
var sample_contact: Node2D
# Keep this observer one-way, as in the existing formal capture consumers.
# A typed concrete audio/Actor dependency can retain the GDScript class graph
# after every actual Node and backend playback has already been released.
var sample_audio: Node
var current_manifest_text := ""
var death_at := -1
var hurt_at := -1
var shot_at := -1000
var chapter_start_wallet := 0
var chapter_start_hp := 0.0
var injury_submitted := false
var got_heal := false
var root_denominations_ok := false
var teardown_reports: Array[Dictionary] = []
var active_frame_count := 0
var postdraw_rows := 0

func _initialize()->void:
	var requested:PackedStringArray=[]
	for argument:String in OS.get_cmdline_user_args():
		if argument.begins_with("--trace="):trace_path=argument.trim_prefix("--trace=")
		elif argument.begins_with("--seed="):seed_label=argument.trim_prefix("--seed=")
		elif argument.begins_with("--species="):requested=argument.trim_prefix("--species=").split(",",false)
		elif argument.begins_with("--behaviors="):requested=argument.trim_prefix("--behaviors=").split(",",false)
	var aliases:Dictionary={"patrol":"patrol_drone","charger":"plains_charger","diver":"plains_diver","hopper":"plains_hopper","sentry":"plains_sentry","fan_sentry":"plains_fan_sentry","root_bell":"plains_root_bell"}
	var matched:Dictionary={}
	for behavior:StringName in CHAPTER_BEHAVIORS:
		if requested.is_empty():selected_behaviors.append(behavior)
		else:
			for name:String in requested:
				if name==String(behavior) or name==str(aliases[String(behavior)]):
					if not selected_behaviors.has(behavior):selected_behaviors.append(behavior)
					matched[name]=true
	if selected_behaviors.is_empty() or (not requested.is_empty() and matched.size()!=requested.size()):
		printerr("Unknown or duplicate requested species/behaviors");quit(1);return
	if trace_path.is_empty():printerr("--trace=PATH is required");quit(1);return
	start.call_deferred()

func start() -> void:
	root.size=Vector2i(1280,720)
	source_before=_source_hashes()
	git_before=_git_source()
	var overlay:=CanvasLayer.new()
	overlay.layer=100
	root.add_child(overlay)
	heading=_label("PLAINS 7 / BODY, IMPACT AND DEATH LOOT / NORMAL SPEED",Vector2(14,626),18)
	detail=_label("Loading actual App; finding an unchanged safe shore",Vector2(14,652),15)
	overlay.add_child(heading);overlay.add_child(detail)
	overlay.add_child(_label("Review fixture: first 0.8s movement held for idle; then real AI / Router / App rewards. Not a natural route.",Vector2(14,692),13))
	process_frame.connect(drive)
	RenderingServer.frame_post_draw.connect(_capture_post_draw)
	_next_chapter.call_deferred()

func _next_chapter() -> void:
	busy=true;ready=false
	chapter+=1
	if chapter>=selected_behaviors.size():
		finish.call_deferred();return
	app=load("res://scripts/demo/demo_app.gd").new() as Node2D;app.meta_persistence_enabled=false
	root.add_child(app)
	if not app.start_plains(seed_label):
		failures.append("Actual App refused plains start");finish.call_deferred();return
	for _i:int in STARTUP_FRAME_BUDGET:
		await physics_frame
		if _stage_ready():break
	if not _stage_ready():
		failures.append("Actual generated stage not ready after bounded startup");finish.call_deferred();return
	original_spawn=app.player.global_position
	current_manifest_text=JSON.stringify(app.stage.generated.manifest)
	for _i:int in 4:await physics_frame
	support=_find_stand()
	if support.is_empty():
		failures.append("No original 256wu safe static shore; no replacement terrain inserted");finish.call_deferred();return
	stand=support.player_location;floor_y=float(support.floor_y)
	var stage:Node2D=app.stage
	var original_count:int=stage.enemies.size()
	app._enemy_contacts.clear();app._enemy_contact=null
	for old:CharacterBody2D in stage.enemies:
		if is_instance_valid(old):old.free()
	stage.enemies.clear();stage.enemy_manifest.clear();stage.pickups.clear()
	# This fixture keeps the real stage/terrain/HUD, but samples the seven
	# factory bodies rather than pretending its original generated roster did.
	# App's nonconnected settlement branch consumes its normal DropService.
	app.connected_region=false
	var behavior:StringName=selected_behaviors[chapter]
	var bonus:="heart" if behavior==&"root_bell" else "note" if behavior==&"sentry" else "coin"
	sample_id=_choose_identity(behavior,bonus)
	sample_motor=_factory(&"create_for_behavior",[behavior,{&"patrol_half_width":18.0}]) as CharacterBody2D
	if sample_motor==null:
		failures.append("Factory refused "+String(behavior));finish.call_deferred();return
	sample_actor=sample_motor.get_node("Actor") as Node
	var hover:=42.0 if sample_actor.definition.aerial else 0.0
	sample_motor.position=stage.to_local(Vector2(stand.x+85.0,floor_y-sample_actor.definition.collision_size.y*.5-hover))
	stage.add_child(sample_motor)
	stage.enemies.append(sample_motor);stage.enemy=sample_motor
	stage.enemy_manifest.append({"id":sample_id,"behavior_id":String(behavior),"fixture":"explicit_review_sample"})
	if not load("res://scripts/presentation/enemy_presentation_binding.gd").call("replace",sample_actor,&"underworld"):
		failures.append("Formal Underworld renderer refused sample");finish.call_deferred();return
	if not app.policy.bind_damageable(StringName(sample_id),sample_actor.damageable,sample_actor.health):
		failures.append("Actual DamagePolicy refused sample receiver");finish.call_deferred();return
	var protected_points:Array[Vector2]=[]
	sample_actor.bind_encounter(app.controller,app.policy,app.lifetime,StringName(sample_id),protected_points)
	sample_contact=load("res://scripts/damage/demo_contact_emitter.gd").new() as Node2D;sample_contact.policy=app.policy;sample_contact.controller=app.controller
	sample_contact.source_id=StringName(sample_id+"/body_contact");sample_contact.half_size=sample_actor.definition.collision_size*.5
	sample_motor.add_child(sample_contact);app._enemy_contacts.append(sample_contact)
	app.player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	app.controller.router.activate_device(&"gamepad");app.controller.router.clear("disclosed_motion_loot_review")
	app.player.reset_at(Vector2(stand.x-105.0,stand.y))
	for _i:int in 4:await physics_frame
	original_camera_zoom=app._run_camera.zoom
	app._run_camera.set_physics_process(false)
	app._run_camera.global_position=Vector2(stand.x,floor_y-65.0)
	app._run_camera.force_update_scroll()
	sample_audio=root.get_tree().get_first_node_in_group(&"game_audio") as Node
	if not is_instance_valid(sample_audio) or sample_audio.get_script().resource_path!="res://scripts/dev/player_presentation_01/weapon_audio_v2.gd" or not app.is_ancestor_of(sample_audio):
		failures.append("Actual App-owned PlayerWeaponFeelAudioV2 service is unavailable");finish.call_deferred();return
	chapter_frame=0;death_at=-1;hurt_at=-1;shot_at=-1000;injury_submitted=false
	chapter_start_wallet=int(app.wallet.balance);chapter_start_hp=app.controller.actor_resources.health.current
	sample_actor.set_physics_process(false);sample_motor.stop()
	var entry:={"case":chapter,"id":String(sample_actor.definition.stable_id),"behavior":String(behavior),"definition":String(sample_actor.definition.stable_id),"definition_path":str(_factory(&"definition_path_for_behavior",[behavior])),"scene":str(_factory(&"scene_path_for_behavior",[behavior])),"chain":"actual_App_review_shore","renderer":"res://scripts/underworld_plains/underworld_enemy.gd","start_frame":active_frame_count+1,"start_seconds":float(Engine.get_process_frames()+1)/60.0,"movie_start_process_frame":Engine.get_process_frames()+1,"fixture":{"entry":"DemoApp.start_plains","production_AI_enabled":true,"initial_idle_movement_hold_frames":IDLE_HOLD_FRAMES,"actor_factory_override":{"patrol_half_width":18.0},"original_generated_enemies_removed":original_count,"authored_pickups_removed":true,"connected_region_false_for_review_settlement":true,"original_manifest_sha256":current_manifest_text.sha256_text(),"floor":support,"initial_player_position":_vec(app.player.global_position),"initial_enemy_position":_vec(sample_motor.global_position),"original_camera_zoom":_vec(original_camera_zoom),"differences":["seven Factory samples replace original encounters/pickups only for review","initial .8s Actor physics held while body clocks continue; then original AI enabled","initial player reset_at and automated gamepad adapter","18wu review patrol lane; original speed/HP/attack timing unchanged","root bell source identity preselected by unchanged real bonus roll; at most one disclosed initial DamagePolicy injury","no natural route or unchanged-roster claim"]},"events":[],"player_events":[],"shots":[],"inputs":[],"deaths":0,"coverage":{},"coverage_gaps":[],"initial_wallet":chapter_start_wallet,"initial_player_HP":chapter_start_hp,"receipt_source_id":sample_id}
	chapter_rows.append(entry)
	var pool:Variant=sample_audio.get("_voices")
	entry.fixture["app_audio"]={"script":sample_audio.get_script().resource_path,"owned_by_actual_App":app.is_ancestor_of(sample_audio),"voice_pool_size":pool.size() if pool is Array else -1}
	var case_index:=chapter
	sample_actor.health.changed.connect(func(result:Object)->void:
		if result.operation!=&"damage" or not _applied(result):return
		chapter_rows[case_index].events.append({"frame":active_frame_count,"movie_frame":Engine.get_process_frames(),"amount":result.amount_applied,"HP":result.snapshot.current,"terminal":result.snapshot.terminal,"event_id":String(result.event_id)})
		if result.snapshot.terminal:death_at=chapter_frame
		elif hurt_at<0:hurt_at=chapter_frame)
	sample_actor.defeated.connect(func(_actor:Node)->void:chapter_rows[case_index].deaths+=1)
	app.controller.actor_resources.health.changed.connect(func(result:Object)->void:
		if not _applied(result):return
		chapter_rows[case_index].player_events.append({"frame":active_frame_count,"movie_frame":Engine.get_process_frames(),"operation":String(result.operation),"amount":result.amount_applied,"HP":result.snapshot.current,"terminal":result.snapshot.terminal,"event_id":String(result.event_id)})
		if result.amount_applied>0:got_heal=true)
	app.controller.shoot_ability.shot_fired.connect(func(direction:Vector2,shot_id:int)->void:
		chapter_rows[case_index].shots.append({"frame":active_frame_count,"movie_frame":Engine.get_process_frames(),"shot_id":shot_id,"direction":_vec(direction)}))
	ready=true;busy=false

func _choose_identity(behavior:StringName,bonus:String)->String:
	var probe:RefCounted=load("res://scripts/rewards/enemy_drop_service.gd").new()
	probe.configure(app._enemy_drops.root_seed,app._enemy_drops.stage_id)
	for index:int in 256:
		var candidate:="review/plains-motion-loot-02/%s/%s"%[String(behavior),index]
		var output:Dictionary=probe.settle(StringName(candidate),behavior)
		if str(output.get("bonus_roll_kind",""))==bonus:return candidate
	failures.append("No unchanged bonus-roll identity found within256");return "review/unresolved/"+String(behavior)

func _request(action:StringName,direction:Vector2)->void:
	var submitted:bool=app.controller.router.request_action(action,direction)
	chapter_rows[chapter].inputs.append({"frame":active_frame_count,"movie_frame":Engine.get_process_frames(),"action":String(action),"direction":_vec(direction),"submitted":submitted})

func _injure_once()->void:
	injury_submitted=true
	if app.controller.actor_resources.health.current<app.controller.actor_resources.health.capacity:return
	var request:RefCounted=load("res://scripts/damage/damage_request.gd").new()
	request.token=app.lifetime.token();request.actor_epoch=app.lifetime.actor_epoch
	request.health_epoch=app.controller.actor_resources.health.epoch
	request.target_id=&"player";request.source_id=&"disclosed_initial_review_injury"
	request.event_id=StringName("review_initial_injury/%s"%chapter);request.amount=1.0
	var accepted:bool=app.policy.submit(request)
	chapter_rows[chapter].fixture["initial_injury_request"]={"submitted":accepted,"amount":1,"policy":"actual FrameDamagePolicy; no direct HP assignment"}

func drive()->void:
	frame+=1
	if busy or finished or not ready:return
	chapter_frame+=1;active_frame_count+=1
	# Avoid inferring the nested PlayerController class through DemoApp. The
	# observer reads/calls the real Node without adding a compiled class edge.
	var controller:Node=app.controller
	var stage:Node2D=app.stage
	if chapter_frame==IDLE_HOLD_FRAMES+1:sample_actor.set_physics_process(true)
	if selected_behaviors[chapter]==&"root_bell" and chapter_frame>=90 and not injury_submitted:_injure_once()
	var aim:Vector2=(sample_motor.global_position-app.player.global_position).normalized()
	if aim.is_zero_approx():aim=Vector2.RIGHT
	controller.router.set_aim(&"gamepad",aim,false)
	var axis:=0.0
	var player_at:Vector2=app.player.global_position
	var delta_x:float=sample_motor.global_position.x-player_at.x
	var units:Array[Dictionary]=[]
	for pickup:Dictionary in stage.pickups:
		if str(pickup.get("source",""))==sample_id:units.append(pickup)
	var after_death:=death_at>=0 and chapter_frame-death_at>=90
	if not sample_actor.health.terminal and chapter_frame>IDLE_HOLD_FRAMES+24:
		if absf(delta_x)>148.0:axis=signf(delta_x)
		elif absf(delta_x)<100.0:axis=-signf(delta_x)
		if chapter_frame>=125 and chapter_frame-shot_at>=48:
			_request(&"shoot_release",aim);shot_at=chapter_frame
	elif after_death:
		var target:=Vector2.INF;var best:=INF
		for pickup:Dictionary in units:
			if pickup.claimed:continue
			var at:Vector2=stage.to_global(pickup.position)
			var distance:=player_at.distance_squared_to(at)
			if distance<best:best=distance;target=at
		if target.is_finite() and absf(target.x-player_at.x)>8.0:axis=signf(target.x-player_at.x)
	# The verified shore is256wu. An actual solid UP ray is required before
	# the input driver walks farther; no floor or actor position is invented.
	var next_x:=player_at.x+axis*12.0
	var edge:=_ray(next_x,floor_y-4.0,floor_y+8.0)
	if edge.is_empty():axis=0.0
	controller.router.set_source_axis(&"gamepad",axis)
	var all_claimed:=not units.is_empty() and units.all(func(p:Dictionary)->bool:return bool(p.claimed))
	var collected_coins:=0;var values:Array[int]=[];var unit_rows:Array[Dictionary]=[]
	for pickup:Dictionary in units:
		if pickup.kind=="coin":
			values.append(int(pickup.amount))
			if pickup.claimed:collected_coins+=int(pickup.amount)
		unit_rows.append({"id":String(pickup.id),"kind":String(pickup.kind),"amount":int(pickup.amount),"position":_vec(pickup.position),"claimed":bool(pickup.claimed),"bounces":int(pickup.get("loot_bounces",0)),"settled":bool(pickup.get("loot_settled",false)),"velocity":_vec(pickup.get("loot_velocity",Vector2.ZERO))})
	if selected_behaviors[chapter]==&"root_bell" and values==[5,1,1]:root_denominations_ok=true
	var state:Dictionary=sample_actor.presentation_state()
	var motion:Variant=_optional(sample_motor.get_node("Presentation"),&"body_motion")
	var row:={"frame":active_frame_count,"movie_process_frame":Engine.get_process_frames(),"case":chapter,"local_frame":chapter_frame,"sampling_phase":"SceneTree.process_frame_before_node_process","idle_hold":chapter_frame<=IDLE_HOLD_FRAMES,"AI_enabled":sample_actor.is_physics_processing(),"player_position":_vec(player_at),"enemy_position":_vec(sample_motor.global_position),"HP":sample_actor.health.current,"player_HP":controller.actor_resources.health.current,"wallet":app.wallet.balance,"state":String(state.get("state",&"")),"body_clock":_optional(motion,&"clock") if motion is Object else null,"drive":_optional(motion,&"travel") if motion is Object else null,"units":unit_rows,"collected_coin_total":collected_coins,"camera_zoom":_vec(app._run_camera.zoom)}
	frames.append(row)
	heading.text="%s / %s   %s   BODY / HURT / DEATH / LOOT"%[chapter+1,selected_behaviors.size(),String(selected_behaviors[chapter]).to_upper()]
	var phase:="IDLE OBSERVATION / movement held; body clock live" if chapter_frame<=IDLE_HOLD_FRAMES else "REAL AI / MOVE AND ACCEPTED HITS" if death_at<0 else "REAL GRAVITY / BOUNCE / WAIT" if not after_death else "REAL APP PICKUP / WALLET AND HP"
	detail.text="%s   |   HP %.0f/%.0f   COINS %s   %.1fs"%[phase,controller.actor_resources.health.current,controller.actor_resources.health.capacity,app.wallet.balance,float(chapter_frame)/60.0]
	if controller.actor_resources.health.terminal:
		failures.append("Player became terminal in chapter "+String(selected_behaviors[chapter]));busy=true;_end_chapter.call_deferred();return
	if (all_claimed and chapter_frame>=CASE_MIN_FRAMES) or chapter_frame>=CASE_MAX_FRAMES:
		busy=true;_end_chapter.call_deferred()

func _capture_post_draw()->void:
	if frames.is_empty() or busy or finished:return
	var row:Dictionary=frames.back()
	if int(row.case)!=chapter:return
	row["rendered_movie_process_frame"]=Engine.get_process_frames()
	row["sampling_phase"]="read-only frame_post_draw confirms preceding process sample"
	postdraw_rows+=1

func _end_chapter()->void:
	app.controller.router.set_source_axis(&"gamepad",0.0)
	var record:Dictionary=chapter_rows[chapter]
	var units:Array[Dictionary]=[]
	for pickup:Dictionary in app.stage.pickups:
		if str(pickup.get("source",""))==sample_id:units.append(pickup)
	var expected:=int(app._enemy_drops.configuration.coin_totals[String(selected_behaviors[chapter])])
	var actual:=int(app.wallet.balance)-chapter_start_wallet
	record["end_frame"]=active_frame_count;record["end_seconds"]=float(Engine.get_process_frames())/60.0
	record["movie_end_process_frame"]=Engine.get_process_frames();record["post_death_observation_frames"]=chapter_frame-death_at if death_at>=0 else 0
	record["configured_coin_total"]=expected;record["actual_wallet_delta"]=actual
	record["final_player_HP"]=app.controller.actor_resources.health.current
	var actual_material_events:Variant=sample_audio.get("material_events") if is_instance_valid(sample_audio) else null
	record["material_events"]=actual_material_events.duplicate(true) if actual_material_events is Array else []
	record["final_units"]=[]
	for pickup:Dictionary in units:record.final_units.append(load("res://scripts/rewards/plains_loot_motion.gd").call("snapshot",pickup))
	record["original_manifest_unchanged"]=current_manifest_text==JSON.stringify(app.stage.generated.manifest)
	var observed:Array[Dictionary]=[]
	var idle_clocks:Array[float]=[]
	var ai_seen:=false
	var moved:=false
	for observation:Dictionary in frames:
		if int(observation.case)!=chapter:continue
		observed.append(observation)
		if bool(observation.idle_hold) and observation.body_clock!=null:idle_clocks.append(float(observation.body_clock))
		if not bool(observation.idle_hold):
			if bool(observation.AI_enabled):ai_seen=true
			if observation.drive!=null and float(observation.drive)>.15:moved=true
	var idle_clock_live:bool=idle_clocks.size()>=40 and idle_clocks.back()-idle_clocks.front()>.5
	var movement_required:bool=selected_behaviors[chapter] not in [&"sentry",&"root_bell"]
	var death_sound_seen:=false
	var hurt_sound_seen:=false
	var land_sound_seen:=false
	for sound:Dictionary in record.material_events:
		if str(sound.event)=="plains_enemy_death":death_sound_seen=true
		if str(sound.event)=="plains_enemy_hurt":hurt_sound_seen=true
		if str(sound.event)=="plains_enemy_land":land_sound_seen=true
	record.coverage={"idle_body_clock":idle_clock_live,"actual_AI_after_idle":ai_seen,"actual_locomotion_or_rooted_species":moved or not movement_required,"material_death":death_sound_seen,"material_hurt":hurt_sound_seen,"material_landing":land_sound_seen,"accepted_nonlethal":hurt_at>=0,"accepted_death":sample_actor.health.terminal and int(record.deaths)==1,"coin_unit_total":actual==expected,"all_spawned_units_claimed":not units.is_empty() and units.all(func(p:Dictionary)->bool:return bool(p.claimed)),"unmodified_generated_manifest":record.original_manifest_unchanged}
	for key:String in record.coverage:
		if not bool(record.coverage[key]):record.coverage_gaps.append(key)
	if not record.coverage_gaps.is_empty():failures.append(String(selected_behaviors[chapter])+": "+",".join(record.coverage_gaps))
	app.abandon_run()
	var drained:bool=await load("res://tests/audio_teardown.gd").drain_world(app)
	teardown_reports.append({"case":chapter,"released":drained})
	if not drained:failures.append("Chapter audio teardown failed")
	app.free();await process_frame;await process_frame
	if not failures.is_empty():finish.call_deferred()
	else:_next_chapter.call_deferred()

func _source_hashes()->Dictionary:
	var paths:Array[String]=["res://tools/plains_motion_loot_02_capture.gd","res://tools/plains_revision_01_comparison.gd","res://scripts/demo/demo_app.gd","res://scripts/demo/generated_demo_stage.gd","res://scripts/art/plains_stage_visual.gd","res://scripts/art/player_feedback.gd","res://scripts/rewards/enemy_drop_service.gd","res://scripts/rewards/plains_loot_motion.gd","res://scripts/audio/game_audio.gd","res://scripts/audio/plains_enemy_audio.gd","res://scripts/enemies/plains_motion_02.gd","res://scripts/enemies/plains_revision_visual.gd","res://scripts/enemies/plains_revision_ground.gd","res://scripts/enemies/plains_revision_flora.gd","res://scripts/enemies/plains_revision_remains.gd","res://scripts/enemies/enemy_feedback_01_remains.gd","res://scripts/enemies/enemy_feedback_01_particles.gd","res://shaders/plains_loot_02.gdshader","res://assets/plains_loot_02/life_orb.png","res://assets/audio/plains_feedback_02/manifest.json","res://config/enemy_drops.json","res://resources/damage/feedback.tres"]
	for behavior:StringName in CHAPTER_BEHAVIORS:paths.append("res://resources/enemies/"+("patrol_drone" if behavior==&"patrol" else "plains_"+String(behavior))+".tres")
	var result:Dictionary={}
	for path:String in paths:result[path]=FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	return result

func finish()->void:
	if finished:return
	finished=true;busy=true
	if process_frame.is_connected(drive):process_frame.disconnect(drive)
	if RenderingServer.frame_post_draw.is_connected(_capture_post_draw):RenderingServer.frame_post_draw.disconnect(_capture_post_draw)
	if is_instance_valid(app):
		app.abandon_run()
		if not await load("res://tests/audio_teardown.gd").drain_world(app):failures.append("Final audio teardown failed")
		app.free();await process_frame
	if chapter_rows.size()!=selected_behaviors.size():failures.append("Requested actual chapters were not completed")
	if selected_behaviors.has(&"root_bell") and not got_heal:failures.append("No real positive player HP grant observed")
	if selected_behaviors.has(&"root_bell") and not root_denominations_ok:failures.append("Root bell exact7=5+1+1 was not observed")
	var after:=_source_hashes();var git_after:=_git_source()
	var stable:bool=source_before==after and git_before==git_after
	if not stable:failures.append("Source changed during capture")
	var gaps:=0
	for item:Dictionary in chapter_rows:gaps+=item.coverage_gaps.size()
	var result:={"task":"PLAINS-MOTION-LOOT-02","kind":"actual_App_staged_review","selected_behaviors":selected_behaviors,"whole_roster":selected_behaviors.size()==CHAPTER_BEHAVIORS.size(),"complete":failures.is_empty(),"seed":seed_label,"entry":"DemoApp.start_plains / disclosed seven-sample review chapters","resolution":[1280,720],"fps":60,"playback_speed":1,"cases":chapter_rows,"frames":frames,"coverage_gap_count":gaps,"failures":failures,"source_before":source_before,"source_after":after,"git_before":git_before,"git_after":git_after,"source_stable":stable,"postdraw_rows":postdraw_rows,"actual_heal_observed":got_heal,"root_7_equals_5_1_1":root_denominations_ok,"audio_teardown":teardown_reports,"not_verified":["natural generated seven-species roster/route","human visual or listening acceptance","physical device performance"]}
	var file:=FileAccess.open(trace_path,FileAccess.WRITE)
	if file==null:printerr("Cannot write review trace");quit(1);return
	file.store_string(JSON.stringify(result,"\t"));file.close()
	await process_frame
	print("PLAINS MOTION LOOT REVIEW: complete; cases=%s; frames=%s; failures=%s"%[chapter_rows.size(),frames.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)

func _label(text_value: String, at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_outline_color",Color("10201d"))
	label.add_theme_constant_override("outline_size",4)
	return label

func _stage_ready() -> bool:
	return is_instance_valid(app) and not app._stage_pending and is_instance_valid(app.stage) and app.stage.get_script().resource_path=="res://scripts/demo/plains_region_stage.gd" and bool(app.stage.get("assembly_ok")) and is_instance_valid(app.player) and is_instance_valid(app.controller) and app._can_interact() and is_instance_valid(app._run_camera)

func _ray(x: float, from_y: float, to_y: float) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(Vector2(x,from_y),Vector2(x,to_y),1,[app.player.get_rid()])
	query.collide_with_areas = false
	return app.player.get_world_2d().direct_space_state.intersect_ray(query)

func _support_record(hit: Dictionary) -> Dictionary:
	var body := hit.collider as StaticBody2D
	var shape_rows: Array[Dictionary] = []
	for child: Node in body.get_children():
		if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
			var collider := child as CollisionShape2D
			shape_rows.append({"path":String(collider.get_path()),"shape_class":collider.shape.get_class(),"world_aabb":_rect(collider.global_transform*collider.shape.get_rect()),"one_way":collider.one_way_collision})
	return {"path":String(body.get_path()),"class":body.get_class(),"point":_vec(hit.position),"normal":_vec(hit.normal),"shape_index":int(hit.shape),"actual_collision_shapes":shape_rows}

func _add_stand_candidate(candidates: Array[Dictionary], seen: Dictionary, x: float, top: float, bottom: float, source: String) -> void:
	if not is_finite(x) or not is_finite(top) or not is_finite(bottom): return
	var key := "%0.2f/%0.2f" % [x,top]
	if seen.has(key): return
	seen[key] = true
	candidates.append({"x":x,"ray_from_y":top-4.0,"ray_to_y":maxf(top+8.0,bottom+4.0),"surface_candidate_y":top,"source":source,"distance_squared_from_original_spawn":Vector2(x,top).distance_squared_to(original_spawn)})

func _add_surface_candidates(candidates: Array[Dictionary], seen: Dictionary, rect: Rect2, source: String) -> void:
	if not rect.has_area(): return
	# Candidate geometry only. Even a large AABB must pass the unchanged real
	# 17-ray support, overhead, SegmentRespawn and danger checks below.
	_add_stand_candidate(candidates,seen,rect.get_center().x,rect.position.y,rect.end.y,source)
	if rect.size.x>=256.0:
		var left := rect.position.x+128.0
		var right := rect.end.x-128.0
		_add_stand_candidate(candidates,seen,clampf(original_spawn.x,left,right),rect.position.y,rect.end.y,source)
		for index: int in ceili((right-left)/64.0)+1:
			_add_stand_candidate(candidates,seen,minf(right,left+index*64.0),rect.position.y,rect.end.y,source)

func _candidate_before(first: Dictionary, second: Dictionary) -> bool:
	if float(first.distance_squared_from_original_spawn)!=float(second.distance_squared_from_original_spawn):
		return float(first.distance_squared_from_original_spawn)<float(second.distance_squared_from_original_spawn)
	if float(first.x)!=float(second.x): return float(first.x)<float(second.x)
	return float(first.surface_candidate_y)<float(second.surface_candidate_y)

func _stand_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for offset: float in [0.0,64.0,128.0,-64.0,192.0,-128.0,256.0,320.0]:
		_add_stand_candidate(candidates,seen,original_spawn.x+offset,original_spawn.y-92.0,original_spawn.y+188.0,"original_spawn_neighborhood")
	for node: Node in app.stage.find_children("*","StaticBody2D",true,false):
		var body := node as StaticBody2D
		if body==null or body.is_queued_for_deletion() or (body.collision_layer & 1)==0: continue
		for child: Node in body.get_children():
			if child is CollisionShape2D:
				var collider := child as CollisionShape2D
				if collider.disabled or collider.shape==null: continue
				var surface: Rect2 = collider.global_transform*collider.shape.get_rect()
				_add_surface_candidates(candidates,seen,surface,String(collider.get_path()))
			elif child is CollisionPolygon2D:
				var polygon := child as CollisionPolygon2D
				if polygon.disabled or polygon.polygon.is_empty(): continue
				var polygon_surface := Rect2(polygon.global_transform*polygon.polygon[0],Vector2.ZERO)
				for point: Vector2 in polygon.polygon: polygon_surface = polygon_surface.expand(polygon.global_transform*point)
				_add_surface_candidates(candidates,seen,polygon_surface,String(polygon.get_path()))
	# Actual manifest geometry provides additional centres where a broad bank
	# is assembled from several narrow bodies. It grants no support by itself.
	var manifest: Dictionary = app.stage.generated.manifest
	for row: Variant in manifest.get("ground_supports",[]):
		if row is Array and row.size()==4:
			_add_surface_candidates(candidates,seen,Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3])),"actual_manifest.ground_supports")
	for row: Variant in manifest.get("nodes",[]):
		if row is Dictionary and row.get("offset") is Array and row.offset.size()==2:
			_add_stand_candidate(candidates,seen,float(row.offset[0]),float(row.offset[1])-92.0,float(row.offset[1])+188.0,"actual_manifest.node/"+str(row.get("id","")))
	candidates.sort_custom(_candidate_before)
	return candidates

func _reject_stand(candidate: Dictionary, reason: String) -> void:
	var receipt := candidate.duplicate()
	receipt["accepted"] = false
	receipt["reason"] = reason
	stand_search.append(receipt)

func _find_stand() -> Dictionary:
	var player_shape := app.player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if player_shape == null or not player_shape.shape is RectangleShape2D: return {}
	var rectangle := player_shape.shape as RectangleShape2D
	var space:PhysicsDirectSpaceState2D = app.player.get_world_2d().direct_space_state
	# A single continuous real shore must carry all three sample positions.
	# No failed search is repaired by moving a platform or inserting geometry.
	for candidate: Dictionary in _stand_candidates():
		var x: float = candidate.x
		var center := _ray(x,float(candidate.ray_from_y),float(candidate.ray_to_y))
		if center.is_empty() or not center.collider is StaticBody2D or (center.normal as Vector2).dot(Vector2.UP)<0.7:
			_reject_stand(candidate,"center ray has no actual standable StaticBody2D")
			continue
		var y: float = center.position.y
		var location := Vector2(x,y-rectangle.size.y*.5-player_shape.position.y)
		if app.segment == null or not app.segment.is_safe(location):
			_reject_stand(candidate,"original SegmentRespawn.is_safe refused actual player shape")
			continue
		var checks: Array[Dictionary] = []
		var continuous := true
		for step: int in range(-128,129,16):
			var hit := _ray(x+step,y-4.0,y+8.0)
			if hit.is_empty() or not hit.collider is StaticBody2D or (hit.normal as Vector2).dot(Vector2.UP)<0.7 or absf(float(hit.position.y)-y)>.5:
				continuous = false
				break
			checks.append(_support_record(hit))
		if not continuous:
			_reject_stand(candidate,"17-ray 256wu continuous same-height static shore refused")
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = RectangleShape2D.new()
		(query.shape as RectangleShape2D).size = Vector2(254,100)
		query.transform = Transform2D(0.0,Vector2(x,y-50.05))
		query.collision_mask = 1
		query.margin = 0.0
		query.exclude = [app.player.get_rid()]
		if not space.intersect_shape(query).is_empty():
			_reject_stand(candidate,"100wu overhead actual shape clearance refused")
			continue
		var safe := true
		var exhibit := Rect2(Vector2(x-128,y-100),Vector2(256,100))
		for danger: Rect2 in app.segment.danger_bounds:
			if danger.intersects(exhibit,true): safe = false
		if not safe:
			_reject_stand(candidate,"original danger bounds intersect 256x100wu exhibit")
			continue
		var accepted := candidate.duplicate()
		accepted["accepted"] = true
		stand_search.append(accepted)
		return {"player_location":location,"floor_y":y,"candidate":candidate,"center":_support_record(center),"continuous_shore_probes":checks,"checks":"17 real layer1 UP rays across256wu +100wu overhead real shape clearance + original SegmentRespawn safe stand/danger bounds"}
	return {}

func _optional(object: Object, key: StringName) -> Variant:
	if object==null: return null
	for row: Dictionary in object.get_property_list():
		if StringName(row.name)==key: return object.get(key)
	return null

func _vec(value: Vector2) -> Array:
	return [value.x,value.y]

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _git_source() -> Dictionary:
	var head_output: Array = []
	var status_output: Array = []
	var working_directory := ProjectSettings.globalize_path("res://")
	var head_exit := OS.execute("git",["-C",working_directory,"rev-parse","HEAD"],head_output,true)
	var status_exit := OS.execute("git",["-C",working_directory,"status","--porcelain"],status_output,true)
	return {"head":String(head_output[0]).strip_edges() if head_exit==0 and not head_output.is_empty() else "unavailable","status":String(status_output[0]) if status_exit==0 and not status_output.is_empty() else "unavailable","head_exit_code":head_exit,"status_exit_code":status_exit}

func _factory(method: StringName, arguments: Array) -> Variant:
	var source: Script = load("res://scripts/enemies/enemy_factory.gd") as Script
	return source.callv(method, arguments)

func _applied(result: Object) -> bool:
	var constants: Dictionary = result.get_script().get_script_constant_map()
	var statuses: Dictionary = constants.get("Status", {})
	return int(result.get("status")) == int(statuses.get("APPLIED", -999))
