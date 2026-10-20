extends RefCounted
const PLAYER := preload("res://scenes/player/player.tscn")
const ENEMY := preload("res://scenes/enemies/patrol_drone.tscn")
var output_dir := "res://build/root_bell/unmanaged"
var tree: SceneTree
var check: Callable
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var actor: EnemyActor
var behavior: RootBellBehavior
var policy: FrameDamagePolicy
var life: DemoLifetime
var frames: Array = []
var events: Array = []
var cases: Array = []
var tick := 0

class SpawnConsumer extends GeneratedDemoStage:
	func _ready() -> void: _spawn_enemies_from_plan()
class SaveConsumer extends PlainsRegionStage:
	func _ready() -> void: pass
class FixtureGround extends Node2D:
	func _draw() -> void:
		PlainsTerrainSkin.draw_platform(self, Rect2(-500, 300, 1800, 600))

func slab(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

func fixture(blocked := false, restored: Dictionary = {}, floor_width := 0.0, direction := 1) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	tree.root.add_child(world)
	frames = []; events = []; tick = 0
	slab(Rect2(0, 300, floor_width, 40) if floor_width > 0 else Rect2(-500, 300, 1800, 40))
	if blocked: slab(Rect2(260, 160, 24, 140))
	player = PLAYER.instantiate()
	player.position = Vector2(64 if direction > 0 else floor_width - 64, 282) if floor_width > 0 else Vector2(180, 282)
	world.add_child(player)
	controller = player.get_node("Controller")
	check.call(controller.enable_shot_energy(), "formal shot energy accepted")
	life = DemoLifetime.new()
	policy = FrameDamagePolicy.new()
	policy.lifetime = life
	world.add_child(policy)
	policy.register_target(&"player", controller.actor_resources.health, true)
	var consumer := SpawnConsumer.new()
	consumer.encounter_plan = {"enemies": [{"id": "root_fixture", "behavior_id": "root_bell", "position": [floor_width * .5 if floor_width > 0 else 340.0, 280], "aerial": false, "patrol_radius": 0}]}
	world.add_child(consumer)
	actor = consumer.enemies[0].get_node("Actor")
	if not restored.is_empty(): actor.restore_instance_health(float(restored.health))
	check.call(consumer.enemies[0].get_node("Presentation") is RootBellPresentation, "actual GeneratedDemoStage consumer binds independent root presentation")
	policy.bind_damageable(&"root_fixture", actor.damageable, actor.health)
	actor.bind_encounter(controller, policy, life, &"root_fixture", [])
	behavior = actor.attack_behavior as RootBellBehavior
	# Same inherited fields consumed by the actual DemoApp restore loop. This is
	# an isolated snapshot fixture, not a claimed complete formal map reload.
	if not restored.is_empty():
		behavior.state = StringName(restored.state)
		behavior.state_time = restored.state_time
		behavior.cooldown = restored.cooldown
		behavior._serial = restored.serial
		for field: String in ["locked_direction", "attack_goal", "attack_origin", "home"]:
			behavior.set(field, Vector2(restored[field][0], restored[field][1]))
	var contact := DemoContactEmitter.new()
	contact.controller = controller; contact.policy = policy; contact.source_id = &"root_contact"
	contact.half_size = actor.definition.collision_size * .5 + Vector2.ONE
	contact.enabled = not actor.health.terminal
	actor.motor.add_child(contact)
	actor.defeated.connect(func(_dead: EnemyActor): contact.enabled = false)
	behavior.state_changed.connect(func(state: StringName): events.append({"kind": "state", "tick": tick + 1, "state": str(state)}))
	behavior.warning_interrupted.connect(func(): events.append({"kind": "interrupted", "tick": tick + 1}))
	behavior.pulse_committed.connect(func(id: StringName, point: Vector2): events.append({"kind": "pulse", "tick": tick + 1, "id": str(id), "point": [point.x, point.y]}))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, id: int): events.append({"kind": "shot", "tick": tick + 1, "shot_id": id, "direction": [direction.x, direction.y]}))
	controller.jump_ability.jumped.connect(func(): events.append({"kind": "accepted_jump", "tick": tick + 1}))
	controller.landed.connect(func(): events.append({"kind": "accepted_landing", "tick": tick + 1}))
	policy.batch_resolved.connect(func(results: Array[DamageResult]):
		for result: DamageResult in results: events.append({"kind": "damage", "tick": tick + 1, "id": str(result.request.event_id), "target": str(result.request.target_id), "health": result.health.current, "amount": result.request.amount}))
	await advance(3)

func advance(count := 1) -> void:
	for unused: int in count:
		await tree.physics_frame
		await tree.process_frame
		tick += 1
		frames.append({"tick": tick, "process_frame": Engine.get_process_frames(), "physics_frame": Engine.get_physics_frames(), "position": [player.global_position.x, player.global_position.y], "grounded": player.is_on_floor(), "player_hp": controller.actor_resources.health.current, "energy": controller.actor_resources.stamina.current, "enemy_hp": actor.health.current, "damage_stun_remaining": actor._damage_stun_remaining, "state": str(behavior.state), "time": behavior.state_time, "goal": [behavior.attack_goal.x, behavior.attack_goal.y], "serial": behavior._serial, "active": controller.active, "axis": controller.router.axis})

func warning() -> bool:
	for unused: int in 100:
		if behavior.state == &"telegraph": return true
		await advance()
	return false

func record(id: String, extra: Dictionary = {}) -> void:
	var row := {"id": id, "scope": "actual_normal_scheduled_Motor_damage_and_GeneratedDemoStage_spawn_fixture", "frames": frames.duplicate(true), "events": events.duplicate(true), "damage_feedback": {"resource_path": actor.damage_feedback.resource_path, "enemy_knockback_seconds": actor.damage_feedback.enemy_knockback_seconds}}
	row.merge(extra)
	cases.append(row)

func count_event(kind: String) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e.kind == kind).size()

func player_damage() -> int:
	return events.filter(func(e: Dictionary) -> bool: return e.kind == "damage" and e.target == "player").size()

func run(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree; check = p_check
	await fixture()
	check.call(await warning(), "grounded real player starts warning")
	var goal := behavior.attack_goal
	var start_hp := controller.actor_resources.health.current
	await advance(65)
	check.call(count_event("pulse") == 1 and player_damage() == 1 and controller.actor_resources.health.current == start_hp - 1, "standing inside real pulse damages once through policy")
	check.call(behavior.attack_goal == goal and behavior._serial == 1, "fixed mark and unique attack serial retained")
	record("stand_in_pulse_positive_damage")
	await fixture()
	check.call(await warning(), "walk-out warning begins")
	goal = behavior.attack_goal
	controller.router.set_move_axis(-1)
	await advance(30)
	controller.router.set_move_axis(0)
	await advance(35)
	check.call(player.global_position.x < goal.x - actor.definition.pulse_size.x and player_damage() == 0 and count_event("pulse") == 1, "real walk out avoids fixed pulse without killing or energy grants")
	check.call(behavior.attack_goal == goal and actor.health.current == 3, "leaving mark never tracks feet or kills target")
	record("walk_out_alive_nonkill")
	await fixture()
	check.call(await warning(), "jump warning begins")
	await advance(35)
	controller.router.request_action(&"jump")
	await advance(30)
	check.call(count_event("pulse") == 1 and player_damage() == 0 and frames.any(func(f: Dictionary) -> bool: return not f.grounded and f.position[1] < 245), "accepted base jump really clears ground pulse")
	await advance(50)
	check.call(player.is_on_floor() and actor.health.current == 3, "base jump lands with enemy alive")
	record("base_jump_nonkill")
	await fixture()
	check.call(await warning(), "interrupt warning begins")
	controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await advance(30)
	check.call(count_event("shot") == 1 and actor.health.current == 2 and count_event("interrupted") == 1 and count_event("pulse") == 0, "real accepted projectile commits HP before warning interrupt")
	check.call(events.any(func(e: Dictionary) -> bool: return e.kind == "damage" and e.target == "root_fixture"), "interrupt traced to formal damage batch")
	record("real_projectile_interrupt")
	await fixture(true)
	controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await advance(100)
	check.call(actor.health.current == 3 and count_event("interrupted") == 0 and count_event("pulse") == 0, "real wall blocks shooting and root sensing")
	record("solid_occlusion_negative")
	await fixture()
	check.call(await warning(), "air shot negative warning begins")
	controller.router.request_action(&"shoot_release", Vector2.UP)
	await advance(65)
	check.call(actor.health.current == 3 and count_event("interrupted") == 0 and count_event("pulse") == 1, "accepted missed shot cannot fake interruption")
	record("miss_does_not_interrupt")
	await fixture()
	check.call(await warning(), "epoch warning begins")
	var old_state := behavior.state
	var old_time := behavior.state_time
	tree.paused = true
	for unused: int in 10: await tree.process_frame
	check.call(behavior.state == old_state and behavior.state_time == old_time, "pause preserves warning and phase")
	tree.paused = false
	life.invalidate_actor()
	await advance(20)
	check.call(count_event("pulse") == 0 and behavior.state == &"recovery", "actor epoch invalidation cancels pending pulse with recovery debt")
	record("pause_actor_epoch")
	await fixture()
	check.call(await warning(), "inactive warning begins")
	controller.active = false
	await advance(70)
	check.call(count_event("pulse") == 0 and player_damage() == 0, "inactive target cancels warning and hazard")
	record("inactive_target")
	await fixture()
	var deaths: Array = []
	actor.defeated.connect(func(value: EnemyActor): deaths.append(value.get_instance_id()))
	for unused: int in 3:
		for wait: int in 90:
			if controller.shoot_ability.cooldown_remaining <= 0: break
			await advance()
		controller.router.request_action(&"shoot_release", Vector2.RIGHT)
		await advance(20)
	check.call(actor.health.terminal and deaths.size() == 1 and actor.motor.collision_layer == 0, "three real shots kill once and clear body")
	var pulse_count := count_event("pulse")
	controller.router.set_move_axis(1)
	for walk_tick: int in 180:
		if player.global_position.x > 400: break
		await advance()
	controller.router.set_move_axis(0)
	check.call(count_event("pulse") == pulse_count and player.global_position.x > 370 and player_damage() == 0, "early dead root is not a required resource/landing and leaves clear path")
	record("early_real_death_and_walk_through")
	await snapshot_cases()
	await width_calibration()
	placement()
	formal_manifest_candidates()
	if is_instance_valid(world): world.free()
	var file := FileAccess.open(output_dir + "/capture.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"cases": cases, "production_pool": false, "scope": "G0/G1 fixtures and actual spawn consumer; formal route/visual/audio/device unverified"}, "\t"))

func width_calibration() -> void:
	# These are bounded engineering observations, not a new admission threshold.
	# Keep the original 560 policy and 1/20 manifest result for separate review.
	for width: float in [400.0, 440.0, 560.0]:
		for direction: int in [-1, 1]:
			await fixture(false, {}, width, direction)
			var takeoff := width * .5 - float(direction) * 90
			var finish := width - 64 if direction > 0 else 64.0
			check.call(await move_to(takeoff), "calibration real supported takeoff width=%s dir=%s" % [width, direction])
			check.call(await warning(), "calibration locks supported ground width=%s dir=%s" % [width, direction])
			controller.router.request_action(&"jump")
			check.call(await move_to(finish, 180), "calibration continuous jump and landing width=%s dir=%s" % [width, direction])
			await advance(45)
			check.call(player_damage() == 0 and actor.health.current == 3 and player.is_on_floor() and count_event("pulse") >= 1 and count_event("accepted_jump") == 1, "calibration living root and actual pulse crossed without damage/shot width=%s dir=%s" % [width, direction])
			var bodies: Array[Node] = world.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D)
			var body := bodies[0] as StaticBody2D
			var size := ((body.get_child(0) as CollisionShape2D).shape as RectangleShape2D).size
			var origin := body.global_position - size * .5
			var actual_enemy_size := ((actor.motor.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
			record("width_%s_dir_%s" % [int(width), direction], {"calibration": {"width": width, "direction": direction, "actual_support_rect_xywh": [origin.x, origin.y, size.x, size.y], "actual_enemy_center": [actor.motor.global_position.x, actor.motor.global_position.y], "actual_enemy_collision_size": [actual_enemy_size.x, actual_enemy_size.y], "actual_pulse_size": [actor.definition.pulse_size.x, actor.definition.pulse_size.y], "takeoff_x": takeoff, "finish_x": finish, "formal_width_policy_changed": false}})

func snapshot_cases() -> void:
	await fixture()
	check.call(await warning(), "snapshot warning begins with actual player")
	await advance(53)
	check.call(behavior.state == &"attack" and player_damage() == 1, "snapshot taken during actual already committed pulse")
	var stage := SaveConsumer.new()
	stage.region_state = PlainsRegionState.new()
	stage.region_state.bind_map("root-lifecycle-fixture")
	stage.generated = {"manifest": {"areas": [], "nodes": []}}
	stage.assembler = RandomStageAssembler.new()
	stage.boss = preload("res://scenes/bosses/windkeeper.tscn").instantiate()
	stage.boss.position = Vector2(-2000, -2000)
	stage.add_child(stage.boss)
	stage.enemies.assign([actor.motor])
	stage.enemy_manifest.assign([{"id": "root_fixture"}])
	stage.assembly_ok = true
	world.add_child(stage)
	await tree.process_frame
	stage.capture_state()
	var saved: Dictionary = stage.region_state.actors.root_fixture.duplicate(true)
	check.call(saved.state == "attack" and saved.serial == behavior._serial and saved.attack_goal == [behavior.attack_goal.x, behavior.attack_goal.y], "actual PlainsRegionStage.capture_state stores pulse phase/serial/mark")
	var ledger := PlainsRegionState.new()
	var serialized := JSON.parse_string(JSON.stringify(stage.region_state.snapshot())) as Dictionary
	check.call(ledger.restore(serialized, "root-lifecycle-fixture") and RandomStageGenerator.new()._same_data(ledger.actors.root_fixture, saved), "actual region ledger serializes and restores inherited root phase without schema changes")
	check.call(not PlainsRegionState.new().restore(serialized, "wrong-manifest"), "mismatched manifest snapshot is rejected")
	stage.assembler.free()
	record("actual_stage_capture_and_ledger_roundtrip")
	await fixture(false, saved)
	check.call(behavior.state == &"recovery" and behavior._serial == int(saved.serial) and behavior.cooldown > 1, "restored old pulse keeps serial and recovery debt instead of rearming")
	await advance(25)
	check.call(player_damage() == 0 and count_event("pulse") == 0, "restored old pulse cannot damage new target or duplicate old attack")
	record("restored_pending_pulse_is_cancelled")
	await fixture()
	check.call(await warning(), "duplicate-hit warning begins")
	controller.router.request_action(&"shoot_release", Vector2.RIGHT)
	await advance(30)
	var damage: Dictionary = events.filter(func(e: Dictionary) -> bool: return e.kind == "damage" and e.target == "root_fixture")[0]
	controller.router.set_move_axis(1)
	for move_tick: int in 40:
		if player.global_position.x >= 180: break
		await advance()
	controller.router.set_move_axis(0)
	check.call(await warning(), "next warning after first actual interruption")
	var before := actor.health.current
	check.call(not actor.damageable.receive_damage({"event_id": damage.id, "amount": 1, "source_faction": &"player", "source_actor_id": player.get_instance_id(), "target_actor_id": actor.damageable.actor_id, "target_epoch": actor.damageable.damage_epoch}), "duplicate actual hit id is rejected by real sink")
	await advance(1)
	check.call(actor.health.current == before and behavior.state == &"telegraph" and count_event("interrupted") == 1, "duplicate hit cannot interrupt another warning or change HP")
	record("duplicate_hit_does_not_interrupt")

func formal_manifest_candidates() -> void:
	var generator := PlainsRegionGenerator.new()
	var tuning := PlayerTuning.load_default()
	var rows: Array = []
	for i: int in 10:
		for difficulty: String in ["intro", "advanced"]:
			var generated := generator.generate("v3-root-bell-%s" % i, tuning, false, "", difficulty)
			check.call(generated.ok and generator.validate(generated.manifest, tuning), "actual formal manifest remains valid behind promotion gate")
			check.call(generated.manifest.enemies.all(func(e: Dictionary) -> bool: return e.behavior_id != "root_bell"), "unadmitted enemy never enters actual generated formal pool")
			var candidate: Dictionary = generated.manifest.duplicate(true)
			var result := PlainsRootBellPlacement.apply(candidate, true)
			check.call(candidate.enemies.size() == generated.manifest.enemies.size() and result.replaced <= 1, "explicit candidate preserves actual formal enemy budget")
			rows.append({"seed": "v3-root-bell-%s" % i, "difficulty": difficulty, "manifest_hash": generated.manifest.manifest_hash, "candidate": result})
	cases.append({"id": "actual_formal_manifest_gated_candidates", "scope": "20 actual generated manifests; candidate placement only, not formal route execution", "frames": [{"manifest_rows": rows}], "events": []})

func move_to(x: float, max_ticks := 120) -> bool:
	for unused: int in max_ticks:
		if absf(player.global_position.x - x) < 5:
			controller.router.set_move_axis(0)
			await advance(6)
			return true
		controller.router.set_move_axis(clampf((x - player.global_position.x) / 20, -1, 1))
		await advance()
	controller.router.set_move_axis(0)
	return false

func showcase(p_tree: SceneTree, p_check: Callable) -> void:
	tree = p_tree; check = p_check
	await fixture()
	var audio := GameAudio.new()
	world.add_child(audio)
	world.add_child(PlainsBackground.new())
	var ground := FixtureGround.new()
	ground.z_index = -2
	world.add_child(ground)
	var camera := Camera2D.new()
	camera.position = Vector2(280, 175)
	camera.zoom = Vector2(1.4, 1.4)
	world.add_child(camera)
	var label := Label.new()
	label.position = Vector2(24, 24)
	label.text = "ROOT BELL | G0/G1 actual-input fixture | NOT formal-route or visual admission\nOne continuous fight: bait + base jump, walk away, real shots interrupt, death clears path"
	var hud := CanvasLayer.new()
	hud.add_child(label)
	world.add_child(hud)
	check.call(await warning(), "movie first warning")
	await advance(35)
	controller.router.request_action(&"jump")
	await advance(80)
	check.call(count_event("accepted_jump") == 1 and player_damage() == 0 and actor.health.current == 3, "movie real base jump avoids first pulse")
	check.call(await warning(), "movie second warning")
	check.call(await move_to(70), "movie moves off fixed mark")
	await advance(45)
	check.call(player_damage() == 0 and actor.health.current == 3, "movie living target bypassed without shooting")
	check.call(await move_to(180), "movie returns on same actual floor")
	for shot: int in 3:
		check.call(await warning(), "movie shot warning " + str(shot))
		controller.router.request_action(&"shoot_release", Vector2.RIGHT)
		await advance(25)
		check.call(actor.health.current == 2 - shot, "movie actual projectile lowers enemy HP " + str(shot))
		if shot < 2: check.call(await move_to(180), "movie real recoil recovery walk")
	check.call(actor.health.terminal and count_event("interrupted") == 2, "movie accepted HP interrupts two warnings and lethal hit kills")
	check.call(await move_to(430, 180), "movie walks through defeated actor")
	await advance(45)
	check.call(player_damage() == 0, "movie one continuous no-damage fight")
	var file := FileAccess.open(output_dir + "/showcase.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope": "single continuous input-driven G0/G1 fixture, actual production spawn/presentation/terrain/audio consumers, not a formal route", "production_pool": false, "camera_zoom": 1.4, "frames": frames, "events": events, "audio_played": audio.played}, "\t"))
	world.free()

func placement() -> void:
	var node := {"id": "lane_join", "module_id": "region_connection", "offset": [0,0], "geometry": {"platforms": [[0,18,640,32]], "one_way": [], "ferries": []}}
	check.call(PlainsRootBellPlacement.rejection_reasons(node, true).is_empty(), "broad supported optional lane eligible")
	for mutation: String in ["narrow", "only_route", "ferry", "thorn", "low_arch", "merchant", "boss", "one_way", "low_ceiling"]:
		var bad := node.duplicate(true)
		if mutation == "narrow": bad.geometry.platforms[0][2] = 120
		elif mutation == "ferry": bad.geometry.ferries = [{"id": "boat"}]
		elif mutation == "one_way": bad.geometry.one_way = [0]
		elif mutation == "low_ceiling": bad.geometry.platforms.append([100,-50,440,30])
		elif mutation != "only_route": bad.id = mutation + "_join"
		check.call(not PlainsRootBellPlacement.rejection_reasons(bad, mutation != "only_route").is_empty(), "placement refuses " + mutation)
	var m := {"nodes": [node], "enemies": [{"id": "plains/enemy/lane/lane_join", "area": "lane_join", "behavior_id": "charger"}], "connections": [{"id": "lane", "a": "a", "b": "b", "kind": "horizontal", "condition": "open", "bidirectional": true}, {"id": "alt1", "a": "a", "b": "c", "kind": "horizontal", "condition": "open", "bidirectional": true}, {"id": "alt2", "a": "c", "b": "b", "kind": "horizontal", "condition": "open", "bidirectional": true}]}
	var before := JSON.stringify(m)
	check.call(PlainsRootBellPlacement.apply(m).status == "promotion_gated" and JSON.stringify(m) == before, "production gate cannot mutate manifest before admission")
	check.call(PlainsRootBellPlacement.apply(m, true).replaced == 1 and m.enemies.size() == 1 and m.enemies[0].behavior_id == "root_bell", "admitted candidate replaces exactly one actual lane without adding enemies")
