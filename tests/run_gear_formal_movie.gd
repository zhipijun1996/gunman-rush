extends SceneTree
## Real formal composition consumer: native title/Home/departure/pause controls.
## The one explicit cache-position fixture is visible in the movie and trace.
## No items, coins, health, enemy state or reward settlement are injected.
var app: Variant
var destination := "res://build/run_gear_feedback/formal-movie/trace.json"
var frame := 0
var assertions := 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var held: Dictionary = {}
var pointer := Vector2.ZERO
var caption: Label
var phase := "正式主游戏 · 标题 → 家园 → 出发"
const SEED := "level-design-v2-baseline/08"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="): destination = arg.trim_prefix("--trace=")
	_run.call_deferred()

func check(value: bool, message: String) -> bool:
	assertions += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)
	return value

func frames(count: int) -> void:
	for unused: int in count:
		await process_frame
		await RenderingServer.frame_post_draw
		frame += 1
		var state: Dictionary = {"video_frame": frame, "drawn_frame": Engine.get_frames_drawn(), "phase": phase, "paused": paused}
		if is_instance_valid(app):
			state["menu"] = str(app.menu.visible_panel)
			state["formal_region"] = app.connected_region
			state["region"] = str(app.active_region_id)
			state["seed"] = str(app.director.seed)
			if is_instance_valid(app.home_scene): state["home_position"] = [app.home_scene.player.position.x, app.home_scene.player.position.y]
			if is_instance_valid(app.player):
				state["position"] = [app.player.position.x, app.player.position.y]
				state["velocity"] = [app.player.velocity.x, app.player.velocity.y]
				state["hp"] = app.controller.actor_resources.health.current
				state["hp_max"] = app.controller.actor_resources.health.capacity
				state["jumps"] = app.controller.jump_ability.maximum_jumps()
				state["damage"] = app.controller.motor.tuning.projectile_damage
				state["shot_serial"] = app.controller.shoot_ability._shot_serial
				state["coins"] = app.wallet.balance
				state["owned"] = Array(app.build.inventory.item_ids())
				state["equipped"] = Array(app.build.item_ids())
				state["gear"] = app.build.equipment.snapshot()
		rows.append(state)

func set_phase(value: String) -> void:
	phase = value
	caption.text = value
	print("FORMAL GEAR MOVIE PHASE: ", value, " / ", frame)
	checkpoints.append({"phase":value, "video_frame":frame, "drawn_frame":Engine.get_frames_drawn()})

func key(code: Key, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind":"key", "key":OS.get_keycode_string(code), "pressed":pressed, "video_frame":frame})

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(4)

func mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - pointer
	if motion.relative.is_zero_approx(): motion.relative = Vector2(1, 0)
	pointer = point
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind":"mouse", "point":[point.x, point.y], "pressed":pressed, "video_frame":frame})

func button(owner: Node, identifier: String, item_id: StringName = &"") -> Button:
	if not is_instance_valid(owner): return null
	for child: Node in owner.find_children("*", "Button", true, false):
		var target := child as Button
		if not target.is_visible_in_tree(): continue
		if not item_id.is_empty() and StringName(target.get_meta(&"instance_id", &"")) != item_id: continue
		if str(target.name).begins_with(identifier) or target.text.begins_with(identifier): return target
	return null

func click(target: Button) -> bool:
	if not check(is_instance_valid(target) and target.is_visible_in_tree() and not target.disabled, "native visible enabled control exists"): return false
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer: (parent as ScrollContainer).ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(5)
	var point := target.get_global_rect().get_center()
	if not check(root.get_visible_rect().has_point(point), "native control center is inside the viewport"): return false
	mouse(point, true)
	await frames(2)
	mouse(point, false)
	await frames(5)
	return true

func choose_cache_fixture() -> Dictionary:
	for chest: Dictionary in (app.stage as PlainsRegionStage).chests:
		if chest.reward_mode != "resources" and not chest.items.is_empty():
			return {"id":str(chest.id), "position":chest.position, "items":Array(chest.items)}
	return {}

func owned_summary() -> Dictionary:
	var instance: Variant = app.build.inventory.instances()[0]
	return {"instance_id":instance.instance_id, "definition_id":instance.definition_id, "gear_cost":instance.item.gear_cost}

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(16, 4)
	caption.add_theme_font_override("font", DemoClockworkTheme.FONT)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)
	set_phase("正式主游戏 · 原生点击开始，进入可操作家园")
	await frames(45)
	if not await click(button(app.menu._root, "BeginAdventure")):
		await finish(); return
	await frames(45)
	if not check(is_instance_valid(app.home_scene) and not app.connected_region, "title Start enters the actual playable Home composition"):
		await finish(); return
	set_phase("正式家园 · 真实 D 行走到聚落出口，W 打开出发界面")
	var home_target: float = app.home_scene.slot_world_foot(&"departure").x - 20.0
	key(KEY_D, true)
	for unused: int in 900:
		if app.home_scene.player.position.x >= home_target: break
		await frames(1)
	key(KEY_D, false)
	await frames(15)
	if not check(app.home_scene.nearest_id == &"departure", "real Home locomotion reaches the authored departure interaction"):
		await finish(); return
	await tap(KEY_W)
	await frames(20)
	if not check(app.menu.home_function_id == &"departure", "real W opens the formal departure panel"):
		await finish(); return
	set_phase("家园正式出口 · 点击出发进入风铃平原，未进入旧开发三房间")
	await frames(45)
	# A deterministic capture seed selects an ordinary formal manifest. It grants
	# no capabilities, item, currency, health or progression.
	app.menu._seed = SEED
	if not await click(button(app.menu._root, "BEGIN / WINDCHIME PLAINS")):
		await finish(); return
	for unused: int in 180:
		if is_instance_valid(app.stage) and not app._stage_pending: break
		await frames(1)
	await frames(30)
	if not check(app.connected_region and app.stage is PlainsRegionStage and app.director.seed == SEED, "native departure starts the real formal Plains region with an ordinary manifest"):
		await finish(); return
	set_phase("正式风铃平原 · 点击暂停直接进入背包，实际玩法停止")
	if not await click(app._pause_button):
		await finish(); return
	await frames(60)
	if not check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0 and app.build.inventory.instances().is_empty(), "first formal pause enters the live empty backpack directly"):
		await finish(); return
	var stopped_position: Vector2 = app.player.position
	var stopped_clock: float = app.stage.clock
	await frames(25)
	if not check(app.player.position == stopped_position and app.stage.clock == stopped_clock, "formal pause stops Motor and actual encounter clock"):
		await finish(); return
	set_phase("背包支持左右切页 · E / Q 进入旅途再返回，不解除暂停")
	await tap(KEY_E)
	await frames(45)
	if not check(paused and app.menu.visible_panel != &"build" and app._equipment_session < 0, "native next page closes the equipment session but keeps the actual game paused"):
		await finish(); return
	await tap(KEY_Q)
	await frames(45)
	if not check(paused and app.menu.visible_panel == &"build" and app._equipment_session > 0, "native previous page returns to backpack with a new editing session"):
		await finish(); return
	await tap(KEY_ESCAPE)
	await frames(15)
	if not check(not paused, "native Escape closes backpack and resumes the formal run"):
		await finish(); return
	# The following is intentionally explicit on-screen and in the machine trace.
	# It proves the original formal cache transaction/UI consumer without claiming
	# traversal of the full platforming branch in this UI-focused short movie.
	set_phase("正式平原 UI 验收 · 显式宝箱位置 fixture（非自然通关），不注资或发道具")
	await frames(45)
	var cache := choose_cache_fixture()
	if not check(not cache.is_empty(), "ordinary fixed formal manifest contains a legal item cache"):
		await finish(); return
	var from_position: Vector2 = app.player.position
	app.player.position = cache.position
	events.append({"kind":"explicit_cache_position_fixture", "video_frame":frame, "from":[from_position.x, from_position.y], "to":[cache.position.x, cache.position.y], "cache_id":cache.id, "items":cache.items})
	cache = {}
	await frames(2)
	await tap(KEY_W)
	if not check(paused and app.reward_modal.opened, "native W opens the actual original formal cache reward modal"):
		await finish(); return
	set_phase("原正式宝箱 · 仅位置 fixture；点击原奖励按钮，由 RewardService 领取入包")
	await frames(60)
	if not await click(button(app.reward_modal._root, "选择 / PICK")):
		await finish(); return
	await frames(20)
	if not check(app.build.inventory.instances().size() == 1 and app.build.item_ids().is_empty(), "native cache claim creates one inactive owned item without bypassing RewardService"):
		await finish(); return
	var owned := owned_summary()
	var baseline_hp: float = app.controller.actor_resources.health.capacity
	var baseline_damage: float = app.controller.motor.tuning.projectile_damage
	var baseline_jumps: int = app.controller.jump_ability.maximum_jumps()
	if not await click(app._pause_button):
		await finish(); return
	set_phase("正式背包 · 左侧图标网格，右侧详情；选择不会自动装备")
	if not await click(button(app.menu._root, "SelectItem", owned.instance_id)):
		await finish(); return
	await frames(90)
	if not check(app.build.item_ids().is_empty() and app.build.equipment.snapshot().used == 0, "native icon selection only changes the inspector, not actual equipment"):
		await finish(); return
	if not await click(button(app.menu._root, "EquipItem")):
		await finish(); return
	set_phase("点击装备 · 已装备图标与负荷即时更新，属性效果生效")
	await frames(100)
	if not check(app.build.equipment.equipped_ids() == [owned.instance_id] and app.build.equipment.snapshot().used == owned.gear_cost, "native inspector equip commits the selected stable instance and exact gear cost"):
		await finish(); return
	if not check(app.controller.actor_resources.health.capacity != baseline_hp or app.controller.motor.tuning.projectile_damage != baseline_damage or app.controller.jump_ability.maximum_jumps() != baseline_jumps, "actual formal controller stat changes from the equipped cache definition"):
		await finish(); return
	if not await click(button(app.menu._root, "UnequipItem")):
		await finish(); return
	set_phase("点击卸下 · 负荷归零，效果完全撤销，道具仍保留在包内")
	await frames(100)
	if not check(app.build.item_ids().is_empty() and app.build.equipment.snapshot().used == 0 and app.build.inventory.instances().size() == 1 and app.controller.actor_resources.health.capacity == baseline_hp and app.controller.motor.tuning.projectile_damage == baseline_damage and app.controller.jump_ability.maximum_jumps() == baseline_jumps, "native unequip removes the actual controller effect while retaining ownership"):
		await finish(); return
	var serial: int = app.controller.shoot_ability._shot_serial
	await tap(KEY_ESCAPE)
	await frames(20)
	check(not paused and app.controller.shoot_ability._shot_serial == serial, "closing formal backpack resumes without firing a stale shot")
	await finish()

func finish() -> void:
	for code: Variant in held.keys(): key(code, false)
	paused = false
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app), "original formal audio resources release cleanly")
		app.free()
		app = null
	for unused: int in 8: await process_frame
	var data := {"schema":"run-gear-formal-native-movie-v1", "scope":"Real native title -> playable Home -> natural Home departure -> ordinary formal Plains -> native pause backpack/pages/selection/equip/unequip. One on-screen explicit position fixture approaches the existing original cache; not natural cache-route traversal or Boss completion. No resource/item/health/settlement injection. Device/player acceptance unverified. New UI has no matched before movie.", "seed":SEED, "checks":assertions, "failures":failures, "checkpoints":checkpoints, "input_events":events, "frames":rows}
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
	else: check(false, "formal movie trace output can be written")
	print("FORMAL GEAR MOVIE: %s frames, %s assertions, %s failures" % [frame, assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
