extends Node2D
## Real continuous InputRouter driver. Position is assigned only at initial spawn.
class SNAPSHOT:
	static func pair(value: Vector2) -> Array: return [value.x,value.y]
	static func capture(actor: PlayerController, _build: Variant = null, scope := "runtime") -> Dictionary:
		var granted: Array[String] = []
		if actor.jump_ability.enabled and actor.jump_ability.maximum_jumps()>0: granted.append("jump")
		if actor.shoot_ability.enabled: granted.append("shot_recoil")
		if actor.traversal.double_enabled: granted.append("double_jump")
		if actor.traversal.wall_enabled: granted.append("wall_climb")
		if actor.traversal.hook_enabled: granted.append("grapple")
		var tuning: Dictionary = {}
		var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/player_tuning.json"))
		for key: String in keys: tuning[key] = actor.motor.tuning.get(key)
		var weapon := actor.shoot_ability.weapon
		return {"scope":scope,"granted_actions":granted,"tuning":tuning,
			"equipped_weapon":{"id":String(weapon.id),"tier":weapon.tier,"definition_path":weapon.resource_path,"definition_sha256":FileAccess.get_sha256(weapon.resource_path)},
			"effective_max_jumps":actor.jump_ability.maximum_jumps(),"air_shots":actor.action_resources.shot_charges,
			"position":pair(actor.motor.position),"velocity":pair(actor.motor.velocity),
			"health":{"current":actor.actor_resources.health.current,"capacity":actor.actor_resources.health.capacity},
			"shot_energy":{"current":actor.actor_resources.stamina.current,"capacity":actor.actor_resources.stamina.capacity},
			"config_hashes":{"player_tuning":FileAccess.get_sha256("res://config/player_tuning.json"),"input_profile":FileAccess.get_sha256("res://config/input_profile.json"),"traversal":FileAccess.get_sha256("res://resources/player/traversal.tres"),"shot_energy":FileAccess.get_sha256("res://game/player/resources/plains_shot_energy.tres")}}
class Observer extends Node:
	var trace: Node
	func _physics_process(_delta: float) -> void:
		trace.observe()

var player: PlayerMotor
var controller: PlayerController
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var requests: Array[Dictionary] = []
var initial_snapshot: Dictionary
var finished := false
var frame := 0
var before_steps := 0
var phase := "outbound"
var branch_landed := false
var returned := false
var stable := 0
var variant := "positive"
var mirror := 1.0
var anchor_point := Vector2(300, 450)
var root_rect := Rect2(-200, 600, 900, 90)
var branch_rect := Rect2(100, 480, 200, 24)
var spawn := Vector2(130, 582)
var mode := "golden"
var seed_value := "forest-playable-00"
var map_index := 1
var route_name := "fast"
var app: Node2D
var stage: Node2D
var initialized := false
var manifest: Dictionary = {}
var itinerary: Array[Dictionary] = []
var leg_index := 0
var leg_phase := "walk"
var leg_age := 0
var leg_retries := 0
var recovery_floor_ticks := 0
var clearance_ticks := 0
var completed_legs: Array[Dictionary] = []
var route_errors: Array[String] = []
var modal_frames: Array[Dictionary] = []
var reward_input_events: Array[Dictionary] = []
var cache_interacted := false
var cache_claimed := false
var modal_age := 0
var modal_button: Button
var modal_button_point := Vector2.ZERO
var modal_click_sent := false
var paused_before_steps := 0
var descent_waypoint := NAN
var descent_floor_y := 0.0
var safe_trace := true
var previous_position := Vector2.ZERO
var anchor: GrappleAnchor

func _ready() -> void:
	process_physics_priority = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if mode == "region":
		begin_region()
		return
	if variant == "mirror":
		mirror = -1
		anchor_point.x *= mirror
		spawn.x *= mirror
		root_rect.position.x = -root_rect.end.x
		branch_rect.position.x = -branch_rect.end.x
	surface("RootLanding", root_rect, false)
	surface("CanopyBranch", branch_rect, true)
	anchor = GrappleAnchor.new()
	anchor.name = "FixedAnchor"
	anchor.position = anchor_point
	add_child(anchor)
	if variant == "blocked": surface("SolidTrunk", Rect2(Vector2(205, 470), Vector2(30, 130)), false)
	player = preload("res://game/player/player.tscn").instantiate() as PlayerMotor
	player.position = spawn
	add_child(player)
	controller = player.get_node("Controller") as PlayerController
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.enable_shot_energy()
	if variant != "no-hook": controller.traversal.grant(&"grapple")
	controller.traversal.action_changed.connect(func(action: StringName) -> void:
		events.append({"tick": frame, "kind": String(action), "position": SNAPSHOT.pair(player.position), "supports": supports()}))
	controller.landed.connect(func() -> void:
		events.append({"tick": frame, "kind": "landed", "position": SNAPSHOT.pair(player.position), "supports": supports()}))
	controller.jump_ability.jumped.connect(func() -> void:
		events.append({"tick": frame, "kind": "jumped", "position": SNAPSHOT.pair(player.position)}))
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, _serial: int) -> void:
		events.append({"tick": frame, "kind": "shot_fired"}))
	initial_snapshot = snapshot()
	install_observer()
	initialized = true

func surface(label: String, rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.one_way_collision = one_way
	body.add_child(shape)
	add_child(body)

func supports() -> Array[String]:
	var result: Array[String] = []
	for index: int in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		if collision.get_normal().dot(Vector2.UP) > 0.7:
			var node := collision.get_collider() as Node
			if node != null:
				for support_id: Variant in node.get_meta("support_ids",[String(node.name)]):
					if String(support_id) not in result: result.append(String(support_id))
	return result

func _physics_process(_delta: float) -> void:
	if finished or not initialized: return
	if mode == "region" and get_tree().paused: return
	frame += 1
	before_steps = player.motion_steps
	if mode == "region":
		drive_region()
		return
	if frame == 12:
		controller.router.set_jump_held(&"forest_driver", true)
		requests.append({"tick": frame, "kind": "jump", "queued": true})
	if frame == 24:
		if variant == "dead-anchor": anchor.queue_free()
		var aim := (anchor_point - player.position - Vector2(0, -6)).normalized()
		if variant == "miss": aim = Vector2.UP
		var queued := controller.router.request_action(&"grapple", aim)
		requests.append({"tick": frame, "kind": "grapple", "queued": queued, "direction": SNAPSHOT.pair(aim)})
	var axis := 0.0
	if phase == "return":
		if "CanopyBranch" in supports() or player.position.y < 550:
			axis = -mirror
		elif player.is_on_floor():
			axis = signf(spawn.x - player.position.x) if absf(player.position.x - spawn.x) > 3 else 0.0
	controller.router.set_move_axis(axis)

func observe() -> void:
	if finished or not initialized: return
	if mode == "region":
		observe_region()
		return
	var support := supports()
	var body := Rect2(player.position - Vector2(12, 18), Vector2(24, 36))
	var full := player.is_on_floor() and "CanopyBranch" in support and body.position.x >= branch_rect.position.x and body.end.x <= branch_rect.end.x
	if phase == "outbound":
		stable = stable + 1 if full else 0
		if stable >= 12:
			branch_landed = true
			phase = "return"
			stable = 0
	else:
		stable = stable + 1 if player.is_on_floor() and "RootLanding" in support and absf(player.position.x - spawn.x) < 8 else 0
		returned = stable >= 12
	frames.append({"tick": frame, "position": SNAPSHOT.pair(player.position), "velocity": SNAPSHOT.pair(player.velocity),
		"grounded": player.is_on_floor(), "supports": support, "full_branch_support": full,
		"traversal": String(controller.traversal.state), "hook_used": controller.traversal.hook_used,
		"motor_steps_this_tick": player.motion_steps - before_steps, "axis": controller.router.axis,
		"energy": controller.actor_resources.stamina.current, "health": controller.actor_resources.health.current,
		"air_shots": controller.action_resources.shot_charges, "phase": phase})
	if returned or frame >= 420:
		finished = true
		controller.router.set_move_axis(0)

func snapshot() -> Dictionary:
	var result := SNAPSHOT.capture(controller, null, "forest_short_H_golden")
	var definition := controller.traversal.definition
	result["traversal_definition"] = {"resource_path": definition.resource_path, "sha256": FileAccess.get_sha256(definition.resource_path), "hook_range": definition.hook_range, "hook_kick": SNAPSHOT.pair(definition.hook_kick), "hook_launch_seconds": definition.hook_launch_seconds}
	return result

func install_observer() -> void:
	var observer := Observer.new()
	observer.trace = self
	observer.process_physics_priority = 1100
	add_child(observer)

func begin_region() -> void:
	var script: Script = load("res://game/application/demo_app.gd")
	if script == null or not script.can_instantiate():
		route_errors.append("formal_DemoApp_compile_failed")
		finished = true
		return
	app = script.new()
	app.meta_persistence_enabled = false
	add_child(app)
	if not app.start_debug_region(&"thorn_forest", map_index, seed_value):
		route_errors.append("formal_debug_entry_rejected")
		finished = true
		return
	for unused: int in 8: await get_tree().physics_frame
	stage = app.stage
	if not is_instance_valid(stage) or not stage.assembly_ok:
		route_errors.append("formal_forest_assembly_failed")
		finished = true
		return
	player = app.player
	controller = app.controller
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	manifest = stage.generated.manifest.duplicate(true)
	for edge_id: String in manifest.routes[route_name]:
		var found := false
		for edge: Dictionary in manifest.connections:
			if edge.id != edge_id: continue
			found = true
			if edge.kind == "hook_steps":
				for step: Dictionary in edge.steps:
					var leg := step.duplicate(true)
					leg.edge_id = edge_id
					leg.kind = "hook"
					itinerary.append(leg)
			else:
				itinerary.append({"edge_id":edge_id,"kind":edge.kind,"landing":edge.path[-1]})
		if not found: route_errors.append("manifest_missing_route_edge_"+edge_id)
	controller.traversal.action_changed.connect(func(action: StringName) -> void:
		events.append({"tick":frame,"kind":String(action),"leg":leg_index,"position":SNAPSHOT.pair(player.position),"supports":supports(),"probe":probe_contacts(),"hook_target":String(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else ""}))
	controller.jump_ability.jumped.connect(func() -> void:
		events.append({"tick":frame,"kind":"jumped","leg":leg_index,"position":SNAPSHOT.pair(player.position)}))
	controller.landed.connect(func() -> void:
		events.append({"tick":frame,"kind":"landed","leg":leg_index,"position":SNAPSHOT.pair(player.position),"supports":supports(),"probe":probe_contacts(),"hook_target":String(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else ""}))
	controller.shoot_ability.shot_fired.connect(func(_aim: Vector2, _serial: int) -> void:
		events.append({"tick":frame,"kind":"shot_fired","leg":leg_index,"aim":SNAPSHOT.pair(_aim),"serial":_serial,"position":SNAPSHOT.pair(player.position),"supports":supports(),"grounded":player.is_on_floor(),"energy":controller.actor_resources.stamina.current}))
	app.policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			if result.request.target_id == &"player":
				events.append({"tick":frame,"kind":"committed_player_damage","leg":leg_index,"source_id":String(result.request.source_id),"amount":result.request.amount,"position":SNAPSHOT.pair(player.position),"supports":supports(),"health":controller.actor_resources.health.current,"traversal":String(controller.traversal.state)})
			else:
				events.append({"tick":frame,"kind":"committed_enemy_damage","leg":leg_index,"source_id":String(result.request.source_id),"target_id":String(result.request.target_id),"amount":result.request.amount,"lethal":result.lethal,"health":result.health.current}))
	for i: int in stage.enemies.size():
		var creature: EnemyMotor = stage.enemies[i]
		var actor: EnemyActor = creature.get_node("Actor")
		var actor_id := String(stage.enemy_manifest[i].id)
		actor.defeated.connect(func(defeated: EnemyActor) -> void:
			events.append({"tick":frame,"kind":"actual_enemy_defeated","leg":leg_index,"manifest_id":actor_id,"health":defeated.health.current,"terminal":defeated.health.terminal,"collision_layer":defeated.motor.collision_layer,"position":SNAPSHOT.pair(defeated.motor.position)}))
	initial_snapshot = snapshot()
	previous_position = player.position
	install_observer()
	initialized = true

func request(kind: StringName, direction := Vector2.ZERO) -> void:
	var accepted := controller.router.request_action(kind,direction)
	requests.append({"tick":frame,"kind":String(kind),"leg":leg_index,"queued":accepted,"direction":SNAPSHOT.pair(direction)})

func drive_region() -> void:
	if leg_index >= itinerary.size():
		finished = true
		controller.router.set_move_axis(0)
		return
	var leg: Dictionary = itinerary[leg_index]
	if route_name == "high_return" and leg.edge_id == "cache_return" and not cache_interacted:
		cache_interacted = true
		request(&"interact")
		leg_phase = "reward"
		controller.router.set_move_axis(0)
		return
	if leg_phase == "reward":
		if not app.reward_modal.opened and cache_claimed:
			leg_phase = "walk"
		else:
			leg_age += 1
			if leg_age > 60:
				route_errors.append("actual_cache_reward_modal_not_open_or_claimed")
				finished = true
			return
	leg_age += 1
	var target := Vector2(leg.landing[0],leg.landing[1])
	var axis := 0.0
	if leg.kind == "hook":
		var takeoff := Vector2(leg.takeoff[0],leg.takeoff[1])
		if leg_phase == "walk":
			var threat := corridor_lantern(takeoff,Vector2(leg.anchor[0],leg.anchor[1])) if player.is_on_floor() and absf(player.position.y-takeoff.y)<2 else null
			if threat != null:
				# A grounded Pulse has a real movement burst. Walk to the actual
				# support centre first, leaving room for its entire recoil path.
				clearance_ticks += 1
				if clearance_ticks > 180:
					route_errors.append("natural_grounded_lantern_clearance_timeout_%s" % leg_index)
					finished = true
					controller.router.set_move_axis(0)
					return
				var centre_x := grounded_support_centre()
				if absf(player.position.x-centre_x)>3:
					axis = signf(centre_x-player.position.x)
				elif controller.shoot_ability.cooldown_remaining<=0 and player.recoil_burst_remaining<=0:
					events.append({"tick":frame,"kind":"observed_hook_corridor_lantern","leg":leg_index,"position":SNAPSHOT.pair(threat.position),"player_position":SNAPSHOT.pair(player.position),"health":(threat.get_node("Actor") as EnemyActor).health.current,"support_centre_x":centre_x,"burst_remaining":player.recoil_burst_remaining})
					request(&"shoot_release",(threat.global_position-player.global_position).normalized())
				controller.router.set_move_axis(axis)
				return
			if absf(player.position.x-takeoff.x) > 3: axis = signf(takeoff.x-player.position.x)
			elif player.is_on_floor() and absf(player.position.y-takeoff.y)<2 and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0:
				controller.router.set_jump_held(&"forest_driver",true)
				requests.append({"tick":frame,"kind":"jump","leg":leg_index,"queued":true})
				leg_phase = "jump"
				leg_age = 0
		elif leg_phase == "jump" and leg_age >= (6 if absf(takeoff.y-target.y) < 100 else 12):
			controller.router.set_jump_held(&"forest_driver",false)
			var aim := (Vector2(leg.anchor[0],leg.anchor[1])-player.position-Vector2(0,-6)).normalized()
			request(&"grapple",aim)
			leg_phase = "hook"
			leg_age = 0
		elif leg_phase == "hook":
			# A hurt cancellation or miss can end an otherwise legal attempt. Only
			# real stable floor support permits walking back and trying again;
			# H/ammo/health are never reset by the driver.
			var can_recover := controller.traversal.state == &"free" and player.is_on_floor() and not full_leg_support(leg)
			recovery_floor_ticks = recovery_floor_ticks+1 if can_recover else 0
			if recovery_floor_ticks >= 3:
				if leg_retries >= 2:
					route_errors.append("natural_hook_recovery_exhausted_%s_%s" % [leg.edge_id,leg_index])
					finished = true
				else:
					leg_retries += 1
					events.append({"tick":frame,"kind":"natural_grounded_route_recovery","leg":leg_index,"attempt":leg_retries,"position":SNAPSHOT.pair(player.position),"supports":supports(),"hook_used":controller.traversal.hook_used,"health":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"air_shots":controller.action_resources.shot_charges})
					leg_phase = "walk"
					leg_age = 0
					recovery_floor_ticks = 0
			if leg_age > 150:
				route_errors.append("hook_leg_timeout_%s_%s" % [leg.edge_id,leg_index])
				finished = true
	else:
		var desired_x := target.x
		if leg.kind == "descent" and player.position.y < target.y-5:
			if player.is_on_floor() and is_nan(descent_waypoint):
				descent_floor_y = player.position.y+18
				descent_waypoint = safe_drop_column(target.x,descent_floor_y)
			if not is_nan(descent_waypoint) and player.position.y < descent_floor_y+20:
				desired_x = descent_waypoint
			elif player.position.y >= descent_floor_y+20:
				descent_waypoint = NAN
			if player.is_on_floor() and absf(player.position.x-desired_x)<4 and leg_age%15 == 1:
				request(&"drop_through")
		if absf(player.position.x-desired_x) > 3: axis = signf(desired_x-player.position.x)
	if leg_age > 360:
		route_errors.append("leg_timeout_%s_%s" % [leg.edge_id,leg_index])
		finished = true
	controller.router.set_move_axis(axis)

func grounded_support_centre() -> float:
	var centre := player.position.x
	var widest := 0.0
	var actual := supports()
	for row: Dictionary in manifest.platforms:
		var rect := Rect2(row.rect[0],row.rect[1],row.rect[2],row.rect[3])
		if row.id in actual and absf(player.position.y+18-rect.position.y)<1 and rect.size.x>widest and player.position.x>=rect.position.x and player.position.x<=rect.end.x:
			centre = rect.get_center().x
			widest = rect.size.x
	return centre

func corridor_lantern(takeoff: Vector2, destination: Vector2) -> EnemyMotor:
	for creature: EnemyMotor in stage.enemies:
		var actor := creature.get_node("Actor") as EnemyActor
		if actor.health.terminal or String(actor.definition.behavior_id) != "forest_lantern": continue
		var nearest := Geometry2D.get_closest_point_to_segment(creature.global_position,takeoff,destination)
		if creature.global_position.distance_to(nearest)<72 and creature.global_position.distance_to(player.global_position)<240:
			# Observe from the intended safe firing point. Terrain that blocks
			# a Pulse also separates this lower support from that distant body;
			# continue the ordinary H route instead of wasting energy into it.
			var origin := Vector2(grounded_support_centre(),player.global_position.y)
			var ray := PhysicsRayQueryParameters2D.create(origin,creature.global_position,1,[player.get_rid()])
			var blocker := get_world_2d().direct_space_state.intersect_ray(ray)
			if not blocker.is_empty():
				if not events.any(func(event: Dictionary) -> bool: return event.kind=="observed_lantern_terrain_occlusion" and event.leg==leg_index):
					events.append({"tick":frame,"kind":"observed_lantern_terrain_occlusion","leg":leg_index,"origin":SNAPSHOT.pair(origin),"target":SNAPSHOT.pair(creature.global_position),"collider":String(blocker.collider.name)})
				continue
			return creature
	return null

func observe_region() -> void:
	if not frames.is_empty() and int(frames[-1].tick) == frame: return
	var support := supports()
	var full_support := false
	if leg_index < itinerary.size():
		var leg: Dictionary = itinerary[leg_index]
		if leg.kind == "hook":
			for row: Dictionary in manifest.platforms:
				if row.id != leg.support_id: continue
				var r: Array = row.rect
				full_support = player.is_on_floor() and leg.support_id in support and player.position.x-12 >= float(r[0]) and player.position.x+12 <= float(r[0])+float(r[2]) and absf(player.position.y+18-float(r[1])) < 1
		else:
			var destination := Vector2(leg.landing[0],leg.landing[1])
			full_support = player.is_on_floor() and absf(player.position.x-destination.x) < 8 and absf(player.position.y-destination.y) < 2
		stable = stable+1 if full_support else 0
		if stable >= 12:
			completed_legs.append({"leg":leg_index,"edge_id":leg.edge_id,"tick":frame,"position":SNAPSHOT.pair(player.position),"supports":support,"energy":controller.actor_resources.stamina.current,"health":controller.actor_resources.health.current})
			leg_index += 1
			leg_phase = "walk"
			leg_age = 0
			leg_retries = 0
			clearance_ticks = 0
			recovery_floor_ticks = 0
			descent_waypoint = NAN
			stable = 0
			controller.router.set_jump_held(&"forest_driver",false)
	var sweep := Rect2(previous_position-Vector2(12,18),Vector2(24,36)).merge(Rect2(player.position-Vector2(12,18),Vector2(24,36)))
	for row: Array in manifest.dangers:
		if sweep.intersects(Rect2(row[0],row[1],row[2],row[3]),true): safe_trace = false
	frames.append({"tick":frame,"position":SNAPSHOT.pair(player.position),"velocity":SNAPSHOT.pair(player.velocity),"supports":support,"grounded":player.is_on_floor(),"leg":leg_index,"leg_phase":leg_phase,"leg_retries":leg_retries,"full_support":full_support,"traversal":String(controller.traversal.state),"motor_steps_this_tick":player.motion_steps-before_steps,"axis":controller.router.axis,"energy":controller.actor_resources.stamina.current,"health":controller.actor_resources.health.current,"air_shots":controller.action_resources.shot_charges,"hook_used":controller.traversal.hook_used,"enemy_count":stage.enemies.size(),"vine_gate_disabled":stage.assembler.vine_shape.disabled,"vine_gate_saved_open":stage.region_state.opened.has("crown_vine")})
	previous_position = player.position
	if leg_index >= itinerary.size():
		returned = route_name == "high_return"
		finished = true
		controller.router.set_move_axis(0)
	if frame > 6000 or not controller.active or controller.actor_resources.health.terminal:
		route_errors.append("route_fatal_or_timeout")
		finished = true

func probe_contacts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var probe := controller.traversal._hook_probe
	if probe == null: return result
	for i: int in probe.get_collision_count():
		var collider: Object = probe.get_collider(i)
		result.append({"collider":String((collider as Node).name) if collider is Node else str(collider),"point":SNAPSHOT.pair(probe.get_collision_point(i))})
	return result

func _process(_delta: float) -> void:
	if mode != "region" or not initialized or finished or not cache_interacted: return
	if app.reward_modal.opened:
		modal_age += 1
		modal_frames.append({"index":modal_age,"gameplay_tick":frame,"paused":get_tree().paused,"position":SNAPSHOT.pair(player.position),"supports":supports(),"motor_steps":player.motion_steps,"modal_open":true})
		if modal_age == 4:
			for button: Button in app.reward_modal.find_children("*","Button",true,false):
				if button.visible and not button.disabled:
					modal_button = button
					modal_button_point = button.get_global_rect().get_center()
					var event := InputEventMouseButton.new()
					event.position = modal_button_point
					event.global_position = modal_button_point
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = true
					get_viewport().push_input(event,true)
					reward_input_events.append({"index":modal_age,"kind":"mouse_button_press","position":SNAPSHOT.pair(modal_button_point),"button_text":button.text,"actual_button_rect":[button.get_global_rect().position.x,button.get_global_rect().position.y,button.size.x,button.size.y]})
					break
		elif modal_age == 5 and is_instance_valid(modal_button):
			var event := InputEventMouseButton.new()
			event.position = modal_button_point
			event.global_position = modal_button_point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = false
			get_viewport().push_input(event,true)
			reward_input_events.append({"index":modal_age,"kind":"mouse_button_release","position":SNAPSHOT.pair(modal_button_point)})
			modal_click_sent = true
		if modal_age > 90:
			route_errors.append("real_reward_pointer_click_timeout")
			finished = true
	else:
		for chest: Dictionary in stage.chests:
			if chest.claimed and stage.region_state.claimed.has(chest.id): cache_claimed = true

func safe_drop_column(destination_x: float, floor_y: float) -> float:
	var floors: Array[Rect2] = []
	var sampled: Dictionary = {}
	for body: StaticBody2D in stage.assembler.support_bodies.values():
		if sampled.has(body.get_instance_id()): continue
		sampled[body.get_instance_id()] = true
		var shape := body.get_node("CollisionShape2D") as CollisionShape2D
		var rect: Rect2 = body.get_meta("support_world_rect",Rect2(shape.global_position+shape.shape.get_rect().position,shape.shape.get_rect().size))
		if absf(rect.position.y-floor_y)<1: floors.append(rect)
	var candidates: Array[float] = [destination_x]
	for rect: Rect2 in floors:
		candidates.append(rect.position.x+24)
		candidates.append(rect.end.x-24)
		candidates.append(rect.position.x-24)
		candidates.append(rect.end.x+24)
	var chosen := destination_x
	var distance := INF
	for x: float in candidates:
		var count := 0
		var full := false
		for rect: Rect2 in floors:
			if x+12>rect.position.x and x-12<rect.end.x:
				count += 1
				full = full or (x-12>=rect.position.x and x+12<=rect.end.x)
		if count == 1 and full and absf(x-destination_x)<distance:
			chosen = x
			distance = absf(x-destination_x)
	return chosen

func full_leg_support(leg: Dictionary) -> bool:
	if not player.is_on_floor() or str(leg.support_id) not in supports(): return false
	for row: Dictionary in manifest.platforms:
		if row.id != leg.support_id: continue
		var rect: Array = row.rect
		return player.position.x-12>=float(rect[0]) and player.position.x+12<=float(rect[0])+float(rect[2]) and absf(player.position.y+18-float(rect[1]))<1
	return false
