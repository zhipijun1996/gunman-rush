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
	app.start_new()
	await ticks(15)
	app.overlay.set_enabled(true)
	app.load_room("P-R01","START-P03-P01:P-R01")
	await ticks(15)
	app.controller.router.set_source_axis(&"keyboard_mouse",1,true)
	await ticks(14)
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	await ticks(3)
	check(app.ui.interact.visible and app.ui.interact.text.begins_with("交谈"),"context interaction has visible native control")
	await touch_button(app.ui.interact,true)
	check(not app.paused and app.ui.page.is_empty(),"cancelled touch never opens interaction")
	await touch_button(app.ui.interact)
	check(app.paused and app.ui.page=="npc","real station GUI touch opens NPC")
	if app.ui.page!="npc":
		app.queue_free();await ticks(4);print("WORLD UI: %d assertions, %d failures" % [checks,failures]);quit(failures);return
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
	app._close_panel()
	app.return_title()
	await ticks(5)
	var saved_revision:=app.state.revision
	for attempt: int in 2:
		app._ui_command("new", "")
		await ticks(3)
		check(app.ui.page=="confirm" and app.state.revision==saved_revision,"cancelled new-game confirmation must be asked again")
		app._close_panel()
	app.queue_free();await ticks(5)
	print("WORLD UI: %d assertions, %d failures" % [checks,failures]);quit(failures)
