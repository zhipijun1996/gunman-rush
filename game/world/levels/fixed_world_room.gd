class_name FixedWorldRoom
extends Node2D
## Authored geometry and placements. Reads contract interfaces; never grants progress.
@export var room_id := ""
@export var platforms: Array[Rect2] = []
@export var one_way_indices: Array[int] = []
@export var start_point := Vector2(144,512)
@export var rest_point := Vector2.ZERO
@export var reward_point := Vector2.ZERO
@export var enemy_placements: Array[Dictionary] = []
@export var signs: Array[Dictionary] = []
@export var hazards: Array[Rect2] = []
@export var boss_identity: StringName
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
	for side: String in ["left","right","up"]:
		var gaps: Array[Vector2] = []
		for door: Dictionary in doors:
			if door.direction != side: continue
			var point := FixedWorldProvider.point(door.position_candidate.local_world_units)
			gaps.append(Vector2(point.x-48,point.x+48) if side=="up" else Vector2(point.y-96,point.y))
		gaps.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.x<b.x)
		gaps.append(Vector2(size.x if side=="up" else size.y,0))
		var start := 0.0
		for gap: Vector2 in gaps:
			if gap.x>start:
				platforms.append(Rect2(start,-32,gap.x-start,32) if side=="up" else Rect2(-32 if side=="left" else size.x,start,32,gap.x-start))
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
	draw_rect(bounds,Color("19272c"))
	for x: int in range(0,int(bounds.size.x),64): draw_line(Vector2(x,0),Vector2(x,bounds.size.y),Color("223039"),1)
	for r: Rect2 in platforms:
		draw_rect(r,Color("596652"))
		draw_line(r.position,Vector2(r.end.x,r.position.y),Color("b9c487"),3)
	for hazard: Rect2 in hazards:
		draw_rect(hazard,Color("b9504c"))
	for door: Dictionary in doors:
		var p := FixedWorldProvider.point(door.position_candidate.local_world_units)
		draw_circle(p,22,Color("8a6767") if door_blocks.has(door.id) and door_blocks[door.id].collision_layer!=0 else Color("d8b35d"))
		draw_line(p-Vector2(0,28),p+Vector2(0,28),Color("f9df8c"),4)
	if rest_point != Vector2.ZERO:
		draw_rect(Rect2(rest_point+Vector2(-28,8),Vector2(56,10)),Color("7dc1b0"))
	if reward_point != Vector2.ZERO:
		draw_circle(reward_point,12,Color("e6d07b"))

func install(controller: PlayerController, policy: FrameDamagePolicy, lifetime: DemoLifetime, saved_enemies: Dictionary, boss_defeated: bool, entry_anchor: Vector2) -> void:
	for placement: Dictionary in enemy_placements:
		var id := str(placement.id)
		var saved: Dictionary = saved_enemies.get(id,{})
		if saved.get("health",1.0)<=0: continue
		var body := EnemyFactory.create_for_behavior(StringName(placement.behavior))
		body.position = FixedWorldProvider.point(placement.point)
		add_child(body)
		var actor := body.get_node("Actor") as EnemyActor
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
	boss = BossFactory.create(boss_identity)
	boss.position = boss_position
	add_child(boss)
	encounter = boss.get_node("Encounter") as BossEncounter
	policy.bind_damageable(&"P_WINDKEEPER",boss.get_node("Damageable"),encounter.health)
	encounter.configure_arena(arena_bounds.position.x,arena_bounds.end.x,controller.motor)
	var segment := SegmentRespawn.new()
	segment.configure(controller,lifetime)
	(encounter as WindkeeperEncounter).bind_stage_geometry(get_node("Arena") as PlatformingModule,controller,policy,lifetime,segment)
	encounter.projectile_created.connect(func(projectile: BossProjectile) -> void:
		var ticket := lifetime.token()
		projectile.hit.connect(func(body: Node,event_id: StringName,amount: float) -> void:
			if body != controller.motor or not lifetime.accepts(ticket): return
			var request := DamageRequest.new()
			request.token = ticket
			request.actor_epoch = ticket.actor_epoch
			request.health_epoch = controller.actor_resources.health.epoch
			request.target_id = &"player"
			request.source_id = &"boss_projectile"
			request.event_id = event_id
			request.amount = amount
			policy.submit(request)))
	boss_contact = DemoContactEmitter.attach(boss,policy,controller,&"boss_body",DamageRequest.Kind.MONSTER,Vector2(72,62))
	boss_contact.contact_rect_provider = (encounter as WindkeeperEncounter).body_contact_rect
	boss_contact.contact_test_provider = (encounter as WindkeeperPressureEncounter).body_contact_sweep
	boss_contact.enabled = false
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
		(door_blocks[door.id] as StaticBody2D).set_deferred("collision_layer",0 if opened else 1)
	queue_redraw()
