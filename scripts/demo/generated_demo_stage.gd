class_name GeneratedDemoStage
extends DemoStage
## Actual Run consumer. Geometry and safe placements come from the recorded generator.
const VISUAL_LAYER := preload("res://scripts/art/plains_stage_visual.gd")
var visual_layer: Node2D
var assembler: RandomStageAssembler
var generated: Dictionary = {}
var tuning: PlayerTuning
var bounds := Rect2()
var anchors: Array[Vector2] = []
var boss_arena := Rect2()
var pickups: Array[Dictionary] = []
var coins_collected := 0
var assembly_ok := false
var enemies: Array[EnemyMotor] = []
var enemy_manifest: Array[Dictionary] = []

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
		if generated.has("exit_points") and generated.exit_points.size() > index:
			location = generated.exit_points[index]
		# Compatibility for old one-port manifests; formal maps record separate ports.
		if terminal.size() == 1 and not generated.has("exit_points"):
			location -= (terminal[0].port as PlatformingModulePort).direction * float(index * 120)
		exit_positions.append(location)
	if stage_type == &"combat":
		_spawn_combat_enemies()
	elif stage_type == &"boss":
		boss = BOSS.instantiate() as Node2D
		boss.position = Vector2(boss_arena.get_center().x, boss_arena.end.y - 40)
		add_child(boss)
		reward_position = boss.position
		_sign(boss.position + Vector2(-100, -110), "CLOCKWORK GUARDIAN", Color("efce88"))
	if stage_type == &"shop":
		_sign(reward_position + Vector2(-90, -65), ROOM_MARKERS[stage_type].text, ROOM_MARKERS[stage_type].color)
	var stream := RunRandomStream.new(str(generated.manifest.seed), "pickups", "stage_%s" % stage_index, "plains-pickups-v1")
	pickups.append({"id": "supply_heart", "kind": "heart", "amount": 2, "position": supply_position, "claimed": false})
	for index: int in points.size():
		if index == 0:
			continue
		var count := 3 if stage_type == &"coin_reward" else 1
		if stage_type == &"coin_reward" or index % 3 == 1:
			for column: int in count:
				pickups.append({"id": "coin_%s_%s" % [index, column], "kind": "coin", "amount": 2 if stage_type == &"coin_reward" else 1, "position": points[index] + Vector2((column - (count - 1) / 2.0) * 18, -12), "claimed": false})
		if index % 4 == 2 or (index == points.size() - 1 and pickups.filter(func(p: Dictionary) -> bool: return p.kind == "note").is_empty()):
			pickups.append({"id": "note_%s" % index, "kind": "note", "amount": 1, "position": points[index] + Vector2(0, -44 - stream.next_int(4)), "claimed": false})
	install_visual_layer(VISUAL_LAYER.new())
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
		if is_instance_valid(visual_layer):
			break
		if pickup.claimed:
			continue
		var point: Vector2 = pickup.position
		if pickup.kind == "coin":
			draw_circle(point, 7, Color("e6be58"))
			draw_circle(point, 5, Color("fff1aa"), false, 1)
		elif pickup.kind == "note":
			draw_circle(point + Vector2(-3, 5), 5, Color("c5a9f5"))
			draw_line(point, point + Vector2(0, -12), Color("e3d3ff"), 3)
			draw_line(point + Vector2(0, -12), point + Vector2(7, -9), Color("e3d3ff"), 3)
	for index: int in exits.size():
		if is_instance_valid(visual_layer):
			break
		_draw_exit_icon(exit_positions[index] + Vector2(-22, -28), exits[index].icon_id)
		draw_rect(Rect2(exit_positions[index] - Vector2(12, 22), Vector2(24, 40)), Color("bcdaae") if completed else Color("677266"), false, 2)
	if not supply_claimed and not is_instance_valid(visual_layer):
		draw_circle(supply_position, 9, Color("8cb889"))
		draw_line(supply_position - Vector2(5, 0), supply_position + Vector2(5, 0), Color("ecedd6"), 2)
		draw_line(supply_position - Vector2(0, 5), supply_position + Vector2(0, 5), Color("ecedd6"), 2)
	if stage_type == &"shop":
		draw_circle(reward_position, 12, Color("ddb87a"))
	if stage_type == &"boss" and reward_available and not is_instance_valid(visual_layer):
		draw_circle(reward_position, 26 + sin(clock * 3) * 3, Color(0.9, 0.72, 0.3, 0.2))
		draw_circle(reward_position, 17, Color("ebd087"), false, 3)
		_draw_exit_icon(reward_position, &"item_reward")

func nearby_exit(location: Vector2) -> int:
	var nearest := -1
	var best := 100.0
	for index: int in exit_positions.size():
		var distance := location.distance_to(exit_positions[index])
		if distance < best:
			best = distance
			nearest = index
	return nearest


func set_completed(value: bool) -> void:
	completed = value
	for index: int in _exit_labels.size():
		_exit_labels[index].text = "GATE / " + exits[index].label if value else "LOCKED / " + exits[index].label
		_exit_labels[index].modulate = Color("d8d5af") if value else Color("7c867b")
	queue_redraw()

func mark_supply_used() -> void:
	supply_claimed = true
	for pickup: Dictionary in pickups:
		if pickup.id == "supply_heart":
			pickup.claimed = true
	queue_redraw()


func show_boss_reward_portal() -> void:
	_sign(reward_position + Vector2(-90, -75), "GOLD GATE / CONFIRM TO CLAIM", Color("ebd087"))
	queue_redraw()


func _spawn_combat_enemies() -> void:
	var desired := 1 if stage_index <= 3 else (2 if stage_index <= 6 else 3)
	var candidates: Array[Dictionary] = []
	var dangers := assembler.world_dangers()
	for module_index: int in assembler.modules.size():
		var module: PlatformingModule = assembler.modules[module_index]
		var widest := Rect2()
		for platform: Rect2 in module.definition.platforms:
			if platform.size.x < 110 or platform.size.x < platform.size.y or platform.size.x <= widest.size.x:
				continue
			var point := module.to_global(Vector2(platform.get_center().x, platform.position.y - 18))
			if point.distance_to(spawn) < 420:
				continue
			var radius := minf(65, maxf(0, platform.size.x / 2 - 36))
			var patrol_volume := Rect2(point - Vector2(radius + 20, 30), Vector2(radius * 2 + 40, 54))
			var safe := true
			for danger: Rect2 in dangers:
				if patrol_volume.intersects(danger.grow(12)):
					safe = false
					break
			if safe:
				widest = platform
		if widest.size.x > 0:
			candidates.append({"module_index": module_index, "position": module.to_global(Vector2(widest.get_center().x, widest.position.y - 18)), "patrol_radius": minf(65, maxf(0, widest.size.x / 2 - 36))})
	var count := mini(desired, candidates.size())
	for index: int in count:
		var slot := mini(candidates.size() - 1, int(float(index + 1) * candidates.size() / float(count + 1)))
		var data: Dictionary = candidates[slot]
		var aerial := false
		# Alternate a hovering patrol over a checked open envelope. No player logic
		# or input dependency; reject aerial elevation if it overlaps terrain/hazards.
		if index % 2 == 1 or (count == 1 and stage_index >= 3):
			var airborne: Vector2 = data.position - Vector2(0, 74)
			var envelope := Rect2(airborne - Vector2(data.patrol_radius + 20, 30), Vector2(data.patrol_radius * 2 + 40, 54))
			aerial = true
			for danger: Rect2 in dangers:
				if envelope.intersects(danger.grow(12)):
					aerial = false
			for module: PlatformingModule in assembler.modules:
				for platform: Rect2 in module.definition.platforms:
					var world_rect := Rect2(module.to_global(platform.position), platform.size)
					if envelope.intersects(world_rect):
						aerial = false
			if aerial:
				data = data.duplicate()
				data.position = airborne
		var drone := PATROL.instantiate() as EnemyMotor
		drone.position = data.position
		var actor := drone.get_node("Actor") as EnemyActor
		actor.definition = actor.definition.duplicate(true) as EnemyDefinition
		actor.definition.patrol_half_width = data.patrol_radius
		actor.definition.aerial = aerial
		add_child(drone)
		enemies.append(drone)
		enemy_manifest.append({"id": "drone" if index == 0 else "drone_%s" % index, "module_index": data.module_index, "position": [data.position.x, data.position.y], "patrol_radius": data.patrol_radius, "aerial": aerial})
	if not enemies.is_empty():
		enemy = enemies[0]

func combat_completed() -> bool:
	for drone: EnemyMotor in enemies:
		if not (drone.get_node("Actor") as EnemyActor).health.terminal:
			return false
	return true

func safe_drop_position(death_position: Vector2) -> Vector2:
	# Settle on a generator-validated landing, so airborne kills cannot strand loot
	# inside a ceiling/hazard. Do not draw a new map or resource during a return.
	var nearest: Vector2 = spawn
	var best := INF
	for point: Vector2 in generated.placement_points:
		var distance := point.distance_squared_to(death_position)
		if distance < best:
			best = distance
			nearest = point
	return nearest - Vector2(0, 8)

func install_visual_layer(layer: Node2D) -> void:
	visual_layer = layer
	layer.call("configure", self)
	add_child(layer)
	queue_redraw()
