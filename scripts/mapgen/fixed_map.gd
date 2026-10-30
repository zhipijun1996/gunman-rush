extends Node2D
## Fixed seed development host. All movement/combat/transactions use main-game actors.
const REGISTRY = preload("res://scripts/mapgen/materialized_registry.gd")
const BOSS = preload("res://scripts/mapgen/boss_binding.gd")
const PLAYER = preload("res://scenes/player/player.tscn")
const CAPABILITIES = preload("res://third_party/mapgen/0.1.0/module_pack/integration/player_capabilities.gd")
var registry = REGISTRY.new()
var motor: PlayerMotor
var player: PlayerController
var policy: FrameDamagePolicy
var wallet := RunWallet.new()
var lifetime := DemoLifetime.new()
var segment := SegmentRespawn.new()
var meta := MetaProgression.new()
var region_state := PlainsRegionState.new()
var boss_binding: Node2D
var run_id := ""
var loaded := false
var load_error := ""
var outcome := "playing"
var events: Array[Dictionary] = []
var _label: Label
var _camera: Camera2D
var _map_view := false
var _paused := false
var _bounds: Rect2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The map root itself stays at the world identity, including negative Blocks.
	if run_id.is_empty(): run_id = "mapgen-930001-" + str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec())
	var opened: Dictionary = registry.open_delivery()
	if not opened.ok: _fail(opened.reason); return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/mapgen_930001.json"))
	var blocks: Array = registry.map_data.bounds_blocks
	_bounds = Rect2(blocks[0] * 128, blocks[1] * 128, (blocks[2] - blocks[0]) * 128, (blocks[3] - blocks[1]) * 128)
	motor = PLAYER.instantiate()
	motor.name = "ExistingGamePlayer"
	motor.process_mode = Node.PROCESS_MODE_PAUSABLE
	motor.position = Vector2(config.spawn.local_position_pixels[0], config.spawn.local_position_pixels[1])
	add_child(motor)
	player = motor.get_node("Controller")
	player.enable_shot_energy()
	var capabilities: Dictionary = CAPABILITIES.apply(player, config.initial_capabilities)
	if not capabilities.ok: _fail(str(capabilities)); return
	var touch := InputSetup.attach(motor, player.router)
	touch.reset_label = "NEW RUN"
	touch.pause_requested.connect(_toggle_pause)
	touch.reset_requested.connect(_new_run)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_player_controller(player)
	policy.register_target(&"player", player.actor_resources.health, true)
	policy.player_fatal.connect(_player_fatal)
	policy.environment_return_requested.connect(_environment_return)
	segment.configure(player, lifetime)
	segment.add_anchor(&"map_start", motor.global_position)
	var services := {"policy": policy, "lifetime": lifetime, "wallet": wallet, "segment": segment, "meta": meta, "region_state": region_state}
	for spec: Dictionary in registry.map_data.instances:
		var receipt: Dictionary = registry.instantiate_materialized(spec, self, player, services, run_id)
		if not receipt.ok: _fail(receipt.reason); return
		registry.instances[spec.id].process_mode = Node.PROCESS_MODE_PAUSABLE
		segment.danger_bounds.append_array(registry.instances[spec.id].module.world_static_dangers())
	boss_binding = BOSS.new()
	boss_binding.name = "NativeBossBinding"
	boss_binding.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(boss_binding)
	var boss_result: Dictionary = boss_binding.setup(registry.instances.M40, player, services)
	if not boss_result.ok: _fail(str(boss_result)); return
	boss_binding.victory.connect(_boss_victory)
	_camera = Camera2D.new()
	_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_camera.position = motor.position
	add_child(_camera)
	_camera.make_current()
	var hud := CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	_label = Label.new()
	_label.position = Vector2(18, 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(_label)
	var actions := HBoxContainer.new()
	actions.position = Vector2(860, 80)
	hud.add_child(actions)
	for action: Array in [["全图 M", _toggle_map], ["暂停", _toggle_pause], ["新一局", _new_run], ["返回主游戏", _return_title]]:
		var button := Button.new()
		button.text = action[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action[1])
		actions.add_child(button)
	player.interact_requested.connect(_interact)
	# Physics must acknowledge terrain before validating the complete spawn body.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not segment.activate_anchor(&"map_start"):
		_fail("M01/game-plains-windchime-lesson/spawn_96_206_unsafe"); return
	loaded = true
	policy.protect_player()
	events.append({"event": "map_loaded", "run_id": run_id, "seed": 930001, "spawn": [motor.position.x, motor.position.y], "single_player": true, "physics_tuning": "config/player_tuning.json"})
	print("MAPGEN_READY ", JSON.stringify({"seed": 930001, "instances": registry.instances.size(), "spawn": [motor.position.x, motor.position.y], "boss_scene": boss_result.scene}))

func _physics_process(_delta: float) -> void:
	if not loaded: return
	if outcome == "playing" and lifetime.active and not get_tree().paused:
		boss_binding.activate()
		if motor.global_position.y > _bounds.end.y + 512:
			# Leaving the map is a native environment hit/segment return, not a refill.
			var request := DamageRequest.new()
			request.token = lifetime.token()
			request.actor_epoch = lifetime.actor_epoch
			request.health_epoch = player.actor_resources.health.epoch
			request.source_id = &"mapgen_world_fall"
			request.target_id = &"player"
			request.event_id = StringName("map_fall/" + str(lifetime.actor_epoch))
			request.kind = DamageRequest.Kind.ENVIRONMENT
			request.amount = 1
			request.fall = true
			policy.submit(request)
	if not _map_view: _camera.global_position = motor.global_position
	_label.text = "固定地图 930001 开发预览  |  HP %s  金币 %s  |  %s\nA/D 移动 · 空格跳跃 · 松开左键射击 · E 钩索 · W 交互 · S 下落\nM 全图 · Esc 暂停 · F5 新一局 · Enter 返回主游戏\n%s" % [player.actor_resources.health.current, wallet.balance, outcome, "先射击风铃，再向右探索" if outcome == "playing" else "本局已结束；可返回主游戏或开始新一局"]

func _interact() -> void:
	if not lifetime.active: return
	for instance: Node2D in registry.instances.values():
		if instance.has_method("request_native_region_interaction"): instance.request_native_region_interaction()
		if instance.has_method("request_native_pickup_interaction"): instance.request_native_pickup_interaction()

func _environment_return() -> void:
	if lifetime.active and not player.actor_resources.health.terminal:
		if not segment.return_to_anchor(): _fail("no_safe_native_segment_anchor")
		else: policy.protect_player()

func _player_fatal() -> void:
	if outcome != "playing": return
	outcome = "defeat"
	lifetime.end()
	player.die()
	events.append({"event": "run_end", "result": outcome, "coins": wallet.balance})

func _boss_victory() -> void:
	if outcome != "playing" or not lifetime.active or player.actor_resources.health.terminal: return
	outcome = "victory"
	events.append({"event": "run_end", "result": outcome, "coins": wallet.balance, "exit_opened": false})
	lifetime.end()
	player.router.clear("mapgen_victory")
	player.shoot_ability.clear_projectiles()
	player.air_focus_ability.stop()
	player.active = false
	motor.reset_motion()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not loaded: return
	# Native cache choice owns its pause. Global overview/pause must not resume
	# the world behind an unresolved mandatory transaction.
	if _native_reward_modal_open(): return
	match event.physical_keycode:
		KEY_F5:
			_new_run()
		KEY_ENTER:
			_return_title()
		KEY_ESCAPE:
			_toggle_pause()
		KEY_M:
			_toggle_map()

func _toggle_pause() -> void:
	if not loaded or _native_reward_modal_open(): return
	_paused = not _paused
	player.router.clear("mapgen_pause")
	player.air_focus_ability.stop()
	get_tree().paused = _paused or _map_view
	_resume_input()

func _toggle_map() -> void:
	if not loaded or _native_reward_modal_open(): return
	_map_view = not _map_view
	player.router.clear("mapgen_overview")
	player.air_focus_ability.stop()
	get_tree().paused = _paused or _map_view
	_resume_input()
	_camera.zoom = Vector2.ONE * minf(1180 / _bounds.size.x, 540 / _bounds.size.y) if _map_view else Vector2.ONE
	if _map_view: _camera.global_position = _bounds.get_center() - Vector2(0, 50 / _camera.zoom.y)
	queue_redraw()

func _resume_input() -> void:
	if get_tree().paused: return
	get_viewport().gui_release_focus()
	(motor.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter).observe_current_key_neutral()

func _draw() -> void:
	if not _map_view or registry.map_data.is_empty(): return
	var font := ThemeDB.fallback_font
	for spec: Dictionary in registry.map_data.instances:
		var origin := Vector2(spec.origin_blocks[0], spec.origin_blocks[1]) * 128
		var size := Vector2(spec.size_blocks[0], spec.size_blocks[1]) * 128
		var color := Color("607e96")
		if spec.role == "target_reward": color = Color("b889d6")
		elif spec.role == "boss": color = Color("f2c66b")
		elif spec.role == "start": color = Color("8bcda9")
		draw_rect(Rect2(origin, size), color, false, 10)
		draw_string(font, origin + Vector2(18, 115), str(spec.id) + (" MX" if spec.transform.mirror_x else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 100, color)
		for seal: Dictionary in spec.seals:
			var raw: Array = seal.rect_pixels
			draw_rect(Rect2(origin + Vector2(raw[0], raw[1]), Vector2(raw[2], raw[3])), Color("ed7e7e"))

func _new_run() -> void:
	if _native_reward_modal_open(): return
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_title() -> void:
	if _native_reward_modal_open(): return
	get_tree().paused = false
	# The existing isolated Web preview owns a session-only full-game menu.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor.has_method("return_to_menu"):
			ancestor.call_deferred("return_to_menu")
			return
		ancestor = ancestor.get_parent()
	get_tree().change_scene_to_file("res://scenes/demo/demo.tscn")

func _native_reward_modal_open() -> bool:
	for instance: Node2D in registry.instances.values():
		var consumer: Variant = instance.get("original_region_chests")
		if consumer != null and is_instance_valid(consumer.app) and consumer.app.reward_modal.opened: return true
	return false

func _fail(reason: String) -> void:
	load_error = reason
	loaded = false
	lifetime.end()
	if is_instance_valid(player): player.die()
	push_error("MAPGEN_LOAD_FAILED " + reason)
	print("MAPGEN_LOAD_FAILED ", reason)

func _exit_tree() -> void:
	lifetime.end()
	if is_instance_valid(player): player.router.clear("mapgen_unload")
	Engine.time_scale = 1.0
