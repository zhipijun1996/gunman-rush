class_name FixedWorldRoom
extends Node2D
## Authored geometry and placements. Reads contract interfaces; never grants progress.
@export var room_id := ""
@export var tutorial_target: String
@export var tutorial_min_move:=100.0
@export var tutorial_recoil_finish_x:=1540.0
@export var platforms: Array[Rect2] = []
@export var one_way_indices: Array[int] = []
@export var start_point := Vector2(144,512)
@export var rest_point := Vector2.ZERO
@export var reward_point := Vector2.ZERO
@export var enemy_placements: Array[Dictionary] = []
@export var signs: Array[Dictionary] = []
@export var hazards: Array[Rect2] = []
@export var hook_points: Array[Vector2] = []
@export var climbable_walls: Array[Rect2] = []
@export var environment_zones: Array[Dictionary] = []
var door_open: Dictionary={}
var services: WorldServices

@export var boss_identity: StringName
@export var boss_binding: Script
@export var defeat_action: String
@export var defeat_flag: String
@export var reward_action: String
@export var reward_text: String
@export var boss_position := Vector2.ZERO
@export var arena_bounds := Rect2()
@export var battle_entry_anchor := Vector2.ZERO
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

func _ready() -> void:
	z_index = -1
	# Visible room bounds stop recoil leaving the room; authored doors cut holes.
	var size := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units).size
	for side: String in ["left","right","up","down"]:
		var gaps: Array[Vector2] = []
		for door: Dictionary in doors:
			if door.direction != side: continue
			var point := FixedWorldProvider.point(door.position_candidate.local_world_units)
			gaps.append(Vector2(point.x-48,point.x+48) if side in ["up","down"] else Vector2(point.y-96,point.y))
		gaps.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x<b.x)
		gaps.append(Vector2(size.x if side in ["up","down"] else size.y,0))
		var start := 0.0
		for gap: Vector2 in gaps:
			if gap.x>start:
				platforms.append(Rect2(start,0 if side=="up" else size.y-32,gap.x-start,32) if side in ["up","down"] else Rect2(0 if side=="left" else size.x-32,start,32,gap.x-start))
			start = maxf(start,gap.y)
	for index: int in platforms.size():
		var body := StaticBody2D.new()
		body.position = platforms[index].get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = platforms[index].size
		collision.shape = shape
		collision.one_way_collision = index in one_way_indices
		if collision.one_way_collision: body.add_to_group("one_way_platform")
		body.add_child(collision)
		add_child(body)
	for door: Dictionary in doors:
		var blocker := StaticBody2D.new()
		blocker.position = FixedWorldProvider.point(door.position_candidate.local_world_units)-Vector2(0,48)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32,96) if door.direction in ["left","right"] else Vector2(96,32)
		var collision := CollisionShape2D.new()
		collision.shape = shape
		blocker.add_child(collision)
		add_child(blocker)
		door_blocks[door.id] = blocker
	var solids: Array[Rect2]=[]
	for i: int in platforms.size():
		if i not in one_way_indices: solids.append(platforms[i])
	add_child(UnderworldTerrain.build(solids))
	for rect: Rect2 in climbable_walls:
		var wall:=WorldClimbableWall.new();wall.bounds=rect;add_child(wall)
	for point: Vector2 in hook_points:
		var anchor:=GrappleAnchor.new();anchor.position=point;anchor.hang_enabled=true;add_child(anchor)
	for sign: Dictionary in signs:
		label_at(str(sign.text),FixedWorldProvider.point(sign.point))

func configure(row: Dictionary) -> void:
	contract = row
	doors = row.doors
	queue_redraw()

func label_at(text: String, point: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size",15)
	label.modulate = Color("cee2b4")
	add_child(label)

func _draw() -> void:
	if contract.is_empty(): return
	var bounds := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units)
	for i: int in platforms.size():
		if i in one_way_indices: UnderworldTerrain.draw_one_way(self,platforms[i])
	for hazard: Rect2 in hazards:
		draw_rect(hazard,Color("b9504c"))
	for door: Dictionary in doors:
		var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
		var rect:=Rect2(p-Vector2(16,96),Vector2(32,96)) if door.direction in ["left","right"] else Rect2(p-Vector2(48,16),Vector2(96,32))
		if not door_open.get(door.id,false):
			draw_rect(rect,Color("3c4b44"))
			draw_rect(rect,Color("9f8b67"),false,3)
			draw_line(rect.position,rect.end,Color("9f8b67"),3)
			draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),Color("9f8b67"),3)
		else:
			draw_rect(rect.grow(4),Color(.85,.72,.42,.2))
			draw_rect(rect,Color("d8b35d"),false,2)
	if rest_point != Vector2.ZERO:
		draw_rect(Rect2(rest_point+Vector2(-28,8),Vector2(56,10)),Color("7dc1b0"))
	if reward_point != Vector2.ZERO:
		draw_texture_rect(UnderworldActors.icon_texture(&"bell"),Rect2(reward_point-Vector2(14,28),Vector2(28,38)),false)
	if services!=null:
		for pickup: Dictionary in services.definitions.get("pickups",[]):
			if pickup.room_id!=room_id or pickup.id in services.ledger().collected: continue
			var point:=FixedWorldProvider.point(pickup.point)
			draw_texture_rect(UnderworldActors.icon_texture(&"chest"),Rect2(point-Vector2(12,10),Vector2(24,28)),false)

func install(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, boss_defeated: bool, entry_anchor: Vector2) -> void:
	for placement: Dictionary in enemy_placements:
		var id := str(placement.id)
		var saved: Dictionary = saved_enemies.get(id,{})
		if saved.get("health",1.0)<=0: continue
		var body := EnemyFactory.create_for_behavior(StringName(placement.behavior))
		body.position = FixedWorldProvider.point(placement.point)
		var actor := body.get_node("Actor") as EnemyActor
		if placement.has("max_health"):
			actor.definition=actor.definition.duplicate(true) as EnemyDefinition
			actor.definition.health_definition.max_health=float(placement.max_health)
			actor.definition.health_definition.initial_current=float(placement.max_health)
		add_child(body)
		if saved.has("health"): actor.restore_instance_health(float(saved.health))
		policy.bind_damageable(StringName(id),actor.damageable,actor.health)
		actor.bind_encounter(controller,policy,lifetime,StringName(id),[entry_anchor])
		if not saved.is_empty() and actor.attack_behavior != null:
			actor.attack_behavior.restore_region_state(saved)
		EnemyPresentationBinding.synchronize(actor)
		DemoContactEmitter.attach(body,policy,controller,StringName(id+":contact"),DamageRequest.Kind.MONSTER,actor.definition.collision_size/2)
		enemies[id] = actor
	for index: int in hazards.size():
		add_child(DemoContactEmitter.environment_rect(hazards[index],policy,controller,StringName(room_id+":terrain:"+str(index))))
	if boss_identity.is_empty() or boss_defeated:
		battle_finished = not boss_identity.is_empty()
		return
	if boss_binding==null:
		push_error("Boss room requires its owned encounter binding: "+room_id)
		return
	var binding: RefCounted=boss_binding.new()
	var installed: Dictionary=binding.call("install",self,boss_identity,boss_position,arena_bounds,controller,policy,lifetime)
	boss=installed.boss;encounter=installed.encounter;boss_contact=installed.contact
	for x: float in [arena_bounds.position.x,arena_bounds.end.x]:
		var seal := StaticBody2D.new()
		seal.position = Vector2(x,arena_bounds.get_center().y)
		seal.collision_layer = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(12,arena_bounds.size.y)
		collision.shape = shape
		seal.add_child(collision)
		add_child(seal)
		seals.append(seal)

func update_battle(player_position: Vector2) -> void:
	if encounter == null or battle_finished: return
	if not battle_started and arena_bounds.grow(-30).has_point(player_position):
		battle_started = encounter.activate()
		boss_contact.enabled = battle_started
		for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",1)
	if encounter.health.terminal: boss_contact.enabled = false

func finish_battle() -> void:
	battle_finished = true
	for seal: StaticBody2D in seals: seal.set_deferred("collision_layer",0)

func snapshot() -> Dictionary:
	var result := {}
	for id: String in enemies:
		var actor: EnemyActor = enemies[id]
		result[id] = actor.region_snapshot()
	return result

func refresh_doors(state: FixedWorldState, content: FixedWorldProvider) -> void:
	for door: Dictionary in doors:
		var opened := bool(door.outbound_allowed) and state.holds(door.requires) and not content.room(str(door.target_room)).is_empty()
		door_open[door.id]=opened
		(door_blocks[door.id] as StaticBody2D).set_deferred("collision_layer",0 if opened else 1)
	queue_redraw()

func bind_services(value: WorldServices,controller: PlayerController,policy: FrameDamagePolicy,lifetime: DemoLifetime) -> void:
	services=value
	for presentation: Node in find_children("*","WorldFlagPresentation",true,false): presentation.bind(value.state.has)
	for zone: Dictionary in environment_zones:
		var fixture:=WorldEnvironmentZone.new()
		fixture.name=str(zone.id)
		fixture.bounds=FixedWorldProvider.rect(zone.bounds)
		fixture.mode=zone.mode;fixture.services=value
		fixture.controller=controller;fixture.policy=policy;fixture.lifetime=lifetime
		add_child(fixture)
	queue_redraw()
