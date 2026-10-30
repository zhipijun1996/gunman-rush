extends SceneTree
## Fixed-map acceptance probes. Fixture placement is explicit and never reported
## as a natural route. Only the spawn suite is a continuous input-driven path.
const SCENE := "res://scenes/mapgen/seed_930001.tscn"
const FIXED_SCENE = preload("res://scenes/mapgen/seed_930001.tscn")
const DELIVERY := "res://third_party/mapgen/0.1.0/"
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var world: Node2D
var player: PlayerController
var motor: PlayerMotor
var rows: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var checks := 0
var failures := 0
var suite := "all"
var output := "user://mapgen-runtime.json"
var map_data: Dictionary
var _shots := 0
var _jumps := 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="): suite = arg.trim_prefix("--suite=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	map_data = JSON.parse_string(FileAccess.get_file_as_string(DELIVERY + "maps/seed-930001.json"))
	var packed := FIXED_SCENE as PackedScene
	if packed == null:
		_record("host/load", false, "runtime", {"reason":"fixed_scene_not_loadable"})
		await _finish(); return
	world = packed.instantiate()
	root.add_child(world)
	await process_frame
	for frame: int in 120:
		if bool(world.get("loaded")) or not str(world.get("load_error")).is_empty(): break
		await _frames(1)
	if not bool(world.get("loaded")):
		_record("host/load", false, "runtime", {"reason":str(world.get("load_error"))})
		await _finish(); return
	player = world.get("player") as PlayerController
	motor = world.get("motor") as PlayerMotor
	if player == null or motor == null:
		_record("host/player", false, "runtime", {"reason":"missing_native_player"})
		await _finish(); return
	player.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: _shots += 1)
	player.jump_ability.jumped.connect(func() -> void: _jumps += 1)
	await _frames(4)
	if suite in ["all", "inventory"]: _inventory()
	if suite in ["all", "controls"]: await _controls()
	if suite in ["all", "spawn"]: await _spawn()
	if suite in ["all", "seams"]: await _seams()
	if suite in ["all", "seals"]: _seals()
	if suite in ["all", "mechanisms"]: await _mechanisms()
	if suite in ["all", "rewards"]: await _rewards()
	if suite in ["all", "boss"]: await _boss()
	await _finish()

func _record(id: String, passed: bool, kind: String, evidence: Dictionary = {}) -> void:
	checks += 1
	if not passed: failures += 1
	var row := {"id":id,"status":"passed" if passed else "failed","kind":kind,"evidence":evidence}
	rows.append(row)
	print("MAPGEN CASE ", JSON.stringify(row))

func _unverified(id: String, kind: String, reason: String) -> void:
	rows.append({"id":id,"status":"unverified","kind":kind,"evidence":{"reason":reason}})

func _instance(id: String) -> Node2D:
	return world.registry.instances.get(id) as Node2D

func _spec(id: String) -> Dictionary:
	for value: Dictionary in map_data.instances:
		if value.id == id: return value
	return {}

func _port(instance_id: String, port_id: String) -> Dictionary:
	for value: Dictionary in _spec(instance_id).ports:
		if value.id == port_id: return value
	return {}

func _v(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _frames(count: int, capture: bool = false) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
		if capture and is_instance_valid(motor):
			trace.append({"physics_frame":Engine.get_physics_frames(),"position":[motor.global_position.x,motor.global_position.y],"velocity":[motor.velocity.x,motor.velocity.y],"grounded":motor.is_on_floor(),"hp":player.actor_resources.health.current,"shots":player.action_resources.shot_charges,"accepted_shots":_shots,"accepted_jumps":_jumps,"motion_steps":motor.motion_steps})

func _inventory() -> void:
	_record("inventory/counts", map_data.instances.size() == 46 and world.registry.instances.size() == 46 and map_data.connections.size() == 55, "static_runtime_inventory", {"instances":world.registry.instances.size(),"connections":map_data.connections.size()})
	var enemy_count := 0
	var reward_count := 0
	var seal_count := 0
	var shared := true
	var identities: Dictionary = {}
	for spec: Dictionary in map_data.instances:
		var instance := _instance(spec.id)
		var content: Dictionary = instance.get("content")
		enemy_count += content.enemies.size()
		reward_count += content.reward_sites.size()
		seal_count += spec.seals.size()
		shared = shared and instance.rewards.actor == player
		var key: String = instance.get("instance_key")
		if identities.has(key): shared = false
		identities[key] = true
		var expected := _v(spec.origin_blocks) * 128.0
		_record("inventory/origin/" + spec.id, instance.global_position.is_equal_approx(expected) and instance.scale.is_equal_approx(Vector2.ONE), "static_runtime_inventory", {"instance":spec.id,"module":spec.module_id,"expected":[expected.x,expected.y],"actual":[instance.global_position.x,instance.global_position.y],"mirror_record":spec.transform.mirror_x})
		var terrain: PlatformingModule = instance.get("module")
		var unique: bool = terrain != null and terrain.definition.platforms.size() == content.platforms.size()
		_record("inventory/unique_terrain/" + spec.id, unique, "static_runtime_inventory", {"instance":spec.id,"module":spec.module_id,"platforms":content.platforms.size()})
	_record("inventory/preserved_contents", enemy_count == 18 and reward_count == 11 and seal_count == 40, "static_runtime_inventory", {"enemy_records":enemy_count,"reward_sites":reward_count,"seals":seal_count})
	_record("inventory/shared_player_identity", shared and identities.size() == 46, "static_runtime_inventory", {"stable_instance_keys":identities.keys(),"player_id":motor.get_instance_id()})

func _spawn() -> void:
	# A prior real-input control probe may have fired. Wait out the native
	# cooldown; never reset its resources or replace its accepted shot.
	await _frames(30)
	var start := _instance("M01")
	var start_position := motor.global_position
	var shots_before := _shots
	var hp := player.actor_resources.health.current
	var player_id := motor.get_instance_id()
	var tuning := FileAccess.get_sha256("res://config/player_tuning.json")
	_record("spawn/settled", motor.is_on_floor() and start.to_local(motor.global_position).distance_to(Vector2(96, 206)) < 3.0, "continuous_native_player", {"position":[start_position.x,start_position.y],"grounded":motor.is_on_floor(),"spawn_is_entry_port":false})
	var latch: ShotLatch = start.cells.latches[0]
	# Aim through the actual muzzle used by the existing projectile system.
	var target := start.to_global(latch.bell_position)
	var direction := (target - motor.global_position).normalized()
	var visual := motor.get_node_or_null("CourierVisual") as CourierVisual
	if visual != null:
		for iteration: int in 8: direction = (target - visual.muzzle_position(direction)).normalized()
	player.router.request_action(&"shoot_release", direction)
	await _frames(45, true)
	_record("spawn/native_bell_projectile", _shots > shots_before and latch.is_open and latch.open_count == 1, "continuous_native_player", {"actual_shots":_shots-shots_before,"bell_open":latch.is_open,"open_count":latch.open_count,"gate_shape_disabled":latch.gate_shape.disabled})
	player.router.set_move_axis(1.0)
	var crossed := false
	for frame: int in 150:
		await _frames(1, true)
		if motor.global_position.x >= 540.0:
			crossed = true; break
		if player.actor_resources.health.terminal: break
	player.router.set_move_axis(0.0)
	await _frames(4, true)
	_record("spawn/M01.exit-to-M02.R", crossed and motor.get_instance_id() == player_id and player.actor_resources.health.current == hp, "continuous_native_player", {"connection":"C001","from_instance":"M01","from_module":_spec("M01").module_id,"from_port":"exit","to_instance":"M02","to_module":_spec("M02").module_id,"to_port":"R","final_position":[motor.global_position.x,motor.global_position.y],"same_player":motor.get_instance_id()==player_id,"hp_before":hp,"hp_after":player.actor_resources.health.current,"physics_unchanged":tuning==FileAccess.get_sha256("res://config/player_tuning.json"),"fixture_repositioned":false})

func _face(face: String) -> Vector2:
	match face:
		"LEFT": return Vector2.LEFT
		"RIGHT": return Vector2.RIGHT
		"TOP": return Vector2.UP
		"BOTTOM": return Vector2.DOWN
	return Vector2.ZERO

func _sweep(from: Vector2, motion: Vector2) -> Dictionary:
	var transform := motor.global_transform
	transform.origin = from
	var collision := KinematicCollision2D.new()
	var blocked := motor.test_move(transform, motion, collision, 0.001, true)
	var collider: Object = collision.get_collider() if blocked else null
	return {"blocked":blocked,"from":[from.x,from.y],"motion":[motion.x,motion.y],"travel":[collision.get_travel().x,collision.get_travel().y],"normal":[collision.get_normal().x,collision.get_normal().y],"collider":str((collider as Node).get_path()) if collider is Node else str(collider),"uses_real_player_shape":true,"body_shape":[24,36]}

func _seams() -> void:
	for connection: Dictionary in map_data.connections:
		var endpoints: Array = [connection.a, connection.b]
		var permitted := 0
		for index: int in 2:
			var source: Dictionary = endpoints[index]
			var destination: Dictionary = endpoints[1-index]
			var port := _port(source.instance_id, source.port_id)
			var receiving := _port(destination.instance_id, destination.port_id)
			if port.permission not in ["OUTPUT", "INOUT"] or receiving.permission not in ["INPUT", "INOUT"]: continue
			permitted += 1
			var seam := _v(connection.position_pixels)
			var outward := _face(port.face)
			var evidence := _sweep(seam - outward * 44.0, outward * 88.0)
			evidence.merge({"connection":connection.id,"source":source,"destination":destination,"source_module":_spec(source.instance_id).module_id,"destination_module":_spec(destination.instance_id).module_id,"surface":connection.surface,"fixture_placement":true,"continuous_route":false,"probe":"full-body corridor sweep at the exact Port center; jump/landing/resource continuation is separate"})
			var seam_passed: bool = not evidence.blocked
			if evidence.blocked and outward==Vector2.DOWN and connection.surface=="ONE_WAY_PLATFORM":
				var collided := root.get_node_or_null(NodePath(str(evidence.collider)))
				var end_center := _v(evidence.from)+_v(evidence.travel)
				var receiving_platform: bool = collided != null and collided.is_in_group(&"one_way_platform") and _instance(destination.instance_id).is_ancestor_of(collided) and _v(evidence.normal).dot(Vector2.UP)>.99 and end_center.y>seam.y+.1
				evidence["destination_one_way_landing"] = receiving_platform
				evidence["body_center_after_seam_pixels"] = end_center.y-seam.y
				evidence["empty_corridor"] = false
				if receiving_platform:
					# The original empty-corridor failure is retained in all-dev01.
					# A real descent must land on that exact receiver, then the native
					# drop action must carry the body farther through the interface.
					_fixture_place(_v(evidence.from))
					await _frames(16)
					var landed_position := motor.global_position
					var landed: bool = motor.is_on_floor() and motor.global_position.y>seam.y and absf(motor.global_position.y-end_center.y)<2
					_record("seam/landing/"+connection.id+"/"+str(index),landed,"scoped_native_player",{"connection":connection.id,"destination":destination,"expected_receiver":evidence.collider,"position":[landed_position.x,landed_position.y],"seam_y":seam.y,"grounded":motor.is_on_floor(),"fixture_placement":true,"continuous_route":false})
					player.router.request_action(&"drop_through")
					await _frames(16)
					var dropped: bool = motor.global_position.y>landed_position.y+40 and player.active and not player.actor_resources.health.terminal
					_record("seam/dropthrough/"+connection.id+"/"+str(index),dropped,"scoped_native_player",{"connection":connection.id,"destination":destination,"before":[landed_position.x,landed_position.y],"after":[motor.global_position.x,motor.global_position.y],"native_action":"drop_through","fixture_placement":"before descent only; no reposition between landing and drop","continuous_route":false})
					seam_passed = landed and dropped
					evidence["probe"] = "Original sweep meets a receiver one-way after its center crosses the seam; actual native descent/landing/drop was required separately. Not an empty corridor or whole route certificate."
			_record("seam/" + connection.id + "/" + str(index), seam_passed, "native_player_collision_sweep", evidence)
		_record("seam/direction/" + connection.id, permitted > 0, "static_contract", {"connection":connection.id,"permitted_directions":permitted})
	_unverified("seams/continuous_all_paths", "continuous_native_player", "Port-center body sweeps do not prove jump, motion phase, resource continuation or whole-map traversal.")

func _seals() -> void:
	for spec: Dictionary in map_data.instances:
		var instance := _instance(spec.id)
		for seal: Dictionary in spec.seals:
			var rect := _rect(seal.rect_pixels)
			var outward := _face(seal.face)
			var center := instance.to_global(rect.get_center())
			# Starting from inside the room, sweep toward the sealed opening.
			var inside := _sweep(center - outward * 60.0, outward * 120.0)
			var exterior := _sweep(center + outward * 60.0, -outward * 120.0)
			var exact_seal := str(instance.get_path())+"/Seal_"+str(seal.port_id)
			var seal_hit: bool = (inside.blocked and str(inside.collider)==exact_seal) or (exterior.blocked and str(exterior.collider)==exact_seal)
			var evidence := {"inside_to_exterior":inside,"exterior_to_inside":exterior,"required_exact_seal":exact_seal,"instance":spec.id,"module":spec.module_id,"port":seal.port_id,"face":seal.face,"seal_rect":seal.rect_pixels,"fixture_placement":true,"continuous_route":false,"scope":"Exact native seal collision from at least one side; authored receiving one-way may intercept the interior probe first."}
			_record("seal/" + spec.id + "/" + seal.port_id, seal_hit, "native_player_collision_sweep", evidence)

func _fixture_place(at: Vector2) -> void:
	# Initial condition for a clearly labelled scoped diagnostic. No abilities,
	# health, currency or action resources are granted/reset by this helper.
	player.router.clear("mapgen_diagnostic_fixture")
	# This explicit diagnostic teleport starts a new actor epoch so authored
	# hazards discard their previous-frame sweep across distant modules. It
	# grants no health, ammo, currency or abilities.
	world.lifetime.invalidate_actor()
	motor.global_position = at
	motor.normal_velocity = Vector2.ZERO
	motor.recoil_velocity = Vector2.ZERO
	motor.velocity = Vector2.ZERO
	motor.recoil_burst_remaining = 0.0

func _mechanisms() -> void:
	for spec: Dictionary in map_data.instances:
		var instance := _instance(spec.id)
		var content: Dictionary = instance.get("content")
		var terrain: PlatformingModule = instance.get("module")
		var expected_one_way: Array[int] = []
		for value: Variant in content.one_way_platform_indices: expected_one_way.append(int(value))
		for index: int in content.platforms.size():
			var shape := terrain.get_node("Platform%d/CollisionShape2D" % index) as CollisionShape2D
			var body := shape.get_parent() as StaticBody2D
			var expected := _rect(content.platforms[index])
			_record("mechanism/terrain/" + spec.id + "/" + str(index), body.position.is_equal_approx(expected.get_center()) and (shape.shape as RectangleShape2D).size.is_equal_approx(expected.size) and shape.one_way_collision == (index in expected_one_way), "static_runtime_inventory", {"instance":spec.id,"module":spec.module_id,"platform":index,"mirror_record":spec.transform.mirror_x,"one_way":shape.one_way_collision})
		for raw: Dictionary in content.latches:
			var found := false
			for latch: ShotLatch in instance.cells.latches:
				if str(latch.link_id) != str(raw.id): continue
				found = latch.bell_position.is_equal_approx(_v(raw.bell)) and latch.gate_rect == _rect(raw.gate)
			_record("mechanism/latch/" + spec.id + "/" + str(raw.id), found, "static_runtime_inventory", {"instance":spec.id,"module":spec.module_id,"mirror_record":spec.transform.mirror_x,"bell":raw.bell,"gate":raw.gate,"note":"Coordinates only; native projectile actuation is tested in spawn and selected mirrored fixture."})
	# An actual one-way landing and upward clearance probe, chosen from the data.
	var one_way_done := false
	for spec: Dictionary in map_data.instances:
		if one_way_done: break
		var instance := _instance(spec.id)
		var content: Dictionary = instance.get("content")
		for index: Variant in content.one_way_platform_indices:
			var rect := _rect(content.platforms[int(index)])
			var top := instance.to_global(Vector2(rect.get_center().x, rect.position.y))
			var descending := _sweep(top - Vector2(0,48), Vector2(0,60))
			var ascending := _sweep(top + Vector2(0,rect.size.y+30), Vector2(0,-70))
			_record("mechanism/oneway_body/"+spec.id+"/"+str(index), descending.blocked and not ascending.blocked, "native_player_collision_sweep", {"instance":spec.id,"module":spec.module_id,"platform":index,"descending":descending,"ascending":ascending,"fixture_placement":true})
			one_way_done = true; break
	# Independent raw-data trajectory checks and live physics-body phase samples.
	for sample: int in 3:
		var phase_before: Dictionary = {}
		for spec: Dictionary in map_data.instances:
			var instance := _instance(spec.id)
			var terrain: PlatformingModule = instance.get("module")
			for moving: ModuleMovingPlatform in terrain.moving_platforms:
				phase_before[str(spec.id)+"/"+str(moving.definition.platform_id)] = moving.motion_clock if moving.bell_controlled else terrain.clock
		await _frames(1)
		for spec: Dictionary in map_data.instances:
			var instance := _instance(spec.id)
			var content: Dictionary = instance.get("content")
			var terrain: PlatformingModule = instance.get("module")
			for index: int in content.moving_platforms.size():
				var raw: Dictionary = content.moving_platforms[index]
				var moving: ModuleMovingPlatform = terrain.moving_platforms[index]
				# AnimatableBody sync_to_physics publishes the requested transform
				# on the next native step. Compare its actual position with the
				# independently captured prior phase, not the advanced module clock.
				var clock: float = phase_before[str(spec.id)+"/"+str(raw.platform_id)]
				var expected := _raw_trajectory(raw, clock)
				_record("mechanism/motion/"+spec.id+"/"+str(raw.platform_id)+"/"+str(sample), moving.position.distance_to(expected)<0.05, "live_native_physics_body", {"instance":spec.id,"module":spec.module_id,"mirror_record":spec.transform.mirror_x,"kind":raw.get("trajectory_kind","linear_ping_pong"),"ellipse_x_sign":raw.get("ellipse_x_sign",1),"clock":clock,"module_clock_after_step":terrain.clock,"phase_sampling":"before native tick; synced physical transform observed after that tick","actual":[moving.position.x,moving.position.y],"expected":[expected.x,expected.y],"bell_controlled":moving.bell_controlled,"moving":moving.motion_running})
	# A native projectile must actuate an actually mirrored mechanism. M20 has
	# safe authored floor at y608; this is a scoped initial placement, not a route.
	if player.active and not player.actor_resources.health.terminal:
		var mirror := _instance("M20")
		var latch: ShotLatch = mirror.cells.latches[0]
		_fixture_place(mirror.to_global(Vector2(760,590)))
		await _frames(5)
		var opened_before := latch.open_count
		var target := mirror.to_global(latch.bell_position)
		var direction := (target-motor.global_position).normalized()
		var visual := motor.get_node_or_null("CourierVisual") as CourierVisual
		if visual != null:
			for iteration: int in 8: direction = (target-visual.muzzle_position(direction)).normalized()
		player.router.request_action(&"shoot_release",direction)
		await _frames(36)
		_record("mechanism/mirrored_projectile/M20/return-catch", latch.open_count>opened_before, "scoped_native_player", {"instance":"M20","module":_spec("M20").module_id,"mirror_record":true,"open_count_before":opened_before,"open_count_after":latch.open_count,"fixture_placement":true,"projectile_delivery":true})
	else:
		_unverified("mechanism/mirrored_projectile/M20/return-catch", "scoped_native_player", "Player became terminal in an earlier suite.")
	_unverified("mechanisms/all_dynamic_phases", "continuous_native_player", "Inventory and selected body/projectile probes do not certify all paired gates, directional enemies, elliptical motion phases or dynamic resource continuations.")


func _raw_trajectory(raw: Dictionary, clock: float) -> Vector2:
	if raw.get("trajectory_kind", "") == "clockwise_ellipse/v1":
		var angle := PI + TAU * fposmod(clock/float(raw.ellipse_period)+float(raw.initial_phase),1.0)
		var radii := _v(raw.ellipse_radii)
		return _v(raw.ellipse_center) + Vector2(cos(angle)*radii.x*float(raw.get("ellipse_x_sign",1)),sin(angle)*radii.y)
	if raw.get("trajectory_kind", "") == "closed_polyline_loop/v1":
		var points: Array = raw.loop_points
		var total := 0.0
		for index: int in points.size()-1: total += _v(points[index]).distance_to(_v(points[index+1]))
		var remaining := fposmod(clock/float(raw.loop_period)+float(raw.initial_phase),1.0)*total
		for index: int in points.size()-1:
			var a := _v(points[index])
			var b := _v(points[index+1])
			var length := a.distance_to(b)
			if remaining<=length or index==points.size()-2: return a.lerp(b,remaining/length)
			remaining -= length
		return _v(points[0])
	var travel := float(raw.travel_duration)
	var dwell := float(raw.dwell_duration)
	var period := (travel+dwell)*2.0
	var elapsed := fposmod(clock+float(raw.initial_phase)*period,period)
	var start := _v(raw.start)
	var finish := _v(raw.finish)
	if elapsed<dwell: return start
	elapsed -= dwell
	if elapsed<travel: return start.lerp(finish,elapsed/travel)
	elapsed -= travel
	if elapsed<dwell: return finish
	return finish.lerp(start,(elapsed-dwell)/travel)

func _rewards() -> void:
	if player.actor_resources.health.terminal or not player.active:
		_record("reward/player_alive", false, "scoped_native_player", {"reason":"previous_suite_player_terminal"}); return
	var player_id := motor.get_instance_id()
	var expected_added := 0
	var before := int(world.wallet.balance)
	var claimed_keys: Array[String] = []
	for spec: Dictionary in map_data.instances:
		var instance := _instance(spec.id)
		var content: Dictionary = instance.get("content")
		for reward: Dictionary in content.reward_sites:
			var service: SimpleRoomReward = instance.rewards.services[str(reward.id)]
			var region := _rect(reward.region)
			var stance := _reward_stance(instance,reward)
			var target := _v(stance.get("world",[0,0]))
			_record("reward/supported_fixture/"+spec.id+"/"+str(reward.id),bool(stance.get("ok",false)),"native_collision_fixture_validation",stance)
			if not bool(stance.get("ok",false)):
				_record("reward/physical_claim/"+spec.id+"/"+str(reward.id),false,"native_collision_fixture_validation",{"instance":spec.id,"module":spec.module_id,"reward":reward.id,"reason":stance.get("reason"),"fixture":stance,"claimed":service.claimed,"coins_added":0,"expected_amount":reward.amount,"fixture_placement":false,"natural_reachability":false})
				_record("reward/no_duplicate/"+spec.id+"/"+str(reward.id),not service.claimed,"runtime_transaction",{"instance":spec.id,"reward":reward.id,"blocked_without_grant":true,"wallet":world.wallet.balance})
				continue
			# reward.position anchors chest artwork. The native player's center
			# is derived from the real support and its unchanged full body shape.
			_fixture_place(target)
			var balance_before := int(world.wallet.balance)
			await _frames(24)
			var local := instance.to_local(motor.global_position)
			var added := int(world.wallet.balance) - balance_before
			var claimed := service.claimed
			_record("reward/physical_claim/" + spec.id + "/" + str(reward.id), claimed and added == int(reward.amount), "scoped_native_player", {"instance":spec.id,"module":spec.module_id,"reward":reward.id,"region":reward.region,"initial_position":[target.x,target.y],"final_local_position":[local.x,local.y],"grounded":motor.is_on_floor(),"in_claim_region":region.has_point(local),"claimed":claimed,"coins_added":added,"expected_amount":reward.amount,"fixture_placement":true,"natural_reachability":false})
			var after_claim := int(world.wallet.balance)
			instance.capture()
			instance.capture()
			_record("reward/no_duplicate/" + spec.id + "/" + str(reward.id), int(world.wallet.balance) == after_claim, "runtime_transaction", {"instance":spec.id,"reward":reward.id,"wallet_after":world.wallet.balance})
			if claimed:
				expected_added += int(reward.amount)
				claimed_keys.append(str(service._definition.stable_id))
	_record("reward/instance_isolation", claimed_keys.size() == 11 and _unique(claimed_keys).size() == 11 and int(world.wallet.balance) == before + expected_added and motor.get_instance_id() == player_id, "runtime_transaction", {"keys":claimed_keys,"wallet_before":before,"wallet_after":world.wallet.balance,"expected_added":expected_added,"same_player":motor.get_instance_id()==player_id})
	await _reward_reload("M41",false)
	await _reward_reload("M43",true)
	await _native_region_chest("coin")
	# A separate fresh run exercises the other native OR alternative; claiming
	# both options in one run would violate the original consumer contract.
	if await _fresh_host("native_chest_note"):
		await _native_region_chest("note")


func _reward_stance(instance: Node2D, reward: Dictionary) -> Dictionary:
	var shape := motor.get_node("CollisionShape2D") as CollisionShape2D
	var half := (shape.shape as RectangleShape2D).size*.5
	var region := _rect(reward.region)
	var anchor := _v(reward.position)
	var terrain: PlatformingModule = instance.get("module")
	var candidates: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for index: int in terrain.definition.platforms.size():
		var rect: Rect2 = terrain.definition.platforms[index]
		var left := maxf(rect.position.x+half.x+.1,region.position.x+.1)
		var right := minf(rect.end.x-half.x-.1,region.end.x-.1)
		if left>right: continue
		var xs: Array[float] = [clampf(anchor.x,left,right),left,right,(left+right)*.5]
		# Include both safe region edges and an 8px grid. Chest anchors may be
		# inside an unused-Port seal although the original claim region extends
		# onto a valid supported stance beside that seal.
		var scan := left
		while scan<=right:
			xs.append(scan)
			scan += 8.0
		for x: float in xs:
			var local := Vector2(x,rect.position.y-half.y-.25)
			if not region.has_point(local): continue
			var position := instance.to_global(local)
			if not world.segment.is_safe(position):
				rejected.append({"support_platform":index,"local":[local.x,local.y],"native_collision_shapes":_body_overlaps(position)})
				continue
			candidates.append({"ok":true,"instance":instance.name,"reward":reward.id,"support_platform":index,"support_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"art_anchor":reward.position,"player_half_size":[half.x,half.y],"local":[local.x,local.y],"world":[position.x,position.y],"safe_native_full_body":true,"distance":local.distance_to(anchor)})
	if candidates.is_empty(): return {"ok":false,"instance":instance.name,"reward":reward.id,"claim_region":reward.region,"reason":"no unchanged full-body supported stance inside original claim region","rejected_native_body_probes":rejected,"seals":_spec(str(instance.name)).seals}
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.distance)<float(b.distance))
	return candidates[0]

func _body_overlaps(at: Vector2) -> Array[String]:
	var collision := motor.get_node("CollisionShape2D") as CollisionShape2D
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = Transform2D(0.0,at+collision.position+Vector2(0,-.05))
	query.collision_mask = motor.collision_mask
	query.exclude = [motor.get_rid()]
	query.margin = 0.0
	var result: Array[String] = []
	for hit: Dictionary in motor.get_world_2d().direct_space_state.intersect_shape(query):
		var collider := hit.collider as Node
		result.append(str(collider.get_path()) if collider != null else str(hit.collider))
	return result

func _shared_services() -> Dictionary:
	return {"policy":world.policy,"lifetime":world.lifetime,"wallet":world.wallet,"meta":world.meta,"region_state":world.region_state,"segment":world.segment}

func _reward_reload(instance_id: String, native_hq: bool) -> void:
	var instance := _instance(instance_id)
	var claimed_before := false
	var state_before: Dictionary = instance.call("export_saved_state") if native_hq else {}
	if native_hq: claimed_before = bool(state_before.get("claimed",false)) and bool(state_before.get("swapped",false))
	else: claimed_before = instance.rewards.services["reward"].claimed
	var coins_before := int(world.wallet.balance)
	var actor_before := motor.get_instance_id()
	var clock_before: float = instance.module.clock
	_fixture_place(_instance("M01").to_global(Vector2(96,206)))
	await _frames(1)
	var unload: Dictionary = world.registry.unload(instance_id)
	await process_frame
	await process_frame
	var removed: bool = not world.registry.instances.has(instance_id)
	_record("reward/reload_saved/"+instance_id,claimed_before and unload.get("ok",false) and unload.get("same_run_state_saved",false) and removed,"same_run_restore_fixture",{"instance":instance_id,"native_hq":native_hq,"claimed_before":claimed_before,"state_before":state_before,"unload":unload,"removed":removed})
	if not removed: return
	var wrong_services := _shared_services()
	wrong_services.wallet = RunWallet.new()
	var refused: Dictionary = world.registry.instantiate_materialized(_spec(instance_id),world,player,wrong_services,str(world.run_id))
	_record("reward/reload_scope_refusal/"+instance_id,not refused.get("ok",false) and str(refused.get("reason","")).begins_with("saved_instance_scope_mismatch") and not world.registry.instances.has(instance_id),"same_run_restore_fixture",{"instance":instance_id,"wrong_wallet":true,"receipt":refused})
	var restored: Dictionary = world.registry.instantiate_materialized(_spec(instance_id),world,player,_shared_services(),str(world.run_id))
	_record("reward/reload_bound/"+instance_id,restored.get("ok",false) and restored.get("same_run_state_restored",false),"same_run_restore_fixture",{"instance":instance_id,"receipt":restored})
	if not restored.get("ok",false): return
	instance = _instance(instance_id)
	instance.process_mode = Node.PROCESS_MODE_PAUSABLE
	var restored_clock: float = instance.module.clock
	var restored_claimed: bool = false
	var state_after: Dictionary = {}
	if native_hq:
		state_after = instance.call("export_saved_state")
		restored_claimed = bool(state_after.get("claimed",false)) and bool(state_after.get("swapped",false)) and instance.rewards.services.is_empty()
	else: restored_claimed = instance.rewards.services["reward"].claimed
	var raw: Dictionary = instance.content.reward_sites[0]
	var stance := _reward_stance(instance,raw)
	_fixture_place(_v(stance.get("world",[0,0])))
	await _frames(8)
	instance.capture()
	instance.capture()
	_record("reward/reload_no_regrant/"+instance_id,restored_claimed and restored_clock>=clock_before and int(world.wallet.balance)==coins_before and motor.get_instance_id()==actor_before,"same_run_restore_fixture",{"instance":instance_id,"native_hq":native_hq,"claimed_restored":restored_claimed,"state_before":state_before,"state_after":state_after,"services_after_restore":instance.rewards.services.size(),"clock_before":clock_before,"clock_restored":restored_clock,"coins_before":coins_before,"coins_after":world.wallet.balance,"same_player":motor.get_instance_id()==actor_before,"fixture_placement":true})
	if instance_id=="M43":
		var dynamic := _instance("M02")
		var retained_id := dynamic.get_instance_id()
		var rejection: Dictionary = world.registry.unload("M02")
		_record("reward/reload_dynamic_rejected",not rejection.get("ok",false) and is_instance_valid(_instance("M02")) and _instance("M02").get_instance_id()==retained_id and not _instance("M02").is_queued_for_deletion(),"same_run_restore_fixture",{"instance":"M02","receipt":rejection,"same_live_instance":_instance("M02").get_instance_id()==retained_id})

func _native_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _native_mouse(pressed: bool, position: Vector2 = Vector2(900,260)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = event.position
	Input.parse_input_event(event)

func _process_frames(count: int) -> void:
	for frame: int in count: await process_frame

func _controls() -> void:
	var shots_before := _shots
	var steps_before := motor.motion_steps
	var epoch_before := player.router.epoch
	var originals: Node = _instance("M29").get("original_region_chests")
	var pickups: Node = _instance("M29").get("original_pickups")
	_record("controls/helper_input_isolation", originals != null and pickups != null and not originals.app.is_processing_input() and not pickups.app.is_processing_input(), "runtime_binding", {"instance":"M29","region_helper_input":originals.app.is_processing_input() if originals != null else null,"pickup_helper_input":pickups.app.is_processing_input() if pickups != null else null,"reason":"embedded native DemoApp helpers have no outer menu; global input belongs to the fixed-map host"})
	# Real native dispatch arms the existing mouse adapter. Opening the map must
	# cancel it, and the subsequent native release must not fire a stale shot.
	_native_mouse(true)
	_native_key(KEY_D,true)
	_native_key(KEY_M,true)
	_native_key(KEY_M,false)
	await _process_frames(4)
	_record("controls/map_native_open", paused and bool(world.get("_map_view")) and player.router.epoch>epoch_before and is_zero_approx(player.router.axis) and not player.router.aim_engaged and _shots==shots_before and motor.motion_steps==steps_before, "native_input_dispatch", {"key":"M","paused":paused,"map_view":world.get("_map_view"),"epoch_before":epoch_before,"epoch_after":player.router.epoch,"axis":player.router.axis,"aim_engaged":player.router.aim_engaged,"accepted_shots":_shots-shots_before,"motion_steps_before":steps_before,"motion_steps_after":motor.motion_steps})
	_native_mouse(false)
	_native_key(KEY_D,false)
	_native_key(KEY_M,true)
	_native_key(KEY_M,false)
	await _process_frames(3)
	_record("controls/map_native_close", not paused and not bool(world.get("_map_view")) and _shots==shots_before, "native_input_dispatch", {"key":"M","paused":paused,"map_view":world.get("_map_view"),"stale_release_shots":_shots-shots_before})
	_native_mouse(true)
	_native_key(KEY_ESCAPE,true)
	_native_key(KEY_ESCAPE,false)
	await _process_frames(3)
	var paused_steps := motor.motion_steps
	await _process_frames(3)
	_record("controls/pause_native_open", paused and bool(world.get("_paused")) and not player.router.aim_engaged and motor.motion_steps==paused_steps, "native_input_dispatch", {"key":"Escape","paused":paused,"host_pause":world.get("_paused"),"aim_engaged":player.router.aim_engaged,"motion_steps_stable":motor.motion_steps==paused_steps})
	_native_mouse(false)
	_native_key(KEY_ESCAPE,true)
	_native_key(KEY_ESCAPE,false)
	await _process_frames(3)
	_record("controls/pause_native_close", not paused and not bool(world.get("_paused")) and _shots==shots_before, "native_input_dispatch", {"key":"Escape","paused":paused,"host_pause":world.get("_paused"),"stale_release_shots":_shots-shots_before})
	# Keep failed cancellation evidence, but do not deadlock subsequent tests.
	paused = false
	await _frames(3)
	_record("controls/native_motor_resumes", motor.motion_steps>paused_steps and _shots==shots_before and not player.router.aim_engaged, "native_input_dispatch", {"motion_steps_after":motor.motion_steps,"motion_steps_paused":paused_steps,"stale_shots":_shots-shots_before})
	_native_key(KEY_D,true)
	var fresh_axis := player.router.axis
	_native_key(KEY_D,false)
	_record("controls/fresh_key_after_resume",fresh_axis>0.99 and is_zero_approx(player.router.axis),"native_input_dispatch",{"key":"D","pressed_axis":fresh_axis,"released_axis":player.router.axis,"no_physics_step_between_edges":true})
	# Vertically upward aim keeps the grounded body's downward recoil against
	# its existing floor and avoids pre-opening the nearby M01 bell.
	_native_mouse(true,Vector2(640,100))
	_native_mouse(false,Vector2(640,100))
	await _frames(12)
	_record("controls/fresh_mouse_after_resume",_shots==shots_before+1,"native_input_dispatch",{"accepted_new_shots":_shots-shots_before,"expected":1,"aim_viewport":[640,100],"native_keyboard_neutral_recovery":true})

func _fresh_host(label: String) -> bool:
	paused = false
	if is_instance_valid(world):
		await TEARDOWN.drain_world(world)
		world.queue_free()
		await process_frame
		await process_frame
	world = (load(SCENE) as PackedScene).instantiate()
	world.set("run_id", "mapgen-test/"+label+"/"+str(Time.get_ticks_usec()))
	root.add_child(world)
	await process_frame
	for frame: int in 120:
		if bool(world.get("loaded")) or not str(world.get("load_error")).is_empty(): break
		await _frames(1)
	if not bool(world.get("loaded")):
		_record("host/fresh/"+label,false,"runtime",{"reason":str(world.get("load_error"))})
		return false
	player = world.get("player") as PlayerController
	motor = world.get("motor") as PlayerMotor
	player.shoot_ability.shot_fired.connect(func(_direction: Vector2, _id: int) -> void: _shots += 1)
	player.jump_ability.jumped.connect(func() -> void: _jumps += 1)
	await _frames(4)
	return true

func _native_region_chest(kind: String) -> void:
	var instance := _instance("M29")
	var consumer: Node = instance.get("original_region_chests")
	var before_coins := int(world.wallet.balance)
	var before_notes := int(world.meta.snapshot().notes)
	var chest_position: Vector2 = instance.to_global(Vector2(208,45.75))
	_fixture_place(chest_position)
	await _frames(8)
	var standing := motor.is_on_floor()
	_native_key(KEY_W,true)
	_native_key(KEY_W,false)
	# The original modal pauses the tree; observe it with process frames.
	for frame: int in 12:
		await process_frame
		if consumer.app.reward_modal.opened: break
	var modal_open: bool = consumer.app.reward_modal.opened
	var choices: Dictionary = {}
	if modal_open:
		for item: ItemDefinition in consumer.app._region_offer.candidates:
			var resource := item as ResourceRewardChoice
			if resource != null: choices[resource.resource_kind] = resource.amount
	_record("reward/M29/native_W_offer/"+kind, modal_open and paused and choices=={"coin":4,"note":1}, "scoped_native_player_interaction", {"instance":"M29","module":_spec("M29").module_id,"local_chest":"source_cache","grounded":standing,"grounding_required_by_native_consumer":false,"actual_key":"W","modal_open":modal_open,"paused":paused,"choices":choices,"fixture_placement":true,"natural_reachability":false})
	var before_map: bool = world.get("_map_view")
	var before_pause: bool = world.get("_paused")
	for attempt: int in 2:
		_native_key(KEY_M,true)
		_native_key(KEY_M,false)
		_native_key(KEY_ESCAPE,true)
		_native_key(KEY_ESCAPE,false)
		await _process_frames(2)
	_record("reward/M29/modal_input_ownership/"+kind, modal_open and paused and consumer.app.reward_modal.opened and bool(world.get("_map_view"))==before_map and bool(world.get("_paused"))==before_pause, "native_input_dispatch", {"instance":"M29","keys":["M","Escape","M","Escape"],"modal_open":consumer.app.reward_modal.opened,"paused":paused,"map_before":before_map,"map_after":world.get("_map_view"),"pause_before":before_pause,"pause_after":world.get("_paused"),"owner":"native region choice modal"})
	if modal_open:
		# This is the package's declared native choice API, consumed by its
		# original DemoApp transaction. It is not a mouse/GUI-choice certificate.
		instance.call("request_native_region_choice",kind)
		consumer.call("capture")
	await _process_frames(3)
	var expected_coin := 4 if kind=="coin" else 0
	var expected_note := 1 if kind=="note" else 0
	var state: Dictionary = consumer.call("snapshot")
	var claimed: bool = state.chests[0].claimed
	_record("reward/M29/native_OR_claim/"+kind, modal_open and claimed and int(world.wallet.balance)==before_coins+expected_coin and int(world.meta.snapshot().notes)==before_notes+expected_note and not consumer.app.reward_modal.opened and not paused, "native_region_transaction", {"instance":"M29","module":_spec("M29").module_id,"selected":kind,"coin_delta":int(world.wallet.balance)-before_coins,"note_delta":int(world.meta.snapshot().notes)-before_notes,"claimed":claimed,"modal_open":consumer.app.reward_modal.opened,"tree_paused":paused,"consumer":"DemoApp._claim_region_chest","choice_api":"request_native_region_choice; capture","mouse_choice_test":false,"snapshot":state})
	var after_coins := int(world.wallet.balance)
	var after_notes := int(world.meta.snapshot().notes)
	instance.call("request_native_region_choice",kind)
	consumer.call("capture")
	instance.call("request_native_region_choice","note" if kind=="coin" else "coin")
	consumer.call("capture")
	_native_key(KEY_W,true)
	_native_key(KEY_W,false)
	await _frames(3)
	_record("reward/M29/native_OR_idempotence/"+kind, claimed and int(world.wallet.balance)==after_coins and int(world.meta.snapshot().notes)==after_notes and not consumer.app.reward_modal.opened, "native_region_transaction", {"instance":"M29","selected":kind,"same_choice_replayed":true,"other_choice_requested":true,"coin_delta":int(world.wallet.balance)-after_coins,"note_delta":int(world.meta.snapshot().notes)-after_notes,"modal_open":consumer.app.reward_modal.opened,"snapshot":consumer.call("snapshot")})
	paused = false

func _unique(values: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values: result[value] = true
	return result

func _boss() -> void:
	var arena := _instance("M40")
	var binding: Node = world.get("boss_binding")
	_record("boss/bound_native_system", is_instance_valid(binding), "runtime_binding", {"instance":"M40","module":_spec("M40").module_id,"native_binding":str(binding.get_script().resource_path) if is_instance_valid(binding) else ""})
	if not is_instance_valid(binding): return
	var entry := _port("M40", "entry")
	var departure := arena.to_global(_v(entry.local_position_pixels))
	_fixture_place(departure + Vector2(-56, 14))
	await _frames(8)
	var active: Variant = binding.get("started")
	_record("boss/arrival_trigger", active == true, "scoped_native_player", {"instance":"M40","port":"entry","face":entry.face,"position":[motor.global_position.x,motor.global_position.y],"active":active,"fixture_placement":true,"continuous_route":false})
	var encounter := binding.get("encounter") as WindkeeperEncounter
	if encounter == null: return
	var health_before := encounter.health.current
	var player_health_before := player.actor_resources.health.current
	var shots_before := _shots
	var observed_phases: Dictionary = {encounter.stage_phase:true}
	# A bounded real-input pilot. It receives no health/ammo grants, modifies no
	# Definitions and never assigns body positions after the arrival fixture.
	for frame: int in 3000:
		if player.actor_resources.health.terminal or not player.active or bool(binding.get("completed")): break
		observed_phases[encounter.stage_phase] = true
		var local := arena.to_local(motor.global_position)
		var desired_x := 1000.0
		player.router.set_move_axis(clampf((desired_x-local.x)/45.0,-1.0,1.0))
		if frame>=240 and frame%60==0:
			var target := (binding.get("boss") as BossMotor).global_position + encounter.definition.collision_offset
			var direction := (target-motor.global_position).normalized()
			var visual := motor.get_node_or_null("CourierVisual") as CourierVisual
			if visual != null:
				for iteration: int in 8: direction = (target-visual.muzzle_position(direction)).normalized()
			player.router.request_action(&"shoot_release",direction)
		await _frames(1, frame%6==0)
	player.router.clear("mapgen_boss_pilot_end")
	_record("boss/native_projectile_damage", encounter.health.current<health_before and _shots>shots_before, "scoped_native_player_combat", {"boss_health_before":health_before,"boss_health_after":encounter.health.current,"accepted_shots":_shots-shots_before,"player_health_before":player_health_before,"player_health_after":player.actor_resources.health.current,"phases_observed":observed_phases.keys(),"fixture_placement":"arrival only; no position assignments or grants during combat"})
	_record("boss/native_battle_victory", bool(binding.get("completed")) and encounter.health.terminal and not player.actor_resources.health.terminal and world.outcome=="victory" and not world.lifetime.active, "scoped_native_player_combat", {"completed":binding.get("completed"),"boss_terminal":encounter.health.terminal,"player_terminal":player.actor_resources.health.terminal,"phases_observed":observed_phases.keys(),"snapshot":binding.call("snapshot"),"outcome":world.outcome,"lifetime_active":world.lifetime.active,"natural_whole_map_arrival":false,"pilot":"hold floor x1000 with Router; after frame240 fire once per60 ticks; zero grants, no reposition during battle"})
	var exit_seal := _spec("M40").seals[0] as Dictionary
	var exit_rect := _rect(exit_seal.rect_pixels)
	var exit_center := arena.to_global(exit_rect.get_center())
	var victory_seal_probe := _sweep(exit_center+Vector2(60,0),Vector2(-120,0))
	_record("boss/exit_stays_sealed_after_victory",bool(binding.get("completed")) and victory_seal_probe.blocked and str(victory_seal_probe.collider)==str(arena.get_path())+"/Seal_exit","native_player_collision_sweep",victory_seal_probe)
	await _same_frame_death_fixture()

func _same_frame_death_fixture() -> void:
	# Independent transactional negative fixture on a fresh host. Direct policy
	# requests prove ordering/cancellation only, never natural Boss combat.
	await TEARDOWN.drain_world(world)
	world.queue_free()
	await process_frame
	await process_frame
	world = (load(SCENE) as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	for frame: int in 120:
		if bool(world.get("loaded")) or not str(world.get("load_error")).is_empty(): break
		await _frames(1)
	if not bool(world.get("loaded")):
		_record("boss/same_frame_fixture_loaded",false,"transaction_fixture",{"reason":str(world.get("load_error"))}); return
	player = world.get("player") as PlayerController
	motor = world.get("motor") as PlayerMotor
	var binding: Node = world.get("boss_binding")
	var arena := _instance("M40")
	_fixture_place(arena.to_global(Vector2(1096,462)))
	await _frames(8)
	if not bool(binding.get("started")):
		_record("boss/same_frame_fixture_started",false,"transaction_fixture",{}); return
	var encounter := binding.get("encounter") as WindkeeperEncounter
	var policy := world.get("policy") as FrameDamagePolicy
	var lifetime := world.get("lifetime") as DemoLifetime
	# Wait for the native host's initial protection window to expire; never
	# mutate its timers merely to force this negative fixture to be admitted.
	for frame: int in 60:
		if policy.player_clock()>=policy._protected_until: break
		await _frames(1)
	var coins_before := int(world.wallet.balance)
	var token := lifetime.token()
	var boss_hit := DamageRequest.new()
	boss_hit.token = token
	boss_hit.actor_epoch = lifetime.actor_epoch
	boss_hit.health_epoch = encounter.health.epoch
	boss_hit.target_id = StringName(binding.get("target_id"))
	boss_hit.source_id = &"mapgen_fixture_player"
	boss_hit.event_id = &"mapgen_same_frame_boss"
	boss_hit.amount = encounter.health.current
	var player_hit := DamageRequest.new()
	player_hit.token = token
	player_hit.actor_epoch = lifetime.actor_epoch
	player_hit.health_epoch = player.actor_resources.health.epoch
	player_hit.target_id = &"player"
	player_hit.source_id = &"mapgen_fixture_boss"
	player_hit.event_id = &"mapgen_same_frame_player"
	player_hit.amount = player.actor_resources.health.current
	var boss_submitted := policy.submit(boss_hit)
	var player_submitted := policy.submit(player_hit)
	await _frames(4)
	_record("boss/same_frame_death_priority", boss_submitted and player_submitted and player.actor_resources.health.terminal and not lifetime.active and not bool(binding.get("completed")) and int(world.wallet.balance)==coins_before, "transaction_fixture", {"boss_request_accepted":boss_submitted,"player_request_accepted":player_submitted,"player_terminal":player.actor_resources.health.terminal,"run_active":lifetime.active,"completion":binding.get("completed"),"wallet_before":coins_before,"wallet_after":world.wallet.balance,"direct_policy_requests":true,"natural_combat":false})
	var seal := _spec("M40").seals[0] as Dictionary
	var rect := _rect(seal.rect_pixels)
	var outward := _face(seal.face)
	var center := arena.to_global(rect.get_center())
	var evidence := _sweep(center-outward*60.0,outward*120.0)
	_record("boss/exit_stays_sealed_after_cancel", evidence.blocked and str(evidence.collider).contains("Seal"), "native_player_collision_sweep", evidence)

func _finish() -> void:
	if is_instance_valid(world):
		if is_instance_valid(player): player.router.clear("mapgen_test_end")
		var clean := await TEARDOWN.drain_world(world)
		_record("host/audio_teardown", clean, "lifecycle")
		world.queue_free()
		await process_frame
		await process_frame
	var report := {"schema":"gunman/mapgen-physical-tests/v1","seed":930001,"suite":suite,"checks":checks,"failures":failures,"cases":rows,"trace":trace,"whole_map_continuous_traversal":"NOT_RUN","human_playtest":false,"device_playtest":false,"scope":"Continuous native input is limited to spawn/M01 bell/M02 seam. All other fixture probes are explicitly labelled; body sweeps use the actual PlayerMotor shape and physics server.","viewport":[root.size.x,root.size.y],"display_server":DisplayServer.get_name()}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("mapgen_report_write_failed"); quit(2); return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	file.close()
	print("MAPGEN DELIVERY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
