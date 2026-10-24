extends SceneTree
## Real native R3 recording. Prior R2 recording and its original driver stay
## separately attributed; damage/heal are explicit official-policy UI fixtures.
var app: Variant
var frame := 0
var trace: Array[Dictionary] = []
var destination := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): destination = arg.trim_prefix("--trace=")
	run.call_deferred()
func frames(count: int) -> void:
	for i: int in count:
		await process_frame
		await RenderingServer.frame_post_draw
		frame += 1
		var actor: Variant = app.controller if is_instance_valid(app) else null
		trace.append({"focus_active":actor.air_focus_ability.active if actor else false,"ring_visible":app._demo_hud.time_ring.is_visible_in_tree() if actor and app._demo_hud else false,"video_frame":frame,"phase":app.menu.visible_panel if is_instance_valid(app) else "disposed","hp":actor.actor_resources.health.current if actor else -1,"energy":actor.actor_resources.stamina.current if actor else -1,"shots":actor.action_resources.shot_charges if actor else -1,"shot_serial":actor.shoot_ability._shot_serial if actor else -1})
func button(owner: Node, prefix: String) -> Button:
	for child: Node in owner.find_children("*","Button",true,false):
		if child.text.begins_with(prefix) or str(child.get_meta(&"ui_legacy_prefix", "")).begins_with(prefix): return child
	return null
func click(target: Control) -> void:
	assert(target != null)
	var parent := target.get_parent()
	while parent:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(2)
	var point := target.get_global_rect().get_center()
	var move := InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;Input.parse_input_event(event);await frames(2)
func key(pressed: bool) -> void:
	var event := InputEventKey.new();event.physical_keycode=KEY_SPACE;event.keycode=KEY_SPACE;event.pressed=pressed;Input.parse_input_event(event)
func run() -> void:
	root.size = Vector2i(1280,720)
	app = load("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	await frames(120)
	print("DEMO UI MOVIE PHASE: title / ", frame)
	await click(button(app.menu._root,"风铃平原"))
	await frames(60)
	print("DEMO UI MOVIE PHASE: home / ", frame)
	app.menu._seed="level-design-v2-baseline/08"
	app._open_home_navigation()
	await click(button(app.menu._root,"Explore"))
	await frames(120)
	print("DEMO UI MOVIE PHASE: formal / ", frame)
	app._submit_damage(&"ui-movie-fixture",DamageRequest.Kind.MONSTER,1.0)
	await frames(60)
	print("DEMO UI MOVIE PHASE: hurt / ", frame)
	SupplyHealEffect.apply(app.controller.actor_resources.health,1.0,&"ui-movie-heal")
	await frames(60)
	print("DEMO UI MOVIE PHASE: healed / ", frame)
	key(true);await frames(12);key(false)
	var point: Vector2 = app.player.get_canvas_transform() * (app.player.global_position + Vector2(0,250))
	var move := InputEventMouseMotion.new();move.position=point;move.global_position=point;Input.parse_input_event(move)
	var press := InputEventMouseButton.new();press.position=point;press.global_position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;Input.parse_input_event(press)
	await frames(60)
	var release := InputEventMouseButton.new();release.position=point;release.global_position=point;release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;Input.parse_input_event(release)
	await frames(100)
	print("DEMO UI MOVIE PHASE: shot / ", frame)
	await click(app._pause_button)
	await frames(60)
	await click(button(app.menu._root,"SETTINGS"))
	await frames(60)
	await click(button(app.menu._root,"BACK"))
	await frames(30)
	await click(button(app.menu._root,"RESUME"))
	await frames(30)
	await click(app.stage.map_view)
	await frames(120)
	await click(button(app.map_modal._root,"CLOSE MAP"))
	await frames(maxi(1,880-frame))
	var had_damage := false
	var had_heal := false
	var had_shot := false
	var had_ring := false
	for row: Dictionary in trace:
		if row.hp == 4.0: had_damage = true
		if had_damage and row.hp == 5.0: had_heal = true
		if row.shot_serial > 0 and row.shots == 0: had_shot = true
		if row.ring_visible and row.focus_active and row.energy < 100.0: had_ring = true
	var file := FileAccess.open(destination,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"Actual DemoApp/native mouse. Scripted official policy damage, SupplyHealEffect restoration; real jump/aim slow-time energy ring/release shooting without shot energy debit. Not a natural combat route or device performance proof.","frames":trace,"damage_observed":had_damage,"heal_observed":had_heal,"shot_observed":had_shot,"time_energy_ring_observed":had_ring},"  "));file.close()
	paused=false
	app.free()
	for i: int in 8: await process_frame
	print("DEMO UI MOVIE: %s frames, damage=%s heal=%s shot=%s ring=%s" % [frame,had_damage,had_heal,had_shot,had_ring])
	quit(0 if had_damage and had_heal and had_shot and had_ring else 1)
