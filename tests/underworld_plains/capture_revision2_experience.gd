extends SceneTree
## Final-source actual App input evidence. No pose/resource injection or teleports.
var app: DemoApp
var mode:="formal"
var output:="res://build/underworld_revision2_experience/trace.json"
var seed:="level-design-v2-baseline/08"
var rows: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var slots: Array[Dictionary]=[]
var failures: Array[String]=[]
var checks:=0
var held: Dictionary={}
var pointer:=Vector2.ZERO
var seen: Dictionary={}
var right_frames: Dictionary={}
var left_frames: Dictionary={}
var animation_build: Dictionary
var initialization: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)
func json_value(value: Variant) -> Variant:
	if value is Vector2:return [value.x,value.y]
	if value is Dictionary:
		var result: Dictionary={}
		for key: Variant in value:result[str(key)]=json_value(value[key])
		return result
	if value is Array:
		var result: Array=[]
		for item: Variant in value:result.append(json_value(item))
		return result
	return value
func actor() -> PlayerMotor:
	return app.home_scene.player if is_instance_valid(app.home_scene) else app.player
func control() -> PlayerController:
	return app.home_scene.controller if is_instance_valid(app.home_scene) else app.controller
func artwork(body: PlayerMotor) -> UnderworldPlayer:
	if not is_instance_valid(body):return null
	for child: Node in body.get_children():
		if child is UnderworldPlayer:return child
	return null
func key(code: Key,pressed: bool) -> void:
	if bool(held.get(code,false))==pressed:return
	held[code]=pressed
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	events.append({"kind":"InputEventKey","key":OS.get_keycode_string(code),"pressed":pressed,"trace_row":rows.size(),"physics_frame":Engine.get_physics_frames()})
func aim_right() -> void:
	var body:=actor()
	if not is_instance_valid(body):return
	var anchor:=body.get_node("CourierVisual") as CourierVisual
	pointer=body.get_canvas_transform()*(anchor.visible_muzzle_position()+Vector2(500,0))
	var motion:=InputEventMouseMotion.new()
	motion.position=pointer
	motion.global_position=pointer
	motion.relative=Vector2(1,0)
	Input.parse_input_event(motion)
func mouse_button(pressed: bool) -> void:
	var click:=InputEventMouseButton.new()
	click.position=pointer
	click.global_position=pointer
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=pressed
	Input.parse_input_event(click)
	events.append({"kind":"InputEventMouseButton","pressed":pressed,"position":[pointer.x,pointer.y],"trace_row":rows.size()})
func ticks(phase: String,count: int) -> void:
	for i: int in count:
		aim_right()
		await physics_frame
		await RenderingServer.frame_post_draw
		observe(phase)
func observe(phase: String) -> void:
	var sample: Dictionary={"phase":phase,"row":rows.size(),"drawn_frames":Engine.get_frames_drawn(),"physics_frame":Engine.get_physics_frames(),"time_scale":Engine.time_scale,"menu_panel":str(app.menu.visible_panel),"tree_paused":paused}
	var body:=actor()
	if is_instance_valid(body):
		var ctl:=control()
		var art:=artwork(body)
		var foot:=body.global_position+Vector2(0,18)
		var hit:=body.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
		var receipt:=art.animation_receipt() if art!=null else {}
		sample.merge({"motor_position":body.global_position,"motor_velocity":body.velocity,"normal_velocity":body.normal_velocity,"motion_steps":body.motion_steps,"grounded":body.is_on_floor(),"collision_foot":foot,"floor_collider":str(hit.collider.get_path()) if not hit.is_empty() else "","health":ctl.actor_resources.health.current,"health_capacity":ctl.actor_resources.health.capacity,"shots_serial":ctl.shoot_ability._shot_serial,"energy":ctl.actor_resources.stamina.current,"router_axis":ctl.router.axis,"aim":ctl.router.aim_direction,"router_epoch":ctl.router.epoch,"animation":receipt})
		if not receipt.is_empty():
			seen[str(receipt.state)]=true
			if str(receipt.state)=="run":
				if float(receipt.facing)>0:right_frames[int(receipt.frame_index)]=true
				else:left_frames[int(receipt.frame_index)]=true
			var frame_list: Array=[]
			for frame: Dictionary in animation_build.frames:
				if str(frame.state)==str(receipt.state):frame_list.append(frame)
			var frame: Dictionary=frame_list[int(receipt.frame_index)]
			var bounds: Array=frame.opaque_bounds
			var pivot: Array=animation_build.anchor
			var factor:=UnderworldActors.HUMANOID_HEIGHT/float(animation_build.standing_body_source_height)
			sample["opaque_body_lowest_y_world"]=body.global_position.y+18+(float(bounds[3])-float(pivot[1]))*factor
			sample["visible_muzzle_matches_authority"]=receipt.muzzle_world==(body.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
		var camera:=body.get_viewport().get_camera_2d()
		if camera!=null:sample["camera_center"]=camera.get_screen_center_position()
		var planes:=app.home_scene.parallax if is_instance_valid(app.home_scene) else app.get_node_or_null("PixelPlainsParallax") as UnderworldParallax
		if planes!=null:sample["layers"]=planes.measured_nodes()
		if is_instance_valid(app.home_scene):
			sample["nearest_id"]=str(app.home_scene.nearest_id)
			sample["reserved_id"]=app.home_scene.reserved_id
			sample["input_blocked"]=app.home_scene.input_blocked
	rows.append(json_value(sample))
func click_named(text: String) -> bool:
	for candidate: Node in app.menu.find_children("*","Button",true,false):
		var button:=candidate as Button
		if button.text!=text or not button.is_visible_in_tree() or button.disabled:continue
		pointer=button.get_global_rect().get_center()
		var motion:=InputEventMouseMotion.new();motion.position=pointer;motion.global_position=pointer;motion.relative=Vector2(1,0);Input.parse_input_event(motion)
		mouse_button(true)
		await physics_frame
		await RenderingServer.frame_post_draw
		observe("pointer_press_"+text)
		mouse_button(false)
		await ticks("pointer_release_"+text,3)
		return true
	return false
func check_body(body: PlayerMotor) -> void:
	check(artwork(body)!=null,"actual consumer installs new shared body")
	check(not body.get_node("CourierVisual").visible and not body.get_node("PlayerFeedback").visible,"old drawings hidden, no double-body compositing")
	check(body.get_node("PlayerVisualAdapter").process_mode==Node.PROCESS_MODE_DISABLED,"old visual adapter disabled")
	var anchor:=body.get_node("CourierVisual") as CourierVisual
	check(anchor.is_node_ready() and anchor.visible_muzzle_position().is_finite(),"authoritative muzzle remains live")
func walk_home(target: float,phase: String) -> void:
	var count:=0
	while is_instance_valid(actor()) and absf(actor().position.x-target)>5 and count<1000:
		key(KEY_D,actor().position.x<target)
		key(KEY_A,actor().position.x>target)
		await ticks(phase,1)
		count+=1
	key(KEY_D,false);key(KEY_A,false)
	await ticks(phase+"_neutral",4)
	check(is_instance_valid(actor()) and absf(actor().position.x-target)<12,"actual keyboard Motor reaches "+phase)
func formal() -> void:
	initialization={"operation":"ordinary DemoApp.start_plains(seed)","root_seed":seed,"initial_position_assignment":false,"direct_pose_or_resource_assignment":false}
	check(app.start_plains(seed),"ordinary formal entry starts one real run")
	await ticks("formal_entry_settle",45)
	if not is_instance_valid(actor()) or not app.stage is PlainsRegionStage:
		check(false,"real formal consumer did not load");return
	var stage:=app.stage as PlainsRegionStage
	check_body(actor())
	var initial_health:=control().actor_resources.health.current
	control().shoot_ability.shot_fired.connect(func(direction: Vector2,id: int) -> void:events.append({"kind":"accepted_shot","direction":[direction.x,direction.y],"id":id,"trace_row":rows.size()}))
	# Find the nearest existing wide tutorial bank. Reach it from natural spawn
	# through real D/Space input, with an actual floor ray to trigger the first gap.
	var bank:=Rect2()
	for slab: Rect2 in PlainsRegionScenery.solid_supports(stage):
		if slab.size.x<299 or absf(slab.position.y-(stage.spawn.y+18))>1 or slab.position.x<stage.spawn.x:continue
		if bank.size==Vector2.ZERO or slab.position.x<bank.position.x:bank=slab
	check(bank.size.x>=299,"existing nearest wide bank is available")
	if bank.size.x<299:return
	var target:=bank.position.x+195
	initialization["natural_spawn"]=json_value(stage.spawn)
	initialization["actual_bank"]=json_value([bank.position.x,bank.position.y,bank.size.x,bank.size.y])
	initialization["driver_policy"]="D from natural spawn; actual floor lookahead ray and held Space over first gap; no reset/teleport"
	var count:=0
	var jump_ticks:=0
	key(KEY_D,true)
	while is_instance_valid(actor()) and actor().position.x<target and count<300:
		var body:=actor()
		var ahead:=body.global_position+Vector2(28,18)
		var ray:=body.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(ahead-Vector2(0,2),ahead+Vector2(0,24),1))
		if body.is_on_floor() and ray.is_empty() and jump_ticks==0:
			key(KEY_SPACE,true);jump_ticks=14
		if jump_ticks>0:
			jump_ticks-=1
			if jump_ticks==0:key(KEY_SPACE,false)
		await ticks("formal_natural_approach",1)
		count+=1
	key(KEY_D,false);key(KEY_SPACE,false)
	await ticks("formal_bank_idle",35)
	check(is_instance_valid(actor()) and absf(actor().position.x-target)<15 and actor().is_on_floor(),"natural keyboard route reaches supported bank")
	if not is_instance_valid(actor()):return
	key(KEY_D,true);await ticks("formal_run_D_aim_right",20);key(KEY_D,false)
	await ticks("formal_neutral_after_D",30)
	key(KEY_A,true);await ticks("formal_run_A_aim_right",26);key(KEY_A,false)
	await ticks("formal_neutral_after_A",30)
	check(artwork(actor()).facing<0 and control().router.aim_direction.x>.98,"body faces left while independent actual mouse aim stays right")
	var shots:=control().shoot_ability._shot_serial
	mouse_button(true);await ticks("formal_ground_shot_press",3);mouse_button(false)
	await ticks("formal_ground_shot_release_recoil",45)
	check(control().shoot_ability._shot_serial==shots+1,"actual pointer release fires one accepted shot")
	check(actor().is_on_floor(),"real ground shot finishes on unchanged bank")
	key(KEY_SPACE,true);await ticks("formal_space_jump_hold",14);key(KEY_SPACE,false)
	await ticks("formal_jump_fall_and_land",90)
	check(actor().is_on_floor(),"Space jump returns to real ground")
	check(control().actor_resources.health.current==initial_health,"nearby actual route has no health loss")
	for state: String in ["idle","run","rise","fall","land"]:check(seen.has(state),"actual formal state observed "+state)
	check(right_frames.size()==8 and left_frames.size()==8,"actual formal left and right run visit all eight authored frame indices")
func home() -> void:
	initialization={"operation":"real TITLE ENTER HOME pointer click","initial_position_assignment":false,"direct_pose_or_resource_assignment":false}
	check(await click_named("ENTER HOME"),"visible ordinary title Home button receives pointer")
	await ticks("home_entry_settle",30)
	if not is_instance_valid(app.home_scene):check(false,"ordinary Home entry failed");return
	check_body(actor())
	var snapshot:=app.meta.snapshot()
	var requests: Array[StringName]=[]
	app.home_scene.requested_interaction.connect(func(id: StringName) -> void:requests.append(id))
	for slot: Dictionary in app.home_scene.world.specification.slots:
		await walk_home(float(slot.x),"home_walk_"+str(slot.id))
		var old_count:=requests.size()
		key(KEY_W,true);await ticks("home_W_"+str(slot.id),2);key(KEY_W,false)
		await ticks("home_service_"+str(slot.id),20)
		if bool(slot.active):
			check(requests.size()==old_count+1 and requests[-1]==StringName(slot.id),"actual W opens original function "+str(slot.id))
			check(app.home_scene.input_blocked and app.menu.visible_panel==&"home_function","function panel owns real Home input")
			check(await click_named("BACK TO HOME"),"actual pointer closes Home service")
			await ticks("home_service_closed_"+str(slot.id),10)
			check(not app.home_scene.input_blocked,"fresh Home input resumes")
		else:
			check(requests.size()==old_count and not app.home_scene.input_blocked,"actual W cannot activate reserved "+str(slot.id))
			check(app.home_scene._prompt.text.contains("尚未开放"),"reserved socket is explicit to player")
		slots.append({"id":slot.id,"reserved":not bool(slot.active),"actual_position":json_value(actor().position),"new_function_requests":requests.size()-old_count,"trace_row":rows.size()})
	check(app.meta.snapshot()==snapshot,"ordinary Home services/reserved visits do not fabricate progression")
	await walk_home(110,"home_full_return_west")
	check(app.home_scene.camera.get_screen_center_position().x<=641,"real camera returns west after full settlement walk")
	await ticks("home_returned_west_idle",45)
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--experience="):mode=argument.trim_prefix("--experience=")
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
		if argument.begins_with("--seed="):seed=argument.trim_prefix("--seed=")
	root.size=Vector2i(1280,720)
	animation_build=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/player_animation/animation_build.json"))
	app=preload("res://game/application/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false
	root.add_child(app)
	await ticks("ordinary_title_boot",45)
	if mode=="formal":await formal()
	elif mode=="home":await home()
	else:check(false,"unknown capture mode")
	for code: Variant in held.keys():key(code,false)
	await ticks("final_neutral",8)
	var data: Dictionary={"schema":"underworld-revision2-actual-experience-v1","mode":mode,"checks":checks,"failures":failures,"initialization":initialization,"input_events":events,"slots":slots,"frames":rows,"seen_states":seen.keys(),"right_run_indices":right_frames.keys(),"left_run_indices":left_frames.keys(),"input_policy":"actual Input.parse_input_event keyboard/mouse; ordinary DemoApp consumers, ordinary KeyboardMouseAdapter enabled; no teleports, input adapter disabling, pose injection, extra resource or physics edits","media_policy":"60fps normal simulation/playback via MovieMaker; software GPU is not device FPS; Dummy output audio not listening acceptance; no live PNG readbacks during input"}
	var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"actual App audio teardown must release")
	app.queue_free()
	for i: int in 5:await process_frame
	print("REVISION2 EXPERIENCE: ",mode," ",rows.size()," frames, ",checks," assertions, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
