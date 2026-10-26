extends SceneTree
## Formal App integration fixtures. Relocation/extra items are explicit test setup,
## not natural traversal evidence; the continuous movie uses natural fixed rooms.
var app: Variant
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var touch_phases: Array[StringName] = []
var scroll_events: Array[String] = []
var capture := "--capture" in OS.get_cmdline_user_args()
const OUTPUT := "res://build/run_gear/ui"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	observations.append({"passed":ok,"assertion":message})
	if not ok: failures += 1; printerr("FAIL: " + message)
func frames(count := 4) -> void:
	for unused: int in count: await process_frame
func button(owner: Node, name_or_prefix: String) -> Button:
	for node: Node in owner.find_children("*", "Button", true, false):
		if node.name == name_or_prefix or node.text.begins_with(name_or_prefix) or str(node.get_meta(&"ui_legacy_prefix", "")).begins_with(name_or_prefix): return node
	return null
func point_for(target: Control) -> Vector2:
	if target == null:
		check(false, "native scroll target exists")
		return Vector2.ZERO
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(6)
	parent = target.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(2)
	return target.get_global_rect().get_center()
func click(target: Control, touch := false) -> void:
	check(target != null, "native input target exists")
	if target == null: return
	var point: Vector2 = await point_for(target)
	if touch:
		target.gui_input.connect(trace_tap_input)
		print("GEAR UI TAP BEFORE ",JSON.stringify({"target":str(target.get_path()),"point":str(point),"rect":str(target.get_global_rect()),"scroll":str(app.menu._scroll.get_global_rect()),"session":app._equipment_session,"generation":app.menu._equipment_generation,"revision":app.build.equipment.snapshot().revision}))
	check(root.get_visible_rect().has_point(point), "target is inside the actual viewport after scrolling")
	if not touch:
		var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; root.push_input(motion,true); await frames(2)
	for pressed: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new(); event.index = 71; event.position = point; event.pressed = pressed; root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new(); event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed; root.push_input(event,true)
		await frames(3)
		if touch: print("GEAR UI TAP EDGE ",JSON.stringify({"pressed":pressed,"hovered":str(root.gui_get_hovered_control()),"button_pressed":target.is_pressed() if is_instance_valid(target) else false,"actual_hover":target.is_hovered() if is_instance_valid(target) else false,"finger":app.menu._scroll_touch._finger if is_instance_valid(app.menu._scroll_touch) else -2,"session":app._equipment_session,"generation":app.menu._equipment_generation,"message":app.menu._equipment_view.get("message","")}))
func observe_touch_phase(phase: StringName) -> void:
	touch_phases.append(phase)
func observe_scroll_input(event: InputEvent) -> void:
	scroll_events.append(event.get_class())
func trace_tap_input(event: InputEvent) -> void:
	print("GEAR UI TAP GUI ", event.get_class(), " ", event.as_text())
func screenshot(name: String) -> void:
	if not capture: return
	await frames(4)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "actual rendered " + name)
func open_build(touch := false) -> void:
	if not paused: await click(app._pause_button, touch)
	await click(button(app.menu._root,"BuildPage"), touch)
	await frames(4)
	check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0, "formal construction opens a live paused editing session")
func first_owned_summary() -> Dictionary:
	var instance: Variant = app.build.inventory.instances()[0]
	return {"instance_id":instance.instance_id,"definition_id":instance.definition_id,"gear_cost":instance.item.gear_cost}
func inventory_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for instance: Variant in app.build.inventory.instances(): result.append(instance.instance_id)
	return result
func grant_backlog() -> void:
	for index: int in 18:
		var fixture_item: Variant = load("res://resources/items/damage_blue.tres").duplicate(true)
		fixture_item.stable_id = StringName("ui_backlog_%s" % index)
		check(app.build.add_item(StringName("ui_backlog/%s" % index),fixture_item), "backlog instance is independently owned")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1280,720)
	app = DemoApp.new(); app.meta_persistence_enabled = false; root.add_child(app)
	await frames(5)
	check(app.start_plains("level-design-v2-baseline/08"), "formal Plains run starts")
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	check(app.connected_region and app.stage is PlainsRegionStage and not app._stage_pending, "actual formal map assembles")
	if not is_instance_valid(app.stage): quit(1); return
	var base_damage: float = app.controller.motor.tuning.projectile_damage
	var chosen: Dictionary = {}
	for chest: Dictionary in (app.stage as PlainsRegionStage).chests:
		if chest.reward_mode != "resources" and not chest.items.is_empty(): chosen = chest; break
	check(not chosen.is_empty(), "fixed formal seed contains an item cache")
	if chosen.is_empty(): quit(1); return
	# Explicit transaction-position fixture. The production cache, UI, token,
	# deferred damage boundary and service are unchanged.
	app.player.position = chosen.position
	chosen = {}
	app._region_interact()
	await frames()
	check(paused and app.reward_modal.opened, "actual cache opens reward UI")
	await click(button(app.reward_modal._root,"选择 / PICK"))
	await frames(8)
	check(app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(), "native reward click adds an un-equipped owned instance")
	check(app.controller.motor.tuning.projectile_damage == base_damage, "cache acquisition does not apply damage effects")
	# Keep custom typed iteration temporaries in synchronous helpers, so this
	# long-lived coroutine does not retain their script constraints until exit.
	var owned := first_owned_summary()
	var owned_ids: Array[StringName] = [owned.instance_id]
	var current_health: float = app.controller.actor_resources.health.current
	await open_build()
	var position_before: Vector2 = app.player.position
	var phase_before: float = app.stage.clock
	await frames(8)
	check(app.player.position == position_before and app.stage.clock == phase_before, "construction pauses actual Motor and encounter clocks")
	await screenshot("desktop-backpack")
	await click(button(app.menu._root,"EquipItem"))
	check(app.build.item_ids() == [owned.definition_id] and int(app.build.equipment.snapshot().used) == owned.gear_cost, "native equip changes only the selected instance and load")
	check(app.controller.actor_resources.health.current == current_health, "equipping never grants free healing")
	await screenshot("desktop-equipped")
	await click(button(app.menu._root,"UnequipItem"))
	check(app.build.item_ids().is_empty() and app.controller.motor.tuning.projectile_damage == base_damage, "native unequip removes the effect completely")
	# Fixture coins exercise the same ledger as natural combat/drop income.
	app.wallet.grant(100,&"gear_ui_fixture_income")
	app._refresh_equipment_view()
	var old_coins: int = app.wallet.balance
	print("GEAR UI UPGRADE BEFORE ", JSON.stringify({"equipment":app.build.equipment.snapshot(),"coins":app.wallet.balance,"quote":app.shop.gear_quote(),"session":app._equipment_session,"token":app._equipment_token.key(),"router":app.controller.router.epoch}))
	await click(button(app.menu._root,"PurchaseGearUpgrade"))
	print("GEAR UI UPGRADE AFTER ", JSON.stringify({"equipment":app.build.equipment.snapshot(),"coins":app.wallet.balance,"message":app.menu._equipment_view.get("message","")}))
	check(app.build.equipment.capacity() == 10 and app.wallet.balance == old_coins-10, "native expansion uses the configured first quote and run wallet")
	var stale_session: int = app._equipment_session
	var stale_revision := int(app.build.equipment.snapshot().revision)
	var stale_token: Variant = app.lifetime.token()
	app.controller.router.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(not app.build.equipment.submit(owned_ids,stale_token,stale_session,stale_revision).accepted, "focus loss rejects an old equipment operation while physics is paused")
	app.controller.router.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(3)
	check(app._equipment_session > 0 and app._equipment_session != stale_session, "focus return creates a new editor session and refreshes cards")
	stale_token = null
	# Backlog fixture stresses actual native layout without adding production items.
	grant_backlog()
	app._refresh_equipment_view()
	root.size = Vector2i(960,540)
	app.overlay.set_enabled(true)
	await frames(10)
	check(app.menu._scroll.get_v_scroll_bar().max_value > app.menu._scroll.size.y, "small-screen backpack has real scroll overflow")
	# Wheel input establishes room to scroll before the independent touch drag.
	var scroll_rect: Rect2 = app.menu._scroll.get_global_rect()
	for unused: int in 100:
		if app.menu._scroll.scroll_vertical == 0: break
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll_rect.get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.factor = 4
		# A native wheel button needs balanced edges. An unpaired press leaves
		# Viewport mouse capture on the old scroller and blocks later touch taps.
		for pressed: bool in [true, false]:
			wheel.pressed = pressed
			root.push_input(wheel,true)
		await frames(1)
	app.menu._scroll_touch.forwarded.connect(observe_touch_phase)
	app.menu._scroll.gui_input.connect(observe_scroll_input)
	var before_scroll: int = app.menu._scroll.scroll_vertical
	var revision_before_drag := int(app.build.equipment.snapshot().revision)
	var coins_before_drag: int = app.wallet.balance
	var start := scroll_rect.get_center()
	var press := InputEventScreenTouch.new(); press.index = 72; press.position = start; press.pressed = true; root.push_input(press,true)
	await frames(2)
	print("GEAR UI TOUCH PRESS ",JSON.stringify({"finger":app.menu._scroll_touch._finger,"contains":app.menu._scroll_touch._contains(start),"tree":app.menu._scroll_touch.is_inside_tree(),"input":app.menu._scroll_touch.is_processing_input(),"mode":app.menu._scroll_touch.process_mode,"visible":app.menu._scroll.is_visible_in_tree(),"handled":root.is_input_handled(),"phases":touch_phases,"events":scroll_events,"canvas":str(root.get_canvas_transform()),"screen":str(root.get_screen_transform())}))
	for index: int in 5:
		var drag := InputEventScreenDrag.new(); drag.index = 72; drag.position = start-Vector2(0,(index+1)*32); drag.relative = Vector2(0,-32); root.push_input(drag,true); await frames(2)
	var release := InputEventScreenTouch.new(); release.index = 72; release.position = start-Vector2(0,160); release.pressed = false; root.push_input(release,true)
	await frames(5)
	print("GEAR UI TOUCH SCROLL ",JSON.stringify({"before":before_scroll,"after":app.menu._scroll.scroll_vertical,"rect":str(scroll_rect),"finger":app.menu._scroll_touch._finger,"device":str(app.menu._menu_device),"phases":touch_phases,"events":scroll_events}))
	check(app.menu._scroll.scroll_vertical > before_scroll, "actual ScreenDrag scrolls the small-screen backpack")
	check(&"press" in touch_phases and &"scroll_begin" in touch_phases and touch_phases.count(&"drag") == 5 and touch_phases.back() == &"release" and app.menu._scroll_touch._finger == -1 and not app.menu._scroll_touch._scrolling, "real root touch gesture traverses adapter and releases scroll ownership")
	check(app.wallet.balance == coins_before_drag and int(app.build.equipment.snapshot().revision) == revision_before_drag, "scrolling cancels the underlying button without purchasing or equipping")
	await click(button(app.menu._root,"EquipItem"),true)
	check(app.build.item_ids().size() == 1, "touch taps can submit an equipment command after scrolling")
	await screenshot("touch-equipped")
	var focus_target := button(app.menu._root,"UnequipItem")
	await point_for(focus_target)
	check(focus_target != null,"touch equip exposes an actual focused unequip control")
	if focus_target != null: focus_target.grab_focus()
	for pressed: bool in [true,false]:
		var joy := InputEventJoypadButton.new(); joy.button_index = JOY_BUTTON_A; joy.pressed = pressed; root.push_input(joy,true); await frames(3)
	check(app.build.item_ids().is_empty(), "gamepad confirm activates the focused unequip control")
	var serial: int = app.controller.shoot_ability._shot_serial
	await click(button(app.menu._root,"返回暂停"),true)
	await click(button(app.menu._root,"RESUME"),true)
	await frames(5)
	check(not paused and app.controller.shoot_ability._shot_serial == serial and app.overlay._captures.is_empty(), "touch close resumes without a stale shot or captured gameplay finger")
	# Formal map lifecycle fixture: drive the real director transition after its
	# completion predicate, without claiming a natural Boss combat recording.
	app.toggle_pause(); app.menu.show_build(app._build_description())
	app._submit_equipment(owned_ids,int(app.build.equipment.snapshot().revision),app._equipment_session)
	var retained_ids: Array = app.build.equipment.equipped_ids()
	var retained_instances := inventory_ids()
	var coins_before_map: int = app.wallet.balance
	app.menu.close_panel()
	check(app.director.complete_stage(app.lifetime.token()), "map lifecycle fixture satisfies the real completion boundary")
	check(app.director.advance_region_map(app.lifetime.token(),&"gear_ui_fixture_map2").accepted(), "real formal director accepts map2 transition")
	for unused: int in 180:
		if not app._stage_pending: break
		await frames(1)
	var instances_after_map := inventory_ids()
	check(app.director.region_map_index == 2 and app.build.equipment.equipped_ids() == retained_ids and app.build.equipment.capacity() == 10 and app.wallet.balance == coins_before_map and instances_after_map == retained_instances, "formal map2 retains exact inventory instances, loadout, expansion and wallet")
	var saved_build: Variant = app.build
	app.controller.actor_resources.health.apply_damage(ActorResourceRequest.new(&"gear_ui_fatal",app.controller.actor_resources.health.epoch,999,app.controller.actor_resources.health.get_instance_id()))
	app._player_fatal()
	await frames(10)
	check(app.player == null and saved_build.inventory.instances().is_empty() and saved_build.item_ids().is_empty() and saved_build.equipment.capacity() == 8, "true death cleans inventory, loadout and expansion before Home")
	check(await load("res://tests/audio_teardown.gd").drain_world(app), "formal App releases audio cleanly")
	saved_build = null
	owned = {}
	app.free(); app = null; await frames(3)
	var file := FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"formal App fixture transactions and actual native UI, not natural traversal or physical Android", "observations":observations,"touch_phases":touch_phases,"scroll_events":scroll_events},"  ")); file.close()
	print("GEAR UI: %s checks, %s failures" % [checks,failures])
	_finish.call_deferred()

func _finish() -> void:
	await process_frame
	quit(0 if failures == 0 else 1)
