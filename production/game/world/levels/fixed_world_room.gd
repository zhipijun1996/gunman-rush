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
@export var section_volumes: Array[Dictionary] = []
@export var retry_anchors: Array[Dictionary] = []
var camera_concealers: Dictionary = {}
var boundary_art_rock: Array[Rect2] = []
@export var region_id := ""
@export var terrain_material := ""
var mechanisms: Dictionary={}
var element_runtime := WorldElementRuntime.new()
var element_policy: FrameDamagePolicy
@export_storage var platform_appearances: Dictionary = {}
var station_animation: WorldChargingStation
var interaction_hosts: Array[WorldRoomInteraction] = []
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
@export var start_point := Vector2.ZERO
var rest_point := Vector2.ZERO
@export var enemy_placements: Array[Dictionary] = []
@export var signs: Array[Dictionary] = []
@export var hazards: Array[Rect2] = []
@export var spike_strips: Array[Dictionary] = []
@export var hook_points: Array[Vector2] = []
@export var climbable_walls: Array[Rect2] = []
@export var environment_zones: Array[Dictionary] = []
var recovery_markers := {}
var loot: WorldCoinDrops
var services: WorldServices
var interaction_point:=Vector2.INF
var door_open: Dictionary={}


var contract: Dictionary = {}
var doors: Array = []
var door_blocks: Dictionary = {}
var enemies: Dictionary = {}
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
		if i in one_way_indices:
			var platform_ids: Array = entity_ids.get("platforms",[])
			var style := str(platform_appearances.get(platform_ids[i],"")) if i < platform_ids.size() else ""
			if style in ["island_shelf","star_truss","clock_brace"]:
				preload("res://game/presentation/world/art/sky_ledge.gd").paint(self,platforms[i],style)
			elif style in ["forest_branch","forest_branch_left","forest_vine"]:
				preload("res://game/presentation/world/art/forest_branch.gd").paint(self,platforms[i],style)
			else:
				UnderworldTerrain.draw_one_way(self,platforms[i])
		elif i in illustrated_platform_indices:
			UnderworldTerrain.draw_mechanism_beam(self,platforms[i])
	for door: Dictionary in doors:
		if door.get("front_door",false) or door.get("npc_guard",false):continue
		var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
		var rect:=Rect2(p-Vector2(16,96),Vector2(32,96)) if door.direction in ["left","right"] else Rect2(p-Vector2(64,16),Vector2(128,32))
		if not door_open.get(door.id,false):
			draw_rect(rect,Color("3c4b44"))
			draw_rect(rect,Color("9f8b67"),false,3)
			draw_line(rect.position,rect.end,Color("9f8b67"),3)
			draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color("9f8b67"),3)

	if interaction_point.is_finite():
		var tip:=interaction_point+Vector2(0,-55)
		draw_polyline(PackedVector2Array([tip+Vector2(-5,5),tip,tip+Vector2(5,5)]),DemoClockworkTheme.PAPER,2)
func spawn_enemy(placement: Dictionary,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime,saved: Dictionary,entry_anchor: Vector2) -> EnemyActor:
	return assembly.call("spawn_enemy",self,placement,controller,policy,lifetime,saved,entry_anchor)

func install(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, entry_anchor: Vector2) -> void:
	assembly.call("install",self,controller,policy,lifetime,saved_enemies,entry_anchor)

func snapshot() -> Dictionary:
	var result := {}
	for id: String in enemies:
		var actor: EnemyActor = enemies[id]
		if actor.get_meta("wave_attempt",false):continue
		if actor.definition.behavior_id == &"chime_target": continue
		result[id] = actor.region_snapshot(true,actor.attack_behavior is ForestCrossbranchBehavior)
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
