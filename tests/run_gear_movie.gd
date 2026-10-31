extends SceneTree
## Continuous real-input demonstration. The fixed three-room development fixture
## is explicitly labelled; no position, health, resources, rewards or enemy state
## are injected. All gameplay movement belongs to the real PlayerMotor.
var app: DemoApp
var destination := "res://build/run_gear_movie/trace.json"
var phase := "开发固定关卡 · 真实输入 / 正式交易与装备UI"
var frame := 0
var assertions := 0
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var events: Array[Dictionary] = []
var checkpoints: Array[Dictionary] = []
var held: Dictionary = {}
var pointer := Vector2.ZERO
var caption: Label

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
	for index: int in count:
		await process_frame
		await RenderingServer.frame_post_draw
		frame += 1
		var state: Dictionary = {"video_frame": frame, "drawn_frame": Engine.get_frames_drawn(), "physics_frame": Engine.get_physics_frames(), "phase": phase, "paused": paused}
		if is_instance_valid(app):
			state["menu"] = str(app.menu.visible_panel)
			state["stage"] = app.director.stage_index
			state["stage_type"] = str(app.director.stage_type_id)
			if is_instance_valid(app.player):
				state["position"] = [app.player.position.x, app.player.position.y]
				state["velocity"] = [app.player.velocity.x, app.player.velocity.y]
				state["hp"] = app.controller.actor_resources.health.current
				state["max_jumps"] = app.controller.motor.tuning.max_jumps
				state["shot_serial"] = app.controller.shoot_ability._shot_serial
				state["coins"] = app.wallet.balance
				state["inventory"] = Array(app.build.inventory.item_ids())
				state["equipped"] = Array(app.build.item_ids())
				state["gear"] = app.build.equipment.snapshot()
				state["actor_epoch"] = app.lifetime.actor_epoch
			rows.append(state)

func set_phase(value: String) -> void:
	phase = value
	if is_instance_valid(caption):
		caption.text = "开发固定关卡 · 真实输入 / 正式交易与装备UI\n" + value
	print("GEAR MOVIE PHASE: ", value, " / ", frame)
	checkpoints.append({"phase": value, "video_frame": frame, "drawn_frame": Engine.get_frames_drawn()})

func key(code: Key, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed: return
	held[code] = pressed
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	events.append({"kind": "key", "key": OS.get_keycode_string(code), "pressed": pressed, "video_frame": frame})

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
	events.append({"kind": "mouse", "point": [point.x, point.y], "pressed": pressed, "video_frame": frame})

func button(owner: Node, identifier: String) -> Button:
	if not is_instance_valid(owner): return null
	for child: Node in owner.find_children("*", "Button", true, false):
		var target := child as Button
		if str(target.name) == identifier or target.text.begins_with(identifier) or str(target.get_meta(&"ui_legacy_prefix", "")).begins_with(identifier):
			return target
	return null

func click(target: Button) -> bool:
	if not check(is_instance_valid(target) and target.is_visible_in_tree() and not target.disabled, "real visible enabled button exists"): return false
	var parent := target.get_parent()
	while parent != null:
		if parent is ScrollContainer: (parent as ScrollContainer).ensure_control_visible(target)
		parent = parent.get_parent()
	await frames(3)
	var point := target.get_global_rect().get_center()
	mouse(point, true)
	await frames(2)
	mouse(point, false)
	await frames(3)
	return true

func walk_to(target_x: float, budget: int) -> bool:
	key(KEY_D, true)
	for index: int in budget:
		if not is_instance_valid(app.player) or app.player.position.x >= target_x: break
		await frames(1)
	key(KEY_D, false)
	await frames(3)
	return check(is_instance_valid(app.player) and app.player.position.x >= target_x - 5.0, "real D input reaches x=%s" % target_x)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	app = preload("res://game/application/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	root.add_child(app)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	caption = Label.new()
	caption.position = Vector2(16, 6)
	caption.add_theme_font_override("font", DemoClockworkTheme.FONT)
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(caption)
	set_phase("新系统连续操作演示；无旧版对照")
	await frames(45)
	# Test fixture selection is setup only. Every subsequent outcome uses real
	# physical input and the unmodified production transaction/equipment services.
	if not check(app.start_demo("gear-recording", false), "fixed development run starts at its natural spawn"):
		await finish(); return
	await frames(60)
	var start_position := app.player.position
	if not check(start_position.distance_to(app.stage.spawn) < 35.0, "run begins at ordinary validated spawn"):
		await finish(); return
	var starting_epoch := app.lifetime.actor_epoch
	set_phase("鼠标瞄准并松开射击，击败巡逻机获得原有 10 金币")
	var enemy := app.stage.enemy.get_node("Actor") as EnemyActor
	for shot: int in 7:
		if enemy.health.terminal: break
		var point: Vector2 = app.player.get_canvas_transform() * enemy.motor.global_position
		mouse(point, true)
		await frames(10)
		point = app.player.get_canvas_transform() * enemy.motor.global_position
		mouse(point, false)
		await frames(35)
	if not check(enemy.health.terminal and app.wallet.balance == 10 and app.controller.shoot_ability._shot_serial >= 3, "physical release shots defeat live patrol and commit original combat reward"):
		await finish(); return
	await frames(35)
	set_phase("真实 D 移动、Space 跳跃，经过缺口进入道具房")
	if not await walk_to(746.0, 240):
		await finish(); return
	key(KEY_D, true)
	key(KEY_SPACE, true)
	await frames(14)
	key(KEY_SPACE, false)
	for index: int in 95:
		if app.player.position.x >= 1115.0: break
		await frames(1)
	key(KEY_D, false)
	await frames(12)
	if not check(app.player.position.x >= 1080 and app.player.position.y > 530 and app.lifetime.actor_epoch == starting_epoch, "real jump crosses gap without return or teleports"):
		await finish(); return
	key(KEY_W, true)
	await frames(2)
	key(KEY_W, false)
	await frames(35)
	if not check(app.director.stage_index == 2 and app.director.stage_type_id == &"item_reward", "ordinary lower exit enters item choice room"):
		await finish(); return
	set_phase("走近奖励并点击领取云踏靴；获得后先入背包")
	if not await walk_to(530.0, 160):
		await finish(); return
	await frames(15)
	if not await click(button(app._actions, "云踏靴")):
		await finish(); return
	await frames(50)
	if not check(app.build.inventory.count_item(&"jump_blue") == 1 and app.build.item_ids().is_empty() and app.controller.motor.tuning.max_jumps == 1, "claim creates one stable inventory instance without an active effect"):
		await finish(); return
	var instance_id := app.build.inventory.instances()[0].instance_id
	if not await click(app._pause_button):
		await finish(); return
	if not await click(button(app.menu._root, "BuildPage")):
		await finish(); return
	set_phase("道具已入包，负荷 0 / 8，尚未生效")
	await frames(90)
	var stage_clock := app.stage.clock
	if not check(paused and app.build.equipment.snapshot().used == 0 and app.menu.visible_panel == &"build", "real construction page pauses gameplay and leaves backpack inactive"):
		await finish(); return
	if not await click(button(app.menu._root, "EquipItem")):
		await finish(); return
	set_phase("点击装备：负荷 3 / 8，跳跃次数从 1 变为 2")
	await frames(110)
	if not check(app.controller.motor.tuning.max_jumps == 2 and app.build.equipment.snapshot().used == 3 and app.build.equipment.equipped_ids() == [instance_id] and app.stage.clock == stage_clock, "equipment click atomically activates item while actual gameplay remains frozen"):
		await finish(); return
	if not await click(button(app.menu._root, "UnequipItem")):
		await finish(); return
	set_phase("点击卸下：负荷回到 0 / 8，跳跃次数恢复 1")
	await frames(110)
	if not check(app.controller.motor.tuning.max_jumps == 1 and app.build.equipment.snapshot().used == 0 and app.build.inventory.instances()[0].instance_id == instance_id, "unequip removes effect completely and preserves original inventory instance"):
		await finish(); return
	if not await click(button(app.menu._root, "PurchaseGearUpgrade")):
		await finish(); return
	set_phase("花费本局 10 金币扩容：8 → 10 槽，金币变为 0")
	await frames(110)
	check(app.build.equipment.capacity() == 10 and app.wallet.balance == 0 and app.build.equipment.snapshot().level == 1, "real gear purchase debits combat coins once and raises capacity by two")
	check(app.meta.snapshot().get("notes", 0) == 0, "gear upgrade leaves permanent notes untouched")
	await finish()

func finish() -> void:
	for code: Variant in held.keys():
		key(code, false)
	paused = false
	if is_instance_valid(app):
		check(await preload("res://tests/audio_teardown.gd").drain_world(app), "real audio resources finish clean teardown")
		app.free()
	for index: int in 8: await process_frame
	var data := {"schema": "run-gear-continuous-native-movie-v1", "scope": "Natural fixed development three-room route, real keyboard/mouse, live patrol and original rewards. Uses production inventory/equipment/shop UI. Not a natural formal-region route or hardware performance/player acceptance. New feature: no before comparison.", "seed": "gear-recording", "checks": assertions, "failures": failures, "checkpoints": checkpoints, "input_events": events, "frames": rows}
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
	else:
		check(false, "trace output can be written")
	print("GEAR MOVIE: %s frames, %s assertions, %s failures" % [frame, assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
