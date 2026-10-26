extends "res://tests/forest_depth_region_trace.gd"
## V16 consumes the actual new world through the original Router/Motor driver.
## Historical layouts, v15 Bible support and v14 references remain untouched.
const EXPLORATION_LAYOUT := "forest-branching-expedition-v16"
var _actual_validated := false
var _unexpected_modal_frames := 0
var _collision_before := Vector2.ZERO
var _reward_transactions: Array[Dictionary] = []
var _reward_before: Dictionary = {}
var _duplicate_neutral_before: Dictionary = {}
var _pointer_start := 0
var _modal_start := 0
var _reward_recorded := false
var _checked_shortcut_edges: Dictionary = {}
class ExplorationGroundPilot extends "res://tests/forest_depth_grove_combat_case.gd":
	func supports_layout(layout: String) -> bool:
		return layout == "forest-branching-expedition-v16"


	func _drive_flank(trace: Node) -> void:
		if state == "flank_set_bank":
			var root: Rect2 = _floor_envelope(trace)
			var half: Vector2 = (trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
			var gap: float = half.x+target.definition.collision_size.x*.5+8.0
			var recoil: float = trace.player.weapon_motion.base_distance(trace.player.tuning,true)
			var enemy_x: float = target.motor.global_position.x
			var incoming_side: float = signf(enemy_x-trace.player.global_position.x)
			var body_gap: float = half.x+target.definition.collision_size.x*.5
			var near_bank := Vector2(enemy_x-incoming_side*(body_gap+24.0),origin.y)
			var safe_min: float = root.position.x+half.x+maxf(0.0,incoming_side*recoil)
			var safe_max: float = root.end.x-half.x+minf(0.0,incoming_side*recoil)
			if safe_min<=safe_max:
				var fitted := Vector2(clampf(near_bank.x,safe_min,safe_max),near_bank.y)
				if (fitted.x-enemy_x)*-incoming_side>=gap and _ground_bank_safe(trace,fitted,target.motor.global_position): near_bank=fitted
			var far_bank := Vector2(enemy_x+flank_side*(body_gap+24.0),origin.y)
			var near_exists: bool = _ground_bank_safe(trace,near_bank,target.motor.global_position)
			var far_exists: bool = _ground_bank_safe(trace,far_bank,target.motor.global_position)
			if root.has_area() and not near_exists and not far_exists and trace.player.is_on_floor():
				# This real narrow one-way cannot contain a horizontal ground
				# recoil on either side. Jump above the actual enemy, fire one
				# downward round, then land before another combat jump.
				trace.event("v16_encounter_vertical_bank_choice",_data(trace).merged({"support":origin_support,"actual_floor":[root.position.x,root.position.y,root.size.x,root.size.y]}))
				trace.jump(true); flight_started=int(trace.tick); air_shots=0; state="flank_v16_vertical_shot"
				return
		if state == "flank_v16_vertical_shot":
			var enemy: Vector2 = target.motor.global_position
			trace.controller.router.set_move_axis(clampf((enemy.x-trace.player.global_position.x)/12.0,-1.0,1.0))
			if air_shots == 0 and not trace.player.is_on_floor() and trace.player.global_position.y+18 < enemy.y-target.definition.collision_size.y*.5-1.0 and _ready_shot(trace) and _direction_hits_body(trace,Vector2.DOWN):
				_shoot(trace,Vector2.DOWN,true); air_shots=1; trace.jump(false)
			if trace.player.normal_velocity.y>=0: trace.jump(false)
			if trace.player.is_on_floor() and int(trace.tick)>flight_started+1:
				if not trace.full_support(origin_support): trace.fail("v16_encounter_vertical_shot_wrong_landing/"+target_id); return
				state="flank_set_bank"; trace.jump(false)
			return
		super._drive_flank(trace)

class ExplorationAirPilot extends "res://tests/forest_depth_air_chain_case.gd":
	var descending_cast := false
	func drive(trace: Node, leg: Dictionary) -> void:
		if active_leg != int(trace.leg_index):
			descending_cast = false
			super.drive(trace,leg)
			if leg.has("action_start"):
				start = trace.point(leg.action_start)
				trace.controller.router.set_move_axis(clampf((start.x-trace.player.global_position.x)/12.0,-1.0,1.0))
			return
		var departure: Dictionary = leg.get("departure",{})
		var outside_drop: bool = departure.get("ground_required",true) == false and not leg.has("approach_steps")
		if not outside_drop:
			super.drive(trace,leg); return
		if trace.age > 400:
			trace.fail("v16_outside_drop_bounded_phase/"+str(trace.phase)); return
		if trace.phase == "align":
			trace.controller.router.set_move_axis(clampf((start.x-trace.player.global_position.x)/12.0,-1.0,1.0))
			trace.stable = trace.stable+1 if trace.at_destination(start,entry_support) and absf(trace.player.velocity.x)<1.0 else 0
			if trace.stable >= 13:
				trace.jump(false)
				trace.event("v16_grounded_outside_departure",{"geometry_instance":instance_data.id,"entry_support":entry_support,"method":"ordinary_walk_off_outside_edge"})
				trace.set_phase("v16_outside_drop")
			return
		if trace.phase == "v16_outside_drop":
			var outside: Vector2 = trace.point(departure.path[-1])
			trace.controller.router.set_move_axis(clampf((outside.x-trace.player.global_position.x)/12.0,-1.0,1.0))
			trace.jump(false)
			var mapped: String = str(instance_data.anchor_id_map.get(str(program[0].get("anchor","")),""))
			var target: Node2D = trace.stage.assembler.hook_targets.get(mapped)
			if not is_instance_valid(target): trace.fail("v16_outside_drop_target_missing"); return
			var half: Vector2 = (trace.player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
			var below := target.global_position.y+half.y+2.0
			var rect: Array = trace.platform(entry_support).rect
			var outside_body: bool = trace.player.global_position.x-half.x > float(rect[0])+float(rect[2])
			if not trace.player.is_on_floor() and outside_body and trace.player.global_position.y >= below:
				descending_cast = true
				trace.event("v16_actual_descending_side_cast",{"geometry_instance":instance_data.id,"target":mapped,"target_position":trace.pair(target.global_position),"velocity":trace.pair(trace.player.velocity),"grounded":trace.player.is_on_floor(),"outside_body":outside_body,"threshold_y":below})
				_submit(trace)
			return
		if trace.phase == "air_chain_receive" and not descending_cast:
			trace.fail("v16_outside_drop_missing_actual_cast"); return
		super.drive(trace,leg)

func canopy_layout() -> bool:
	# Reuse ordinary sequence endpoint labels and the actual ground-combat
	# pilot. The old interwoven/woven special encounters remain ineligible.
	return manifest.get("layout_version") == EXPLORATION_LAYOUT

func begin() -> void:
	grove_combat_case = ExplorationGroundPilot.new()
	air_chain_case = ExplorationAirPilot.new()
	await super.begin()
	if not initialized or not failures.is_empty(): return
	if manifest.get("layout_version") != EXPLORATION_LAYOUT:
		fail("exploration_requires_actual_v16"); return
	_actual_validated = ThornForestRegionGenerator.new().validate(manifest, player.tuning)
	if not _actual_validated:
		fail("exploration_actual_manifest_validator_rejected"); return
	var expanded: Array[Dictionary] = []
	for leg: Dictionary in itinerary:
		if leg.kind == "airborne_chain":
			for index: int in leg.get("approach_steps",[]).size():
				var approach: Dictionary = leg.approach_steps[index].duplicate(true)
				approach.edge_id = leg.edge_id; approach.step_index = index; approach.approach = true
				expanded.append(approach)
		expanded.append(leg)
	itinerary = expanded
	_collision_before = (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
	if _collision_before != Vector2(24,36): fail("exploration_actual_player_collision_changed")

func fail(reason: String) -> void:
	# Preserve the original failure condition, while exposing actual App
	# generation/assembly status instead of guessing from an empty Manifest.
	var diagnostic := {"kind":"v16_failure_diagnostic","tick":tick,"reason":reason,"requested_layout_pin":recorded_layout_version,"actual_manifest_layout":str(manifest.get("layout_version",""))}
	if is_instance_valid(app):
		diagnostic.app_status = str(app.get("_status"))
		var actual_stage := app.get("stage") as Node
		diagnostic.actual_stage_exists = is_instance_valid(actual_stage)
		if is_instance_valid(actual_stage):
			diagnostic.actual_stage_class = actual_stage.get_class()
			var actual_script := actual_stage.get_script() as Script
			diagnostic.actual_stage_script = actual_script.resource_path if actual_script != null else ""
			if actual_stage is GeneratedDemoStage:
				diagnostic.assembly_ok = (actual_stage as GeneratedDemoStage).assembly_ok
				var generated: Dictionary = (actual_stage as GeneratedDemoStage).generated
				diagnostic.generated_ok = generated.get("ok",false)
				diagnostic.generated_error = str(generated.get("error",""))
	events.append(diagnostic)
	super.fail(reason)

func _physics_process(delta: float) -> void:
	if initialized and not finished and not get_tree().paused and leg_index < itinerary.size():
		var current: Dictionary = itinerary[leg_index]
		for edge: Dictionary in manifest.connections:
			if str(edge.id) != str(current.edge_id) or not str(edge.get("condition","")).begins_with("opened:") or _checked_shortcut_edges.has(str(edge.id)): continue
			if bool(current.get("claim_before_edge",false)) and not duplicate_checked: break
			var key := str(edge.condition).trim_prefix("opened:")
			var shortcut_id := str(edge.get("shortcut_id",key))
			var shape: CollisionShape2D = stage.assembler._reward_shortcut_shapes.get(shortcut_id)
			if not stage.region_state.opened.has(key) or not is_instance_valid(shape) or not shape.disabled:
				fail("v16_actual_reward_shortcut_not_open/"+key); return
			var source_claim := ""
			for shortcut: Dictionary in manifest.get("forest_shortcuts",[]):
				if str(shortcut.id) == shortcut_id: source_claim = str(shortcut.unlock_reward_id)
			var qualified := "thorn_forest/map_%s/" % map_index+source_claim
			if source_claim.is_empty() or not stage.region_state.claimed.has(qualified): fail("v16_shortcut_without_actual_reward_claim"); return
			event("v16_actual_reward_shortcut_entry",{"edge_id":str(edge.id),"shortcut_id":shortcut_id,"opened_key":key,"shape_disabled":shape.disabled,"opened":stage.region_state.opened.has(key),"qualified_claim":qualified})
			_checked_shortcut_edges[str(edge.id)] = true
	if initialized and not finished and not get_tree().paused and leg_index < itinerary.size() and str(itinerary[leg_index].get("kind","")) in ["short_hook_crossing","live_hook_crossing","live_pod_defeat"]:
		if not is_instance_valid(player) or not is_instance_valid(controller) or not app.lifetime.active:
			fail("actual_run_ended"); return
		tick += 1; age += 1; before_steps = player.motion_steps
		if tick > 18000: fail("route_tick_budget"); return
		if tick-leg_started > 1800: fail("edge_tick_budget/"+str(leg_index)+"/"+phase); return
		var leg: Dictionary = itinerary[leg_index]
		if bool(leg.get("claim_before_edge",false)) and not duplicate_checked:
			claim_local_id = str(leg.claim_id); drive_cache(); return
		if str(leg.kind) == "live_pod_defeat": _drive_pod_defeat(leg)
		elif str(leg.kind) == "live_hook_crossing" or str(leg.get("release_mode","")) == "hang_jump": _drive_exchange(leg)
		else: _drive_short_hook(leg)
		return
	super._physics_process(delta)

func _drive_short_hook(leg: Dictionary) -> void:
	var takeoff := point(leg.path[0])
	var goal := point(leg.landing)
	var anchor_id := str(leg.anchor_id)
	var target: Node2D = stage.assembler.hook_targets.get(anchor_id)
	if not is_instance_valid(target): fail("v16_short_hook_actual_target_missing"); return
	if phase == "align":
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12.0,-1.0,1.0))
		stable = stable+1 if at_destination(takeoff,str(leg.from_support_id)) and absf(player.velocity.x)<1.0 and player.recoil_burst_remaining<=0 else 0
		if stable >= 12:
			event("v16_short_hook_departure",{"edge_id":leg.edge_id,"from_support_id":leg.from_support_id,"target":anchor_id,"supports":supports()})
			jump(true); set_phase("v16_short_hook_launch")
		return
	if phase == "v16_short_hook_launch":
		controller.router.set_move_axis(0)
		if not player.is_on_floor() and age >= 1:
			var origin := player.global_position+Vector2(0,-6)
			var offset := target.global_position-origin
			if offset.length() > controller.traversal.definition.hook_range:
				fail("v16_short_hook_outside_actual_range"); return
			event("v16_short_hook_intent",{"edge_id":leg.edge_id,"target":anchor_id,"target_position":pair(target.global_position),"origin":pair(origin),"actual_range":controller.traversal.definition.hook_range})
			if hook(anchor_id): set_phase("v16_short_hook_contact")
		return
	if phase == "v16_short_hook_contact":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]:
			fail("v16_short_hook_actual_target_missed"); return
		if controller.traversal.state == &"hook_kick": jump(false)
		if controller.traversal.state == &"free":
			var contacted := false
			for accepted: Dictionary in events:
				if int(accepted.get("leg",-1)) == leg_index and accepted.get("kind") == "hook_contact_kick" and accepted.get("target") == anchor_id: contacted = true
			if not contacted: fail("v16_short_hook_no_actual_contact"); return
			set_phase("v16_short_hook_receive")
		return
	controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
	stable = stable+1 if at_destination(goal,str(leg.landing_support_id)) else 0
	if stable >= 12: complete_leg()


func _live_actor(leg: Dictionary) -> EnemyActor:
	var found: EnemyActor = null
	for index: int in stage.enemy_manifest.size():
		var row: Dictionary = stage.enemy_manifest[index]
		if str(row.id) != str(leg.encounter_id): continue
		if found != null or str(row.get("geometry_instance","")) != str(leg.geometry_instance) or str(row.get("authored_slot_id","")) != str(leg.authored_slot_id) or str(row.get("behavior_id","")) != "forest_swing_pod":
			fail("v16_live_pod_identity_mismatch"); return null
		found = stage.enemies[index].get_node("Actor") as EnemyActor
	if found == null: fail("v16_live_pod_actual_actor_missing")
	return found

func _pod_sample(actor: EnemyActor) -> Dictionary:
	return {"motor_instance":actor.motor.get_instance_id(),"position":pair(actor.motor.global_position),"velocity":pair(actor.motor.velocity),"health":actor.health.current,"terminal":actor.health.terminal,"damageable_active":actor.damageable.active,"collision_layer":actor.motor.collision_layer,"body_size":pair(actor.definition.collision_size),"behavior_id":String(actor.definition.behavior_id),"depth_state":actor.attack_behavior.call("depth_snapshot")}

func _hook_event(state: StringName) -> void:
	super._hook_event(state)
	if events.is_empty(): return
	var actual_target: Node2D = controller.traversal.hook_target
	events[-1].target_instance = actual_target.get_instance_id() if is_instance_valid(actual_target) else 0
	events[-1].kick_side = controller.traversal.kick_side
	events[-1].velocity = pair(player.velocity)
	for index: int in stage.enemy_manifest.size():
		var actor: EnemyActor = stage.enemies[index].get_node("Actor") as EnemyActor
		if actual_target == actor.motor:
			events[-1].target_actor_id = str(stage.enemy_manifest[index].id)
			events[-1].actual_pod = _pod_sample(actor) if actor.definition.behavior_id == &"forest_swing_pod" else {}

func _drive_exchange(leg: Dictionary) -> void:
	var live := str(leg.kind) == "live_hook_crossing"
	var actor: EnemyActor = _live_actor(leg) if live else null
	if finished: return
	var target: Node2D = actor.motor if live else stage.assembler.hook_targets.get(str(leg.anchor_id))
	if not is_instance_valid(target): fail("v16_exchange_actual_target_missing"); return
	if live and actor.health.terminal: fail("v16_live_pod_defeated_before_exchange"); return
	if not live and (not target is GrappleAnchor or not (target as GrappleAnchor).hang_enabled):
		fail("v16_fixed_exchange_requires_actual_hanging_fruit"); return
	var source := point(leg.path[0])
	var goal := point(leg.landing)
	if phase == "align":
		jump(false)
		controller.router.set_move_axis(clampf((source.x-player.global_position.x)/12.0,-1.0,1.0))
		stable = stable+1 if at_destination(source,str(leg.from_support_id)) and absf(player.velocity.x)<1.0 and player.recoil_burst_remaining<=0 else 0
		if stable < 12: return
		if live:
			var row: Dictionary = {}
			for candidate: Dictionary in stage.enemy_manifest:
				if str(candidate.id) == str(leg.encounter_id): row = candidate
			var home := point(row.position)
			var definition := actor.definition as ForestEnemyDefinition
			var favorable := target.global_position.x >= home.x+definition.patrol_half_width*.9 and target.global_position.y <= home.y-definition.swing_rise*.8 and actor.motor.velocity.x >= 0.0
			if not favorable:
				if age % 12 == 0: event("v16_live_phase_declined",{"encounter_id":str(leg.encounter_id),"actual_pod":_pod_sample(actor),"supports":supports()})
				return
		event("v16_exchange_departure",{"edge_id":leg.edge_id,"live":live,"target_instance":target.get_instance_id(),"supports":supports(),"actual_pod":_pod_sample(actor) if live else {}})
		jump(true); set_phase("v16_exchange_launch"); return
	if phase == "v16_exchange_launch":
		controller.router.set_move_axis(0)
		if player.is_on_floor() or age < 1: return
		var origin := player.global_position+Vector2(0,-6)
		var direction := target.global_position-origin
		if direction.length() > controller.traversal.definition.hook_range: fail("v16_exchange_outside_actual_range"); return
		event("v16_exchange_intent",{"edge_id":leg.edge_id,"live":live,"target_instance":target.get_instance_id(),"target_position":pair(target.global_position),"origin":pair(origin),"actual_range":controller.traversal.definition.hook_range,"encounter_id":str(leg.get("encounter_id","")),"actual_pod":_pod_sample(actor) if live else {}})
		request(&"grapple",direction.normalized()); jump(false); set_phase("v16_exchange_contact"); return
	if controller.traversal.state in [&"hook_miss",&"hook_retract"]: fail("v16_exchange_actual_hook_missed"); return
	if phase == "v16_exchange_contact":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
		if not live and controller.traversal.state == &"hook_hang":
			jump(false); event("v16_fixed_hang_observed",{"target":str(leg.anchor_id),"target_instance":target.get_instance_id(),"hook_tip":pair(controller.traversal.hook_tip)})
			set_phase("v16_exchange_hang_release"); return
		if live and controller.traversal.state == &"hook_kick": jump(false)
		if controller.traversal.state != &"free": return
		if not live: fail("v16_fixed_exchange_never_hung"); return
		var contact := false
		for accepted: Dictionary in events:
			if int(accepted.get("leg",-1)) == leg_index and accepted.get("kind") == "hook_contact_kick" and accepted.get("target_actor_id","") == str(leg.encounter_id): contact = true
		if not contact: fail("v16_live_exchange_no_actual_pod_contact"); return
		set_phase("v16_exchange_receive"); return
	if phase == "v16_exchange_hang_release":
		if controller.traversal.state != &"hook_hang": fail("v16_fixed_hang_lost_before_jump"); return
		event("v16_fixed_hang_jump_intent",{"target":str(leg.anchor_id),"target_instance":target.get_instance_id()})
		jump(true); set_phase("v16_exchange_receive"); return
	controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
	if not live: release_jump_after_clearance(str(leg.landing_support_id))
	stable = stable+1 if at_destination(goal,str(leg.landing_support_id)) else 0
	if stable >= 12: complete_leg()

func _drive_pod_defeat(leg: Dictionary) -> void:
	var actor := _live_actor(leg)
	if finished or actor == null: return
	var bank := point(leg.path[0])
	controller.router.set_move_axis(clampf((bank.x-player.global_position.x)/12.0,-1.0,1.0)); jump(false)
	if tick-leg_started > 600: fail("v16_live_pod_defeat_600_frame_bound"); return
	if actor.health.terminal:
		var actual_drop: Dictionary = stage.region_state.drops.get(str(leg.encounter_id),{})
		if actual_drop.is_empty(): return
		stable = stable+1 if at_destination(bank,str(leg.landing_support_id)) and player.recoil_burst_remaining<=0 else 0
		if stable >= 12:
			event("v16_live_pod_actual_defeat_settlement",{"encounter_id":str(leg.encounter_id),"actual_pod":_pod_sample(actor),"settled_drop":actual_drop.duplicate(true),"manifest_drop":manifest.enemy_drops.get(str(leg.encounter_id),{}).duplicate(true),"hook_unavailable":not actor.damageable.active and actor.motor.collision_layer == 0})
			complete_leg()
		return
	stable = stable+1 if at_destination(bank,str(leg.from_support_id)) and player.recoil_burst_remaining<=0 else 0
	if stable < 12 or controller.shoot_ability.cooldown_remaining>0 or controller.shoot_ability.rounds_remaining>0 or controller.actor_resources.stamina.current<controller.shot_energy.shot_energy_cost: return
	var offset := actor.motor.global_position-player.global_position
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,actor.motor.global_position,5,[player.get_rid()])
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.get("collider") != actor.motor: return
	var unit := offset.normalized()
	for unused: int in 12: unit = unit.normalized()
	event("v16_live_pod_shot_intent",{"encounter_id":str(leg.encounter_id),"actual_pod":_pod_sample(actor),"supports":supports(),"aim":pair(unit)})
	request(&"shoot_release",unit); stable = 0


func _same_support_gap() -> bool:
	if leg_index >= itinerary.size(): return false
	var leg: Dictionary = itinerary[leg_index]
	return str(leg.kind) == "jump_gap" and str(leg.get("from_support_id","")) == str(leg.get("support_id",""))

func release_gap_after_vertical_clearance(support_id: String) -> void:
	if _same_support_gap(): return
	super.release_gap_after_vertical_clearance(support_id)

func release_jump_after_clearance(support_id: String) -> void:
	if not _same_support_gap(): super.release_jump_after_clearance(support_id); return
	var target := platform(support_id)
	if target.is_empty(): fail("jump_target_support_missing/"+support_id); return
	var rect := Rect2(target.rect[0],target.rect[1],target.rect[2],target.rect[3])
	var foot := player.global_position+Vector2(0,18)
	var goal := point(itinerary[leg_index].landing)
	var horizontal_clear := player.global_position.x-12>=rect.position.x-.1 and player.global_position.x+12<=rect.end.x+.1 and absf(player.global_position.x-goal.x)<=12.0
	if not jump_released and age>=int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second)) and foot.y<=rect.position.y-1 and horizontal_clear:
		event("jump_clearance_release",{"support_id":support_id,"foot":pair(foot),"target_top":rect.position.y,"target_rect":target.rect.duplicate(),"actual_landing":pair(goal),"same_support_landing_clearance":true})
		jump(false); jump_released=true
	if age>120: fail("bounded_jump_clearance_timeout/"+support_id); return
	if age>3:
		for index: int in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_normal().y>.7 and not full_support(support_id): fail("jump_ceiling_blocked/"+support_id); return
	if age>8 and not player.is_on_floor() and player.velocity.y>0 and foot.y>rect.position.y+1: fail("jump_descending_below_target/"+support_id)
	elif age>20 and player.is_on_floor() and support_id not in supports(): fail("jump_landed_on_wrong_support/"+support_id)

func drive_cache() -> void:
	if not cache_pending:
		_reward_before = _neutral_reader_snapshot()
		_pointer_start = pointer_events.size(); _modal_start = modal_frames.size()
	if cache_claimed and duplicate_tick < 0 and not app.reward_modal.opened:
		_duplicate_neutral_before = _neutral_reader_snapshot()
	super.drive_cache()
	if duplicate_checked and not _reward_recorded:
		var after := _neutral_reader_snapshot()
		for key: String in ["claimed","items","coins","notes"]:
			if _duplicate_neutral_before.get(key) != after.get(key):
				fail("v16_duplicate_reward_changed_resources"); return
		_reward_transactions.append({"claim_id":claim_local_id,"edge_id":str(itinerary[leg_index].edge_id),"leg":leg_index,"tick":tick,"before":_reward_before.duplicate(true),"after":after,"duplicate_before":_duplicate_neutral_before.duplicate(true),"duplicate_after":after,"pointer_events":pointer_events.slice(_pointer_start).duplicate(true),"modal_frames":modal_frames.slice(_modal_start).duplicate(true)})
		_reward_recorded = true

func complete_leg() -> void:
	var has_claim: bool = leg_index < itinerary.size() and bool(itinerary[leg_index].get("claim_before_edge",false))
	if has_claim and (not cache_claimed or not duplicate_checked or not _reward_recorded):
		fail("v16_claim_edge_completed_without_real_reward"); return
	super.complete_leg()
	if has_claim:
		cache_pending = false; cache_claimed = false; duplicate_checked = false; _reward_recorded = false
		duplicate_tick = -1; modal_age = 0; modal_button = null
		claim_before = {}; claim_after = {}; duplicate_before = {}; duplicate_after = {}

func observe() -> void:
	var before := frames.size()
	super.observe()
	if frames.size() == before: return
	var size := (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
	frames[-1].body = [player.global_position.x-size.x*.5, player.global_position.y-size.y*.5, size.x, size.y]
	frames[-1].hook_start = pair(controller.traversal.hook_start)
	frames[-1].hook_tip = pair(controller.traversal.hook_tip)
	frames[-1].shot_energy_delay = controller.shot_energy._delay
	frames[-1].burst_remaining = player.recoil_burst_remaining
	frames[-1].burst_velocity = pair(player.recoil_velocity)
	for index: int in frames[-1].enemies.size():
		var row: Dictionary = stage.enemy_manifest[index]
		if str(row.get("behavior_id","")) != "forest_swing_pod": continue
		var actor: EnemyActor = stage.enemies[index].get_node("Actor") as EnemyActor
		frames[-1].enemies[index].merge(_pod_sample(actor))
		frames[-1].enemies[index].geometry_instance = str(row.get("geometry_instance",""))
		frames[-1].enemies[index].authored_slot_id = str(row.get("authored_slot_id",""))
	frames[-1].pending_air_grants = controller.received_resource_grants.map(func(grant: Dictionary) -> Dictionary: return {"amount":int(grant.amount),"session_id":int(grant.session_id)})

func snapshot() -> Dictionary:
	var data := super.snapshot()
	if data.is_empty(): return data
	data.grounded = player.is_on_floor()
	data.hook_used = controller.traversal.hook_used
	data.shot_energy_delay = controller.shot_energy._delay
	data.shot_economy = {"owner_id":player.get_instance_id(),"session_id":controller.session_id,"weapon_epoch":controller.shoot_ability.weapon_epoch,"hits":controller.shot_energy._hits.duplicate(true),"combat_packets":controller.combat_energy._packets.duplicate(true)}
	data.pending_air_grants = controller.received_resource_grants.map(func(grant: Dictionary) -> Dictionary: return {"amount":int(grant.amount),"session_id":int(grant.session_id)})
	data.notes = app.meta.snapshot().get("notes",0)
	data.coins = app.wallet.balance
	data.collision_size = pair((player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size)
	return data

func _neutral_reader_snapshot() -> Dictionary:
	return {"claimed":stage.region_state.claimed.duplicate(true),"items":app.build.inventory.item_ids(),"coins":app.wallet.balance,"notes":app.meta.snapshot().get("notes",0),"position":pair(player.global_position),"motion_steps":player.motion_steps}

func _process(delta: float) -> void:
	if initialized and not finished and is_instance_valid(stage):
		var reader := stage.get("discoveries") as ForestBibleDiscoveries
		if cache_claimed and duplicate_tick >= 0 and is_instance_valid(reader) and reader.is_open():
			# Duplicate interaction may offer the co-located story Reader. Use
			# actual Escape input; never call a claim/close implementation hook.
			var before := _neutral_reader_snapshot()
			var was_paused := get_tree().paused
			for pressed: bool in [true,false]:
				var key := InputEventKey.new()
				key.physical_keycode = KEY_ESCAPE; key.keycode = KEY_ESCAPE; key.pressed = pressed
				get_viewport().push_input(key,true)
			var after := _neutral_reader_snapshot()
			event("v16_duplicate_cache_reader_dismissed",{"paused_before":was_paused,"reader_closed":not reader.is_open(),"paused_after":get_tree().paused,"keys":["Escape_press","Escape_release"],"before":before,"after":after})
			if not was_paused or reader.is_open() or get_tree().paused or before != after:
				fail("v16_duplicate_reader_not_neutral")
		if get_tree().paused and not app.reward_modal.opened:
			_unexpected_modal_frames += 1
			if _unexpected_modal_frames > 90: fail("v16_unexpected_modal_frame_budget")
		else: _unexpected_modal_frames = 0
	super._process(delta)

func admission_evidence() -> Dictionary:
	return {"schema":"forest-exploration-runtime-v16","actual_layout":str(manifest.get("layout_version","")),"actual_validated":_actual_validated,"requested_layout_pin":recorded_layout_version,"actual_requested_layout_cleared":is_instance_valid(app) and app._requested_forest_layout.is_empty(),"body_collision_before":pair(_collision_before),"body_collision_after":pair((player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size) if is_instance_valid(player) else [],"world_source_sha256":FileAccess.get_sha256("res://scripts/generation/forest_exploration_world.gd"),"module_source_sha256":FileAccess.get_sha256("res://scripts/generation/forest_exploration_modules.gd"),"strategy":"original_18000_route_1800_edge_Router_Motor_ground_combat_no_injection","legacy_reference_used":false,"reward_transactions":_reward_transactions.duplicate(true)}
