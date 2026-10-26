extends SceneTree
const DRIVER=preload("res://tests/underworld_plains/home_terrace_driver.gd")
var checks:=0
var failures:=0
var app: DemoApp
var driver: HomeTerraceDriver
var visits: Array[Dictionary]=[]
var requests: Array[StringName]=[]
var output:="res://build/underworld_r3/home/"
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error(message)
func frames(count: int) -> void:
	for tick: int in count:await physics_frame
func find_button(node: Node,text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and (str(node.name)==text or node.text.begins_with(text)):return node
	for child: Node in node.get_children():
		var found:=find_button(child,text)
		if found!=null:return found
	return null
func click(text: String) -> bool:
	var button:=find_button(app.menu,text)
	check(button!=null,"Actual visible UI button "+text)
	if button==null:return false
	var point:=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion)
	await frames(2)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;Input.parse_input_event(event);await frames(2)
	return true
func capture(id: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+id+".png")==OK,"Native GPU "+id)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size=Vector2i(1280,720)
	app=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false
	# Explicit economic test fixture, inherited from the original Home App
	# business test. This grants no movement ability and is not production input.
	app.meta.grant_notes(9,&"home_terrace_economy_fixture")
	root.add_child(app)
	await frames(8)
	await click("ContinueAdventure")
	await click("ChooseExistingProfile")
	await frames(8)
	var home:=app.home_scene
	check(is_instance_valid(home),"Actual TITLE Continue and existing-profile pointers enter current default Home")
	if home==null:quit(1);return
	driver=DRIVER.new(home)
	home.requested_interaction.connect(func(id: StringName) -> void:requests.append(id))
	check(app.player==null and app.wallet==null and not app.lifetime.active,"Home remains separate from Run economy and lifetime")
	check(home.world.specification.schema=="underworld-home-v2-terraces","Actual consumer uses new authorized spatial contract")
	check(home.world.specification.slots.size()==12 and home.world.specification.slots.filter(func(entry: Dictionary) -> bool: return bool(entry.active)).size()==5,"Twelve original stations remain, with the authored arms workshop now the fifth functional service")
	check(home.controller.jump_ability.maximum_jumps()==1 and home.player.tuning.max_jumps==1,"Route uses actual basic single jump, no future movement grants")
	check(home.world.terrain.core_layer.get_used_cells().size()>100,"Actual native TileMapLayer remains populated")
	check(home.player.get_node_or_null("UnderworldPlayer")!=null and not home.player.get_node("CourierVisual").visible,"One current player presentation, legacy body hidden")
	# Preserve the independent R2 presentation guards. Mere node existence does
	# not prove the old body/adapter is inactive or the authority muzzle is live.
	check(home.player.get_node_or_null("UnderworldPlayer") is UnderworldPlayer and home.player.get_node("UnderworldPlayer") is PlayerMotionCandidateVisual and home.avatar_selection_id=="courier" and app.avatar_selection_id=="courier","Actual shared presentation is the current new Courier default")
	var default_body:=home.player.get_node("UnderworldPlayer") as PlayerMotionCandidateVisual
	var motion:=home.player.get_node_or_null("MotionFeel") as PlayerMotionFeel
	check(not home.player.get_node("PlayerFeedback").visible and motion!=null and motion.visual==default_body and motion.is_processing() and default_body!=null and default_body.candidate_enabled and default_body.profile!=null and default_body.profile.valid() and default_body.profile.resource_path=="res://resources/player_presentation_01/motion_v1.tres","Legacy feedback remains hidden while actual new-default MotionFeel/profile is active")
	check(home.player.get_node("PlayerVisualAdapter").process_mode==Node.PROCESS_MODE_DISABLED,"Legacy adapter cannot draw a duplicate body")
	var muzzle_owner:=home.player.get_node("CourierVisual") as CourierVisual
	check(muzzle_owner.is_node_ready() and muzzle_owner.visible_muzzle_position().is_finite() and default_body!=null and default_body.motor==home.player and default_body.controller==home.controller and default_body.visible and default_body.is_processing(),"Hidden authoritative muzzle remains ready and finite")
	var body_count:=0
	for child: Node in home.player.get_children():
		if child is UnderworldPlayer:body_count+=1
	check(body_count==1 and home.player.get_node_or_null("SelectedAvatarBody")==null,"Exactly one shared new-default player body is installed")
	for platform: Dictionary in home.world.specification.platforms:
		var body:=home.get_node_or_null(NodePath(str(platform.id))) as StaticBody2D
		var shape:=body.get_node_or_null("CollisionShape2D") as CollisionShape2D if body!=null else null
		check(body!=null and body.is_in_group("one_way_platform") and shape!=null and shape.one_way_collision,"Actual declared terrace uses native one-way collision "+str(platform.id))
	var before:=app.meta.snapshot()
	var purchase_done:=false
	for entry: Dictionary in home.world.specification.slots:
		var id:=StringName(entry.id)
		var slot_meta_before:=app.meta.snapshot()
		check(await driver.reach(id),"Actual keyboard/Motor reaches "+str(id))
		var foot:=home.slot_world_foot(id)
		check(home.player.is_on_floor() and absf(home.player.position.y+18-foot.y)<4 and absf(home.player.position.x-foot.x)<9,"Feet rest on correct actual tier "+str(id))
		check(home.nearest_candidate(Vector2(foot.x,foot.y-18))==(id if bool(entry.active) else &""),"Active ID belongs to actual slot layer "+str(id))
		if foot.y<HomeScene.FLOOR_Y:
			check(home.nearest_candidate(Vector2(foot.x,HomeScene.FLOOR_Y-18)).is_empty(),"Upstairs function cannot be selected from ground below "+str(id))
		var count:=requests.size()
		driver.key(KEY_W,true);await driver.frames(2);driver.key(KEY_W,false);await driver.frames(2)
		if bool(entry.active):
			check(requests.size()==count+1 and requests[-1]==id,"Real W delivers exact existing ID "+str(id))
			check(home.input_blocked and app.menu.visible_panel==&"home_function","Actual App panel takes input "+str(id))
			check(home.controller.router.axis==0 and home.player.normal_velocity==Vector2.ZERO,"Panel clears original movement "+str(id))
			if id==&"upgrade":
				check(app.meta.snapshot()==slot_meta_before,"Upgrade travel and opening the panel cannot alter any Meta field before legal purchase")
				var position_before:=home.player.position
				await click("PERMANENT VITALITY")
				await frames(3)
				check(app.meta.snapshot().notes==4 and app.meta.snapshot().upgrades.vitality==1,"Native purchase uses actual permanent wallet, original five-note price")
				check(home.player.position==position_before and home.input_blocked,"Purchase does not recreate or move Home player")
				var paid:=app.meta.snapshot()
				await click("PERMANENT VITALITY")
				check(app.meta.snapshot()==paid,"Repeat click on consumed quote is idempotent")
				purchase_done=true
			await capture("panel_"+str(id))
			await click("BACK TO HOME")
			await driver.frames(3)
			check(not home.input_blocked and home.controller.router.axis==0,"Close returns current Home without replay "+str(id))
		else:
			check(requests.size()==count and not home.input_blocked,"Reserved station emits no fake function "+str(id))
			check(home.reserved_id==str(id) and home._prompt.text.contains("预留"),"Reserved status matches actual tier "+str(id))
			check(home.world.slot_nodes[str(id)].text.contains("预留"),"World label also explicitly marks reserved station "+str(id))
		var slot_meta_after:=app.meta.snapshot()
		if id!=&"upgrade":
			check(slot_meta_after==slot_meta_before,"Visiting and interacting cannot alter any Meta field "+str(id))
		visits.append({"id":str(id),"foot":[foot.x,foot.y],"position":[home.player.position.x,home.player.position.y],"floor":home.player.is_on_floor(),"expected_action":str(id) if bool(entry.active) else "","tick":driver.ticks,"meta_before":slot_meta_before,"meta_after":slot_meta_after})
		if id in [&"upgrade",&"achievements",&"courier",&"departure"]:await capture("station_"+str(id))
	check(purchase_done,"Economic regression reached original actual upgrade consumer")
	check(app.meta.snapshot().notes==4 and app.meta.snapshot().upgrades.vitality==1 and app.meta.snapshot().profile_revision==int(before.profile_revision)+1,"All other visits/reserved clicks grant and spend nothing")
	# Actual airborne W is rejected, even when crossing the character's x.
	check(await driver.reach(&"character"),"Keyboard returns west to original character business")
	var airborne_count:=requests.size()
	driver.key(KEY_SPACE,true);await driver.frames(4);driver.key(KEY_W,true);await driver.frames(2);driver.key(KEY_W,false);driver.key(KEY_SPACE,false);await driver.frames(38)
	check(requests.size()==airborne_count and not home.input_blocked,"Airborne W cannot accidentally open service")
	check(await driver.drop_to_floor(),"Actual S exits platforms to safe ground")
	check(await driver.walk_to(110),"Whole village route returns to western spawn using real keyboard")
	check(home.camera.get_screen_center_position().x<=641,"Actual camera returns to western limit")
	await capture("returned_west")
	var roots: Array[Dictionary]=[]
	for sprite: Node in home.world.get_children():
		if not sprite is Sprite2D or not sprite.has_meta("home_root"):continue
		var foot: Vector2=sprite.get_meta("home_root")
		var hit:=home.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1))
		check(not hit.is_empty() and hit.collider is StaticBody2D,"Root has true static platform support "+str(sprite.name))
		roots.append({"id":str(sprite.name),"foot":[foot.x,foot.y],"static":not hit.is_empty() and hit.collider is StaticBody2D})
	var layers:=home.parallax.measured_nodes()
	check(layers.size()==3 and layers[0].camera_coefficient!=layers[1].camera_coefficient and layers[1].camera_coefficient!=layers[2].camera_coefficient,"Three independent real layers retain three camera rates")
	check(await driver.reach(&"departure"),"Actual walking follows east road through exit landmark")
	check(home.world.get_node_or_null("DepartureRoadDirection")!=null and home.slot_world_foot(&"departure").x>float(home.world.specification.departure_road.from_x),"Departure is beyond settlement at real outgoing road")
	driver.key(KEY_W,true);await driver.frames(2);driver.key(KEY_W,false);await driver.frames(2)
	check(home.input_blocked and app.menu.visible_panel==&"home_function","Existing departure confirmation is still authoritative")
	driver.release_all()
	var route_trace:=driver.trace.duplicate(true)
	var route_events:=driver.events.duplicate(true)
	var route_errors:=driver.errors.duplicate()
	var health_safe:=true
	var single_jump:=true
	var tiers: Dictionary={}
	for sample: Dictionary in route_trace:
		health_safe=health_safe and int(sample.hp)==5
		single_jump=single_jump and int(sample.jumps)<=1
	for visit: Dictionary in visits:tiers[int(visit.foot[1])]=true
	check(health_safe,"Every recorded travel frame preserves original five HP")
	check(single_jump,"Every recorded travel frame uses at most the original single jump")
	check(tiers.size()==3,"Actual visits occupy ground plus two distinct airborne service tiers")
	await click("BEGIN / WINDCHIME PLAINS")
	await frames(12)
	check(app.generated_plains and app.director.stage_index==1 and app.home_scene==null and is_instance_valid(app.player),"Actual departure button creates one formal run and unloads Home")
	check(app.controller.actor_resources.health.capacity==6 and app.wallet.balance==0,"Fresh Run gets real permanent baseline and fresh wallet")
	check(not app.start_plains("duplicate-terrace-departure"),"Repeated departure cannot create another Run")
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;Input.parse_input_event(escape);await frames(3);escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=false;Input.parse_input_event(escape);await frames(2)
	check(app.menu.visible_panel==&"build","Actual Escape pauses the new formal run")
	await click("PausePage")
	await click("LeaveAdventure")
	check(app.menu.visible_panel==&"confirm_home","Original destructive return requires confirmation")
	await click("LEAVE RUN")
	await frames(12)
	check(is_instance_valid(app.home_scene) and app.player==null and app.director.state==DemoRunDirector.State.HOME,"Confirmed return creates exactly actual Home")
	check(app.home_scene.controller.actor_resources.health.capacity==6 and app.meta.snapshot().notes==4,"Return preserves actual permanent progress and fresh health baseline")
	check(route_errors.is_empty(),"No hidden driver reachability failures")
	var file:=FileAccess.open(output+"receipt.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":"underworld-home-terraces-v1","checks":checks,"failures":failures,"visits":visits,"roots":roots,"layers":layers,"events":route_events,"trace":route_trace,"driver_errors":route_errors,"fixture_notes":9,"fixture_notes_reason":"original Home App economic fixture; no movement/resource grants during travel","source":"current actual default App/Home/InputSetup/Router/Motor; root Source binding records exact owned hashes","legacy_replay":"tests/fixtures/underworld_home_r2/replay.json","gaps":["GPU dynamic review and physical device remain separate","all routes use basic single jump, no shots/grapple/wall-jump/teleport"]},"\t"));file.close()
	driver=null
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"Actual App audio releases before teardown")
	app.queue_free();await frames(6)
	print("UNDERWORLD HOME TERRACES: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
