extends SceneTree
## Explicit station access fixture isolates real GUI touches; normal route is tested separately.
var app: FixedWorldApp
var failures:=0
var checks:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	print("UI CHECK ",ok," ",label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func touch_button(button: Button,cancelled: bool=false) -> void:
	await ticks(3)
	if app.ui.shell!=null: app.ui.shell.scroll.ensure_control_visible(button)
	await ticks(3)
	var point:=button.get_global_transform_with_canvas()*(button.size/2)
	print("TOUCH ",button.text," ",point," rect=",button.get_global_rect()," window=",root.size)
	for down: bool in [true,false]:
		var event:=InputEventScreenTouch.new()
		event.index=4;event.pressed=down;event.position=point
		event.canceled=cancelled and not down
		root.push_input(event,true)
		await ticks(3)
func find(prefix: String) -> Button:
	for node: Node in app.ui.root.find_children("*","Button",true,false):
		if (node as Button).text.begins_with(prefix) and (node as Button).is_visible_in_tree(): return node as Button
	return null
func run() -> void:
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_ui_test.json"
	app.settings_path="user://world_ui_settings_test.json"
	app.save_profile="ui_fixture"
	for path: String in [app.save_path,app.settings_path]:
		for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(path+suffix)
	root.add_child(app)
	check(app.title.find_child("TitleBackdrop",true,false)!=null,"original title illustration is mounted")
	# Explicit presentation edge fixture: a fading heart tip can collapse at float precision.
	var heart:=DemoHeartStrip.new();root.add_child(heart)
	var tiny:=0.00000001
	heart.present(tiny,1);heart.set_process(false)
	await ticks(3)
	check(heart.current==tiny,"fractional heart rendering preserves the exact observed health value")
	heart.queue_free()
	app.start_new()
	# Arrival is covered by station_arrival; this fixture isolates touch UI.
	var ready:=app.state.value.duplicate(true);ready.flags.append("station_rest_taught")
	app.state.commit(ready,app.state.revision)
	await ticks(15)
	app.overlay.set_enabled(true)
	app.load_room("P-R01","INTRO-P24-P01:P-R01")
	for i: int in 180:
		await physics_frame
		if not app.busy: break
	app.player.reset_at(app.room.get_node("Npc0").position)
	app.controller.router.set_source_axis(&"keyboard_mouse",0,true)
	await ticks(14)
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	await ticks(3)
	check(not app.ui.interact.visible and app.context_target().get("kind","")=="npc","Up interaction replaces extra HUD button")
	var at:=app.overlay.left_center
	var press:=InputEventScreenTouch.new();press.index=7;press.pressed=true;press.position=at
	root.push_input(press,true);await ticks(2)
	var cancel_touch:=InputEventScreenTouch.new();cancel_touch.index=7;cancel_touch.position=at;cancel_touch.canceled=true
	root.push_input(cancel_touch,true);await ticks(2)
	check(not app.paused,"canceled neutral joystick does not interact")
	press=InputEventScreenTouch.new();press.index=8;press.pressed=true;press.position=at
	root.push_input(press,true);await ticks(2)
	var up_drag:=InputEventScreenDrag.new();up_drag.index=8;up_drag.position=at-Vector2(0,app.overlay.radius);up_drag.relative=Vector2(0,-app.overlay.radius)
	root.push_input(up_drag,true);await ticks(4)
	check(app.paused and app.ui.page=="dialogue","real left joystick Up opens NPC response")
	if app.ui.page!="dialogue":
		await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4);print("WORLD UI: %d assertions, %d failures" % [checks,failures]);quit(failures);return
	await ticks(5)
	var dialogue:=app.ui.shell as WorldDialogue
	check(dialogue._panel.size.y-dialogue.rows.get_combined_minimum_size().y<70,"short dialogue shrinks after text wrapping without a large empty lower panel")
	await touch_button(find("查看服务"))
	check("NPC_P_REC" in app.services.ledger().met,"NPC meeting persists")
	await touch_button(find("告别"))
	check(not app.paused and not app.controller.router.aim_engaged,"closing service restores cancelled clean input")
	var packet:=app.controller.shoot_ability.packet_id
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=Vector2(700,300)
		event.global_position=event.position;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await ticks(1)
	check(app.controller.shoot_ability.packet_id==packet,"compatibility mouse after touch close cannot fire a ghost shot")
	var revision:=app.state.revision
	app.show_map()
	await ticks(4)
	check(app.ui.page=="map" and app.state.revision==revision,"expanded map is read-only")
	var maps:=app.ui.shell.find_children("*","FixedWorldMap",true,false)
	check(maps.size()==1,"expanded and mini map share fixed world map view")
	var map:=maps[0] as FixedWorldMap
	for index: int in 2:
		var finger:=InputEventScreenTouch.new()
		finger.index=index;finger.pressed=true
		finger.position=map.get_global_transform_with_canvas()*Vector2(map.size.x*(.4+.2*index),map.size.y*.5)
		root.push_input(finger,true);await ticks(2)
	for step: int in 2:
		for index: int in 2:
			var drag:=InputEventScreenDrag.new()
			drag.index=index
			drag.position=map.get_global_transform_with_canvas()*Vector2(map.size.x*((.3-.1*step) if index==0 else (.7+.1*step)),map.size.y*.5)
			root.push_input(drag,true);await ticks(2)
	check(map.zoom>1 and app.state.revision==revision,"raw two-finger map pinch zooms without revealing knowledge")
	for index: int in 2:
		var release:=InputEventScreenTouch.new();release.index=index;release.pressed=false
		root.push_input(release,true);await ticks(2)
	var escape:=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.keycode=KEY_ESCAPE;escape.pressed=true
	root.push_input(escape,true);await ticks(3)
	check(not app.paused and app.ui.page.is_empty() and root.gui_get_focus_owner()==null,"focused map Escape closes and returns clean gameplay focus")
	app._show_settings()
	await ticks(4)
	var movement:=app.ui.shell.find_children("*","OptionButton",true,false)[0] as OptionButton
	await touch_button(movement)
	var popup:=movement.get_popup()
	var choice:=Vector2(popup.position)+Vector2(popup.size)*.5
	for down: bool in [true,false]:
		var finger:=InputEventScreenTouch.new();finger.index=4;finger.pressed=down;finger.position=choice
		root.push_input(finger,true);await ticks(3)
	check(movement.selected==1,"paused settings popup accepts actual touch selection")
	var settings_revision:=app.preferences.revision
	await touch_button(find("应用并保存"))
	check(not app.paused and app.preferences.revision==settings_revision+1 and app.preferences.value.input.touch_move_mode=="digital","first save touch after popup selection commits independent settings")
	app.return_title()
	await ticks(5)
	var saved_revision:=app.state.revision
	for attempt: int in 2:
		app._ui_command("new", "")
		await ticks(3)
		check(app.ui.page=="confirm" and app.state.revision==saved_revision,"cancelled new-game confirmation must be asked again")
		app._close_panel()
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD UI: %d assertions, %d failures" % [checks,failures]);quit(failures)
