class_name OrdinaryRoomSession
extends Node2D
## Host for one authored room. A world/transition owner can supply storage and
## progression; the standalone room never discovers a campaign or an old save.
@export_file("*.json") var document_path := ""
@export var profile_slot := ""
const WORLD_WEAPONS := {"gun":preload("res://resources/weapons/pulse_gun.tres"),"B":preload("res://resources/weapons/recoil_bomb.tres"),"weapon_shuriken":preload("res://resources/weapons/shadow_shuriken.tres")}
var content_sites: WorldContentSites
var recoil_guard: WorldRecoilGuard
var equipment := EquipmentRuntime.new()
var equipment_menu: EquipmentMenu
var equipment_sites: Array[EquipmentSite] = []
var heal_base: Dictionary
@export var content_room_id := ""
@export_file("*.json") var content_lock_path := "res://config/imported_world/current.lock.json"
@export_file("*.json") var content_bindings_path := "res://config/imported_world/bindings.json"
var encounters: Array[WorldRoomEncounter] = []
var opening: PlainsOpening
var focus_vignette: FocusVignette
var rest_sequence: WorldRestSequence
var focus_heal: WorldFocusHeal
var audio_service: PlayerWeaponFeelAudioV2
signal sign_read(text: String)
signal terrain_return_requested
signal respawn_requested
var sign_reader: RoomSignReader
var recovery := RoomRecovery.new()
var touch_controls: RoomTouchControls
var room_dressing: Node2D
var room: FixedWorldRoom
var player: PlayerMotor
var camera: WorldCamera
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
var passage_discoveries: Array = []
var blast_passages: Dictionary = {}
var weapon_growth: Dictionary = {}

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

func open(document: Dictionary, storage: WorldSaveService = null, previous: OrdinaryRoomSession = null, catalog: WorldContentCatalog = null, entry_door_id := "", respawning := false) -> String:
	if room != null: return "room_already_open"
	if document.has("error"): return str(document.error)
	if previous != null:
		var before := previous.content_catalog.bundle_sha256 if previous.content_catalog != null else ""
		var after := catalog.bundle_sha256 if catalog != null else ""
		if before != after: return "room_content_version_mismatch"
	if not document.get("exits", {}) is Dictionary: return "room_exits_invalid"
	var exits: Dictionary = document.get("exits", {})
	var entries: Dictionary = exits.duplicate()
	if catalog != null:
		for link: Dictionary in catalog.connections(str(document.room_id)).get("rows",[]):
			if link.connection_type != "interior": continue
			var site: Dictionary = document.get("sites",{}).get(link.id,{})
			if WorldRoomValidation.vector(site.get("at")):
				entries[link.id] = {"spawn":site.at}
		for station: Dictionary in catalog.object("transport").value.stations:
			if station.room != document.room_id: continue
			var site: Dictionary = document.get("sites",{}).get(station.id,{})
			if WorldRoomValidation.vector(site.get("at")): entries[station.id] = {"spawn":site.at}
	if not entry_door_id.is_empty() and not entries.has(entry_door_id):
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
		at = FixedWorldProvider.point(entries[entry_door_id].spawn)
	if respawning:
		if previous == null or previous.lifetime.active or not previous.controller.actor_resources.health.terminal or previous.state.value.rest.room != room.room_id or not entry_door_id.is_empty():
			room.free()
			room = null
			return "room_respawn_unavailable"
		at = FixedWorldProvider.point(previous.state.value.rest.point)
	var bounds := FixedWorldProvider.rect(bounds_data)
	if not bounds.has_point(at):
		room.free()
		room = null
		return "spawn_outside_room"
	var room_camera := preload("res://game/world/levels/room_camera_contract.gd").resolve(document)
	var row := {"doors":[],"camera":room_camera,"world_geometry":WorldRoomSpace.document_geometry(bounds_data,exits)}
	row["exits"] = entries
	var sections: Array[Dictionary] = []
	for zone: String in document.get("zone_areas",{}):
		sections.append({"id":zone,"bounds":document.zone_areas[zone]})
	row["sections"] = sections
	room.configure(row)
	if catalog != null:
		weapon_growth=catalog.object("growth").value
		state.maximum_attack_rank=weapon_growth.shared_attack.levels.size()-1
	state.content = FixedWorldProvider.new()
	var content_identity := JSON.stringify(document) + (":" + catalog.bundle_sha256 if catalog != null else "")
	state.content.data = {"rooms":{room.room_id:row},"actions":document.get("actions",[]),
		"start_room":room.room_id,"start_point":[room.start_point.x,room.start_point.y],"content_version":content_identity.sha256_text()}
	if previous != null:
		if not respawning and (previous.room == null or not previous.lifetime.active or previous.room.room_id == room.room_id or not previous.pending_defeats.is_empty() or previous.controller.has_pending_damage()):
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
		var departing: Dictionary = rooms.get(previous.room.room_id,{})
		var remaining := {} if departing.get("refresh_on_leave",false) else previous.room.snapshot()
		rooms[previous.room.room_id] = {"enemies":remaining,"mechanisms":next.mechanisms}
		if respawning:
			# Advancing the cycle refreshes regular enemies in every visited room.
			# The dead controller already cleared its summons and combat energy.
			previous.equipment.stage(next,"rest","")
			next = previous._stage_defeats(next)
			next.cycle += 1
			for visit: Dictionary in rooms.values():
				visit.enemies = {}
		var destination: Dictionary = rooms.get(room.room_id,{})
		next.visited_states = rooms
		next.enemies = destination.get("enemies",{}).duplicate(true)
		next.mechanisms = destination.get("mechanisms",{}).duplicate(true)
		next.room = room.room_id
		next.entry = entry_door_id
		if not entries.is_empty() and room.room_id not in next.explored:
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
		previous.controller.shoot_ability.cancel_packet(&"scene_changed")
		previous.controller.air_focus_ability.stop()
		previous.lifetime.end()
		previous.process_mode = Node.PROCESS_MODE_DISABLED
		previous.queue_free()
	elif storage != null:
		var saved := storage.load_profile()
		if catalog != null and saved.get("payload") is Dictionary and not saved.payload.is_empty():
			var saved_version: String=str(saved.payload.get("content_version",""))
			var current_version: String=state.content.data.content_version
			if saved_version != current_version:
				room.free()
				room = null
				return "room_content_save_version_mismatch"
		if not saved.get("accepted", false) or (not saved.payload.is_empty() and (saved.payload.get("room") != room.room_id or not state.restore_profile(saved,catalog))):
			room.free()
			room = null
			return "room_save_unavailable"
	if previous == null and not state.value.is_empty():
		var saved_spawn := at
		if state.value.entry in entries:
			saved_spawn = FixedWorldProvider.point(entries[state.value.entry].spawn)
		elif state.value.entry.is_empty() and state.value.rest.room==room.room_id:
			saved_spawn = FixedWorldProvider.point(state.value.rest.point)
		if not bounds.has_point(saved_spawn):
			room.free()
			room = null
			return "spawn_outside_room"
		at = saved_spawn
	content_catalog = catalog
	content_enemy_gold = prepared.get("enemy_gold", {})
	passage_discoveries = prepared.get("passage_discoveries", [])
	blast_passages=prepared.get("blast_passages",{})
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
		state.value = state.fresh(controller.actor_resources.health.capacity, not document.get("sites",{}).has(PlainsOpening.SITE))
		if not entries.is_empty():
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
	var carry := PlayerCarryLight.new()
	carry.settings = preload("res://config/player_carry_light.json").data
	player.add_child(carry)
	var aim := PlayerAimGuide.new()
	aim.controller = controller
	player.add_child(aim)
	focus_vignette = FocusVignette.new()
	focus_vignette.ability = controller.air_focus_ability
	add_child(focus_vignette)
	focus_heal = WorldFocusHeal.new()
	focus_heal.controller = controller
	heal_base = JSON.parse_string(FileAccess.get_file_as_string("res://config/focus_heal.json"))
	focus_heal.settings = heal_base.duplicate(true)
	player.add_child(focus_heal)
	focus_heal.ready_to_heal.connect(_heal)
	controller.interact_requested.connect(_interact)
	player.reset_at(at)
	touch_controls = RoomTouchControls.mount(self)
	policy = FrameDamagePolicy.new()
	policy.lifetime = lifetime
	policy.has_retry_anchors = not room.retry_anchors.is_empty()
	add_child(policy)
	policy.register_target(&"player",controller.actor_resources.health,true)
	policy.register_player_controller(controller)
	policy.player_fatal.connect(_player_died)
	add_child(room)
	for row_encounter: Dictionary in content_context.get("encounters",[]):
		if document.get("sites",{}).has(row_encounter.id):
			var encounter := WorldRoomEncounter.new()
			encounter.configure(self,row_encounter,document.sites[row_encounter.id])
			encounters.append(encounter)
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
	services.stage_resources = _stage_station_transaction
	equipment.bind(self)
	state.committed.connect(_sync_sidearm)
	_sync_sidearm(state.revision)
	if catalog != null:
		recoil_guard=WorldRecoilGuard.new()
		recoil_guard.controller=controller
		if previous!=null and previous.recoil_guard!=null and not respawning:
			recoil_guard.cooldown=previous.recoil_guard.cooldown
			recoil_guard.landing_ready=previous.recoil_guard.landing_ready
		add_child(recoil_guard)
		var glow:=WorldRecoilGuardVisual.new()
		glow.guard=recoil_guard
		player.add_child(glow)
		policy.transient_protection=recoil_guard.protects
		state.committed.connect(_sync_world_abilities)
		_sync_world_abilities(state.revision)
	state.capture_live = capture_live
	equipment_menu = EquipmentMenu.new()
	equipment_menu.session = self
	add_child(equipment_menu)
	if not room.signs.is_empty():
		if catalog != null: controller.router.set_meta(&"world_up_interaction",true)
		sign_reader = RoomSignReader.new()
		sign_reader.session = self
		add_child(sign_reader)
		sign_read.connect(sign_reader.open)
	recovery.entry_point = at
	policy.environment_return_requested.connect(_on_terrain_failure)
	for node: Node in room.find_children("*","",true,false):
		if node is WorldResourcePickup: node.bind(self)
		if node is WorldMovingPlatform: node.bind_activation(state)
		if node is WorldRoomInteraction:
			node.bind(state)
			if node.action.get("type") == "coin_chest": node.bind_coin_chest(self)
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
	if catalog != null:
		preload("res://rooms/world/world_room_dressing.gd").install(self,document,catalog)
	if catalog != null and not document.get("sites",{}).is_empty():
		content_sites=WorldContentSites.new()
		room.add_child(content_sites)
		content_sites.install(self,document)
	if document.get("sites",{}).has(PlainsOpening.SITE) and not state.has("gun"):
		opening = PlainsOpening.new()
		opening.install(self,FixedWorldProvider.point(document.sites[PlainsOpening.SITE].at))
	# The room, controller and restored state must be live before zone selection.
	camera = WorldCamera.new()
	camera.target = player
	camera.controller = controller
	camera.room = room
	for encounter: WorldRoomEncounter in encounters:
		camera.zones.encounters[encounter.encounter.id] = encounter
	var entry_gate: Dictionary = exits.get(state.value.entry,{})
	if entry_gate.has("direction"):
		camera.arrival_direction = -float(entry_gate.direction[0])
	camera.settings = preload("res://config/world_camera.json").data
	camera.landmark = document.get("scenery",{}).get("camera_landmark",{})
	if not camera.landmark.is_empty():
		camera.landmark_point = FixedWorldProvider.point(document.sites[camera.landmark.site].at)
	# Keep the node with its actor but let the solver own its world transform.
	camera.top_level = true
	player.add_child(camera)
	camera.make_current()
	camera.enter_room(bounds)
	player.repositioned.connect(camera.reset_view)
	policy.batch_resolved.connect(_camera_damage_feedback)
	return ""

func _camera_damage_feedback(results: Array[DamageResult]) -> void:
	if not camera.is_current(): return
	const IMPACT := preload("res://game/combat/damage/feedback.tres")
	for result: DamageResult in results:
		if result.request.target_id != &"player" or result.hp_lost <= 0: continue
		camera.shake(IMPACT.death_shake if result.lethal else IMPACT.impact_shake,.18)
		return

func _sync_sidearm(_revision: int) -> void:
	var armed := state.has("gun")
	if controller.shoot_ability.enabled!=armed:
		controller.shoot_ability.enabled=armed

func _sync_world_abilities(_revision: int) -> void:
	var abilities := {"W":&"wall_climb","H":&"grapple","D":&"double_jump"}
	for flag: String in abilities:
		if controller.traversal.has_capability(abilities[flag])!=state.has(flag):
			controller.traversal.grant(abilities[flag],state.has(flag))
	recoil_guard.owned=state.has("Q")
	controller.shoot_ability.behavior().intro_pulse_owned=state.has("intro_active_skill")
	var selected: String=state.value.story_hosts.get("selected_weapon","gun")
	var rank:=WorldWeaponWorkshop.rank(state,"attack")
	controller.motor.tuning.projectile_damage=weapon_growth.shared_attack.levels[rank].damage
	var available:=world_weapon_loadouts()
	var chosen: WeaponDefinition=available.get(selected,WORLD_WEAPONS.gun)
	if chosen!=controller.shoot_ability.weapon: controller.shoot_ability.equip(chosen)
	controller.shoot_ability.behavior().shared_skill_owned=state.has("skill_tier_1")
	equipment.sync_resources()

func world_weapon_loadouts() -> Dictionary:
	if weapon_growth.is_empty(): return {}
	return WorldWeaponWorkshop.loadouts(state,weapon_growth,WORLD_WEAPONS)

func select_world_weapon(id: String, revision: int) -> bool:
	if content_catalog==null or not world_weapon_loadouts().has(id) or revision!=state.revision: return false
	if not controller.active or controller.has_pending_damage() or not pending_defeats.is_empty(): return false
	var next:=state.candidate()
	next.story_hosts["selected_weapon"]=id
	return state.commit(next,revision)

func capture_live(candidate: Dictionary) -> void:
	candidate.services.effects = equipment.snapshot()
	candidate.combat_energy = controller.combat_energy.current
	candidate.hp = controller.actor_resources.health.current
	if room.loot != null: room.loot.persist_into(candidate)

func checkpoint(include_accepted_defeats := false) -> bool:
	if controller == null or controller.actor_resources.health.terminal or controller.has_pending_damage(): return false
	var next := state.candidate()
	next.enemies = room.snapshot()
	if not pending_defeats.is_empty():
		return include_accepted_defeats and _commit_defeats(next)
	return state.commit(next,state.revision)

func _equipment_access(kind: String, id: String) -> bool:
	var charging := kind == "rest" and is_instance_valid(rest_sequence) and rest_sequence.active and rest_sequence.attempted
	if (not controller.active and not charging) or controller.has_pending_damage(): return false
	if kind in ["equip","unequip","rest"]:
		return room.station_animation != null and player.position.distance_to(room.rest_point) <= 52
	if kind == "select": return true
	if kind=="upgrade" and content_sites!=null and content_sites.smith_available(): return true
	for site: EquipmentSite in equipment_sites:
		if not site.available(player.global_position): continue
		if kind == "upgrade" and site.kind == "smith": return true
		if kind == "claim" and site.kind == "reward" and site.source_id == id: return true
	return false

func _stage_station_transaction(candidate: Dictionary, kind: String, id: String) -> void:
	equipment.stage(candidate,kind,id)
	if kind=="rest":
		var visits: Dictionary = candidate.get("visited_states",{})
		for visit: Dictionary in visits.values():
			visit.enemies = {}
		var current: Dictionary = visits.get(room.room_id,{})
		current["refresh_on_leave"] = true
		visits[room.room_id] = current
		candidate.visited_states = visits
		candidate.rest = {"room":room.room_id,"entry":"","point":[room.rest_point.x,room.rest_point.y]}
		candidate.entry = ""

func begin_station_rest(revision: int) -> bool:
	if is_instance_valid(rest_sequence) and rest_sequence.active: return false
	rest_sequence = WorldRestSequence.new()
	add_child(rest_sequence)
	if rest_sequence.begin(self, revision): return true
	rest_sequence.queue_free()
	return false

func equipment_transaction(kind: String,id: String,revision: int) -> bool:
	var receipt := "%s/%s/%s" % [kind,id,revision]
	var before := state.revision
	if not services.transact(kind,id,receipt,revision): return false
	if before != state.revision: equipment.after_transaction(kind,id)
	return true

func _interact() -> void:
	if opening!=null and opening.interact(): return
	if room == null or controller.actor_resources.health.terminal: return
	for encounter: WorldRoomEncounter in encounters:
		if encounter.confirm(): return
	if content_sites!=null and content_sites.interact(): return
	for site: EquipmentSite in equipment_sites:
		if not site.available(player.global_position): continue
		if site.kind == "reward": equipment_transaction("claim",site.source_id,state.revision); return
		if site.kind == "smith": equipment_menu.open("smith"); return
	if _equipment_access("rest",""): equipment_menu.open("rest"); return
	var section := room.section_at(player.position)
	for host: WorldRoomInteraction in room.interaction_hosts:
		if host.available(player.position, section):
			var candidate := state.action_candidate(host.action_id, room.room_id, section)
			if not candidate.is_empty() and host.action.get("type") == "coin_chest":
				var source := "chest:%s/%s" % [room.room_id,host.action_id]
				var units := WorldCoinDrops.create_units(source,host.action.amount,host.position,player.position,room.room_id)
				candidate = services.drop_candidate(candidate,source,units)
			if not candidate.is_empty() and state.commit(candidate,state.revision): host.celebrate()
			return
	for mechanism: Node in room.element_runtime.nodes.values():
		if mechanism is WorldMovingPlatform and mechanism.interact(): return
	var nearby := readable_sign()
	if not nearby.is_empty(): sign_read.emit(str(nearby.text))

func readable_sign() -> Dictionary:
	if opening!=null and not state.has("gun") and opening.can_reach(): return {}
	for sign_data: Dictionary in room.signs:
		if player.position.distance_to(sign_data.interaction_point) <= 60:
			return sign_data
	return {}

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
			if not WorldBlastPassage.stage(self,candidate,target,changes[target]): return
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

func _stage_defeats(candidate: Dictionary) -> Dictionary:
	for id: String in pending_defeats:
		var defeat: Dictionary = pending_defeats[id]
		if not candidate.receipts.has("income:"+str(defeat.source)):
			var total := float(defeat.base_gold) * (1.0 + float(defeat.bonus)) + float(candidate.services.effects.get("gold_fraction",equipment.fx.gold_fraction))
			var units: Array[Dictionary] = []
			if total >= 1: units = WorldCoinDrops.create_units(defeat.source,floori(total),defeat.position,player.position,room.room_id)
			candidate = services.drop_candidate(candidate, defeat.source, units)
			candidate.services.effects.gold_fraction = total - floorf(total)
		candidate.enemies[id] = defeat.enemy
	return candidate

func _settle_defeats() -> void:
	if not _commit_defeats(state.candidate()): retry_delay = 1.0

func _commit_defeats(candidate: Dictionary) -> bool:
	if not state.commit(_stage_defeats(candidate),state.revision): return false
	equipment.fx.gold_fraction = state.value.services.effects.get("gold_fraction",0.0)
	pending_defeats.clear()
	room.loot.sync()
	return true

func _on_terrain_failure() -> void:
	if terrain_return_requested.has_connections(): terrain_return_requested.emit()
	else: recovery.retry(self)

func _player_died() -> void:
	controller.die()
	if respawn_requested.has_connections():
		respawn_requested.emit()
		return
	# Reload at the last living checkpoint, with the death's resource and summon state.
	pending_death = state.value.duplicate(true)
	pending_death.services.effects = equipment.snapshot()
	pending_death.combat_energy = controller.combat_energy.current
	_settle_death()

func _settle_death() -> void:
	if state.commit(pending_death,state.revision): pending_death = {}
	else: retry_delay = 1.0

func _observe_passages() -> void:
	for site: Dictionary in passage_discoveries:
		if state.has(site.id): continue
		var at := player.position
		var reached: bool = site.passage.has_point(at)
		for point: Vector2 in site.points:
			if at.distance_squared_to(point) <= site.radius * site.radius:
				reached = true
				break
		if not reached or not content_catalog.condition_match(site.event,state.value.flags,state.value.services.equipped).matches: continue
		var next: Dictionary
		if state.content.action(site.id).is_empty():
			# The locked discovery owns the flag even when the room has no extra local action.
			next = state.candidate()
			next.flags.append(site.id)
			next.receipts[site.id] = {"source":site.id,"source_hash":MetaSaveService.canonical_json(site.event).sha256_text(),"revision":state.revision+1}
		else:
			next = state.action_candidate(site.id,room.room_id,room.section_at(at))
		if not next.is_empty(): state.commit(next,state.revision)

func _physics_process(delta: float) -> void:
	if not blast_passages.is_empty(): WorldBlastPassage.observe(self)
	if not passage_discoveries.is_empty() and lifetime.active and controller.active:
		_observe_passages()
	if room != null and controller != null and controller.active:
		if not room.retry_anchors.is_empty(): recovery.observe(room,player)
		elif not recovery.entry_verified: recovery.observe_arrival(room,player)
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
