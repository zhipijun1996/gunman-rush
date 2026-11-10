class_name FixedWorldApp
extends Node2D
## Application use cases. Shared player/physics/services outlive each room.
var content := FixedWorldProvider.new()
var state := FixedWorldState.new()
# The geometry migration preview has its own slot; never reinterpret old positions.
var save_path := "user://fixed_world_plains04_construction.json"
var save_profile := "plains04_construction"
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
var introduction: WorldIntroSequence
var wave_encounter: WorldWaveEncounter
var title: Control
var q_guard: WorldRecoilGuard
var focus_heal: WorldFocusHeal
var story: WorldStorySequence
var rest_sequence: WorldRestSequence
var music: GameMusic
var ui: FixedWorldUI
var overlay: TouchOverlay
var services:=WorldServices.new()
var service_view:=WorldServicesView.new()
var preferences:=WorldSettings.new()
var settings_view:=WorldSettingsView.new()
var settings_path:="user://player_settings_v1.json"
var build_state: BuildState
var _service_ticket:=0
var _service_token: DemoToken
var _npc_id:=""
var _accepted_damage:=false
var _last_notice:=""
var review: WorldRoomReview
var workbench: WorldWorkbenchBridge


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
	review = WorldRoomReview.new()
	review.app = self
	workbench = WorldWorkbenchBridge.new()
	workbench.setup(self)
	if not workbench.enabled: review.requested()

func _make_ui() -> void:
	ui=FixedWorldUI.new()
	ui.world=state;ui.content=content
	add_child(ui)
	title=ui.title._root
	ui.command.connect(_ui_command)
	service_view.ui=ui;service_view.services=services
	service_view.input_device=func()->StringName:return controller.router.current_device if controller!=null else &"keyboard_mouse"
	settings_view.ui=ui;settings_view.settings=preferences
	settings_view.applied=func() -> void:
		_apply_preferences()
		_close_panel()
	_apply_preferences()

func _apply_preferences() -> void:
	preferences.apply(controller)
	if is_instance_valid(focus_heal):focus_heal.reduced=bool(preferences.value.reduced)
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
	controller.router.set_meta(&"world_up_interaction",true)
	HomeWeaponSelection.new().apply(controller)
	overlay=InputSetup.attach_menu(player,controller.router,toggle_pause)
	controller.enable_shot_energy()
	controller.motor.tuning.projectile_damage = float(content.data.player.starting_projectile_damage)
	preferences.apply(controller)
	if is_instance_valid(focus_heal):focus_heal.reduced=bool(preferences.value.reduced)
	if overlay.enabled: controller.router.touch_mouse_guard_until_usec=Time.get_ticks_usec()+InputRouter.TOUCH_MOUSE_GUARD_USEC
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerFeedback").hide()
	player.add_child(PlayerPresentationRuntime.make_body(player,controller,"PixelPlainsActor"))
	PlayerPresentationRuntime.attach(player)
	var carry_light := PlayerCarryLight.new()
	carry_light.settings = content.data.player.carry_light
	player.add_child(carry_light)
	build_state=BuildState.new()
	build_state.configure(controller,lifetime,&"fixed_world")
	build_state.commit_equipment_sources(services.effect_sources())
	_restore_hp(float(state.value.hp))
	controller.combat_energy.grant("world_restore",minf(float(state.value.get("combat_energy",0)),controller.combat_energy.capacity()))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.amount_applied<0: _accepted_damage=true)
	ui.bind(controller)
	q_guard = WorldRecoilGuard.new()
	q_guard.controller = controller
	q_guard.owned = state.has("Q")
	q_guard.cooldown_seconds = float(content.data.runtime_rules.q.cooldown_seconds)
	player.add_child(q_guard)
	var guard_visual:=WorldRecoilGuardVisual.new()
	guard_visual.guard=q_guard
	player.add_child(guard_visual)
	focus_heal=WorldFocusHeal.new()
	focus_heal.controller=controller;focus_heal.settings=content.data.player.focus_heal
	focus_heal.reduced=bool(preferences.value.reduced)
	player.add_child(focus_heal)
	focus_heal.ready_to_heal.connect(func() -> void: enqueue("focus_heal",""))
	RunComposition.attach_player_guides(player,controller)
	controller.interact_requested.connect(_interact)
	tutorial=WorldTutorial.new()
	tutorial.controller=controller;tutorial.state=state
	player.add_child(tutorial)
	tutorial.action_requested.connect(func(id: String) -> void: enqueue("action",id))
	camera = WorldCamera.new()
	(camera as WorldCamera).target=player
	(camera as WorldCamera).controller=controller
	(camera as WorldCamera).settings=content.data.player.camera
	add_child(camera)
	title.hide()
	music.request_track(&"plains")

func _acquire() -> int:
	if is_instance_valid(rest_sequence): rest_sequence.finish()
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
	next.configure(resolved.room)
	var draft: Dictionary = resolved.get("draft", {})
	if not draft.is_empty():
		var draft_error := WorldRoomDraft.apply(next, draft)
		if not draft_error.is_empty():
			next.free()
			busy = false
			status = "草稿无法装载："+draft_error
			return
	var previous_room := room
	var previous_position := player.position
	var ticket := _acquire()
	next.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	candidate=WorldTraveler.prepare(state,candidate,id)
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
		status = state.error if not state.error.is_empty() else "过门进度未保存，请离开门口后重试。"
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
	room.cycle_at_load=int(state.value.cycle)
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
	room.install_mechanisms(controller,lifetime,state.value.get("mechanisms",{}),func(id: String) -> void:enqueue("mechanism",id))
	_refresh_traveler()
	room.loot.pickup_requested.connect(func(id: String) -> void: enqueue("coin",id))
	_apply_capabilities()
	var bounds := FixedWorldProvider.rect(room.contract.world_geometry.bounds_world_units)
	(camera as WorldCamera).room=room
	(camera as WorldCamera).enter_room(bounds)
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
		_finish_room_entry("入口落脚中断，已恢复操作；可返回门口重试。")
		return
	var motion: Dictionary=content.data.player.entry_motion
	var entry_direction:="" if resolved.entry.get("front_door",false) else str(resolved.entry.get("direction",""))
	if entry_direction in ["left","right"]:
		var inward:=1.0 if entry_direction=="left" else -1.0
		player.reset_at(anchor-Vector2(inward*float(motion.walk_distance),1))
		await ui.finish_transition()
		for frame: int in ceili(float(motion.walk_seconds)/get_physics_process_delta_time()):
			await get_tree().physics_frame
			if ticket!=_ticket: return
			player.step(inward*float(motion.walk_axis),get_physics_process_delta_time())
		player.reset_motion()
	elif entry_direction=="up":
		player.reset_at(FixedWorldProvider.point(resolved.entry.landing_contract.entry_position_world_units))
		await ui.finish_transition()
		for frame: int in ceili(float(motion.timeout_seconds)/get_physics_process_delta_time()):
			await get_tree().physics_frame
			if ticket!=_ticket: return
			player.step(0,get_physics_process_delta_time())
			if player.is_on_floor() and absf(player.position.x-anchor.x)<4: break
	var upward_entry: bool=not resolved.entry.is_empty() and resolved.entry.direction=="down"
	if upward_entry:
		player.reset_at(FixedWorldProvider.point(resolved.entry.landing_contract.entry_position_world_units))
		await ui.finish_transition()
		controller.jump_ability.on_landed()
		controller.jump_ability.advance(get_physics_process_delta_time(),true)
		controller.jump_ability.request_jump()
		controller.jump_ability.try_jump(player)
	if entry_direction.is_empty(): await ui.finish_transition()
	if upward_entry:
		for frame: int in ceili(float(motion.timeout_seconds)/get_physics_process_delta_time()):
			await get_tree().physics_frame
			if ticket!=_ticket or not is_instance_valid(player): return
			if frame==ceili(float(motion.hop_hold_seconds)/get_physics_process_delta_time()):controller.jump_ability.release_jump(player)
			controller.jump_ability.update_hold(get_physics_process_delta_time(),player)
			player.step(clampf((anchor.x-player.position.x)/float(motion.hop_steering_distance),-float(motion.hop_axis),float(motion.hop_axis)),get_physics_process_delta_time())
			controller.jump_ability.after_move(player)
			if frame>1 and player.is_on_floor() and absf(player.position.x-anchor.x)<4: break
		controller.jump_ability.on_landed()
		player.reset_motion()
	if ticket!=_ticket or not is_instance_valid(player): return
	if entry_direction in ["up","down"] and (not player.is_on_floor() or player.position.distance_to(anchor)>8):
		_finish_room_entry("入口未抵达落脚面，已恢复操作；可返回门口重试。")
		return
	_finish_room_entry()

func _finish_room_entry(entry_issue: String = "") -> void:
	# Even an interrupted entry must finish the new room's ownership and restore input.
	player.reset_motion()
	controller._was_grounded = false
	controller.active = true
	busy = false
	_door_ready = false
	_queue.clear()
	music.request_track(&"home" if room.rest_point!=Vector2.ZERO or not room.find_children("*","WorldNpc",true,false).is_empty() else &"plains")
	status = room.arrival_text if not room.arrival_text.is_empty() else str(room.contract.name)
	tutorial.enter(room,player.position)
	introduction=WorldIntroSequence.new();introduction.app=self
	room.add_child(introduction);introduction.enter()
	story=WorldStorySequence.new();room.add_child(story);story.setup(self)
	wave_encounter=null
	if not room.wave_encounter.is_empty():
		wave_encounter=WorldWaveEncounter.new()
		room.add_child(wave_encounter);wave_encounter.setup(self)
	var carry:=player.get_node_or_null("CarryLight") as PointLight2D
	if carry!=null:carry.enabled=room.art_profile!="starbridge_graybox"
	_npc_id=""
	if not entry_issue.is_empty():status=entry_issue

func _apply_capabilities() -> void:
	var ice:WeaponDefinition=preload("res://resources/weapons/pulse_ice.tres")
	var primary:WeaponDefinition=preload("res://resources/weapons/pulse_gun.tres")
	var owns_ice:=state.has(str(services.definitions.get("smith_visit",{}).get("unlock_flag","skill_tier_1")))
	if controller.shoot_ability.weapon.mode==WeaponDefinition.Mode.PULSE:
		var desired:WeaponDefinition=ice if owns_ice else primary
		if controller.shoot_ability.weapon!=desired:controller.shoot_ability.equip(desired)
	var resonance: Dictionary=content.data.collection_rules.resonance
	controller.combat_energy.set_capacity_bonus(floorf(float(state.value.inventory.get("resonance_shard",0))/float(resonance.shards_per_upgrade))*float(resonance.capacity_gain_each))
	if build_state!=null: build_state.commit_equipment_sources(services.effect_sources())
	var rights: Dictionary={&"grapple":"H",&"double_jump":"D",&"wall_climb":"W"}
	for id: StringName in rights:
		var owned:=state.has(rights[id])
		if controller.traversal.has_capability(id)!=owned: controller.traversal.grant(id,owned)
	q_guard.owned = state.has("Q")
	if room != null:
		room.refresh_doors(state,content)
		_refresh_traveler()

func _snapshot() -> Dictionary:
	var candidate := state.value.duplicate(true)
	if controller != null:
		candidate.hp = maxf(1,controller.actor_resources.health.current)
		candidate.max_hp=controller.actor_resources.health.capacity
		candidate.combat_energy=controller.combat_energy.current
	if room != null and room.cycle_at_load==int(state.value.cycle): candidate.enemies.merge(room.snapshot(),true)
	if room!=null and room.loot!=null: room.loot.persist_into(candidate)
	if room!=null:
		if not candidate.has("mechanisms"):candidate.mechanisms={}
		candidate.mechanisms.merge(room.mechanism_snapshot(),true)
	return candidate

func enqueue(kind: String,id: String) -> void:
	if busy or paused or room == null or not lifetime.active: return
	_queue.append({"kind":kind,"id":id,"token":lifetime.token()})

func context_target() -> Dictionary:
	if room==null or player==null: return {}
	if is_instance_valid(introduction):
		var intro_target:=introduction.target()
		if not intro_target.is_empty():return intro_target
	var best: Dictionary={}
	var distance:=82.0
	for door: Dictionary in room.doors:
		if door.get("front_door",false) and player.position.distance_to(FixedWorldProvider.point(door.position_candidate.local_world_units)-Vector2(0,18))<72:
			return {"kind":"door","id":door.id,"label":str(door.get("label","进入"))}
	for npc: Node in room.find_children("*","WorldNpc",true,false):
		var d:=player.position.distance_to((npc as Node2D).position)
		if d<distance: best={"kind":"npc","id":npc.npc_id,"label":"交谈 · "+npc.display_name};distance=d
	if room.rest_point!=Vector2.ZERO:
		var d:=player.position.distance_to(room.rest_point)
		if d<70 and d<distance: best={"kind":"rest","id":room.room_id,"label":"充电 · 保存复位点"};distance=d
	if room.reward_point!=Vector2.ZERO and room.battle_finished and not state.value.receipts.has(room.reward_action):
		var d:=player.position.distance_to(room.reward_point)
		if d<80 and d<distance: best={"kind":"action","id":room.reward_action,"label":room.reward_text};distance=d
	for host: WorldRoomInteraction in room.interaction_hosts:
		var d:=player.position.distance_to(host.position)
		if d<distance and host.available(player.position,room.section_at(player.position)):
			best={"kind":"action","id":host.action_id,"label":host.label};distance=d
	for pickup: Dictionary in services.definitions.get("pickups",[]):
		if pickup.room_id!=room.room_id or pickup.id in services.ledger().collected: continue
		var d:=player.position.distance_to(FixedWorldProvider.point(pickup.point))
		if d<65 and d<distance: best={"kind":"pickup","id":pickup.id,"label":"拾取 · "+pickup.label};distance=d
	if best.is_empty():
		for i: int in room.signs.size():
			if player.position.distance_to(room.signs[i].interaction_point)<90:
				return {"kind":"sign","id":str(i),"label":"阅读"}
	return best

func _interact() -> void:
	if busy or paused or room==null: return
	var target:=context_target()
	if not target.is_empty():
		# A real interaction consumes this shared up gesture, including non-modal pickups.
		controller.router.camera_activity_serial += 1
		enqueue(target.kind,target.id)

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
	if player.is_on_floor():
		for retry: Dictionary in room.retry_anchors:
			if FixedWorldProvider.rect(retry.bounds).has_point(player.position) and room.section_at(player.position)==str(retry.get("section","main")):
				entry_anchor=FixedWorldProvider.point(retry.point)
	for enemy_id: String in room.enemies:
		var key:="income:enemy:"+enemy_id+":cycle:"+str(room.cycle_at_load)
		if room.enemies[enemy_id].definition.behavior_id != &"chime_target" and room.enemies[enemy_id].health.terminal and not state.value.receipts.has(key): enqueue("income",enemy_id)
	if _accepted_damage:
		_accepted_damage=false
		if state.commit(services.damage_candidate(_snapshot()),state.revision): _apply_capabilities()
	var entering_battle := not room.battle_started
	room.update_battle(player.position)
	if entering_battle and room.battle_started:
		# Authored entering-side refuge remains supported after the central bridge breaks.
		entry_anchor = room.battle_entry_anchor
	if room.encounter != null and room.encounter.health.terminal and not room.battle_finished:
		enqueue("action",room.defeat_action)
	for action: Dictionary in content.actions_in(room.room_id):
		if action.room_id==room.room_id and str(action.get("section_id","main"))==room.section_at(player.position) and action.type=="automatic_landmark" and not state.value.receipts.has(action.id): enqueue("action",action.id)
	if player.position.y > float(room.contract.world_geometry.bounds_world_units[3])+64:
		_fail_terrain()
	var near_door := false
	for door: Dictionary in room.doors:
		if door.get("front_door",false):continue
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
		elif request.kind == "mechanism":_commit_mechanism(str(request.id))
		elif request.kind == "focus_heal": _commit_focus_heal()
		elif request.kind == "rest": _rest()
		elif request.kind == "door": _cross(str(request.id))
		elif request.kind == "intro_pickup" and is_instance_valid(introduction):introduction.pickup()
		elif request.kind == "npc": _open_npc(str(request.id))
		elif request.kind == "sign":
			if _pause_world():
				var sign: Dictionary=room.signs[int(request.id)]
				var action_id:=str(sign.get("action_ref",""))
				if not action_id.is_empty() and not state.value.receipts.has(action_id):
					var candidate:=state.action_candidate(action_id,room.room_id,room.section_at(player.position))
					if not candidate.is_empty():state.commit(candidate,state.revision)
				GameAudio.cue(self,&"confirm")
				var panel:=ui.panel("dialogue",WorldText.text("dialogue.sign"),str(room.signs[int(request.id)].text))
				panel.button(WorldText.text("dialogue.close"),_close_panel);panel.focus_first()
		elif request.kind == "pickup":
			if services.request("collect",str(request.id),"pickup:"+str(request.id),state.revision):
				status="零件已收好，回小站交给回收匠。"
				GameAudio.cue(self,&"confirm")
				room.celebrate_service_pickup(str(request.id));room.queue_redraw()
		elif request.kind == "income":
			if (room.enemies[str(request.id)] as EnemyActor).definition.behavior_id == &"chime_target": continue
			var source:="enemy:"+str(request.id)+":cycle:"+str(room.cycle_at_load)
			var actor: EnemyActor=room.enemies[str(request.id)]
			var candidate:=_drop_candidate(_snapshot(),source,int(services.definitions.enemy_gold),actor.motor.position)
			if not candidate.is_empty(): state.commit(candidate,state.revision)
		elif request.kind == "coin":
			if not room.loot.can_collect(str(request.id)): continue
			var candidate:=services.collect_coin_candidate(_snapshot(),str(request.id))
			if not candidate.is_empty() and state.commit(candidate,state.revision):
				room.loot.sync();GameAudio.cue(self,&"coin")
				var feedback:=player.get_node_or_null("PlayerFeedback") as PlayerFeedback
				if feedback!=null: feedback.reward_received(player.global_position,false)

func _drop_candidate(candidate: Dictionary,id: String,amount: int,origin: Vector2) -> Dictionary:
	var safe:=entry_anchor
	var ray:=PhysicsRayQueryParameters2D.create(origin,origin+Vector2(0,2048),1)
	var hit:=get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP)>.65: safe=(hit.position as Vector2)-Vector2(0,12)
	if id.begins_with("boss:"): safe=room.battle_entry_anchor
	return services.drop_candidate(candidate,id,WorldCoinDrops.create_units(id,amount,origin,safe,room.room_id))

func _commit_mechanism(id: String) -> void:
	var latch:=room.mechanisms.get(id) as WorldShotLatch
	if latch==null or not latch.can_commit():return
	var candidate:=_snapshot();candidate.mechanisms[id]=latch.proposed_state()
	if not state.commit(candidate,state.revision):
		status="机关尚未保存，请再敲一次铃。";latch.cancel_pending();return
	latch.accept_committed()

func _commit_action(id: String) -> void:
	var action:=content.action(id)
	if state.value.receipts.has(id) and not bool(action.get("repeat",false)): return
	var host:=room.physical_action(id)
	var section:=room.section_at(player.position)
	if host!=null and not host.available(player.position,section):return
	if host==null and action.get("type","") not in ["tutorial","automatic_landmark","boss_defeat"] and id!=room.reward_action:return
	if action.get("type","")=="boss_defeat" and (room.encounter==null or not room.encounter.health.terminal):return
	var candidate := state.action_candidate(id,room.room_id,section)
	if candidate.is_empty(): return
	candidate.hp = controller.actor_resources.health.current
	candidate.combat_energy=controller.combat_energy.current
	if room.cycle_at_load==int(state.value.cycle): candidate.enemies.merge(room.snapshot(),true)
	if host!=null and action.get("type","")=="chest" and int(action.get("coin_drop_amount",0))>0:
		candidate=_drop_candidate(candidate,"chest:"+id,int(action.coin_drop_amount),host.position)
	if id==room.defeat_action: candidate=_drop_candidate(candidate,"boss:"+str(room.boss_identity),int(services.definitions.boss_gold),room.boss.position)
	if not state.commit(candidate,state.revision):
		status = "保存失败，结果未提交："+state.error
		return
	if id == room.defeat_action: room.finish_battle()
	if host!=null:
		host.celebrate()
		if id=="repair_P" and is_instance_valid(story):story.play_repair.call_deferred(host.position)
		if content.action(id).type=="local_return":GameAudio.cue(self,&"bell")
		else:GameAudio.cue_committed_reward(self,&"item_get",&"confirm")
	if id == room.reward_action: GameAudio.cue(self,&"confirm")
	_apply_capabilities()
	status=WorldText.text("action."+id,str(content.action(id).get("description","进度已保存")))

func _cross(id: String) -> void:
	if room.battle_started and not room.battle_finished: return
	for door: Dictionary in room.doors:
		if door.id != id: continue
		# Consume the approach before any async work, including rejected or failed entries.
		# Leaving the trigger rearms it; a rollback must not retry every frame.
		_door_ready = false
		if not door.outbound_allowed or not state.holds(door.requires):
			status = "通路尚未开启，请先完成本处教学或事件。"
			return
		if content.room(str(door.target_room)).is_empty():
			status = "前方区域尚未施工，请循已开放的墙面缺口继续探索。"
			return
		busy = true
		load_room.call_deferred(str(door.target_room),str(door.target_door_id))

func _rest() -> void:
	if is_instance_valid(rest_sequence) and rest_sequence.active:return
	rest_sequence=WorldRestSequence.new()
	add_child(rest_sequence)
	if not rest_sequence.begin(self):rest_sequence.queue_free()

func _commit_rest() -> bool:
	var candidate := services.rest_candidate(_snapshot())
	candidate.cycle += 1
	candidate.enemies = {}
	candidate.hp = controller.actor_resources.health.capacity
	candidate.entry=""
	candidate.rest = {"room":room.room_id,"entry":"","point":[room.rest_point.x,room.rest_point.y]}
	if not state.commit(candidate,state.revision):
		status = state.error
		return false
	_restore_hp(float(candidate.hp))
	controller.router.clear("explicit_rest")
	controller.shoot_ability.clear_projectiles()
	q_guard.cancel()
	status=WorldText.text("rest.completed")
	return true

func _fail_terrain() -> void:
	var safety := SegmentRespawn.new()
	safety.configure(controller,lifetime)
	if not safety.is_safe(entry_anchor):
		status = "进入侧锚点不可用，暂停恢复。"
		controller.active = false
		return
	controller.router.clear("terrain_return")
	controller.shoot_ability.clear_projectiles()
	ui.begin_transition()
	player.reset_at(entry_anchor-Vector2(0,1))
	(camera as WorldCamera).reset_view()
	ui.finish_transition()
	lifetime.invalidate_actor()
	controller.session_id += 1
	q_guard.cancel()
	state.commit(_snapshot(),state.revision)
	status = "返回本次实际进入侧；周期与已提交结果保留。"

func _recover_death() -> void:
	tutorial.reset_proof()
	var death_snapshot:=services.damage_candidate(state.value.duplicate(true)) if _accepted_damage else state.value.duplicate(true)
	if room!=null:
		if not death_snapshot.has("mechanisms"):death_snapshot.mechanisms={}
		death_snapshot.mechanisms.merge(room.mechanism_snapshot(),true)
	_accepted_damage=false
	var candidate := services.rest_candidate(death_snapshot)
	candidate.cycle += 1
	candidate.enemies = {}
	candidate.hp = controller.actor_resources.health.capacity
	candidate.combat_energy=0.0
	candidate.room = str(candidate.rest.room)
	candidate.entry = ""
	if not state.commit(candidate,state.revision):
		status = "死亡恢复保存失败："+state.error
		busy = false
		return
	controller.combat_energy.reset()
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
	if is_instance_valid(rest_sequence) and rest_sequence.active:
		if rest_sequence.suspended:_close_panel()
		else:rest_sequence.suspend(true);ui.show_pause()
	elif paused: _close_panel()
	elif _pause_world(): ui.show_pause()
func _close_panel() -> void:
	if is_instance_valid(rest_sequence) and rest_sequence.active:
		ui.close();rest_sequence.suspend(false);return
	if is_instance_valid(story) and story.active:
		story.advance();return
	if is_instance_valid(introduction) and introduction.dialogue_active:
		introduction.advance();return
	_service_ticket+=1
	_npc_id=""
	ui.close()
	if controller!=null:
		get_viewport().gui_release_focus()
		controller.router.clear("panel_close")
		var keyboard:=player.get_node_or_null("KeyboardMouseAdapter") as KeyboardMouseAdapter
		if keyboard!=null: keyboard.observe_current_key_neutral()
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
	if is_instance_valid(rest_sequence) and rest_sequence.active:return
	if is_instance_valid(story) and story.active:return
	if is_instance_valid(introduction) and introduction.dialogue_active:return
	if controller!=null and (paused or _pause_world()): ui.show_map()
func _ui_command(kind: String,_id: String) -> void:
	if is_instance_valid(rest_sequence) and rest_sequence.active and kind not in ["pause","close","title"]:return
	if is_instance_valid(story) and story.active and kind not in ["close","title"]:return
	if is_instance_valid(introduction) and introduction.dialogue_active and kind not in ["close","title"]:return
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
		"title":
			if review.active: review.leave()
			else: return_title()
		"review": review.show()
		"inventory":
			if controller!=null and (paused or _pause_world()):
				_service_ticket+=1
				_service_token=lifetime.token()
				_npc_id=""
				service_view.submit=_submit_service.bind(_service_ticket)
				service_view.show_inventory()
		"heal_hold":
			if controller!=null and (_id=="0" or (not busy and not paused)): controller.router.set_focus_heal_held(&"touch",_id=="1")
		"settings": _show_settings()
		"help":
			var modal:=ui.panel("help","操作说明",WorldText.text("world.controls"))
			modal.button("返回",_close_panel)
func _start_from_title() -> void:
	ui.close()
	if not start_new():
		ui.root.hide()
		ui.title.show_notice(status)

func _open_npc(id: String) -> void:
	for node: Node in room.find_children("*","WorldNpc",true,false):
		if node.npc_id==id: node.greet()
	if not _pause_world(): return
	_service_ticket+=1;_service_token=lifetime.token();_npc_id=id
	var identity:=_npc(id)
	if id==WorldTraveler.ID:
		var candidate:=WorldTraveler.talk_candidate(state,room.room_id)
		if not candidate.is_empty():state.commit(candidate,state.revision)
	else: services.request("meet",id,"meet:"+id,state.revision)
	service_view.submit=_submit_service.bind(_service_ticket)
	GameAudio.cue(self,&"confirm")
	service_view.show_greeting(identity)
func _refresh_traveler() -> void:
	var eligible:=not WorldTraveler.chapter(state,room.room_id).is_empty()
	var existing: WorldNpc
	for node: Node in room.find_children("*","WorldNpc",true,false):
		if node.npc_id==WorldTraveler.ID:existing=node
	if not eligible:
		if existing!=null:room.remove_child(existing);existing.queue_free()
		return
	if existing!=null:return
	var npc:=WorldNpc.new();npc.npc_id=WorldTraveler.ID;npc.display_name="阿栖"
	var story:=WorldTraveler.chapter(state,room.room_id)
	npc.chapter=str(story.get("visual_chapter",story.get("id","")))
	npc.position=room.traveler_point
	room.add_child(npc)
func _npc(id: String) -> Dictionary:
	if id==WorldTraveler.ID:return WorldTraveler.identity(state,room.room_id)
	for npc: Dictionary in content.data.get("npcs",[]):
		if npc.id==id:
			var identity:=npc.duplicate(true)
			if room!=null and room.room_id in npc.get("visit_rooms",[]):identity.room_id=room.room_id
			return identity
	return {}
func _submit_service(kind: String,id: String,revision: int,ticket: int) -> void:
	if not paused or busy or ticket!=_service_ticket or not lifetime.accepts(_service_token) or controller.actor_resources.health.terminal or policy.has_pending_player_damage(): return
	var required_service:=WorldServices.required_service(kind)
	if not required_service.is_empty() and required_service not in _npc(_npc_id).get("services",[]): return
	_sequence+=1
	var accepted:=services.request(kind,id,"%d:%d" % [state.revision,_sequence],revision)
	if accepted:
		if kind in ["deliver","smith_install"]: GameAudio.cue(self,&"confirm")
		if room!=null: room.queue_redraw()
		_apply_capabilities()
		if kind=="use":
			var health:=controller.actor_resources.health
			health.heal(ActorResourceRequest.new(StringName("world_heal:"+str(state.revision)),health.epoch,float(state.value.hp)-health.current,health.get_instance_id()))
	var message:=("冰弹已安装。" if kind=="smith_install" else "已保存。") if accepted else services.reason()
	if _npc_id.is_empty(): service_view.show_inventory(message)
	else: service_view.show_npc(_npc(_npc_id),message)
func _show_settings() -> void:
	if controller!=null and not paused and not _pause_world(): return
	settings_view.show()

func return_title() -> void:
	if not state.commit(_snapshot(),state.revision):
		status = state.error
		return
	if is_instance_valid(rest_sequence):rest_sequence.finish()
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
	if room != null: room.queue_free()
	room = null
	if policy != null: policy.queue_free()
	policy = null
	ui.unbind()
	if is_instance_valid(camera): camera.queue_free()
	build_state=null
	music.request_track(&"home")

func _update_hud() -> void:
	if ui==null or controller==null: return
	ui.hud.present_recoil_guard(q_guard.owned,q_guard.landing_ready and q_guard.cooldown<=0,q_guard.is_protecting(),q_guard.cooldown,q_guard.cooldown_seconds)
	var target:=context_target()
	if room!=null:
		var highlight:=Vector2.INF
		match target.get("kind",""):
			"sign": highlight=room.signs[int(target.id)].interaction_point
			"rest": highlight=room.rest_point
			"door":
				for door:Dictionary in room.doors:
					if door.id==target.id:highlight=FixedWorldProvider.point(door.position_candidate.local_world_units)-Vector2(0,18)
			"action": highlight=room.reward_point
			"pickup":
				for pickup: Dictionary in services.definitions.pickups:
					if pickup.id==target.id: highlight=FixedWorldProvider.point(pickup.point)
		if room.interaction_point!=highlight:
			room.interaction_point=highlight;room.queue_redraw()
		for npc: Node in room.find_children("*","WorldNpc",true,false):
			npc.highlighted=target.get("kind","")=="npc" and target.get("id","")==npc.npc_id
	var notice:=status
	if room!=null and room.encounter!=null and not room.battle_finished: notice="%s · %d HP" % [room.encounter.definition.display_name,room.encounter.health.current]
	ui.present(controller,str(state.value.room),str(content.room(state.value.room).get("name","")),notice,str(target.get("label","")),int(services.ledger().gold),bool(preferences.value.reduced),focus_heal.ratio(),focus_heal.available())

func _exit_tree() -> void:
	if is_instance_valid(rest_sequence):rest_sequence.finish()
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
	candidate.combat_energy=controller.combat_energy.current
	if room!=null and room.cycle_at_load==int(state.value.cycle): candidate.enemies.merge(room.snapshot(),true)
	return candidate

func _commit_focus_heal() -> void:
	if not focus_heal.pending: return
	if busy or paused or not lifetime.active or not focus_heal.available() or not controller.router.focus_heal_held():
		focus_heal.resolve(false);return
	var settings: Dictionary=content.data.player.focus_heal
	var health:=controller.actor_resources.health
	var energy:=controller.combat_energy
	var candidate:=_snapshot()
	var event:="focus_heal:"+str(state.revision+1)
	candidate.hp=minf(health.capacity,health.current+float(settings.heal))
	candidate.combat_energy=energy.current-float(settings.cost)
	if not state.commit(candidate,state.revision):
		status=WorldText.text("heal.save_failed");focus_heal.resolve(false);return
	var spent:=energy.consume(event,float(settings.cost))
	var result:=health.heal(ActorResourceRequest.new(StringName(event),health.epoch,float(settings.heal),health.get_instance_id()))
	assert(spent and result.accepted(),"Preflighted resource commit must remain synchronous")
	focus_heal.resolve(true)

