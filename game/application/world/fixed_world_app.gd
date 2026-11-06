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
var tutorial: WorldTutorial
var title: Control
var q_guard: WorldRecoilGuard
var music: GameMusic
var ui: FixedWorldUI
var overlay: TouchOverlay
var services:=WorldServices.new()
var service_view:=WorldServicesView.new()
var preferences:=WorldSettings.new()
var settings_view:=WorldSettingsView.new()
var settings_path:="user://player_settings_v1.json"
var build_state: BuildState
var parallax: UnderworldParallax
var _service_ticket:=0
var _service_token: DemoToken
var _npc_id:=""
var _accepted_damage:=false
var _last_notice:=""


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
	services.prepare_candidate=_prepare_service_candidate
	services.state=state
	services.definitions=content.data.get("demo_services",{})
	preferences.open(settings_path,save_profile)
	preferences.apply(null)
	WorldText.configure(content.data.get("ui_texts",{}))
	_make_ui()

func _make_ui() -> void:
	ui=FixedWorldUI.new()
	ui.world=state;ui.content=content
	add_child(ui)
	title=ui.title._root
	ui.command.connect(_ui_command)
	service_view.ui=ui;service_view.services=services
	settings_view.ui=ui;settings_view.settings=preferences
	settings_view.applied=func() -> void:
		_apply_preferences()
		_close_panel()
	_apply_preferences()

func _apply_preferences() -> void:
	preferences.apply(controller)
	if overlay!=null: overlay.update_layout()
	ui.title._reduced_effects=preferences.value.reduced
	var backdrop:=ui.title._root.find_child("TitleBackdrop",true,false)
	if backdrop!=null: backdrop.set("reduced_effects",preferences.value.reduced)

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
	_fatal = false
	_return = false
	_queue.clear()
	_accepted_damage=false
	player = preload("res://game/player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	HomeWeaponSelection.new().apply(controller)
	overlay=InputSetup.attach_menu(player,controller.router,toggle_pause)
	controller.enable_shot_energy()
	controller.motor.tuning.projectile_damage = float(content.data.player.starting_projectile_damage)
	preferences.apply(controller)
	if overlay.enabled: controller.router.touch_mouse_guard_until_usec=Time.get_ticks_usec()+InputRouter.TOUCH_MOUSE_GUARD_USEC
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	player.add_child(PlayerPresentationRuntime.make_body(player,controller,"PixelPlainsActor"))
	PlayerPresentationRuntime.attach(player)
	build_state=BuildState.new()
	build_state.configure(controller,lifetime,&"fixed_world")
	build_state.commit_equipment_sources(services.effect_sources())
	_restore_hp(float(state.value.hp))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.amount_applied<0: _accepted_damage=true)
	ui.bind(controller)
	q_guard = WorldRecoilGuard.new()
	q_guard.controller = controller
	q_guard.owned = state.has("Q")
	q_guard.cooldown_seconds = float(content.data.runtime_rules.q.cooldown_seconds)
	player.add_child(q_guard)
	RunComposition.attach_player_guides(player,controller)
	controller.interact_requested.connect(_interact)
	tutorial=WorldTutorial.new()
	tutorial.controller=controller;tutorial.state=state
	player.add_child(tutorial)
	tutorial.action_requested.connect(func(id: String) -> void: enqueue("action",id))
	camera = Camera2D.new()
	camera.zoom = Vector2(1.6,1.6)
	camera.position_smoothing_enabled = false
	player.add_child(camera)
	parallax=UnderworldParallax.new()
	parallax.configure(camera)
	add_child(parallax)
	title.hide()
	music.request_track(&"plains")

func _acquire() -> int:
	_ticket += 1
	busy = true
	ui.begin_transition()
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
	next.visible=false
	add_child(next)
	next.refresh_doors(state,content)
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
		await ui.finish_transition()
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
		await ui.finish_transition()
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
	room.visible=true
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
	room.install(controller,policy,lifetime,state.value.enemies,state.has(room.defeat_flag),entry_anchor)
	room.bind_services(services,controller,policy,lifetime)
	_apply_capabilities()
	var bounds := FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.zoom = Vector2(1.6,1.6)
	# Land at the authored near-side ledge; no automatic leap across the new room.
	player.reset_at(anchor-Vector2(0,1))
	var landed := false
	for i: int in 30:
		await get_tree().physics_frame
		if ticket != _ticket: return
		player.step(0,get_physics_process_delta_time())
		if player.is_on_floor():
			landed=true
			break
	if not landed:
		await ui.finish_transition()
		status="入口缺少实际支撑，请返回标题后继续。"
		busy=false
		return
	await ui.finish_transition()
	if ticket!=_ticket or not is_instance_valid(player): return
	controller._was_grounded = false
	controller.active = true
	busy = false
	_door_ready = false
	_queue.clear()
	music.request_track(&"home" if not room.find_children("*","WorldNpc",true,false).is_empty() else &"plains")
	status = room.arrival_text if not room.arrival_text.is_empty() else str(room.contract.name)
	tutorial.enter(room,player.position)
	_npc_id=""
	for enemy_id: String in room.enemies:
		var actor: EnemyActor=room.enemies[enemy_id]
		actor.defeated.connect(func(_actor: EnemyActor) -> void: enqueue("income",enemy_id))

func _apply_capabilities() -> void:
	if build_state!=null: build_state.commit_equipment_sources(services.effect_sources())
	var rights: Dictionary={&"grapple":"H",&"double_jump":"D",&"wall_climb":"W"}
	for id: StringName in rights:
		var owned:=state.has(rights[id])
		if controller.traversal.has_capability(id)!=owned: controller.traversal.grant(id,owned)
	q_guard.owned = state.has("Q")
	if room != null: room.refresh_doors(state,content)

func _snapshot() -> Dictionary:
	var candidate := state.value.duplicate(true)
	if controller != null:
		candidate.hp = maxf(1,controller.actor_resources.health.current)
		candidate.max_hp=controller.actor_resources.health.capacity
	if room != null: candidate.enemies.merge(room.snapshot(),true)
	return candidate

func enqueue(kind: String,id: String) -> void:
	if busy or paused or room == null or not lifetime.active: return
	_queue.append({"kind":kind,"id":id,"token":lifetime.token()})

func context_target() -> Dictionary:
	if room==null or player==null: return {}
	var best: Dictionary={}
	var distance:=82.0
	for npc: Node in room.find_children("*","WorldNpc",true,false):
		var d:=player.position.distance_to((npc as Node2D).position)
		if d<distance: best={"kind":"npc","id":npc.npc_id,"label":"交谈 · "+npc.display_name};distance=d
	if room.rest_point!=Vector2.ZERO:
		var d:=player.position.distance_to(room.rest_point)
		if d<70 and d<distance: best={"kind":"rest","id":room.room_id,"label":"休息 · 保存复活点"};distance=d
	if room.reward_point!=Vector2.ZERO and room.battle_finished and not state.value.receipts.has(room.reward_action):
		var d:=player.position.distance_to(room.reward_point)
		if d<80 and d<distance: best={"kind":"action","id":room.reward_action,"label":room.reward_text};distance=d
	for pickup: Dictionary in services.definitions.get("pickups",[]):
		if pickup.room_id!=room.room_id or pickup.id in services.ledger().collected: continue
		var d:=player.position.distance_to(FixedWorldProvider.point(pickup.point))
		if d<65 and d<distance: best={"kind":"pickup","id":pickup.id,"label":"拾取 · "+pickup.label};distance=d
	return best

func _interact() -> void:
	if busy or paused or room==null: return
	var target:=context_target()
	if not target.is_empty(): enqueue(target.kind,target.id)

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
	if _accepted_damage:
		_accepted_damage=false
		if state.commit(services.damage_candidate(_snapshot()),state.revision): _apply_capabilities()
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
		enqueue("action",room.defeat_action)
	for action: Dictionary in content.actions_in(room.room_id):
		if action.room_id==room.room_id and action.type=="automatic_landmark" and not state.value.receipts.has(action.id): enqueue("action",action.id)
	if player.position.y > float(room.contract.world_geometry.bounds_world_units[3])-64 and not _near_lower_door():
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
		elif request.kind == "npc": _open_npc(str(request.id))
		elif request.kind == "pickup":
			if services.request("collect",str(request.id),"pickup:"+str(request.id),state.revision): status="零件已收好，回小站交给回收匠。"
		elif request.kind == "income":
			state.commit(services.earned_candidate(_snapshot(),"enemy:"+str(request.id)+":cycle:"+str(int(state.value.cycle)),int(services.definitions.enemy_gold)),state.revision)

func _commit_action(id: String) -> void:
	if state.value.receipts.has(id): return
	var candidate := state.action_candidate(id,room.room_id)
	if candidate.is_empty(): return
	candidate.hp = controller.actor_resources.health.current
	candidate.enemies.merge(room.snapshot(),true)
	if id==room.defeat_action: candidate=services.earned_candidate(candidate,"boss:"+str(room.boss_identity),int(services.definitions.boss_gold))
	if not state.commit(candidate,state.revision):
		status = "保存失败，结果未提交："+state.error
		return
	if id == room.defeat_action: room.finish_battle()
	_apply_capabilities()
	status=WorldText.text("action."+id,str(content.action(id).get("description","进度已保存")))

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
	var candidate := services.rest_candidate(_snapshot())
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
	tutorial.reset_proof()
	var death_snapshot:=services.damage_candidate(state.value.duplicate(true)) if _accepted_damage else state.value.duplicate(true)
	_accepted_damage=false
	var candidate := services.rest_candidate(death_snapshot)
	candidate.cycle += 1
	candidate.enemies = {}
	candidate.hp = controller.actor_resources.health.capacity
	candidate.room = str(candidate.rest.room)
	candidate.entry = ""
	if not state.commit(candidate,state.revision):
		status = "死亡恢复保存失败："+state.error
		busy = false
		return
	_restore_hp(float(candidate.hp))
	controller.active = true
	lifetime.active = true
	lifetime.epoch += 1
	load_room(str(candidate.room),"")

func submit_damage(source: StringName,kind: DamageRequest.Kind,amount: float,event: StringName,category: StringName=&"solid") -> void:
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
	request.hazard_category=category
	policy.submit(request)

func _pause_world() -> bool:
	if busy or controller==null or (policy!=null and policy.has_pending_player_damage()): return false
	controller.router.clear("world_panel")
	q_guard.cancel()
	paused=true;get_tree().paused=true
	return true
func toggle_pause() -> void:
	if paused: _close_panel()
	elif _pause_world(): ui.show_pause()
func _close_panel() -> void:
	_service_ticket+=1
	_npc_id=""
	ui.close()
	if controller!=null:
		controller.router.clear("panel_close")
		if overlay.enabled: controller.router.touch_mouse_guard_until_usec=Time.get_ticks_usec()+InputRouter.TOUCH_MOUSE_GUARD_USEC
		paused=false;get_tree().paused=false
	else:
		ui.root.hide()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index==JOY_BUTTON_START: toggle_pause()
		elif event.button_index==JOY_BUTTON_BACK: show_map()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE: toggle_pause()
		elif event.physical_keycode==KEY_M: show_map()
		elif event.physical_keycode==KEY_I: _ui_command("inventory","")
func show_map() -> void:
	if controller!=null and (paused or _pause_world()): ui.show_map()
func _ui_command(kind: String,_id: String) -> void:
	match kind:
		"new":
			if state.storage._exists(false):
				var modal:=ui.panel("confirm","开始新的旅途？","这会替换当前世界存档，用户设置保留。")
				modal.button("确认新游戏",_start_from_title)
				modal.button("取消",_close_panel)
			else: _start_from_title()
		"continue":
			if not continue_world(): ui.title.show_notice(status)
		"pause": toggle_pause()
		"close": _close_panel()
		"map": show_map()
		"interact": _interact()
		"title": return_title()
		"inventory":
			if controller!=null and (paused or _pause_world()):
				_service_ticket+=1
				_service_token=lifetime.token()
				_npc_id=""
				service_view.submit=_submit_service.bind(_service_ticket)
				service_view.show_inventory()
		"settings": _show_settings()
		"help":
			var modal:=ui.panel("help","操作说明","A/D 移动，空格跳跃；鼠标瞄准，松开发射；W或场景交互按钮交谈/休息/拾取；M地图，I背包。手机使用摇杆/跳跃/HOOK和屏幕交互按钮。")
			modal.button("返回",_close_panel)
func _start_from_title() -> void:
	ui.close()
	if not start_new():
		ui.root.hide()
		ui.title.show_notice(status)

func _open_npc(id: String) -> void:
	if not _pause_world(): return
	_service_ticket+=1;_service_token=lifetime.token();_npc_id=id
	services.request("meet",id,"meet:"+id,state.revision)
	service_view.submit=_submit_service.bind(_service_ticket)
	service_view.show_npc(_npc(id))
func _npc(id: String) -> Dictionary:
	for npc: Dictionary in content.data.get("npcs",[]):
		if npc.id==id: return npc
	return {}
func _submit_service(kind: String,id: String,revision: int,ticket: int) -> void:
	if not paused or busy or ticket!=_service_ticket or not lifetime.accepts(_service_token) or controller.actor_resources.health.terminal or policy.has_pending_player_damage(): return
	if kind in ["buy","deliver"] and not "gear_delivery" in _npc(_npc_id).get("services",[]): return
	if kind in ["upgrade","repair"] and not "equipment_gold_upgrade" in _npc(_npc_id).get("services",[]): return
	_sequence+=1
	var accepted:=services.request(kind,id,"%d:%d" % [state.revision,_sequence],revision)
	if accepted:
		if kind=="deliver": GameAudio.cue(self,&"confirm")
		if room!=null: room.queue_redraw()
		_apply_capabilities()
		if kind=="use":
			var health:=controller.actor_resources.health
			health.heal(ActorResourceRequest.new(StringName("world_heal:"+str(state.revision)),health.epoch,float(state.value.hp)-health.current,health.get_instance_id()))
	var message:="已保存。" if accepted else services.reason()
	if _npc_id.is_empty(): service_view.show_inventory(message)
	else: service_view.show_npc(_npc(_npc_id),message)
func _show_settings() -> void:
	if controller!=null and not paused and not _pause_world(): return
	settings_view.show()

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
	ui.unbind()
	if is_instance_valid(parallax): parallax.queue_free()
	build_state=null
	music.request_track(&"home")

func _update_hud() -> void:
	if ui==null or controller==null: return
	var target:=context_target()
	var notice:=status
	if room!=null and room.encounter!=null and not room.battle_finished: notice="%s · %d HP" % [room.encounter.definition.display_name,room.encounter.health.current]
	ui.present(controller,str(state.value.room),str(content.room(state.value.room).get("name","")),notice,str(target.get("label","")),int(services.ledger().gold),bool(preferences.value.reduced))

func _exit_tree() -> void:
	_ticket += 1
	get_tree().paused = false
	Engine.time_scale = 1.0
	lifetime.end()

func _restore_hp(amount: float) -> void:
	var definition := controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
	definition.max_health=controller.actor_resources.health.capacity
	definition.initial_current = clampf(amount,1,definition.max_health)
	controller.actor_resources.health.configure(definition)


func _prepare_service_candidate(candidate: Dictionary) -> Dictionary:
	if controller==null or build_state==null: return candidate
	var preview:=build_state.preview_sources(services.effect_sources(candidate.services))
	if not preview.accepted: return {}
	candidate.hp=minf(float(candidate.hp),float(preview.values[&"max_health"]))
	candidate.max_hp=float(preview.values[&"max_health"])
	if room!=null: candidate.enemies.merge(room.snapshot(),true)
	return candidate

func _near_lower_door() -> bool:
	for door: Dictionary in room.doors:
		if door.direction=="down" and player.position.distance_to(FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units))<80: return true
	return false
