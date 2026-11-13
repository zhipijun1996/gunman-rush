class_name FixedWorldRoom
extends Node2D
## Authored geometry and placements. Reads contract interfaces; never grants progress.
var assembly: Script = load(WorldElementCatalog.component_path("WorldRoomAssembly"))
var document_error := ""
@export var document_ref := "":
	set(value):
		document_ref = value
		if not value.is_empty():
			var document := WorldRoomDocument.read(value)
			document_error = str(document.error) if document.has("error") else WorldRoomDocument.apply(self, document)
@export var room_id := ""
@export var arrival_text: String
var traveler_point := Vector2.ZERO
@export var route_guide: Dictionary = {}
var intro_sequence: Dictionary = {}
var onboarding: Dictionary = {}
var wave_encounter: Dictionary = {}
var tutorial_action: String
var tutorial_target: String
var tutorial_min_move:=100.0
var tutorial_recoil_finish_x:=1540.0
@export var section_volumes: Array[Dictionary] = []
@export var retry_anchors: Array[Dictionary] = []
var camera_concealers: Dictionary = {}
var boundary_art_rock: Array[Rect2] = []
@export var art_placements: Array[Dictionary] = []
@export var art_profile := "meadow"
## Explicit regional threshold sample; empty for authored full rooms.
@export var region_preview := ""
var mechanisms: Dictionary={}
var element_runtime := WorldElementRuntime.new()
var element_policy: FrameDamagePolicy
@export_storage var platform_appearances: Dictionary = {}
var station_animation: WorldChargingStation
var interaction_hosts: Array[WorldRoomInteraction] = []
var service_pickup_sprites: Dictionary={}
@export var platforms: Array[Rect2] = []
## Authored polygon geometry; the same vertices feed physics and presentation.
@export var terrain_polygons: Array[Dictionary] = []
## Optional versioned appearance; authoritative solids and hazards remain separate.
@export var terrain_paint: Dictionary = {}
## Stable authoring identities for legacy indexed arrays. Never used as progress.
@export var entity_ids: Dictionary = {}
@export var one_way_indices: Array[int] = []
## Explicit scenery supplies the surface image; authored rectangles still collide.
@export var illustrated_platform_indices: Array[int] = []
@export var masonry_platform_indices: Array[int] = []
@export var start_point := Vector2(144,512)
var rest_point := Vector2.ZERO
var reward_point := Vector2.ZERO
@export var enemy_placements: Array[Dictionary] = []
@export var signs: Array[Dictionary] = []
@export var hazards: Array[Rect2] = []
@export var spike_strips: Array[Dictionary] = []
var story_sequence: Dictionary = {}
@export var hook_points: Array[Vector2] = []
@export var climbable_walls: Array[Rect2] = []
@export var environment_zones: Array[Dictionary] = []
var interaction_point:=Vector2.INF
var cycle_at_load := 0
var door_open: Dictionary={}
var services: WorldServices
var loot: WorldCoinDrops

var boss_identity: StringName
var boss_binding: Script
var defeat_action: String
var defeat_flag: String
var reward_action: String
var reward_text: String
var boss_position := Vector2.ZERO
var arena_bounds := Rect2()
var battle_entry_anchor := Vector2.ZERO
var arena_door_height := 192.0
var contract: Dictionary = {}
var doors: Array = []
var door_blocks: Dictionary = {}
var enemies: Dictionary = {}
var boss: BossMotor
var encounter: BossEncounter
var boss_contact: DemoContactEmitter
var seals: Array[StaticBody2D] = []
var battle_started := false
var battle_finished := false

static func material_for_profile(profile: String) -> String:
	return {"clockheart":"mill","mill":"mill","barn":"barn","cellar":"cellar","secret":"cellar","well":"well"}.get(profile,"")
func interior_material() -> String:
	return material_for_profile(art_profile)

func platform_index(id: String) -> int:
	return entity_ids.get("platforms",[]).find(id)

func _ready() -> void:
	assembly.call("build",self)

func section_at(point: Vector2) -> String:
	for volume: Dictionary in section_volumes:
		if FixedWorldProvider.rect(volume.bounds).has_point(point): return str(volume.id)
	return "main"

func physical_action(id: String) -> WorldRoomInteraction:
	for host: WorldRoomInteraction in interaction_hosts:
		if host.action_id==id: return host
	return null

func install_mechanisms(controller: PlayerController,lifetime: DemoLifetime,saved: Dictionary,submit: Callable) -> void:
	element_runtime.bind(self,controller,element_policy,lifetime,saved,submit)

func mechanism_snapshot() -> Dictionary:
	return element_runtime.snapshot()

func configure(row: Dictionary) -> void:
	contract = row
	# Logical sections may gain explicit trigger volumes in the editor. Existing
	# authored volumes remain the fallback when a section has no spatial extent.
	for section: Dictionary in row.get("sections", []):
		if not section.get("bounds") is Array or section.bounds.size() != 4: continue
		var found := false
		for volume: Dictionary in section_volumes:
			if volume.id == section.id:
				volume.bounds = section.bounds.duplicate()
				found = true
				break
		if not found: section_volumes.append({"id":section.id, "bounds":section.bounds.duplicate()})
	doors = row.doors.filter(func(door: Dictionary) -> bool: return door.get("target_implemented",false))
	queue_redraw()

func _draw() -> void:
	if contract.is_empty(): return
	var bounds := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units)
	for i: int in platforms.size():
		if i in one_way_indices and i not in illustrated_platform_indices: UnderworldTerrain.draw_one_way(self,platforms[i])
	for door: Dictionary in doors:
		if door.get("front_door",false) or door.get("npc_guard",false):continue
		var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
		var rect:=Rect2(p-Vector2(16,96),Vector2(32,96)) if door.direction in ["left","right"] else Rect2(p-Vector2(64,16),Vector2(128,32))
		if not door_open.get(door.id,false):
			if art_placements.any(func(p:Dictionary)->bool: return p.get("closed_gate_for","")==str(door.id)):
				UnderworldTerrain.draw_mechanism_beam(self,rect)
				continue
			draw_rect(rect,Color("3c4b44"))
			draw_rect(rect,Color("9f8b67"),false,3)
			draw_line(rect.position,rect.end,Color("9f8b67"),3)
			draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color("9f8b67"),3)

	if not boss_identity.is_empty():
		for x: float in [arena_bounds.position.x,arena_bounds.end.x]:
			var doorway:=Rect2(x-6,arena_bounds.end.y-arena_door_height,12,arena_door_height)
			if battle_started and not battle_finished: draw_rect(doorway,Color("d8b35d"))

	if interaction_point.is_finite():
		var tip:=interaction_point+Vector2(0,-55)
		draw_polyline(PackedVector2Array([tip+Vector2(-5,5),tip,tip+Vector2(5,5)]),DemoClockworkTheme.PAPER,2)
	if reward_point != Vector2.ZERO and battle_finished and services!=null and not services.state.value.receipts.has(reward_action):
		WorldProps.draw_icon(self,ItemPresentation.icon(&"echo"),reward_point,30)

func spawn_enemy(placement: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,saved: Dictionary,entry_anchor: Vector2) -> EnemyActor:
	return assembly.call("spawn_enemy",self,placement,controller,policy,lifetime,saved,entry_anchor)

func install(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, boss_defeated: bool, entry_anchor: Vector2) -> void:
	assembly.call("install",self,controller,policy,lifetime,saved_enemies,boss_defeated,entry_anchor)

func update_battle(player_position: Vector2) -> void:
	if encounter == null or battle_finished: return
	if not battle_started and Rect2(arena_bounds.position+Vector2(8,0),arena_bounds.size-Vector2(16,0)).grow(.1).encloses(Rect2(player_position-Vector2(12,18),Vector2(24,36))):
		battle_started = encounter.activate()
		boss_contact.enabled = battle_started
		for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",1)
		queue_redraw()
	if encounter.health.terminal: boss_contact.enabled = false

func finish_battle() -> void:
	battle_finished = true
	for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",0)
	queue_redraw()

func snapshot() -> Dictionary:
	var result := {}
	for id: String in enemies:
		var actor: EnemyActor = enemies[id]
		if actor.get_meta("wave_attempt",false):continue
		if actor.definition.behavior_id == &"chime_target": continue
		result[id] = actor.region_snapshot()
		var remains:=EnemyPresentationBinding.remains(actor.motor.get_node("Presentation"))
		if actor.health.terminal and remains!=null:
			var support:=remains.support_node()
			if is_instance_valid(support) and support.has_meta(&"world_ground"):
				var rect: Rect2=support.get_meta(&"world_ground")
				var pose:=remains.presentation_snapshot({"kind":"ground","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
				if not pose.is_empty(): result[id].corpse=pose
			elif is_instance_valid(support) and support.has_meta(&"world_ground_polygon"):
				var pose:=remains.presentation_snapshot({"kind":"ground_polygon","id":str(support.get_meta(&"world_ground_polygon"))})
				if not pose.is_empty(): result[id].corpse=pose
	return result

func refresh_doors(state: FixedWorldState, content: FixedWorldProvider) -> void:
	for door: Dictionary in doors:
		var opened := bool(door.outbound_allowed) and state.holds(door.requires) and not content.room(str(door.target_room)).is_empty()
		door_open[door.id]=opened
		(door_blocks[door.id] as StaticBody2D).set_deferred("collision_layer",0 if opened or door.get("front_door",false) or door.get("npc_guard",false) else 1)
	queue_redraw()

func bind_services(value: WorldServices,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> void:
	assembly.call("bind_services",self,value,controller,policy,lifetime)

func _refresh_service_pickups(_revision: int) -> void:
	for id: String in service_pickup_sprites:service_pickup_sprites[id].visible=id not in services.ledger().collected

func celebrate_service_pickup(id: String) -> void:
	if not service_pickup_sprites.has(id):return
	var art:=WorldSpriteAnimation.new();art.asset_id="collection_burst";art.disposable=true
	art.position=service_pickup_sprites[id].position-Vector2(0,18);art.z_index=10;add_child(art)

func _corpse_support(pose: Dictionary) -> Node2D:
	for body: Node in find_children("*","StaticBody2D",true,false):
		if body.has_meta(&"world_ground_polygon") and pose.get("support", {}).get("kind") == "ground_polygon":
			if str(body.get_meta(&"world_ground_polygon")) == str(pose.support.get("id", "")): return body as Node2D
		if not body.has_meta(&"world_ground"): continue
		var rect: Rect2=body.get_meta(&"world_ground")
		if [rect.position.x,rect.position.y,rect.size.x,rect.size.y]==pose.get("support",{}).get("rect",[]): return body as Node2D
	return null

func update_camera_concealment(active: String, frame: Dictionary) -> void:
	for id: String in camera_concealers:
		var entering: bool=not frame.get("portal",{}).is_empty() and id in [str(frame.a.id),str(frame.b.id)]
		camera_concealers[id].visible = id!=active and not entering
