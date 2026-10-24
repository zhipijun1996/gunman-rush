extends SceneTree
var checks:=0
var failures:=0
var app: DemoApp
var records: Array[Dictionary]=[]
var output:="res://build/underworld_home/"
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func frames(count: int) -> void:
	for i: int in count: await physics_frame
func walk_to(home: HomeScene,target: float) -> void:
	var ticks:=0
	while absf(home.player.position.x-target)>5 and ticks<1100:
		home.controller.router.set_source_axis(&"keyboard_mouse",signf(target-home.player.position.x))
		await physics_frame
		ticks+=1
	home.controller.router.set_source_axis(&"keyboard_mouse",0)
	await frames(3)
	check(absf(home.player.position.x-target)<10,"Actual Motor walks to socket %.0f"%target)
func capture(home: HomeScene,id: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():return
	home.camera.force_update_scroll()
	await process_frame
	await RenderingServer.frame_post_draw
	var path:=output+id+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"Actual Home GPU image "+id)
func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://scenes/demo/demo.tscn").instantiate() as DemoApp
	app.meta_persistence_enabled=false
	root.add_child(app)
	await frames(3)
	app.menu.requested_enter_home.emit()
	await frames(8)
	var home:=app.home_scene
	check(is_instance_valid(home),"Real TITLE→HOME consumer exists")
	check(home.player.get_node_or_null("UnderworldPlayer") is UnderworldPlayer,"Shared actual player presentation installed")
	check(not home.player.get_node("CourierVisual").visible and not home.player.get_node("PlayerFeedback").visible,"Legacy body and feedback drawings are hidden")
	check(home.player.get_node("PlayerVisualAdapter").process_mode==Node.PROCESS_MODE_DISABLED,"Legacy visual adapter cannot redraw a second body")
	var anchor:=home.player.get_node("CourierVisual") as CourierVisual
	check(anchor.is_node_ready() and anchor.visible_muzzle_position().is_finite(),"Hidden authoritative muzzle node remains live and finite")
	var body_count:=0
	for child: Node in home.player.get_children():
		if child is UnderworldPlayer:body_count+=1
	check(body_count==1,"Exactly one actual Underworld player body is installed")
	check(home.world.terrain.core_layer.get_used_cells().size()>100,"Native real TileMapLayer ground is populated")
	check(home.world.specification.slots.size()==12,"Four legacy functions and eight future sockets exist")
	var snapshot:=app.meta.snapshot()
	var ids: Array[StringName]=[]
	home.requested_interaction.connect(func(id: StringName) -> void:ids.append(id))
	for entry: Dictionary in home.world.specification.slots:
		await walk_to(home,float(entry.x))
		check(home.player.is_on_floor(),"Socket is reachable on safe ground "+str(entry.id))
		var expected:=StringName(entry.id) if bool(entry.active) else &""
		check(home.nearest_id==expected,"Only implemented function IDs are actionable "+str(entry.id))
		var count:=ids.size()
		home.controller.router.request_action(&"interact")
		await frames(3)
		if bool(entry.active):
			check(ids.size()==count+1 and ids[-1]==expected,"Router delivers exact original interaction ID")
			check(home.input_blocked and app.menu.visible_panel==&"home_function","Real function panel owns input")
			app.menu.close_panel()
			await frames(3)
			check(not home.input_blocked and home.controller.router.axis==0,"Panel closes without replaying movement")
		else:
			check(ids.size()==count and not home.input_blocked,"Reserved socket cannot open or fabricate a function")
			check(home._prompt.text.contains("预留") and home.world.slot_nodes[str(entry.id)].text.contains("预留"),"Reserved status is explicit in world and context")
		records.append({"slot":entry.id,"position":[home.player.position.x,home.player.position.y],"expected_action":str(expected),"reserved":not bool(entry.active),"camera":[home.camera.get_screen_center_position().x,home.camera.get_screen_center_position().y]})
		if str(entry.id) in ["upgrade","relics","garden"]:await capture(home,str(entry.id))
	check(app.meta.snapshot()==snapshot,"Visiting all sockets does not create currency or upgrades")
	var rays: Array[Dictionary]=[]
	for child: Node in home.world.get_children():
		if not child is Sprite2D or not child.has_meta("home_root"):continue
		var foot: Vector2=child.get_meta("home_root")
		var hit:=home.player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,2),1))
		check(not hit.is_empty() and hit.collider is StaticBody2D,"Actual world sprite root reaches real static floor "+str(child.name))
		rays.append({"node":str(child.name),"foot":[foot.x,foot.y],"static":not hit.is_empty() and hit.collider is StaticBody2D})
	var layers:=home.parallax.measured_nodes()
	check(layers.size()==3,"Three original independent parallax sources are active")
	check(layers[0].camera_coefficient!=layers[1].camera_coefficient and layers[1].camera_coefficient!=layers[2].camera_coefficient,"Three actual camera rates remain distinct")
	await walk_to(home,110)
	check(home.camera.get_screen_center_position().x<=641,"Camera returns to western safe square")
	if "--capture" in OS.get_cmdline_user_args():await capture(home,"returned_west")
	var f:=FileAccess.open(output+"receipt.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema":"underworld-home-actual-consumer-v1","checks":checks,"failures":failures,"slots":records,"roots":rays,"layers":layers,"future_function_grants":false,"navigation_contract":"Five active services including the authored arms workshop, real panels; original home_app_runner additionally covers departure, upgrade and save baseline"},"\t"));f.close()
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"Actual Home audio must release before teardown")
	app.queue_free()
	await frames(5)
	print("UNDERWORLD HOME: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
