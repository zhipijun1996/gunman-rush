class_name GeneratedDemoStage
extends DemoStage
## Actual Run consumer. Geometry and safe placements come from the recorded generator.
var assembler: RandomStageAssembler
var generated: Dictionary = {}
var tuning: PlayerTuning
var bounds := Rect2()
var anchors: Array[Vector2] = []
var boss_arena := Rect2()
var pickups: Array[Dictionary] = []
var coins_collected := 0
var assembly_ok := false

func configure_generated(data: Dictionary, player_tuning: PlayerTuning) -> void:
	generated = data
	tuning = player_tuning

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	assembler = RandomStageAssembler.new()
	add_child(assembler)
	var assembled := assembler.build(generated.manifest, tuning)
	if not assembled.ok:
		push_error("Generated run assembly failed: " + str(assembled.error))
		return
	assembly_ok = true
	bounds = assembler.bounds
	spawn = assembler.world_entry()
	anchors = assembler.world_anchors()
	anchor_position = anchors[mini(1, anchors.size() - 1)]
	boss_arena = generated.boss_arena
	var points: Array[Vector2] = []
	points.assign(generated.placement_points)
	supply_position = points[mini(1, points.size() - 1)]
	reward_position = points[maxi(0, points.size() - 2)]
	var terminal := assembler.world_exits()
	exit_positions.clear()
	for index: int in exits.size():
		var location: Vector2 = terminal[mini(index, terminal.size() - 1)].position
		# Two route choices remain visually and interactively distinct on one safe dock.
		if terminal.size() == 1:
			location -= (terminal[0].port as PlatformingModulePort).direction * float(index * 120)
		exit_positions.append(location)
		_exit_labels.append(_sign(location + Vector2(-75, -75 - index * 20), "LOCKED"))
	_supply_label = _sign(supply_position + Vector2(-45, -55), "SUPPLY +2 HP", Color("a4d6a4"))
	if stage_type == &"combat":
		enemy = PATROL.instantiate() as EnemyMotor
		var terminal_module: PlatformingModule = assembler.modules.back()
		var patrol_floor := terminal_module.definition.platforms[0]
		for platform: Rect2 in terminal_module.definition.platforms:
			if platform.size.x > patrol_floor.size.x and platform.size.x > platform.size.y:
				patrol_floor = platform
		enemy.position = terminal_module.to_global(Vector2(patrol_floor.get_center().x, patrol_floor.position.y - 46))
		var actor := enemy.get_node("Actor") as EnemyActor
		actor.definition = actor.definition.duplicate(true) as EnemyDefinition
		actor.definition.patrol_half_width = minf(100, maxf(0, patrol_floor.size.x / 2 - 22))
		add_child(enemy)
		_sign(enemy.position + Vector2(-75, -60), "DEFEAT THE DRONE")
	elif stage_type == &"boss":
		boss = BOSS.instantiate() as Node2D
		boss.position = Vector2(boss_arena.get_center().x, boss_arena.end.y - 40)
		add_child(boss)
		reward_position = boss.position
		_sign(boss.position + Vector2(-100, -110), "CLOCKWORK GUARDIAN", Color("efce88"))
	if ROOM_MARKERS.has(stage_type) and stage_type != &"coin_reward":
		_sign(reward_position + Vector2(-90, -65), ROOM_MARKERS[stage_type].text, ROOM_MARKERS[stage_type].color)
	var stream := RunRandomStream.new(str(generated.manifest.seed), "pickups", "stage_%s" % stage_index, "plains-pickups-v1")
	for index: int in points.size():
		if index == 0:
			continue
		var count := 3 if stage_type == &"coin_reward" else 1
		if stage_type == &"coin_reward" or index % 3 == 1:
			for column: int in count:
				pickups.append({"id": "coin_%s_%s" % [index, column], "kind": "coin", "amount": 2 if stage_type == &"coin_reward" else 1, "position": points[index] + Vector2((column - (count - 1) / 2.0) * 18, -12), "claimed": false})
		if index % 4 == 2 or (index == points.size() - 1 and pickups.filter(func(p: Dictionary) -> bool: return p.kind == "note").is_empty()):
			pickups.append({"id": "note_%s" % index, "kind": "note", "amount": 1, "position": points[index] + Vector2(0, -44 - stream.next_int(4)), "claimed": false})
	queue_redraw()

func manifest_pickups() -> Array:
	var data: Array = []
	for pickup: Dictionary in pickups:
		data.append({"id": pickup.id, "kind": pickup.kind, "amount": pickup.amount, "position": [pickup.position.x, pickup.position.y]})
	return data

func reached_finish(location: Vector2) -> bool:
	for exit: Vector2 in exit_positions:
		if location.distance_to(exit) < 150:
			return true
	return false

func _physics_process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if not assembly_ok:
		return
	for pickup: Dictionary in pickups:
		if pickup.claimed:
			continue
		var point: Vector2 = pickup.position
		if pickup.kind == "coin":
			draw_circle(point, 7, Color("e6be58"))
			draw_circle(point, 5, Color("fff1aa"), false, 1)
		else:
			draw_circle(point + Vector2(-3, 5), 5, Color("c5a9f5"))
			draw_line(point, point + Vector2(0, -12), Color("e3d3ff"), 3)
			draw_line(point + Vector2(0, -12), point + Vector2(7, -9), Color("e3d3ff"), 3)
	for index: int in exits.size():
		_draw_exit_icon(exit_positions[index] + Vector2(-22, -28), exits[index].icon_id)
		draw_rect(Rect2(exit_positions[index] - Vector2(12, 22), Vector2(24, 40)), Color("bcdaae") if completed else Color("677266"), false, 2)
	if not supply_claimed:
		draw_circle(supply_position, 9, Color("8cb889"))
		draw_line(supply_position - Vector2(5, 0), supply_position + Vector2(5, 0), Color("ecedd6"), 2)
		draw_line(supply_position - Vector2(0, 5), supply_position + Vector2(0, 5), Color("ecedd6"), 2)
	if reward_available or stage_type in [&"item_reward", &"shop", &"health_reward"]:
		draw_circle(reward_position, 12, Color("ddb87a"))

func nearby_exit(location: Vector2) -> int:
	var nearest := -1
	var best := 95.0
	for index: int in exit_positions.size():
		var distance := location.distance_to(exit_positions[index])
		if distance < best:
			best = distance
			nearest = index
	return nearest
