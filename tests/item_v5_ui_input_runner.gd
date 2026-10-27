extends SceneTree
## Native adapter and Control callbacks. Synthetic input and layout proxies are
## explicit; this runner does not claim physical Android/controller validation.
var assertions := 0
var failures := 0
var _tick := 0
var _nodes: Array[Node] = []
var router: InputRouter
var keyboard: KeyboardMouseAdapter
var gamepad: GamepadAdapter
var touch: TouchOverlay

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+label)

func actions() -> Array[Dictionary]:
	_tick += 1
	return router.consume_actions(_tick)

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	keyboard._unhandled_input(event)

func point(index: int, location: Vector2, pressed: bool, canceled: bool = false) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = location
	event.pressed = pressed
	event.canceled = canceled
	return touch.handle_touch(event)

func drag(index: int, location: Vector2, relative: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = location
	event.relative = relative
	return touch.handle_touch(event)

func input_fixture() -> void:
	router = InputRouter.new()
	root.add_child(router)
	_nodes.append(router)
	var origin := Node2D.new()
	origin.position = Vector2(100,100)
	root.add_child(origin)
	_nodes.append(origin)
	keyboard = KeyboardMouseAdapter.new()
	keyboard.router = router
	keyboard.aim_origin = origin
	root.add_child(keyboard)
	_nodes.append(keyboard)
	gamepad = GamepadAdapter.new()
	gamepad.router = router
	gamepad.aim_origin = origin
	root.add_child(gamepad)
	_nodes.append(gamepad)
	touch = TouchOverlay.new()
	touch.router = router
	touch.aim_origin = origin
	root.add_child(touch)
	_nodes.append(touch)

func keyboard_edges() -> void:
	router.item_skill_available = true
	router.weapon_skill_available = true
	key(KEY_R,true)
	var first := actions()
	check(first.size() == 1 and first[0].type == &"item_skill","R press creates the independent item skill action")
	key(KEY_R,true,true)
	key(KEY_R,true)
	check(actions().is_empty(),"key repeat and held R cannot create additional item skills")
	key(KEY_R,false)
	key(KEY_Q,true)
	var weapon := actions()
	check(weapon.size() == 1 and weapon[0].type == &"weapon_skill","Q continues to address the weapon skill")
	key(KEY_Q,false)
	router.item_skill_available = false
	key(KEY_R,true)
	check(actions().is_empty(),"R without an equipped item skill does not queue an action")
	key(KEY_R,false)
	router.item_skill_available = true
	key(KEY_R,true)
	actions()
	router.clear("menu_open")
	key(KEY_R,true)
	check(actions().is_empty(),"an R held through cancellation cannot cast again")
	key(KEY_R,false)
	key(KEY_R,true)
	check(actions().size() == 1,"a fresh R press after observed release is accepted")
	key(KEY_R,false)
	paused = true
	key(KEY_R,true)
	check(actions().is_empty() and not router.request_action(&"item_skill",Vector2.RIGHT),"paused gameplay rejects both adapter and direct item input")
	paused = false
	key(KEY_R,false)
	router.clear("keyboard_end")

func gamepad_edges() -> void:
	router.item_skill_available = true
	router.activate_device(&"gamepad")
	for index: int in 2: gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	for index: int in 2: gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT)
	gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false,false,false,true)
	var item := actions()
	check(item.size() == 1 and item[0].type == &"item_skill" and item[0].direction.distance_to(Vector2.RIGHT) < .001,"RB uses the actual right-stick aim for the item skill")
	gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false,false,false,true)
	check(actions().is_empty(),"held RB cannot repeatedly cast")
	for index: int in 3: gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	check(actions().is_empty(),"centering the main stick after RB does not add a primary shot")
	for index: int in 2: gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT)
	for index: int in 3: gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	var shot := actions()
	check(shot.size() == 1 and shot[0].type == &"shoot_release","a newly armed stick can fire normally after the item gesture")
	gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false,false,true)
	var weapon := actions()
	check(weapon.size() == 1 and weapon[0].type == &"weapon_skill","Y remains the separate weapon skill")
	gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO,false,false,false,false,true)
	actions()
	router.clear("gamepad_pause")
	gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false,false,false,true)
	check(actions().is_empty(),"RB held through router cancellation remains blocked")
	gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,false,false,false,true)
	check(actions().size() == 1,"RB requires a fresh released-to-pressed edge after cancellation")
	gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
	router.clear("gamepad_end")

func touch_multifinger() -> void:
	touch.set_enabled(true)
	router.item_skill_available = true
	router.weapon_skill_available = true
	router.weapon_context_available = true
	router.grapple_available = true
	router.item_skill_label = "回环飞轮"
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		touch._configure_layout(Rect2(Vector2.ZERO,Vector2(dimensions)),Vector2(dimensions))
		var center := touch.item_skill_center
		var item_radius := touch.hook_radius*.8
		var safe := Rect2(Vector2.ZERO,Vector2(dimensions))
		check(safe.encloses(Rect2(center-Vector2.ONE*item_radius,Vector2.ONE*item_radius*2)),"item touch target fits the %s viewport" % dimensions)
		check(center.distance_to(touch.skill_center) > item_radius*2 and center.distance_to(touch.context_center) > item_radius*2 and center.distance_to(touch.hook_center) > item_radius+touch.hook_radius,"item target is separate from weapon skill, context and hook at %s" % dimensions)
		var pause_rect: Rect2 = touch.get("_pause_rect")
		check(not pause_rect.grow(item_radius).has_point(center) and center.distance_to(touch.jump_center) > item_radius+touch.jump_hit_radius,"item target does not cover MENU or jump at %s" % dimensions)
		point(20,touch.right_center,true)
		var aimed := touch.right_center+Vector2(touch.radius*.8,0)
		drag(20,aimed,Vector2(touch.radius*.8,0))
		check(router.aim_engaged,"main aim finger is armed before independent item activation at %s" % dimensions)
		check(point(21,center,true) and actions().is_empty(),"pressing the item control captures its own finger without casting early")
		point(21,center,false)
		var item := actions()
		check(item.size() == 1 and item[0].type == &"item_skill" and item[0].direction.distance_to(Vector2.RIGHT) < .001,"item finger release submits one shared-aim action at %s" % dimensions)
		point(20,aimed,false)
		check(actions().is_empty(),"releasing the still-held main aim finger cannot append a primary shot")
		point(22,center,true)
		point(22,center,false,true)
		check(actions().is_empty(),"system cancellation of an item finger does not cast")
		point(22,center,false)
		check(actions().is_empty(),"late release of the canceled item capture remains inert")
	router.clear("touch_end")
	touch.set_enabled(false)
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	await process_frame

func catalog_formatting() -> void:
	var items := ItemCatalogV5.all_items()
	check(items.size() == 72,"presentation verifies all 72 real catalog entries")
	for definition: ItemDefinition in items:
		for level: int in range(1,definition.max_level+1):
			var text := ItemPresentation.effects(definition,level)
			check(not text.is_empty() and not text.contains("{") and not text.contains("_by_level") and not text.contains("尚未同步") and not text.contains("具体机制见"),"%s Lv%s has a resolved player-facing effect description" % [definition.stable_id,level])
	check(ItemPresentation.effects(ItemCatalogV5.get_item(&"B11"),2).contains("+2"),"HP formatter selects level two instead of all level values")
	check(ItemPresentation.effects(ItemCatalogV5.get_item(&"G01")).contains("6秒") and ItemPresentation.effects(ItemCatalogV5.get_item(&"G16")).contains("0.9D"),"current H-column values win over conflicting historical prose")
	check(ItemPresentation.reason(&"maximum_level").contains("最高等级") and not ItemPresentation.reason(&"unknown_internal_reason").contains("unknown_internal"),"known and unknown machine reasons remain readable")
	var growth_drone := ItemCatalogV5.get_item(&"G19")
	check(ItemPresentation.effects(growth_drone).contains("基础伤害0.3D") and not ItemPresentation.effects(growth_drone).contains("当前"),"unowned companion preview clearly labels its base damage")
	var evolved := ItemPresentation.effects(growth_drone,1,{"evolution":2})
	check(evolved.contains("成长2/2") and evolved.contains("当前每2.5秒攻击0.42D"),"owned companion details use actual evolution state independently of the item level")

func label_texts(node: Node) -> String:
	var texts: PackedStringArray = []
	for child: Node in node.find_children("*","Label",true,false): texts.append((child as Label).text)
	return "\n".join(texts)

func item_cards(node: Node) -> Array[ItemCard]:
	var cards: Array[ItemCard] = []
	for child: Node in node.find_children("*","",true,false):
		if child is ItemCard: cards.append(child)
	return cards

func acquisition_and_reward_levels() -> void:
	var definition := ItemCatalogV5.get_item(&"B11")
	var toast := ItemAcquiredToast.new()
	root.add_child(toast)
	_nodes.append(toast)
	toast.show_item(definition,2)
	var text := label_texts(toast)
	check(text.contains("道具升级") and text.contains("Lv2") and text.contains("+2"),"acquisition toast displays the owned upgraded level and its current effect")
	toast.show_item(definition)
	text = label_texts(toast)
	check(text.contains("Lv1") and text.contains("+1") and not text.contains("道具升级"),"historical one-argument toast defaults to level one")
	toast.clear()
	var modal := StageRewardModal.new()
	root.add_child(modal)
	_nodes.append(modal)
	var selections: Array[StringName] = []
	modal.item_selected.connect(func(id: StringName) -> void: selections.append(id))
	var offer := RewardOffer.new()
	offer.offer_id = &"level_preview"
	offer.candidates.assign([definition])
	modal.show_offer(offer,"下张地图",{&"B11":2})
	var cards := item_cards(modal)
	check(cards.size() == 1 and (cards[0] as ItemCard).level == 2 and label_texts(modal).contains("领取后 Lv2") and label_texts(modal).contains("+2"),"reward preview describes the level that this acquisition will actually reach")
	var old_card := cards[0] as ItemCard if not cards.is_empty() else null
	modal.show_offer(offer,"下张地图")
	if old_card != null: old_card.selected.emit(&"B11")
	check(selections.is_empty(),"reopening a reward invalidates old level-preview selection callbacks")
	cards = item_cards(modal)
	check(cards.size() == 1 and (cards[0] as ItemCard).level == 1,"historical two-argument reward API retains a level-one preview")
	var current := cards[0] as ItemCard if not cards.is_empty() else null
	if current != null: current.selected.emit(&"B11")
	check(selections == [&"B11"],"fresh reward card still submits its stable definition ID exactly once")
	modal.close()
	if current != null: current.selected.emit(&"B11")
	check(selections.size() == 1,"closed reward cards cannot submit another selection")

func menu_and_shop_guards() -> void:
	var menu := DemoMenu.new()
	root.add_child(menu)
	_nodes.append(menu)
	var selected: Array = []
	menu.equipment_active_selected.connect(func(id: StringName,revision: int,session: int) -> void: selected.append([id,revision,session]))
	menu.show_build("")
	var view := {"capacity":8,"used":5,"remaining":3,"revision":42,"session":7,"coins":999,"items":[
		{"instance_id":&"active","definition":ItemCatalogV5.get_item(&"P24"),"level":1,"max_level":1,"equipped":true,"active_capable":true,"active_selected":false},
		{"instance_id":&"health","definition":ItemCatalogV5.get_item(&"B11"),"level":2,"max_level":3,"equipped":true},
		{"instance_id":&"broken","definition":ItemCatalogV5.get_item(&"B30"),"level":1,"max_level":1,"equipped":false,"broken":true,"repair_quote":{"available":false,"price":18,"reason":&"not_in_shop","quote_version":2}}]}
	menu.set_equipment_view(view)
	await process_frame
	var old_active := menu.find_child("SelectActiveItem",true,false) as Button
	check(old_active != null,"equipped active item exposes its selection action")
	if old_active != null:
		old_active.pressed.emit()
		check(selected == [[&"active",42,7]],"active selection carries instance, revision and editing session")
		menu.call("_select_equipment",&"health")
		old_active.pressed.emit()
		check(selected.size() == 1,"an old active button is inert after detail selection changes")
	var description := menu.find_child("SelectedItemEffects",true,false) as Label
	check(description != null and description.text.contains("+2") and not description.text.contains("max_hp"),"pause details show the actual current level without internal parameter names")
	menu.call("_select_equipment",&"broken")
	var repair := menu.find_child("RepairSelectedItem",true,false) as Button
	check(repair != null and repair.disabled and menu.find_child("SelectedItemBroken",true,false) != null,"broken inventory shows its state and cannot remotely repair outside a shop")
	menu.call("_select_equipment",&"active")
	old_active = menu.find_child("SelectActiveItem",true,false) as Button
	view.revision = 43
	menu.set_equipment_view(view)
	if old_active != null: old_active.pressed.emit()
	check(selected.size() == 1,"a view refresh invalidates old active-selection buttons")
	var current_active := menu.find_child("SelectActiveItem",true,false) as Button
	if current_active != null: current_active.pressed.emit()
	check(selected == [[&"active",42,7],[&"active",43,7]],"a newly rendered button carries the fresh revision")
	menu.close_panel()
	if current_active != null: current_active.pressed.emit()
	check(selected.size() == 2,"closing the menu invalidates its last active action")
	var shop := ItemShopModal.new()
	root.add_child(shop)
	_nodes.append(shop)
	var bought: Array[StringName] = []
	var repaired: Array = []
	var rerolled: Array[bool] = []
	shop.catalog_purchase_requested.connect(func(id: StringName) -> void: bought.append(id))
	shop.repair_requested.connect(func(id: StringName,version: int) -> void: repaired.append([id,version]))
	shop.catalog_reroll_requested.connect(func() -> void: rerolled.append(true))
	var snapshot := {"offers":[
		{"offer_id":&"offer_a","item":ItemCatalogV5.get_item(&"B03"),"price":28,"stock":1,"eligible":true},
		{"offer_id":&"offer_b","item":ItemCatalogV5.get_item(&"B11"),"price":25,"stock":1,"eligible":true},
		{"offer_id":&"offer_c","item":ItemCatalogV5.get_item(&"B04"),"price":30,"stock":1,"eligible":true}],"reroll":{"available":true,"price":0},"repairs":[{"instance_id":&"broken","item":ItemCatalogV5.get_item(&"B30"),"available":true,"price":18,"quote_version":7}]}
	shop.show_catalog(snapshot,999)
	check(shop.find_child("CatalogCard_offer_a",true,false) != null and shop.find_child("CatalogCard_offer_b",true,false) != null and shop.find_child("CatalogCard_offer_c",true,false) != null,"catalog shop renders all three distinct offers")
	var old_buy := shop.find_child("CatalogBuy_offer_a",true,false) as Button
	if old_buy != null:
		old_buy.pressed.emit()
		old_buy.pressed.emit()
	check(bought == [&"offer_a"],"one shop view can submit a purchase only once")
	shop.show_catalog(snapshot,999)
	if old_buy != null: old_buy.pressed.emit()
	check(bought.size() == 1,"reopening a shop cannot reactivate an old purchase button")
	var old_repair := shop.find_child("CatalogRepair_broken",true,false) as Button
	if old_repair != null: old_repair.pressed.emit()
	check(repaired == [[&"broken",7]],"repair action carries its frozen owned instance and quote version")
	snapshot.repairs[0].quote_version = 8
	shop.show_catalog(snapshot,999)
	if old_repair != null: old_repair.pressed.emit()
	check(repaired.size() == 1,"new repair quotes invalidate old repair callbacks")
	var reroll := shop.find_child("CatalogReroll",true,false) as Button
	if reroll != null:
		reroll.pressed.emit()
		reroll.pressed.emit()
	check(rerolled.size() == 1,"free reroll button submits one transaction per view")
	shop.close()
	if reroll != null: reroll.pressed.emit()
	check(rerolled.size() == 1,"closing the shop cancels pending reroll buttons")
	var capture_directory := capture_target()
	if not capture_directory.is_empty(): await capture_menu_views(menu,capture_directory)

func capture_target() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			return argument.trim_prefix("--capture-dir=").strip_edges()
	return ""

func capture_menu_png(menu: DemoMenu, directory: String, stem: String, dimensions: Vector2i, rows: Array) -> void:
	for unused: int in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var filename := stem+".png"
	check(image != null and image.get_size() == dimensions,"actual post-draw capture has the requested %s pixel dimensions" % dimensions)
	if image == null: return
	check(image.save_png(directory.path_join(filename)) == OK,"actual software-GL menu viewport saves "+filename)
	var scroll := menu.find_child("BackpackScroll",true,false) as ScrollContainer
	var description := menu.find_child("SelectedItemEffects",true,false) as Label
	var slots := menu.find_child("GearSlots",true,false)
	rows.append({"file":filename,"viewport":[image.get_width(),image.get_height()],"scope":"actual software-GL render of explicit V5 menu snapshot; mobile-layout proxy, not physical Android","selected_instance":str(menu._selected_instance_id),"selected_effect":description.text if description != null else "","gear_cells":slots.get_child_count() if slots != null else 0,"gear_used":menu._equipment_view.used,"owned_items":menu._equipment_view.items.size(),"scroll_vertical":scroll.scroll_vertical if scroll != null else 0,"scroll_max":scroll.get_v_scroll_bar().max_value if scroll != null else 0,"scroll_page":scroll.get_v_scroll_bar().page if scroll != null else 0})

func capture_menu_views(menu: DemoMenu, destination: String) -> void:
	# Optional GL-only evidence branch. Default headless assertions and their
	# ordering remain unchanged; never save a dummy renderer's image as evidence.
	if DisplayServer.get_name() == "headless":
		check(false,"--capture-dir requires a real GL display; headless capture is refused")
		return
	var directory := ProjectSettings.globalize_path(destination)
	check(DirAccess.make_dir_recursive_absolute(directory) == OK,"optional real-render evidence directory is writable")
	var items: Array[Dictionary] = []
	var worn: Array[StringName] = [&"P24",&"G15",&"P14"]
	var used := 0
	for definition: ItemDefinition in ItemCatalogV5.all_items():
		var equipped := definition.stable_id in worn
		if equipped: used += definition.gear_cost
		items.append({"instance_id":StringName("visual/"+String(definition.stable_id)),"definition":definition,"level":definition.max_level,"max_level":definition.max_level,"equipped":equipped,"active_capable":definition.stable_id in ItemCatalogV5.ACTIVE_IDS,"active_selected":definition.stable_id == &"P24","effect_state":{"evolution":2} if definition.stable_id == &"G19" else {},"broken":definition.stable_id == &"B30","repair_quote":{"available":false,"price":18,"reason":&"not_in_shop","quote_version":1}})
	var view := {"capacity":14,"used":used,"remaining":14-used,"revision":71,"session":19,"coins":90,"summary":"背包72件 · 已装备3件 · 当前主动：回环飞轮","items":items,"upgrade":{"available":false,"price":0,"capacity":14,"reason":"已达本局容量上限"}}
	var evidence: Array = []
	var original_size := root.size
	var original_scale := root.content_scale_size
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		menu.show_build("")
		menu.set_equipment_view(view)
		for unused: int in 8: await process_frame
		# Long un-equipped covenant description, real Lv labels, broken state,
		# three equipped cards and fourteen cog cells share the actual screen.
		menu.call("_select_equipment",&"visual/P18")
		var scroll := menu.find_child("BackpackScroll",true,false) as ScrollContainer
		check(scroll != null and scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page,"actual %s V5 backpack has native scroll overflow" % dimensions)
		if scroll != null: scroll.scroll_vertical = 0
		await capture_menu_png(menu,directory,"v5-backpack-%sx%s-top" % [dimensions.x,dimensions.y],dimensions,evidence)
		# Scroll is an explicit layout fixture; screenshots are never described
		# as proof of natural ownership, active effects or a physical touch drag.
		if scroll != null: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		menu.call("_select_equipment",&"visual/G19")
		for unused: int in 4: await process_frame
		check(scroll != null and scroll.scroll_vertical > 0,"actual %s native backpack is visibly scrolled for the second capture" % dimensions)
		await capture_menu_png(menu,directory,"v5-backpack-%sx%s-scrolled" % [dimensions.x,dimensions.y],dimensions,evidence)
	menu.close_panel()
	root.size = original_size
	root.content_scale_size = original_scale
	var file := FileAccess.open(directory.path_join("capture-manifest.json"),FileAccess.WRITE)
	check(file != null,"optional visual evidence manifest can be written")
	if file != null:
		file.store_string(JSON.stringify({"scope":"explicit snapshot fixture through actual DemoMenu/ItemPresentation; software GL and mobile layout proxy only; not physical Android, natural route, owned-item effect validation, or player approval","display_server":DisplayServer.get_name(),"render_adapter":RenderingServer.get_video_adapter_name(),"fixture_equipped_definition_ids":worn,"rows":evidence},"  "))
		file.close()

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	if "--verify-failure-exit" in OS.get_cmdline_user_args():
		check(false,"intentional strict-exit counterexample")
		quit(1)
		return
	input_fixture()
	keyboard_edges()
	gamepad_edges()
	await touch_multifinger()
	catalog_formatting()
	acquisition_and_reward_levels()
	await menu_and_shop_guards()
	paused = false
	for node: Node in _nodes:
		if is_instance_valid(node): node.free()
	_nodes.clear()
	await process_frame
	print("ITEM V5 UI INPUT: %s assertions, %s failures" % [assertions,failures])
	quit(1 if failures else 0)
