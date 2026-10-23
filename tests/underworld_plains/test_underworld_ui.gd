extends SceneTree
## Production UI classes with actual viewport mouse dispatch; no purchase grant,
## campaign traversal, physical device or commercial visual acceptance inferred.
var checks := 0
var failures := 0
var inventory: Array[Dictionary] = []
var capture := "--capture" in OS.get_cmdline_user_args()
var output := "res://build/underworld_plains/ui_rework"
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1;printerr("FAIL: "+message)
func frames(count := 3) -> void:
	for i: int in count: await process_frame
func button(parent: Node, prefix: String) -> Button:
	for node: Node in parent.find_children("*","Button",true,false):
		if (node as Button).text.begins_with(prefix) or str(node.get_meta(&"ui_legacy_prefix", "")).begins_with(prefix): return node
	return null
func click(target: Control) -> void:
	check(target != null,"actual requested button exists")
	if target == null: return
	check(target.is_visible_in_tree(),"actual pointer target is visible, not an old hidden control")
	if not target.is_visible_in_tree(): return
	# Let deferred initial focus settle before scrolling a later button into
	# view; otherwise its pending restore can undo this helper's scroll.
	await frames(4)
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(4)
	var point := target.get_global_rect().get_center()
	check(root.get_visible_rect().has_point(point),"actual button hit center is inside viewport")
	var move := InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
	for pressed: bool in [true,false]:
		var mouse := InputEventMouseButton.new();mouse.position=point;mouse.global_position=point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;Input.parse_input_event(mouse)
		await frames(2)
func observe(id: String, control: Control) -> void:
	var nodes: Array[Dictionary]=[]
	for node: Node in control.find_children("*","Control",true,false):
		if node is Button: nodes.append({"type":"button","text":node.text,"rect":[node.global_position.x,node.global_position.y,node.size.x,node.size.y],"disabled":node.disabled,"font":str(node.get_theme_font("font").resource_path),"fill":node.get_theme_stylebox("normal").bg_color.to_html()})
		if node is Label: nodes.append({"type":"label","text":node.text,"color":node.get_theme_color("font_color").to_html()})
		if node is ProgressBar: nodes.append({"type":"resource_bar","actual_value":node.value,"actual_capacity":node.max_value})
		if node is TextureRect and node.texture!=null:
			var path: String = node.texture.atlas.resource_path if node.texture is AtlasTexture else node.texture.resource_path
			check(not path.begins_with("res://assets/title_home/"),"actual menu contains no old painted logo/background")
	inventory.append({"id":id,"observed_actual_node_tree":true,"window_size":[root.size.x,root.size.y],"logical_viewport_size":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"buttons":nodes})
	if capture:
		await frames(4);await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/"+id+".png")==OK,"actual native UI image saved")
func run() -> void:
	root.size=Vector2i(1280,720);DirAccess.make_dir_recursive_absolute(output)
	var theme := UnderworldUI.create_theme()
	for style: String in ["normal","hover","pressed","disabled","focus"]:
		check(theme.get_stylebox(style,"Button") is StyleBoxFlat,"shared native button state "+style)
	check(theme.get_color("font_color","Label")==UnderworldUI.TEXT,"shared readable light text on ink")
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/underworld_plains/ui/icon_regions.json"))
	var atlas := load("res://"+str(metadata.atlas)) as Texture2D
	check(atlas!=null and metadata.regions.size()==18,"actual generated inventory sheet has eighteen consumers")
	for key: String in metadata.regions:
		var icon := ItemPresentation.icon(StringName(key)) as AtlasTexture
		check(icon!=null and icon.atlas==atlas and icon.filter_clip,"actual complete icon consumer "+key)
		check(Rect2(Vector2.ZERO,atlas.get_size()).encloses(icon.region),"actual icon region in bounds "+key)
	var menu := DemoMenu.new();root.add_child(menu)
	var starts: Array[String]=[];var resumes: Array[int]=[];var leaves: Array[int]=[];var upgrades: Array[int]=[];var patches: Array[Dictionary]=[]
	menu.requested_plains.connect(func(seed: String): starts.append(seed));menu.requested_resume.connect(func():resumes.append(1));menu.requested_home.connect(func():leaves.append(1));menu.requested_upgrade.connect(func():upgrades.append(1));menu.settings_changed.connect(func(patch: Dictionary):patches.append(patch))
	menu.show_title();await frames();await observe("title",menu._root)
	var touch_settings := button(menu._content,"SETTINGS")
	for pressed: bool in [true,false]:
		var tap:=InputEventScreenTouch.new();tap.index=88;tap.position=touch_settings.get_global_rect().get_center();tap.pressed=pressed;Input.parse_input_event(tap);await frames(2)
	check(menu.visible_panel==&"settings","actual native touch activates regular menu control without mouse emulation")
	if menu.visible_panel==&"settings":await click(button(menu._content,"BACK"))
	await click(button(menu._content,"SETTINGS"));check(menu.visible_panel==&"settings","native title mouse opens settings")
	menu._sliders.right_enter_deadzone.value=.2;menu._sliders.right_exit_deadzone.value=.3
	await click(button(menu._content,"APPLY"));check(patches.is_empty() and not menu._settings_error.text.is_empty(),"native invalid settings never submit")
	await click(button(menu._content,"RESTORE DEFAULTS"));check(patches.is_empty(),"restore remains preview")
	await click(button(menu._content,"APPLY"));check(patches.size()==1,"valid native Apply submits one validated settings patch")
	await observe("settings",menu._root);await click(button(menu._content,"BACK"));check(menu.visible_panel==&"title","native settings back returns title")
	await click(button(menu._content,"HOW TO PLAY"));check(menu.visible_panel==&"help","native help opens");await observe("help",menu._root)
	await click(button(menu._content,"BACK"));await click(button(menu._content,"风铃平原"));check(starts==["level-design-v2-baseline/08"] and menu.visible_panel.is_empty(),"original primary entry seed and request preserved")
	menu.show_home_navigation();await frames();await observe("home_navigation",menu._root)
	var text := ""
	for node: Node in menu._content.find_children("*","Button",true,false):text+=node.text
	check(text.contains("MODULE LAB") and text.contains("RANDOM STAGE") and text.contains("3 rooms") and not text.contains("8 rooms"),"current development routes preserved; retired eight-room option absent")
	for service: StringName in [&"character",&"achievements",&"departure",&"upgrade"]:
		menu.set_meta_state({"notes":0,"upgrade_quote":{"level":0,"max_level":3,"price":5,"available":true}});menu.show_home_panel(service);await frames();await observe("home_"+str(service),menu._root)
	menu.set_meta_state({"notes":0,"upgrade_quote":{"level":0,"max_level":3,"price":5,"available":true}});menu.show_home_panel(&"upgrade");await click(button(menu._content,"PERMANENT"));check(upgrades.is_empty(),"actual disabled upgrade rejects native click")
	menu.set_meta_state({"notes":7,"upgrade_quote":{"level":0,"max_level":3,"price":5,"available":true}});menu.show_home_panel(&"upgrade");await click(button(menu._content,"PERMANENT"));await click(button(menu._content,"PERMANENT"));check(upgrades.size()==1,"same UI confirmation cannot submit upgrade twice")
	menu.show_pause();await frames();await observe("pause",menu._root)
	await click(button(menu._content,"RETURN TO HOME"));check(menu.visible_panel==&"confirm_home" and leaves.is_empty(),"leave still asks actual UI confirmation")
	await click(button(menu._content,"KEEP PLAYING"));check(resumes.size()==1 and leaves.is_empty(),"cancel resumes same run without leave")
	menu.show_pause();await click(button(menu._content,"RETURN TO HOME"));await observe("leave_confirmation",menu._root);await click(button(menu._content,"LEAVE RUN"));check(leaves.size()==1,"confirmed native leave emits once")
	menu.hide_home()
	var item: ItemDefinition=load("res://resources/items/jump_blue.tres")
	var offer: RefCounted=load("res://scripts/shops/shop_offer.gd").new();offer.item=item;offer.price=10;offer.stock=1
	var shop:=ItemShopModal.new();root.add_child(shop);var buys:Array[int]=[];shop.purchase_requested.connect(func():buys.append(1))
	shop.show_offer(offer,0,true);await frames();await observe("shop_unaffordable",shop._root);await click(button(shop._root,"BUY"));check(buys.is_empty(),"actual unaffordable shop button rejects click")
	shop.show_offer(offer,10,true);await click(button(shop._root,"BUY"));check(buys.size()==1,"actual affordable button emits original purchase request");await observe("shop",shop._root);shop.close();check(not shop.opened and shop._root==null,"shop close disposes root");shop.show_offer(offer,10,false);check(button(shop._root,"BUY").disabled,"reopened ineligible quote stays disabled");shop.close();shop.free()
	var reward:=StageRewardModal.new();root.add_child(reward);var reward_offer: RefCounted=load("res://scripts/rewards/reward_offer.gd").new();reward_offer.candidates.append(item);reward_offer.candidates.append(load("res://resources/items/damage_blue.tres"));reward.show_offer(reward_offer,"MAP 2");await frames();await observe("reward",reward._root);var choices:Array[StringName]=[];reward.item_selected.connect(func(id:StringName):choices.append(id));await click(button(reward._root,"选择 / PICK"));check(choices==[item.stable_id],"actual reward button preserves accepted stable item ID");reward.close();reward.free()
	var exit:=StageExitModal.new();root.add_child(exit);exit.show_exit("MAP 2","Reward remains owned by gameplay service");await frames();await observe("stage_exit",exit._root);exit.close();exit.free()
	menu.free();await frames(3)
	var app := DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app);await frames(4)
	await click(button(app.menu._content,"风铃平原"));await frames(8)
	check(app.connected_region and app.stage is PlainsRegionStage and app.stage.map_index==1,"native primary title click creates actual formal map1")
	await observe("actual_formal_hud",app._resources_hud)
	# The requested rounded material replaces the old black palette snapshot;
	# keep the original consumer assertion against its effective shared style.
	check(app._pause_button.theme==app._demo_hud._chrome_theme and app._pause_button.get_theme_stylebox("normal").bg_color==DemoClockworkTheme.create_theme().get_stylebox("normal","CompactButton").bg_color,"actual App MENU button consumes shared theme")
	var actual_player := app.player
	var shots: int=app.controller.shoot_ability._shot_serial
	app.controller.router.set_source_axis(&"keyboard_mouse",1.0)
	await click(app._pause_button)
	check(paused and app.menu.visible_panel==&"pause" and app.controller.router.axis==0,"actual pause pointer cancels movement and pauses same world")
	await click(button(app.menu._content,"SETTINGS"));await observe("actual_run_settings",app.menu._root);await click(button(app.menu._content,"BACK"));check(paused,"settings back retains real world pause")
	await click(button(app.menu._content,"YOUR BUILD"));await observe("actual_build",app.menu._root);await click(button(app.menu._content,"BACK"));await click(button(app.menu._content,"RESUME"))
	check(not paused and app.player==actual_player and app.controller.shoot_ability._shot_serial==shots,"resume preserves player and does not emit an old shot")
	await click(app.stage.map_view);check(paused and app.map_modal.opened,"actual minimap pointer opens original fog map")
	var old_zoom: float=app.map_modal.canvas.zoom
	await click(button(app.map_modal._root,"ZOOM +"));check(app.map_modal.canvas.zoom>old_zoom,"actual map zoom button still changes only map projection")
	await observe("actual_fog_map",app.map_modal._root);await click(button(app.map_modal._root,"CLOSE MAP"));check(not paused and not app.map_modal.opened,"actual map close resumes original player")
	app.overlay.set_enabled(true);await frames(4)
	check(app.overlay._safe_rect.encloses(Rect2(app.overlay.jump_center-Vector2.ONE*app.overlay.jump_hit_radius,Vector2.ONE*app.overlay.jump_hit_radius*2)),"real touch hit rectangle stays inside authored safe area")
	var touch:=InputEventScreenTouch.new();touch.index=77;touch.position=app.overlay.jump_center;touch.pressed=true;Input.parse_input_event(touch);await frames(2)
	check(app.overlay._captures.get(77)==&"jump","real touch event captures original jump button index")
	await observe("actual_touch_hud",app._resources_hud)
	var menu_touch:=InputEventScreenTouch.new();menu_touch.index=78;menu_touch.position=app.overlay._pause_rect.get_center();menu_touch.pressed=true;Input.parse_input_event(menu_touch);await frames(3)
	check(paused and app.menu.visible_panel==&"pause" and app.overlay._captures.is_empty(),"actual touch MENU pauses and cancels held touch without stale release")
	menu_touch=InputEventScreenTouch.new();menu_touch.index=78;menu_touch.position=app.overlay._pause_rect.get_center();menu_touch.pressed=false;Input.parse_input_event(menu_touch);await frames(2)
	touch=InputEventScreenTouch.new();touch.index=77;touch.position=app.overlay.jump_center;touch.pressed=false;Input.parse_input_event(touch);await frames(2)
	await click(button(app.menu._content,"RESUME"));check(app.overlay._captures.is_empty(),"resume requires a new touch")
	app.overlay.set_enabled(false)
	for viewport: Vector2i in [Vector2i(960,540),Vector2i(720,1280)]:
		root.size=viewport;await frames(3);app.menu.show_pause();await frames(4)
		for control: Node in app.menu._content.find_children("*","Button",true,false):
			check(root.get_visible_rect().encloses(control.get_global_rect()),"actual small viewport menu buttons fit horizontally and vertically")
		await observe("viewport_"+str(viewport.x)+"x"+str(viewport.y),app.menu._root)
		await click(button(app.menu._content,"RESUME"))
	root.size=Vector2i(1280,720);await frames(3)
	await click(app._pause_button);await click(button(app.menu._content,"RETURN TO HOME"));await click(button(app.menu._content,"LEAVE RUN"));await frames(8)
	check(app.home_scene!=null and app.player==null and not paused,"actual leave confirmation unloads run and returns real Home")
	if app.home_scene!=null:await observe("actual_home_return",app.home_scene._status.get_parent())
	else:app.abandon_run();await frames(8)
	if not await load("res://tests/audio_teardown.gd").drain_world(app):check(false,"actual App audio teardown drains")
	app.free();item=null;offer=null;reward_offer=null;atlas=null;theme=null;await frames(4)
	var file:=FileAccess.open(output+"/ui_inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify({"schema":"underworld-ui-actual-inventory-v1","checks":checks,"failures":failures,"actual_mouse_dispatch":true,"capture":capture,"consumers":inventory,"scope":"Native UI class entry/click/disabled/quote/settings/close fixture. No economic settlement, campaign traversal, web or physical-device claim."},"  "));file.close()
	# Finish only after this async scope (including typed quote locals) returns.
	# The engine guard remains strict; no ObjectDB/resource warning is ignored.
	finish.call_deferred()
func finish() -> void:
	await frames(6)
	print("UNDERWORLD UI: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
