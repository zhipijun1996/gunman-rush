extends SceneTree
## Formal App integration fixtures. Relocation/extra items are explicit test setup,
## not natural traversal evidence. Formal pause opens the actual backpack directly.
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
		if parent is ScrollContainer and parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: parent.ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(6)
	parent = target.get_parent()
	while parent != null:
		if parent is ScrollContainer and parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: parent.ensure_control_visible(target)
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
	await frames(4)
	check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0, "one native pause click directly opens a live backpack editing session")
func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = pressed; root.push_input(event, true); await frames(3)
func joy(id: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new(); event.button_index = id; event.pressed = pressed; root.push_input(event, true); await frames(3)
func instance_button(id: StringName) -> Button:
	for node: Node in app.menu._root.find_children("*", "Button", true, false):
		if StringName(node.get_meta(&"instance_id", &"")) == id: return node
	return null
func backpack_scroll() -> ScrollContainer:
	return app.menu._root.find_child("BackpackScroll", true, false) as ScrollContainer
func backpack_adapter() -> Node:
	var scroll := backpack_scroll()
	if scroll == null: return null
	for node: Node in scroll.find_children("*", "Node", true, false):
		if node.has_signal("forwarded"): return node
	return null
func select_instance(id: StringName, touch := false) -> void:
	var before_revision := int(app.build.equipment.snapshot().revision)
	await click(instance_button(id), touch)
	check(int(app.build.equipment.snapshot().revision) == before_revision, "selecting an icon only displays details without changing equipment")
func another_instance_id(excluded: StringName) -> StringName:
	for entry: Dictionary in app.menu._equipment_view.get("items", []):
		var id := StringName(entry.get("instance_id", &""))
		if id != excluded: return id
	return &""
func check_gear_cells(expected_capacity: int, expected_used: int) -> void:
	var slots := app.menu._root.find_child("GearSlots", true, false) as Container
	check(slots != null and slots.get_child_count() == expected_capacity, "actual load indicator contains one cell for each of %s gear capacity" % expected_capacity)
	if slots == null: return
	var occupied_count := 0
	var native_shapes := true
	var all_on_screen := true
	for child: Node in slots.get_children():
		# This is a draw-node/state contract, not a substitute for rendered-shape
		# review. The independent visual review inspects the captured actual cogs.
		native_shapes = native_shapes and child is Control and not child is ColorRect and child.get_script() != null and child.has_method("_draw")
		if not child is Control: continue
		var cell := child as Control
		if bool(cell.get("occupied")): occupied_count += 1
		native_shapes = native_shapes and cell.get_canvas_item().is_valid() and cell.size.x >= 18 and cell.size.y >= 18
		all_on_screen = all_on_screen and cell.is_visible_in_tree() and root.get_visible_rect().grow(0.5).encloses(cell.get_global_rect())
	check(native_shapes, "gear cells are real two-dimensional custom-draw controls rather than ColorRect load strips")
	check(occupied_count == expected_used and expected_used == int(app.build.equipment.snapshot().used), "filled gear cells equal the actual equipped-instance cost sum")
	check(all_on_screen, "all %s actual gear cells fit inside the current viewport" % expected_capacity)
func first_owned_summary() -> Dictionary:
	var instance: Variant = app.build.inventory.instances()[0]
	return {"instance_id":instance.instance_id,"definition_id":instance.definition_id,"gear_cost":instance.item.gear_cost}
func inventory_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for instance: Variant in app.build.inventory.instances(): result.append(instance.instance_id)
	return result
func grant_backlog() -> void:
	for index: int in 48:
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
	check_gear_cells(8, 0)
	check(app.menu._root.find_child("BackpackItems", true, false) is GridContainer and app.menu._root.find_child("EquippedItems", true, false) is GridContainer, "actual backpack and equipped areas use separate icon grids")
	await select_instance(owned.instance_id)
	var selected_name := (app.menu._root.find_child("SelectedItemName", true, false) as Label).text
	await select_instance(owned.instance_id)
	check(instance_button(owned.instance_id).button_pressed and (app.menu._root.find_child("SelectedItemName", true, false) as Label).text == selected_name, "clicking the selected icon again preserves its highlight and displayed item")
	var detail := app.menu._root.find_child("EquipmentDetail", true, false) as Control
	var grid := app.menu._root.find_child("BackpackItems", true, false) as Control
	check(detail != null and grid != null and detail.get_global_rect().position.x >= grid.get_global_rect().end.x, "desktop selected item details occupy the separate right panel")
	var page_session: int = app._equipment_session
	var page_revision := int(app.build.equipment.snapshot().revision)
	var page_token: Variant = app.lifetime.token()
	await key(KEY_E)
	check(paused and app.menu.visible_panel == &"pause", "native next-page key opens journey while actual world remains paused")
	check(not app.build.equipment.submit(owned_ids, page_token, page_session, page_revision).accepted and app.build.item_ids().is_empty(), "leaving backpack invalidates the old equipment session without a partial equip")
	await key(KEY_Q)
	check(paused and app.menu.visible_panel == &"build" and app._equipment_session != page_session, "native previous-page key opens a new backpack session")
	await joy(JOY_BUTTON_LEFT_SHOULDER)
	check(paused and app.menu.visible_panel == &"help", "gamepad LB switches to the previous real pause page")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(paused and app.menu.visible_panel == &"build", "gamepad RB switches back to backpack")
	await click(button(app.menu._root, "PageNext"), true)
	check(paused and app.menu.visible_panel == &"pause", "touch next-page arrow opens journey")
	await click(button(app.menu._root, "PagePrevious"), true)
	check(paused and app.menu.visible_panel == &"build", "touch previous-page arrow returns to backpack")
	page_token = null
	await select_instance(owned.instance_id)
	await screenshot("desktop-backpack")
	await click(button(app.menu._root,"EquipItem"))
	check(app.build.item_ids() == [owned.definition_id] and int(app.build.equipment.snapshot().used) == owned.gear_cost, "native equip changes only the selected instance and load")
	check(app.controller.actor_resources.health.current == current_health, "equipping never grants free healing")
	check_gear_cells(8, int(owned.gear_cost))
	check(not is_equal_approx(float(app.controller.actor_resources.health.capacity), floor(float(app.controller.actor_resources.health.capacity))) and str(app.menu._build).contains(str(app.controller.actor_resources.health.capacity)), "actual fractional maximum HP is visible precisely in the construction summary")
	await screenshot("desktop-equipped")
	await click(button(app.menu._root,"UnequipItem"))
	check(app.build.item_ids().is_empty() and app.controller.motor.tuning.projectile_damage == base_damage, "native unequip removes the effect completely")
	check_gear_cells(8, 0)
	# Fixture coins exercise the same ledger as natural combat/drop income.
	app.wallet.grant(100,&"gear_ui_fixture_income")
	app._refresh_equipment_view()
	var old_coins: int = app.wallet.balance
	print("GEAR UI UPGRADE BEFORE ", JSON.stringify({"equipment":app.build.equipment.snapshot(),"coins":app.wallet.balance,"quote":app.shop.gear_quote(),"session":app._equipment_session,"token":app._equipment_token.key(),"router":app.controller.router.epoch}))
	await click(button(app.menu._root,"PurchaseGearUpgrade"))
	print("GEAR UI UPGRADE AFTER ", JSON.stringify({"equipment":app.build.equipment.snapshot(),"coins":app.wallet.balance,"message":app.menu._equipment_view.get("message","")}))
	check(app.build.equipment.capacity() == 10 and app.wallet.balance == old_coins-10, "native expansion uses the configured first quote and run wallet")
	check_gear_cells(10, 0)
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
	await frames(5)
	await select_instance(owned.instance_id)
	var stale_action := button(app.menu._root, "EquipItem")
	var stale_purchase := button(app.menu._root, "PurchaseGearUpgrade")
	var other_id := another_instance_id(owned.instance_id)
	var other_icon := instance_button(other_id)
	var revision_before_selection := int(app.build.equipment.snapshot().revision)
	var coins_before_selection: int = app.wallet.balance
	check(stale_action != null and stale_purchase != null and other_icon != null, "selection-change rejection fixture has two real instance controls and an affordable upgrade")
	# Deliberately exercise a same-frame stale GUI signal before queue_free.
	# The previous detail action must be inert after focus selects another item.
	if stale_action != null and stale_purchase != null and other_icon != null:
		other_icon.grab_focus()
		stale_action.pressed.emit()
		stale_purchase.pressed.emit()
	check(int(app.build.equipment.snapshot().revision) == revision_before_selection and app.build.item_ids().is_empty() and app.wallet.balance == coins_before_selection, "same-frame stale detail action cannot equip the previous item or spend coins after selection changes")
	stale_action = null
	stale_purchase = null
	await frames(4)
	if other_icon != null: other_icon.grab_focus()
	await key(KEY_RIGHT)
	var focus_after_right := root.gui_get_focus_owner()
	check(paused and app.menu.visible_panel == &"build" and focus_after_right != null and not StringName(focus_after_right.get_meta(&"instance_id", &"")).is_empty() and focus_after_right != other_icon, "native right direction moves between item icons without switching pause pages")
	root.size = Vector2i(960,540)
	app.overlay.set_enabled(true)
	await frames(10)
	var small_scroll := backpack_scroll()
	var small_adapter := backpack_adapter()
	check(small_scroll != null and small_adapter != null, "small-screen backpack owns an independent native scroller and touch adapter")
	if small_scroll == null or small_adapter == null: quit(1); return
	check(small_scroll.get_v_scroll_bar().max_value > small_scroll.size.y, "small-screen icon backpack has real scroll overflow")
	var detail_bounds := (app.menu._root.find_child("EquipmentDetail", true, false) as Control).get_global_rect()
	var load_bounds := (app.menu._root.find_child("GearLoad", true, false) as Control).get_global_rect()
	# Wheel input establishes room to scroll before the independent touch drag.
	var scroll_rect: Rect2 = small_scroll.get_global_rect()
	for unused: int in 100:
		if small_scroll.scroll_vertical == 0: break
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
	small_adapter.forwarded.connect(observe_touch_phase)
	small_scroll.gui_input.connect(observe_scroll_input)
	var before_scroll: int = small_scroll.scroll_vertical
	var revision_before_drag := int(app.build.equipment.snapshot().revision)
	var coins_before_drag: int = app.wallet.balance
	var start := scroll_rect.get_center()
	var press := InputEventScreenTouch.new(); press.index = 72; press.position = start; press.pressed = true; root.push_input(press,true)
	await frames(2)
	print("GEAR UI TOUCH PRESS ",JSON.stringify({"finger":small_adapter._finger,"contains":small_adapter._contains(start),"visible":small_scroll.is_visible_in_tree(),"handled":root.is_input_handled(),"phases":touch_phases,"events":scroll_events}))
	for index: int in 5:
		var drag := InputEventScreenDrag.new(); drag.index = 72; drag.position = start-Vector2(0,(index+1)*32); drag.relative = Vector2(0,-32); root.push_input(drag,true); await frames(2)
	var release := InputEventScreenTouch.new(); release.index = 72; release.position = start-Vector2(0,160); release.pressed = false; root.push_input(release,true)
	await frames(5)
	print("GEAR UI TOUCH SCROLL ",JSON.stringify({"before":before_scroll,"after":small_scroll.scroll_vertical,"rect":str(scroll_rect),"finger":small_adapter._finger,"device":str(app.menu._menu_device),"phases":touch_phases,"events":scroll_events}))
	check(small_scroll.scroll_vertical > before_scroll, "actual ScreenDrag scrolls the small-screen backpack")
	check(&"press" in touch_phases and &"scroll_begin" in touch_phases and touch_phases.count(&"drag") == 5 and touch_phases.back() == &"release" and small_adapter._finger == -1 and not small_adapter._scrolling, "real root touch gesture traverses adapter and releases scroll ownership")
	check(app.wallet.balance == coins_before_drag and int(app.build.equipment.snapshot().revision) == revision_before_drag, "scrolling cancels the underlying button without purchasing or equipping")
	check((app.menu._root.find_child("EquipmentDetail", true, false) as Control).get_global_rect() == detail_bounds and (app.menu._root.find_child("GearLoad", true, false) as Control).get_global_rect() == load_bounds, "backpack scrolling keeps the selected details and gear load fixed on screen")
	await select_instance(owned.instance_id, true)
	await click(button(app.menu._root,"EquipItem"),true)
	check(app.build.item_ids().size() == 1, "touch taps can submit an equipment command after scrolling")
	check_gear_cells(10, int(owned.gear_cost))
	await screenshot("touch-equipped")
	var focus_target := button(app.menu._root,"UnequipItem")
	await point_for(focus_target)
	check(focus_target != null,"touch equip exposes an actual focused unequip control")
	if focus_target != null: focus_target.grab_focus()
	await joy(JOY_BUTTON_A)
	check(app.build.item_ids().is_empty(), "gamepad confirm activates the focused unequip control")
	# The existing explicit UI income fixture funds two more real purchases;
	# never overwrite capacity or bypass the authoritative policy and ledger.
	var coins_before_max: int = app.wallet.balance
	var second_price := int(app.shop.gear_quote().price)
	await click(button(app.menu._root, "PurchaseGearUpgrade"), true)
	check(app.build.equipment.capacity() == 12 and second_price > 0 and app.wallet.balance == coins_before_max - second_price, "native second expansion purchases twelve capacity using the authoritative price quote")
	var final_price := int(app.shop.gear_quote().price)
	await click(button(app.menu._root, "PurchaseGearUpgrade"), true)
	check(app.build.equipment.capacity() == 14 and final_price > 0 and app.wallet.balance == coins_before_max - second_price - final_price, "native final expansion purchases fourteen capacity through the same run ledger")
	check_gear_cells(14, 0)
	var max_slots := app.menu._root.find_child("GearSlots", true, false) as Control
	var max_left := app.menu._root.find_child("InventoryCollection", true, false) as Control
	check(max_slots != null and max_left != null and max_slots.get_global_rect().end.x <= max_left.get_global_rect().end.x + 0.5, "fourteen actual gear cells remain within the left collection at the 960x540 window")
	await screenshot("touch-max-capacity")
	var serial: int = app.controller.shoot_ability._shot_serial
	await click(button(app.menu._root,"ResumeAdventure"),true)
	await frames(5)
	check(not paused and app.controller.shoot_ability._shot_serial == serial and app.overlay._captures.is_empty(), "touch close resumes without a stale shot or captured gameplay finger")
	# Formal map lifecycle fixture: drive the real director transition after its
	# completion predicate, without claiming a natural Boss combat recording.
	app.toggle_pause()
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
	check(app.director.region_map_index == 2 and app.build.equipment.equipped_ids() == retained_ids and app.build.equipment.capacity() == 14 and app.wallet.balance == coins_before_map and instances_after_map == retained_instances, "formal map2 retains exact inventory instances, loadout, expansion and wallet")
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
