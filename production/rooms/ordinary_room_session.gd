class_name OrdinaryRoomSession
extends Node2D
## Host for one authored room. A world/transition owner can supply storage and
## progression; the standalone room never discovers a campaign or an old save.
@export_file("*.json") var document_path := ""
var focus_heal: WorldFocusHeal
var audio_service: PlayerWeaponFeelAudioV2
signal sign_read(text: String)
var room: FixedWorldRoom
var player: PlayerMotor
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime := DemoLifetime.new()
var services := WorldServices.new()
var drop_rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/room_rewards.json"))
var state := FixedWorldState.new()

class RoomMemory extends WorldSaveService:
	func commit(_payload: Dictionary, _revision: int) -> bool:
		return true

func _ready() -> void:
	if not document_path.is_empty():
		var error := open(WorldRoomDocument.read(document_path))
		if not error.is_empty(): push_error(error)

func open(document: Dictionary, storage: WorldSaveService = null) -> String:
	if room != null: return "room_already_open"
	if document.has("error"): return str(document.error)
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
	var bounds := FixedWorldProvider.rect(bounds_data)
	if not bounds.has_point(at):
		room.free()
		room = null
		return "spawn_outside_room"
	var row := {"doors":[],"camera":{},"world_geometry":{"boundary":[],"bounds_world_units":bounds_data,"space_rects":[bounds_data]}}
	room.configure(row)
	state.content = FixedWorldProvider.new()
	state.content.data = {"rooms":{room.room_id:row},"actions":document.get("actions",[]),
		"start_room":room.room_id,"start_point":[at.x,at.y],"content_version":JSON.stringify(document).sha256_text()}
	state.storage = storage if storage != null else RoomMemory.new()
	state.storage.content_version = state.content.data.content_version
	state.storage.payload_validator = state.valid
	if storage != null:
		var saved := storage.load_profile()
		if not saved.get("accepted", false) or (not saved.payload.is_empty() and (saved.payload.get("room") != room.room_id or not state.restore_profile(saved))):
			room.free()
			room = null
			return "room_save_unavailable"

	services.state = state
	services.definitions = drop_rules
	audio_service = PlayerWeaponFeelAudioV2.new()
	add_child(audio_service)
	player = preload("res://game/player/player.tscn").instantiate()
	add_child(player)
	controller = player.get_node("Controller")
	controller.enable_shot_energy()
	if state.value.is_empty(): state.value = state.fresh(controller.actor_resources.health.capacity)
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
	focus_heal.settings = JSON.parse_string(FileAccess.get_file_as_string("res://config/focus_heal.json"))
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
	add_child(room)
	room.install(controller, policy, lifetime, state.value.enemies, at)
	room.install_mechanisms(controller, lifetime, state.value.mechanisms, _activate)
	room.services = services
	for node: Node in room.find_children("*","",true,false):
		if node is WorldMovingPlatform: node.bind_activation(state)
		if node is WorldRoomInteraction:
			node.bind(state)
			room.interaction_hosts.append(node)
	if room.rest_point != Vector2.ZERO:
		room.station_animation = WorldChargingStation.new()
		room.station_animation.position = room.rest_point
		room.add_child(room.station_animation)
	for zone: Dictionary in room.environment_zones:
		var fixture := WorldEnvironmentZone.new()
		fixture.bounds = FixedWorldProvider.rect(zone.bounds)
		fixture.mode = zone.mode
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

func _interact() -> void:
	if room == null or controller.actor_resources.health.terminal: return
	var section := room.section_at(player.position)
	for host: WorldRoomInteraction in room.interaction_hosts:
		if host.available(player.position, section):
			var candidate := state.action_candidate(host.action_id, room.room_id, section)
			if not candidate.is_empty() and state.commit(candidate,state.revision): host.celebrate()
			return
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
	var candidate := state.value.duplicate(true)
	candidate.hp = minf(health.capacity, health.current + amount)
	candidate.combat_energy = energy.current - cost
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
	var candidate := state.value.duplicate(true)
	for target: String in changes:
		if room.element_runtime.nodes[target].state_scope == "permanent":
			candidate.mechanisms[target] = changes[target]
	if candidate.mechanisms == state.value.mechanisms or state.commit(candidate, state.revision):
		room.element_runtime.accept(id, changes)

func _defeated(actor: EnemyActor, id: String) -> void:
	if actor.definition.behavior_id == &"chime_target": return
	var source := "enemy:"+id+":cycle:"+str(state.value.cycle)
	var amount := int(drop_rules.enemy_gold)
	var candidate := state.value.duplicate(true)
	candidate.enemies = room.snapshot()
	if amount > 0:
		var units := WorldCoinDrops.create_units(source, amount, actor.motor.position, player.position, room.room_id)
		candidate = services.drop_candidate(candidate, source, units)
	if not candidate.is_empty() and state.commit(candidate, state.revision): room.loot.sync()

func _collect(id: String) -> void:
	if not room.loot.can_collect(id): return
	var candidate := services.collect_coin_candidate(state.value.duplicate(true), id)
	if not candidate.is_empty() and state.commit(candidate, state.revision):
		room.loot.sync()
		GameAudio.cue(player,&"coin")
		player.get_node("PlayerFeedback").reward_received(player.global_position,false)

func _exit_tree() -> void:
	lifetime.end()
