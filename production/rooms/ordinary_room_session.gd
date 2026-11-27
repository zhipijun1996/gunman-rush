class_name OrdinaryRoomSession
extends Node2D
## Host for one authored room. A world/transition owner can supply storage and
## progression; the standalone room never discovers a campaign or an old save.
@export_file("*.json") var document_path := ""
@export var profile_slot := ""
var equipment := EquipmentRuntime.new()
var equipment_menu: EquipmentMenu
var equipment_sites: Array[EquipmentSite] = []
var heal_base: Dictionary
@export var content_room_id := ""
@export_file("*.json") var content_lock_path := "res://config/imported_world/current.lock.json"
@export_file("*.json") var content_bindings_path := "res://config/imported_world/bindings.json"
var focus_heal: WorldFocusHeal
var audio_service: PlayerWeaponFeelAudioV2
signal sign_read(text: String)
var sign_reader: RoomSignReader
var recovery := RoomRecovery.new()
var room: FixedWorldRoom
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var services := WorldServices.new()
var drop_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/room_rewards.json"))
var state := FixedWorldState.new()
var pending_defeats: Dictionary = {}
var pending_death := {}
var retry_delay := 0.0
var content_catalog: WorldContentCatalog
var content_context: Dictionary = {}
var content_enemy_gold: Dictionary = {}

class RoomMemory extends WorldSaveService:
	func commit(_payload: Dictionary, _revision: int) -> bool:
		return true

func _ready() -> void:
	var storage: WorldSaveService
	if not profile_slot.is_empty():
		storage = WorldSaveService.new()
		storage.configure("user://equipment_%s.json" % profile_slot,OS.has_feature("web"),profile_slot)
	if not content_room_id.is_empty():
		var error := open_content(content_room_id, content_lock_path, content_bindings_path, storage)
		if not error.is_empty(): push_error(error)
	elif not document_path.is_empty():
		var error := open(WorldRoomDocument.read(document_path), storage)
		if not error.is_empty(): push_error(error)

func open_content(room_id: String, lock_path := "res://config/imported_world/current.lock.json", bindings_path := "res://config/imported_world/bindings.json", storage: WorldSaveService = null, allow_test_bindings := false, previous: OrdinaryRoomSession = null, entry_door_id := "") -> String:
	if room != null: return "room_already_open"
	var catalog := WorldContentCatalog.new()
	var result := catalog.load_locked(lock_path)
	if not result.get("ok", false): return str(result.error)
	result = catalog.load_bindings(bindings_path, allow_test_bindings)
	if not result.get("ok", false): return str(result.error)
	result = catalog.room_document(room_id)
	if not result.get("ok", false): return str(result.error)
	return open(WorldRoomDocument.read(result.path), storage, previous, catalog, entry_door_id)

func open(document: Dictionary, storage: WorldSaveService = null, previous: OrdinaryRoomSession = null, catalog: WorldContentCatalog = null, entry_door_id := "") -> String:
	if room != null: return "room_already_open"
	if document.has("error"): return str(document.error)
	if previous != null:
		var before := previous.content_catalog.bundle_sha256 if previous.content_catalog != null else ""
		var after := catalog.bundle_sha256 if catalog != null else ""
		if before != after: return "room_content_version_mismatch"
	if not document.get("exits", {}) is Dictionary: return "room_exits_invalid"
	var exits: Dictionary = document.get("exits", {})
	if not entry_door_id.is_empty() and not exits.has(entry_door_id):
		return "room_entry_unknown"
	var prepared := {}
	if catalog != null:
		prepared = WorldContentRoomBridge.prepare(document, catalog)
		if not prepared.get("ok", false): return str(prepared.error)
	elif document.has("content_bindings"):
		return "content_catalog_required"
	var root_row: Variant = document.get("root")
	if not root_row is Dictionary or not root_row.get("properties") is Dictionary: return "room_root_required"
	if not WorldRoomValidation.vector(root_row.properties.get("start_point")):
		return "room_spawn_required"
	var bounds_data: Variant = document.get("bounds")
	if not WorldRoomValidation.rectangle(bounds_data): return "room_bounds_required"
	var result := WorldRoomDocument.instantiate(document)
	if result.has("error"): return str(result.error)
	room = result.room
	var at := room.start_point
	if not entry_door_id.is_empty():
		at = FixedWorldProvider.point(exits[entry_door_id].spawn)
	var bounds := FixedWorldProvider.rect(bounds_data)
	if not bounds.has_point(at):
		room.free()
		room = null
		return "spawn_outside_room"
	var row := {"doors":[],"camera":{},"world_geometry":WorldRoomSpace.document_geometry(bounds_data,exits)}
	row["exits"] = exits
	room.configure(row)
	state.content = FixedWorldProvider.new()
	var content_identity := JSON.stringify(document) + (":" + catalog.bundle_sha256 if catalog != null else "")
	state.content.data = {"rooms":{room.room_id:row},"actions":document.get("actions",[]),
		"start_room":room.room_id,"start_point":[room.start_point.x,room.start_point.y],"content_version":content_identity.sha256_text()}
	if previous != null:
		if previous.room == null or not previous.lifetime.active or previous.room.room_id == room.room_id or not previous.pending_defeats.is_empty() or previous.controller.has_pending_damage():
			room.free()
			room = null
			return "room_transition_unavailable"
		storage = previous.state.storage
	state.storage = storage if storage != null else RoomMemory.new()
	state.storage.content_version = state.content.data.content_version
	state.storage.payload_validator = state.valid
	if previous != null:
		state.revision = previous.state.revision
		var next := previous.state.candidate()
		var rooms: Dictionary = next.get("visited_states",{})
		rooms[previous.room.room_id] = {"enemies":previous.room.snapshot(),"mechanisms":next.mechanisms}
		var destination: Dictionary = rooms.get(room.room_id,{})
		next.visited_states = rooms
		next.enemies = destination.get("enemies",{}).duplicate(true)
		next.mechanisms = destination.get("mechanisms",{}).duplicate(true)
		next.room = room.room_id
		next.entry = entry_door_id
		if not exits.is_empty() and room.room_id not in next.explored:
			next.explored.append(room.room_id)
		next.content_version = state.content.data.content_version
		var effects: Dictionary = next.services.effects
		effects.erase("field")
		effects.guard_hits = []
		effects.target = {}
		effects.marks = {}
		effects.dots = {}
		effects.time = {}
		if not state.commit(next,state.revision):
			state.storage.payload_validator = previous.state.valid
			state.storage.content_version = previous.state.content.data.content_version
			room.free()
			room = null
			return "room_transition_save_failed"
		previous.controller.air_focus_ability.stop()
		previous.lifetime.end()
		previous.process_mode = Node.PROCESS_MODE_DISABLED
		previous.queue_free()
	elif storage != null:
		var saved := storage.load_profile()
		if catalog != null and saved.get("payload") is Dictionary and not saved.payload.is_empty() and saved.payload.get("content_version") != state.content.data.content_version:
			room.free()
			room = null
			return "room_content_save_version_mismatch"
		if not saved.get("accepted", false) or (not saved.payload.is_empty() and (saved.payload.get("room") != room.room_id or not state.restore_profile(saved))):
			room.free()
			room = null
			return "room_save_unavailable"
	if previous == null and state.value.get("entry","") in exits:
		var saved_spawn := FixedWorldProvider.point(exits[state.value.entry].spawn)
		if not bounds.has_point(saved_spawn):
			room.free()
			room = null
			return "spawn_outside_room"
		at = saved_spawn
	content_catalog = catalog
	content_enemy_gold = prepared.get("enemy_gold", {})
	content_context = prepared.get("room_context", {})

	services.state = state
	services.definitions = drop_rules
	services.content_catalog = catalog
	audio_service = PlayerWeaponFeelAudioV2.new()
	add_child(audio_service)
	player = preload("res://game/player/player.tscn").instantiate()
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	if state.value.is_empty():
		state.value = state.fresh(controller.actor_resources.health.capacity)
		if not exits.is_empty():
			state.value.entry = entry_door_id
			state.value.explored.append(room.room_id)
	var health_definition := controller.actor_resources.health_definition.duplicate(true) as HealthDefinition
	health_definition.initial_current = clampf(state.value.hp, 1, health_definition.max_health)
	controller.actor_resources.health.configure(health_definition)
	controller.combat_energy.grant("room_entered", float(state.value.combat_energy))
	player.get_node("CourierVisual").hide()
	player.get_node("PlayerVisualAdapter").process_mode = Node.PROCESS_MODE_DISABLED
	player.add_child(PlayerPresentationRuntime.make_body(player, controller, "PlayerBody"))
	PlayerPresentationRuntime.attach(player)
	focus_heal = WorldFocusHeal.new()
	focus_heal.controller = controller
	heal_base = JSON.parse_string(FileAccess.get_file_as_string("res://config/focus_heal.json"))
	focus_heal.settings = heal_base.duplicate(true)
	player.add_child(focus_heal)
	focus_heal.ready_to_heal.connect(_heal)
	controller.interact_requested.connect(_interact)
	player.reset_at(at)
	var camera := Camera2D.new()
	player.add_child(camera)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	policy.player_fatal.connect(_player_died)
	add_child(room)
	room.install(controller, policy, lifetime, state.value.enemies, at)
	room.services = services
	room.install_mechanisms(controller, lifetime, state.value.mechanisms, _activate)
	for site: Node in room.find_children("*","",true,false):
		if site is EquipmentSite:
			site.services = services
			equipment_sites.append(site)
			state.committed.connect(site.refresh)
			site.refresh()
	services.can_access = _equipment_access
	services.stage_resources = equipment.stage
	equipment.bind(self)
	state.capture_live = capture_live
	equipment_menu = EquipmentMenu.new()
	equipment_menu.session = self
	add_child(equipment_menu)
	if not room.signs.is_empty():
		sign_reader = RoomSignReader.new()
		sign_reader.session = self
		add_child(sign_reader)
		sign_read.connect(sign_reader.open)
	if not room.retry_anchors.is_empty(): policy.environment_return_requested.connect(func(): recovery.retry(self))
	for node: Node in room.find_children("*","",true,false):
		if node is WorldResourcePickup: node.bind(self)
		if node is WorldMovingPlatform: node.bind_activation(state)
		if node is WorldRoomInteraction:
			node.bind(state)
			if node.action_owner_id.is_empty(): room.interaction_hosts.append(node)
	if room.rest_point != Vector2.ZERO or room.get_meta("editor_element_rows",{}).values().any(func(element): return element.get("definition_id") == "recovery.station"):
		room.station_animation = WorldChargingStation.new()
		room.station_animation.position = room.rest_point
		room.add_child(room.station_animation)
	for zone: Dictionary in room.environment_zones:
		var fixture := WorldEnvironmentZone.new()
		fixture.bounds = FixedWorldProvider.rect(zone.bounds)
		fixture.mode = zone.mode
		if fixture.mode == "wind":
			fixture.wind_pattern = zone.wind_pattern
			fixture.wind_direction = FixedWorldProvider.point(zone.wind_direction)
			fixture.wind_acceleration = zone.wind_acceleration
			fixture.wind_speed_cap = zone.wind_speed_cap
			fixture.vortex_direction = zone.vortex_direction
		fixture.services = services
		fixture.controller = controller
		fixture.policy = policy
		fixture.lifetime = lifetime
		room.add_child(fixture)
	room.loot = WorldCoinDrops.new()
	room.loot.services = services
	room.loot.controller = controller
	room.loot.room_id = room.room_id
	room.add_child(room.loot)
	room.loot.sync()
	room.loot.pickup_requested.connect(_collect)
	for id: String in room.enemies:
		var actor: EnemyActor = room.enemies[id]
		actor.defeated.connect(_defeated.bind(id))
	return ""

func capture_live(candidate: Dictionary) -> void:
	candidate.services.effects = equipment.snapshot()
	candidate.combat_energy = controller.combat_energy.current
	candidate.hp = controller.actor_resources.health.current
	if room.loot != null: room.loot.persist_into(candidate)

func checkpoint() -> bool:
	if controller == null or controller.actor_resources.health.terminal: return false
	return state.commit(state.candidate(),state.revision)

func _equipment_access(kind: String, id: String) -> bool:
	if not controller.active or controller.has_pending_damage(): return false
	if kind in ["equip","unequip","rest"]:
		return room.station_animation != null and player.position.distance_to(room.rest_point) <= 52
	if kind == "select": return true
	for site: EquipmentSite in equipment_sites:
		if not site.available(player.global_position): continue
		if kind == "upgrade" and site.kind == "smith": return true
		if kind == "claim" and site.kind == "reward" and site.source_id == id: return true
	return false

func equipment_transaction(kind: String,id: String,revision: int) -> bool:
	var receipt := "%s/%s/%s" % [kind,id,revision]
	var before := state.revision
	if not services.transact(kind,id,receipt,revision): return false
	if before != state.revision: equipment.after_transaction(kind,id)
	return true

func _interact() -> void:
	if room == null or controller.actor_resources.health.terminal: return
	for site: EquipmentSite in equipment_sites:
		if not site.available(player.global_position): continue
		if site.kind == "reward": equipment_transaction("claim",site.source_id,state.revision); return
		if site.kind == "smith": equipment_menu.open("smith"); return
	if _equipment_access("rest",""): equipment_menu.open("rest"); return
	var section := room.section_at(player.position)
	for host: WorldRoomInteraction in room.interaction_hosts:
		if host.available(player.position, section):
			var candidate := state.action_candidate(host.action_id, room.room_id, section)
			if not candidate.is_empty() and state.commit(candidate,state.revision): host.celebrate()
			return
	for mechanism: Node in room.element_runtime.nodes.values():
		if mechanism is WorldMovingPlatform and mechanism.interact(): return
	for sign_data: Dictionary in room.signs:
		if player.position.distance_to(sign_data.interaction_point) <= 60:
			sign_read.emit(str(sign_data.text))
			return

func _heal() -> void:
	if not lifetime.active or not focus_heal.available() or not controller.router.focus_heal_held():
		focus_heal.resolve(false)
		return
	var health := controller.actor_resources.health
	var energy := controller.combat_energy
	var amount := float(focus_heal.settings.heal)
	var cost := float(focus_heal.settings.cost)
	var candidate := state.candidate()
	candidate.hp = minf(health.capacity, health.current + amount)
	candidate.combat_energy = energy.current - cost
	equipment.stage_spending(candidate.services.effects,cost)
	if not state.commit(candidate,state.revision):
		focus_heal.resolve(false)
		return
	var event := "focus_heal:"+str(state.revision)
	energy.consume(event,cost)
	health.heal(ActorResourceRequest.new(StringName(event),health.epoch,amount,health.get_instance_id()))
	focus_heal.resolve(true)

func _activate(id: String) -> void:
	var changes := room.element_runtime.proposal(id)
	if changes.is_empty(): return
	var candidate := state.candidate()
	var world_result := false
	for target_id: String in changes:
		var receiver: Node = room.element_runtime.nodes[target_id]
		if receiver is WorldPermanentResult:
			candidate = receiver.world_candidate()
			if candidate.is_empty(): return
			world_result = true
	for target: String in changes:
		if room.element_runtime.nodes[target].state_scope == "permanent":
			candidate.mechanisms[target] = changes[target]
	if (not world_result and candidate.mechanisms == state.value.mechanisms) or state.commit(candidate, state.revision):
		room.element_runtime.accept(id, changes)

func _defeated(actor: EnemyActor, id: String) -> void:
	if actor.definition.behavior_id == &"chime_target": return
	var source := "enemy:"+str(room.room_id)+"/"+id+":cycle:"+str(state.value.cycle)
	equipment.scene.killed(actor.motor.global_position)
	# Imported per-enemy base participates in the existing equipment bonus transaction.
	var base_gold := int(content_enemy_gold[id]) if content_catalog != null else int(drop_rules.enemy_gold)
	pending_defeats[id] = {"source":source, "base_gold":base_gold, "bonus":equipment.p("P39","gold_bonus"),"position":actor.motor.position, "enemy":room.snapshot()[id]}
	_settle_defeats()

func _settle_defeats() -> void:
	var candidate := state.candidate()
	for id: String in pending_defeats:
		var defeat: Dictionary = pending_defeats[id]
		if not candidate.receipts.has("income:"+str(defeat.source)):
			var total := float(defeat.base_gold) * (1.0 + float(defeat.bonus)) + float(candidate.services.effects.get("gold_fraction",equipment.fx.gold_fraction))
			var units := WorldCoinDrops.create_units(defeat.source,floori(total),defeat.position,player.position,room.room_id)
			candidate = services.drop_candidate(candidate, defeat.source, units)
			candidate.services.effects.gold_fraction = total - floorf(total)
		candidate.enemies[id] = defeat.enemy
	if state.commit(candidate, state.revision):
		equipment.fx.gold_fraction = state.value.services.effects.get("gold_fraction",0.0)
		pending_defeats.clear()
		room.loot.sync()
	else:
		retry_delay = 1.0

func _player_died() -> void:
	controller.die()
	# Reload at the last living checkpoint, with the death's resource and summon state.
	pending_death = state.value.duplicate(true)
	pending_death.services.effects = equipment.snapshot()
	pending_death.combat_energy = controller.combat_energy.current
	_settle_death()

func _settle_death() -> void:
	if state.commit(pending_death,state.revision): pending_death = {}
	else: retry_delay = 1.0

func _physics_process(delta: float) -> void:
	if room != null and controller != null and controller.active and not room.retry_anchors.is_empty(): recovery.observe(room,player)
	if not pending_death.is_empty():
		retry_delay -= delta
		if retry_delay <= 0: _settle_death()
		return
	if not lifetime.active or pending_defeats.is_empty(): return
	retry_delay -= delta
	if retry_delay <= 0: _settle_defeats()

func _collect(id: String) -> void:
	if not room.loot.can_collect(id): return
	var candidate := services.collect_coin_candidate(state.candidate(), id)
	if not candidate.is_empty() and state.commit(candidate, state.revision):
		room.loot.sync()
		GameAudio.cue(player,&"coin")
		player.get_node("PlayerFeedback").reward_received(player.global_position,false)

func _exit_tree() -> void:
	equipment.freeze.release()
	lifetime.end()
