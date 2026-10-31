class_name GeneratedDemoStage
extends DemoStage
## Actual Run consumer. Geometry and safe placements come from the recorded generator.
const VISUAL_LAYER := preload("res://game/presentation/world/art/plains_stage_visual.gd")
var visual_layer: Node2D
var assembler: RandomStageAssembler
var generated: Dictionary = {}
var level_plan: LevelPlan
var tuning: PlayerTuning
var bounds := Rect2()
var anchors: Array[Vector2] = []
var boss_arena := Rect2()
var pickups: Array[Dictionary] = []
var reward_ready_at:=0.0
var coins_collected := 0
var assembly_ok := false
var enemies: Array[EnemyMotor] = []
var enemy_manifest: Array[Dictionary] = []
var encounter_plan: Dictionary = {}
var route_signpost: RouteSignpost
var shot_latch_encounter: GeneratedShotLatchEncounter
var shot_latches: Array[ShotLatch] = []

func configure_generated(data: Dictionary, player_tuning: PlayerTuning) -> void:
	generated = data
	tuning = player_tuning

func configure_level(plan: LevelPlan, source_view: Dictionary, player_tuning: PlayerTuning) -> void:
	level_plan=plan
	# The existing region adapters retain their own view/recording source. The
	# shared LevelRuntime only sees the plan and never requires this dictionary.
	configure_generated(source_view,player_tuning)

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
	_install_route_signpost()
	var expected_encounters := PlainsEncounterPlanner.recorded_plan(generated.manifest)
	if generated.has("encounter_plan") and not RandomStageGenerator.new()._same_data(generated.encounter_plan, expected_encounters):
		assembly_ok = false
		push_error("Generated encounter plan differs from validated map/configuration")
		return
	encounter_plan = expected_encounters
	_spawn_enemies_from_plan()
	if stage_type == &"boss":
		boss = BossFactory.create(&"windkeeper")
		boss.position = Vector2(boss_arena.get_center().x, boss_arena.end.y - 65)
		add_child(boss)
		reward_position = boss.position
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
	_install_branch_bonuses()
	install_visual_layer(VISUAL_LAYER.new())
	var dressing := PlainsSetDressing.new()
	dressing.name = "PlainsSetDressing"
	add_child(dressing)
	dressing.configure(self)
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
	_advance_pickup_motion(delta)
	queue_redraw()

func _advance_pickup_motion(delta: float) -> void:
	for pickup: Dictionary in pickups:
		PlainsLootMotion.advance(pickup,delta,self)
	_persist_pickup_motion()

# App commits the resource transaction before these local map mutations.
func record_collected_coins(amount: int) -> void:
	coins_collected += amount

func commit_pickup_claim(pickup: Dictionary, record_region_claim: bool) -> void:
	pickup.claimed = true
	pickup.claimed_position=pickup.position
	pickup.claimed_at=clock
	if record_region_claim: _record_claim(pickup.id)

func _record_claim(_id: Variant) -> void:
	pass

# Keep persistence at the caller's original point after reward feedback.
func persist_pickup_motion() -> void:
	_persist_pickup_motion()

func _persist_pickup_motion() -> void:
	pass

func _save_pickup_units(drops: Dictionary) -> void:
	# Record live positions so a reload resumes existing entitlements at rest,
	# without replaying the death spray or creating a second unit/receipt.
	for pickup: Dictionary in pickups:
		var source := str(pickup.get("source",""))
		if source.is_empty() or not drops.has(source): continue
		var records: Array = drops[source].get("units",[])
		for record: Dictionary in records:
			if str(record.id)==str(pickup.id): record.merge(PlainsLootMotion.snapshot(pickup),true)

func restore_drop_pickups(drop: Dictionary, identity: String, claims: Dictionary) -> void:
	if drop.has("units"):
		for record: Dictionary in drop.units:
			var pickup := PlainsLootMotion.restore(record,clock)
			pickup.claimed=claims.has(pickup.id) or bool(record.get("claimed",false))
			pickups.append(pickup)
	elif drop.get("kind","none")!="none":
		pickups.append({"id":"drop_"+identity,"kind":drop.kind,"amount":int(drop.amount),"position":Vector2(drop.position[0],drop.position[1]),"claimed":claims.has("drop_"+identity),"source":identity})

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


func _spawn_enemies_from_plan() -> void:
	for index: int in encounter_plan.enemies.size():
		var data: Dictionary=encounter_plan.enemies[index]
		var drone: EnemyMotor
		if level_plan!=null:
			drone=LevelRuntime.create_actor(level_plan.actors[index])
		else:
			# Explicit old non-region previews continue through the same factory.
			var overrides := {&"patrol_half_width":data.patrol_radius,&"aerial":data.aerial}
			if data.has("dive_depth"): overrides[&"dive_depth"] = float(data.dive_depth)
			drone=EnemyFactory.create_for_behavior(StringName(data.behavior_id),overrides)
			if drone!=null: drone.position=Vector2(data.position[0],data.position[1])
		if drone == null:
			assembly_ok = false
			push_error("Recorded enemy behavior/instance overrides rejected: " + String(data.behavior_id))
			return
		var actor := drone.get_node("Actor") as EnemyActor
		if actor.definition.behavior_id == &"root_bell":
			var old := drone.get_node("Presentation")
			drone.remove_child(old)
			old.free()
			var presentation := RootBellPresentation.new()
			presentation.name = "Presentation"
			presentation.actor = actor
			drone.add_child(presentation)
		add_child(drone)
		enemies.append(drone)
		enemy_manifest.append(data.duplicate(true))
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

func _install_route_signpost() -> void:
	if exits.is_empty() or not generated.manifest.has("fork_node"):
		return
	var fork: PlatformingModule = assembler.modules[int(generated.manifest.fork_node)]
	# The second authored anchor is the safe decision point before the first
	# ascending step. Keep the post beside it, not at the distant terminal doors.
	route_signpost = RouteSignpost.new()
	route_signpost.name = "RouteSignpost"
	route_signpost.position = fork.position + fork.definition.anchors[1] + Vector2(-65, 18)
	route_signpost.z_index = 2
	var directions: Array[Vector2] = []
	for index: int in exits.size():
		var first_node: int = generated.manifest.terminal_paths[index][0]
		var seam: Dictionary = generated.manifest.seams[first_node - 1]
		directions.append(Vector2.UP if seam.from_port_id == "fork_up" else Vector2.RIGHT)
	route_signpost.configure(exits, directions, generated.manifest.get("branch_profiles", []))
	add_child(route_signpost)

func _install_branch_bonuses() -> void:
	# The generator commits the risk/reward budget. Use its checked landing points
	# and the existing per-pickup receipt ledger; no draw or regeneration on return.
	var profiles: Array = generated.manifest.get("branch_profiles", [])
	var paths: Array = generated.manifest.get("terminal_paths", [])
	for index: int in mini(profiles.size(), paths.size()):
		var profile: Dictionary = profiles[index]
		if profile.get("risk", "steady") != "challenge" or paths[index].is_empty():
			continue
		var terminal: PlatformingModule = assembler.modules[int(paths[index][-1])]
		var candidates := terminal.world_anchors()
		if candidates.is_empty():
			continue
		var point: Vector2 = candidates[candidates.size() / 2]
		if not generated.placement_points.has(point):
			continue
		for kind: String in ["coin", "note"]:
			var amount := int(profile.get("bonus_coins" if kind == "coin" else "bonus_notes", 0))
			var pickup_id := "branch_%s_bonus_%s" % [index, kind]
			if amount <= 0 or pickups.any(func(p: Dictionary) -> bool: return p.id == pickup_id):
				continue
			pickups.append({"id": pickup_id, "kind": kind, "amount": amount,
				"position": point + Vector2(-12 if kind == "coin" else 12, -8),
				"claimed": false, "branch_index": index})

func setup_shot_latches(controller: PlayerController, lifetime: DemoLifetime) -> bool:
	if not PlainsShotLatchPlanner.validate(generated.manifest):
		return false
	shot_latch_encounter = GeneratedShotLatchEncounter.new()
	shot_latch_encounter.name = "GeneratedShotLatchEncounter"
	add_child(shot_latch_encounter)
	if not shot_latch_encounter.setup(generated.manifest, assembler, controller, lifetime):
		return false
	shot_latches = shot_latch_encounter.latches
	return true

func cancel_shot_latch_requests(permanent: bool = false) -> void:
	if not is_instance_valid(shot_latch_encounter):
		return
	if permanent:
		shot_latch_encounter.cancel()
	else:
		shot_latch_encounter.cancel_pending()
