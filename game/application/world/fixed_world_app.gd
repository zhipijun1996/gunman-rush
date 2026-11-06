class_name FixedWorldApp
extends Node2D
## Application use cases. Shared player/physics/services outlive each room.
var content := FixedWorldProvider.new()
var state := FixedWorldState.new()
var save_path := "user://fixed_world_v1.json"
var save_profile := "local"
var player: PlayerMotor
var controller: PlayerController
var room: FixedWorldRoom
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var entry_anchor := Vector2.ZERO
var camera: Camera2D
var status := ""
var busy := false
var paused := false
var _ticket := 0
var _queue: Array[Dictionary] = []
var _fatal := false
var _return := false
var _door_ready := false
var _sequence := 0
var _initial_x := 0.0
var _moved := 0.0
var _tutorial_shot := false
var _tutorial_recoil := false
var _tutorial_jumped := false
var _tutorial_move_landed := false
var _recoil_origin := Vector2.ZERO
var _recoil_moved := false
var _air_recoil_pending := false
var _new_confirm := false
var canvas: CanvasLayer
var title: VBoxContainer
var hud: Label
var map_label: Label
var menu: VBoxContainer
var q_guard: WorldRecoilGuard
var music: GameMusic

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1200
	var audio := PlayerWeaponFeelAudioV2.new()
	add_child(audio)
	music = GameMusic.new()
	music.volume_source = audio
	add_child(music)
	music.request_track(&"home")
	state.content = content
	var storage := WorldSaveService.new()
	storage.configure(save_path,OS.has_feature("web"),save_profile)
	state.storage = storage
	storage.payload_validator = state.valid
	if not content.open(): status = content.error
	else: storage.content_version = str(content.data.content_version)
	_make_ui()

func _button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280,48)
	button.pressed.connect(action)
	parent.add_child(button)

func _make_ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)
	title = VBoxContainer.new()
	title.position = Vector2(460,180)
	canvas.add_child(title)
	var name_label := Label.new()
	name_label.text = "失序之钟\n首个环路 · 结构灰盒"
	name_label.add_theme_font_size_override("font_size",28)
	title.add_child(name_label)
	_button(title,"新游戏",func() -> void:
		if state.storage._exists(false) and not _new_confirm:
			_new_confirm = true
			status = "再次选择新游戏，将替换本试玩的新世界存档。"
			return
		start_new())
	_button(title,"继续",continue_world)
	hud = Label.new()
	hud.position = Vector2(22,14)
	hud.custom_minimum_size.x = 1200
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_theme_font_size_override("font_size",18)
	canvas.add_child(hud)
	menu = VBoxContainer.new()
	menu.position = Vector2(460,220)
	canvas.add_child(menu)
	_button(menu,"继续探索",toggle_pause)
	_button(menu,"已探索地图",show_map)
	map_label = Label.new()
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_label.custom_minimum_size.x = 360
	menu.add_child(map_label)
	_button(menu,"保存并返回标题",return_title)
	menu.hide()

func start_new() -> bool:
	if content.data.is_empty() or is_instance_valid(player): return false
	# Read first so a corrupt/future save is never silently destroyed.
	var previous := state.storage.load_profile()
	if not previous.get("accepted",false):
		status = "存档需要恢复：" + state.storage.status
		return false
	state.revision = int(previous.revision)
	var health := preload("res://resources/actors/prototype_health.tres") as HealthDefinition
	if not state.commit(state.fresh(health.max_health),state.revision):
		status = state.error
		return false
	_create_player()
	load_room("P-R03","")
	return true

func continue_world() -> bool:
	if is_instance_valid(player) or not state.restore():
		status = state.error
		return false
	_create_player()
	load_room(str(state.value.room),str(state.value.entry))
	return true

func _create_player() -> void:
	_moved = 0
	_tutorial_shot = false
	_tutorial_recoil = false
	_tutorial_jumped = false
	_tutorial_move_landed = false
	_air_recoil_pending = false
	_recoil_moved = false
	_fatal = false
	_return = false
	_queue.clear()
	_new_confirm = false
	player = preload("res://game/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	HomeWeaponSelection.new().apply(controller)
	InputSetup.attach_menu(player,controller.router,toggle_pause)
	controller.enable_shot_energy()
	controller.motor.tuning.projectile_damage = float(content.data.player.starting_projectile_damage)
	_restore_hp(float(state.value.hp))
	q_guard = WorldRecoilGuard.new()
	q_guard.controller = controller
	q_guard.owned = state.has("Q")
	q_guard.cooldown_seconds = float(content.data.runtime_rules.q.cooldown_seconds)
	player.add_child(q_guard)
	RunComposition.attach_player_guides(player,controller)
	controller.interact_requested.connect(_interact)
	controller.jump_ability.jumped.connect(func() -> void: _tutorial_jumped = true)
	controller.landed.connect(func() -> void:
		if room == null or room.room_id!="P-R03": return
		_tutorial_move_landed = _tutorial_jumped
		if state.has("intro_shoot") and _recoil_moved and player.position.x>=1540: _tutorial_recoil = true)
	controller.weapon_damage_committed.connect(func(_packet: int,_shot: int,receiver: Damageable,_session: int,_epoch: int) -> void:
		if room != null and room.room_id=="P-R03" and room.enemies.has("P-R03:practice:01") and receiver==(room.enemies["P-R03:practice:01"] as EnemyActor).damageable: _tutorial_shot = true)
	controller.shoot_ability.shot_fired.connect(_shot)
	camera = Camera2D.new()
	camera.zoom = Vector2(1.6,1.6)
	camera.position_smoothing_enabled = false
	player.add_child(camera)
	title.hide()
	music.request_track(&"plains")

func _shot(_direction: Vector2,_shot_id: int) -> void:
	if room != null and room.room_id == "P-R03":
		_air_recoil_pending = not controller._was_grounded
		_recoil_origin = player.position
		_recoil_moved = false

func _acquire() -> int:
	_ticket += 1
	busy = true
	controller.active = false
	controller.router.clear("world_handoff")
	controller.shoot_ability.clear_projectiles()
	controller.received_resource_grants.clear()
	q_guard.cancel()
	return _ticket

func load_room(id: String, entry: String) -> void:
	var request := LevelRequest.new()
	request.room_id = id
	request.entry_door_id = entry
	request.expected_hash = str(content.data.content_version)
	var resolved := content.resolve(request)
	if resolved.has("error"):
		busy = false
		status = "暂不可通行：" + str(resolved.error)
		return
	var next := (resolved.scene as PackedScene).instantiate() as FixedWorldRoom
	if next == null or next.room_id != id:
		if next != null: next.free()
		busy = false
		status = "房间身份不匹配"
		return
	var previous_room := room
	var previous_position := player.position
	var ticket := _acquire()
	next.process_mode = Node.PROCESS_MODE_PAUSABLE
	next.configure(resolved.room)
	add_child(next)
	# Prepare and validate physical support before destroying the old room.
	var old_layers: Dictionary = {}
	var old_modes: Dictionary = {}
	if previous_room != null:
		for node: Node in previous_room.find_children("*","",true,false):
			old_modes[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
		previous_room.process_mode = Node.PROCESS_MODE_DISABLED
		for body: CollisionObject2D in previous_room.find_children("*","CollisionObject2D",true,false):
			old_layers[body] = body.collision_layer
			body.collision_layer = 0
	var anchor := next.start_point
	if not resolved.entry.is_empty(): anchor = FixedWorldProvider.point(resolved.entry.landing_contract.safe_standing_position_world_units)
	elif id == str(state.value.rest.room): anchor = next.rest_point if next.rest_point != Vector2.ZERO else next.start_point
	player.reset_at(anchor-Vector2(0,1))
	await get_tree().physics_frame
	await get_tree().physics_frame
	if ticket != _ticket or not is_instance_valid(player):
		next.queue_free()
		return
	var safety := SegmentRespawn.new()
	safety.configure(controller,lifetime)
	if not safety.is_safe(anchor):
		next.queue_free()
		player.reset_at(previous_position)
		if previous_room != null:
			previous_room.process_mode = Node.PROCESS_MODE_PAUSABLE
			for node: Node in old_modes: node.process_mode = int(old_modes[node])
			for body: CollisionObject2D in old_layers: body.collision_layer = int(old_layers[body])
		controller.active = true
		busy = false
		status = "入口没有完整身体净空或实际支撑：" + id + "/" + entry
		return
	var candidate := _snapshot()
	candidate.room = id
	candidate.entry = entry
	if id not in candidate.explored: candidate.explored.append(id)
	if not state.commit(candidate,state.revision):
		next.queue_free()
		player.reset_at(previous_position)
		if previous_room != null:
			previous_room.process_mode = Node.PROCESS_MODE_PAUSABLE
			for node: Node in old_modes: node.process_mode = int(old_modes[node])
			for body: CollisionObject2D in old_layers: body.collision_layer = int(old_layers[body])
		controller.active = true
		busy = false
		status = state.error
		return
	lifetime.stage_epoch += 1
	lifetime.invalidate_actor()
	lifetime.active = true
	controller.session_id += 1
	if is_instance_valid(policy): policy.queue_free()
	if previous_room != null:
		remove_child(previous_room)
		previous_room.queue_free()
	room = next
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	entry_anchor = anchor
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	policy.transient_protection = q_guard.protects
	policy.player_fatal.connect(func() -> void: _fatal = true)
	policy.environment_return_requested.connect(func() -> void: _return = true)
	room.install(controller,policy,lifetime,state.value.enemies,state.has("boss_P_WINDKEEPER_defeated"),entry_anchor)
	_apply_capabilities()
	var bounds := FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.zoom = Vector2(1.6,1.6)
	# Vertical entry follows the authored door and a collision-tested Motor arc;
	# horizontal entry settles on the actual supported approach.
	var vertical: bool = not resolved.entry.is_empty() and str(resolved.entry.direction) in ["up","down"]
	var origin := FixedWorldProvider.point(resolved.entry.landing_contract.entry_position_world_units) if vertical else anchor-Vector2(0,3)
	player.reset_at(origin)
	var landed := false
	for i: int in 100:
		await get_tree().physics_frame
		if ticket != _ticket: return
		var dt := get_physics_process_delta_time()
		if vertical and str(resolved.entry.direction)=="down" and i<48:
			var t := float(i+1)/48.0
			var desired := origin.lerp(anchor,t)-Vector2(0,220*sin(PI*t))
			player.request_ability_velocity((desired-player.position)/dt)
		player.step(0,dt)
		if player.is_on_floor():
			landed = true
			break
	if not landed:
		status = "入口落地失败；请重新进入本房间。"
		busy = false
		return
	controller._was_grounded = false
	controller.active = true
	busy = false
	_door_ready = false
	_queue.clear()
	status = str(room.contract.name)
	_initial_x = player.position.x

func _apply_capabilities() -> void:
	controller.traversal.grant(&"grapple",state.has("H"))
	q_guard.owned = state.has("Q")
	if room != null: room.refresh_doors(state,content)

func _snapshot() -> Dictionary:
	var candidate := state.value.duplicate(true)
	if controller != null: candidate.hp = maxf(1,controller.actor_resources.health.current)
	if room != null: candidate.enemies.merge(room.snapshot(),true)
	return candidate

func enqueue(kind: String,id: String) -> void:
	if busy or paused or room == null or not lifetime.active: return
	_queue.append({"kind":kind,"id":id,"token":lifetime.token()})

func _interact() -> void:
	if busy or room == null: return
	if room.rest_point != Vector2.ZERO and player.position.distance_to(room.rest_point)<70:
		enqueue("rest",room.room_id)
	elif room.reward_point != Vector2.ZERO and player.position.distance_to(room.reward_point)<80 and room.battle_finished:
		enqueue("action","get_H")

func _physics_process(_delta: float) -> void:
	_update_hud()
	if paused or busy or room == null or controller == null: return
	if _fatal:
		_fatal = false
		_queue.clear()
		_recover_death.call_deferred()
		busy = true
		return
	if _return:
		_return = false
		_queue.clear()
		_fail_terrain()
		return
	if not lifetime.active: return
	var entering_battle := not room.battle_started
	room.update_battle(player.position)
	if entering_battle and room.battle_started:
		# Authored entering-side refuge remains supported after the central bridge breaks.
		entry_anchor = room.battle_entry_anchor
	if room.battle_started and not room.battle_finished:
		camera.top_level = true
		camera.global_position = room.arena_bounds.get_center()
		camera.zoom = Vector2.ONE
	elif camera.top_level:
		camera.top_level = false
		camera.position = Vector2.ZERO
		camera.zoom = Vector2(1.6,1.6)
	if room.encounter != null and room.encounter.health.terminal and not room.battle_finished:
		enqueue("action","defeat_P_WINDKEEPER")
	if room.room_id == "P-R03":
		_moved = maxf(_moved,absf(player.position.x-_initial_x))
		if _air_recoil_pending and player.recoil_burst_remaining>0 and player.position.distance_to(_recoil_origin)>20: _recoil_moved = true
		if _moved>100 and _tutorial_move_landed and not state.has("intro_move"): enqueue("action","tutorial_move")
		elif _tutorial_shot and state.has("intro_move") and not state.has("intro_shoot"): enqueue("action","tutorial_shoot")
		elif _tutorial_recoil and state.has("intro_shoot") and not state.has("intro_complete"): enqueue("action","tutorial_recoil")
	if room.room_id == "P-R01" and not state.has("station_briefed"): enqueue("action","station_briefing")
	if player.position.y > float(room.contract.world_geometry.bounds_world_units[3])+80:
		submit_damage(&"fall",DamageRequest.Kind.ENVIRONMENT,1,StringName("fall:"+str(Engine.get_physics_frames())))
	var near_door := false
	for door: Dictionary in room.doors:
		var point := FixedWorldProvider.point(door.position_candidate.local_world_units)
		var near := player.position.distance_to(point-Vector2(0,18))<45
		if near:
			near_door = true
			if _door_ready: enqueue("door",str(door.id))
	if not near_door: _door_ready = true
	var pending := _queue
	_queue = []
	for request: Dictionary in pending:
		if not lifetime.accepts(request.token) or busy: continue
		if request.kind == "action": _commit_action(str(request.id))
		elif request.kind == "rest": _rest()
		elif request.kind == "door": _cross(str(request.id))

func _commit_action(id: String) -> void:
	if state.value.receipts.has(id): return
	var candidate := state.action_candidate(id,room.room_id)
	if candidate.is_empty(): return
	candidate.hp = controller.actor_resources.health.current
	candidate.enemies.merge(room.snapshot(),true)
	if not state.commit(candidate,state.revision):
		status = "保存失败，结果未提交："+state.error
		return
	if id == "defeat_P_WINDKEEPER": room.finish_battle()
	_apply_capabilities()
	status = "获得钩索 H，可沿原路返回小站。" if id == "get_H" else str(content.action(id).get("description","进度已保存"))

func _cross(id: String) -> void:
	if room.battle_started and not room.battle_finished: return
	for door: Dictionary in room.doors:
		if door.id != id: continue
		if not door.outbound_allowed or not state.holds(door.requires):
			status = "通路尚未开启，请先完成本处教学或事件。"
			return
		if content.room(str(door.target_room)).is_empty():
			status = "前方区域尚未施工，本次路线请循金色标记。"
			return
		busy = true
		load_room.call_deferred(str(door.target_room),str(door.target_door_id))

func _rest() -> void:
	var candidate := _snapshot()
	candidate.cycle += 1
	candidate.enemies = {}
	candidate.hp = controller.actor_resources.health.capacity
	candidate.rest = {"room":room.room_id,"entry":"","point":[room.rest_point.x,room.rest_point.y]}
	if not state.commit(candidate,state.revision):
		status = state.error
		return
	_restore_hp(float(candidate.hp))
	busy = true
	load_room.call_deferred(room.room_id,"")

func _fail_terrain() -> void:
	var safety := SegmentRespawn.new()
	safety.configure(controller,lifetime)
	if not safety.is_safe(entry_anchor):
		status = "进入侧锚点不可用，暂停恢复。"
		controller.active = false
		return
	controller.router.clear("terrain_return")
	controller.shoot_ability.clear_projectiles()
	player.reset_at(entry_anchor-Vector2(0,1))
	lifetime.invalidate_actor()
	controller.session_id += 1
	q_guard.cancel()
	state.commit(_snapshot(),state.revision)
	status = "返回本次实际进入侧；周期与已提交结果保留。"

func _recover_death() -> void:
	_tutorial_shot = false
	_tutorial_recoil = false
	_air_recoil_pending = false
	_recoil_moved = false
	var candidate := state.value.duplicate(true)
	candidate.cycle += 1
	candidate.enemies = {}
	candidate.hp = controller.actor_resources.health.capacity
	candidate.room = str(candidate.rest.room)
	candidate.entry = ""
	if not state.commit(candidate,state.revision):
		status = "死亡恢复保存失败："+state.error
		busy = false
		return
	controller.actor_resources.health.configure(controller.actor_resources.health_definition)
	controller.active = true
	lifetime.active = true
	lifetime.epoch += 1
	load_room(str(candidate.room),"")

func submit_damage(source: StringName,kind: DamageRequest.Kind,amount: float,event: StringName) -> void:
	if policy == null or not lifetime.active: return
	var request := DamageRequest.new()
	request.source_id = source
	request.event_id = event
	request.target_id = &"player"
	request.token = lifetime.token()
	request.actor_epoch = lifetime.actor_epoch
	request.health_epoch = controller.actor_resources.health.epoch
	request.kind = kind
	request.amount = amount
	policy.submit(request)

func toggle_pause() -> void:
	if busy or controller == null or (policy != null and policy.has_pending_player_damage()): return
	paused = not paused
	controller.router.clear("pause")
	q_guard.cancel()
	get_tree().paused = paused
	menu.visible = paused

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE: toggle_pause()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M: show_map()

func return_title() -> void:
	if not state.commit(_snapshot(),state.revision):
		status = state.error
		return
	_ticket += 1
	get_tree().paused = false
	paused = false
	busy = false
	lifetime.end()
	controller.router.clear("title")
	controller.shoot_ability.clear_projectiles()
	player.queue_free()
	player = null
	controller = null
	room.queue_free()
	room = null
	policy.queue_free()
	policy = null
	menu.hide()
	title.show()
	music.request_track(&"home")

func _update_hud() -> void:
	if hud == null: return
	var details := ""
	if controller != null:
		details = "%s   HP %d/%d   周期 %d   H %s\nA/D 移动 · 空格跳跃 · 鼠标瞄准并松开发射 · W 交互/休息 · M 地图 · Esc 暂停\n" % [state.value.room,controller.actor_resources.health.current,controller.actor_resources.health.capacity,state.value.cycle,"已获得" if state.has("H") else "未获得"]
		if room != null and room.encounter != null and not room.battle_finished: details += "牧风者 %d HP\n" % room.encounter.health.current
	hud.text = details + status

func _exit_tree() -> void:
	_ticket += 1
	get_tree().paused = false
	Engine.time_scale = 1.0
	lifetime.end()

func _restore_hp(amount: float) -> void:
	var definition := controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
	definition.initial_current = clampf(amount,1,definition.max_health)
	controller.actor_resources.health.configure(definition)

func show_map() -> void:
	if controller == null or busy: return
	if not paused: toggle_pause()
	if not paused: return
	var rows: PackedStringArray = ["已到达的房间（查看不增加探索记录）："]
	for id: String in state.value.explored:
		rows.append(("● " if id==room.room_id else "· ")+str(content.room(id).get("name",id)))
	map_label.text = "\n".join(rows)
