extends "res://tests/forest_bible_world_trace.gd"
## New-version consumer; the old v15 route corpus and its reader stay explicit.
func canopy_layout() -> bool:
	return manifest.get("layout_version")=="forest-varied-bible-v17" or super.canopy_layout()

func interwoven_layout() -> bool:
	return manifest.get("layout_version")=="forest-varied-bible-v17" or super.interwoven_layout()

func woven_layout() -> bool:
	return manifest.get("layout_version")=="forest-varied-bible-v17" or super.woven_layout()

func begin() -> void:
	stop_after_legs = 10000
	await super.begin()
	if not initialized or not failures.is_empty(): return
	if manifest.get("layout_version")!="forest-varied-bible-v17" or not ThornForestRegionGenerator.new().validate(manifest,player.tuning):
		fail("varied_formal_identity_or_manifest_rejected")

func admission_evidence() -> Dictionary:
	return {"scope":"new_v17_actual_App_input_not_historical_corpus_or_FUN","source_layout":str(manifest.get("layout_version","")),"actual_validated":ThornForestRegionGenerator.new().validate(manifest,player.tuning)}

func _physics_process(delta: float) -> void:
	if initialized and not finished and not get_tree().paused and is_instance_valid(player) and is_instance_valid(controller) and app.lifetime.active and leg_index < itinerary.size():
		var leg: Dictionary = itinerary[leg_index]
		if str(leg.get("release_mode","")) == "hang_jump" and (not bool(leg.get("claim_before_edge",false)) or duplicate_checked):
			tick += 1
			age += 1
			before_steps = player.motion_steps
			if tick > 18000 or tick-leg_started > 1800: fail("varied_hang_route_budget"); return
			_drive_fixed_hang_return(leg)
			return
	super._physics_process(delta)

func _drive_fixed_hang_return(leg: Dictionary) -> void:
	var target: Node2D = stage.assembler.hook_targets.get(str(leg.anchor_id))
	if not is_instance_valid(target) or not target is GrappleAnchor or not (target as GrappleAnchor).hang_enabled:
		fail("varied_return_requires_actual_fixed_hanging_fruit"); return
	var source := point(leg.path[0])
	var goal := point(leg.landing)
	if phase == "align":
		jump(false)
		controller.router.set_move_axis(clampf((source.x-player.global_position.x)/12.0,-1.0,1.0))
		stable = stable+1 if at_destination(source,str(leg.from_support_id)) and absf(player.velocity.x)<1.0 else 0
		if stable >= 12:
			event("varied_fixed_return_departure",{"anchor_id":str(leg.anchor_id),"supports":supports()})
			jump(true); set_phase("varied_return_launch")
		return
	if phase == "varied_return_launch":
		controller.router.set_move_axis(0.0)
		if player.is_on_floor() or age < 1: return
		var direction := target.global_position-player.global_position-Vector2(0,-6)
		if direction.length() > controller.traversal.definition.hook_range: fail("varied_return_outside_actual_hook_range"); return
		event("varied_fixed_return_hook_intent",{"anchor_id":str(leg.anchor_id),"target":pair(target.global_position),"distance":direction.length()})
		request(&"grapple",direction.normalized()); jump(false); set_phase("varied_return_contact"); return
	if controller.traversal.state in [&"hook_miss",&"hook_retract"]: fail("varied_return_actual_hook_miss"); return
	if phase == "varied_return_contact":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
		if controller.traversal.state == &"hook_hang":
			jump(false)
			event("varied_fixed_hang_observed",{"anchor_id":str(leg.anchor_id),"target_instance":target.get_instance_id(),"hook_tip":pair(controller.traversal.hook_tip)})
			set_phase("varied_return_hang_jump")
		return
	if phase == "varied_return_hang_jump":
		if controller.traversal.state != &"hook_hang": fail("varied_hang_lost_before_jump"); return
		event("varied_fixed_hang_jump_intent",{"anchor_id":str(leg.anchor_id),"target_instance":target.get_instance_id()})
		jump(true); set_phase("varied_return_receive"); return
	controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
	release_jump_after_clearance(str(leg.landing_support_id))
	stable = stable+1 if at_destination(goal,str(leg.landing_support_id)) else 0
	if stable >= 12: complete_leg()

func drive_hollow(leg: Dictionary) -> void:
	if str(leg.get("geometry_instance","")) != "varied_double_window" or str(leg.kind) != "hollow_outer_recovery":
		super.drive_hollow(leg); return
	# Mirror the legal old lower-window input, using the actual mirrored anchor
	# and receiving root. No mirrored actor coordinates or Motor writes.
	var row := instance(leg)
	var start := local_point(row,row.local_geometry.nodes.R.position)
	var goal := point(leg.landing)
	var entry := mapped_support(row,"outer_root")
	var receiver := str(leg.landing_support_id)
	var target: Node2D = stage.assembler.hook_targets.get(str(row.anchor_id_map.lower_window_ring))
	if not is_instance_valid(target): fail("varied_lower_window_anchor_missing"); return
	if age > 360: fail("varied_lower_window_bounded_phase/"+phase); return
	if phase == "align":
		controller.router.set_move_axis(clampf((start.x-player.global_position.x)/12.0,-1.0,1.0))
		stable = stable+1 if at_destination(start,entry) else 0
		if stable >= 12: set_phase("varied_lower_takeoff")
	elif phase == "varied_lower_takeoff":
		var takeoff := point(leg.path[1])
		controller.router.set_move_axis(clampf((takeoff.x-player.global_position.x)/12.0,-1.0,1.0))
		if at_destination(takeoff,entry): jump(true); set_phase("varied_lower_launch")
	elif phase == "varied_lower_launch":
		controller.router.set_move_axis(1.0)
		var offset := target.global_position-player.global_position-Vector2(0,-6)
		if player.global_position.x >= point(row.translation).x-340 and player.global_position.y <= point(row.translation).y+220 and offset.length()<=controller.traversal.definition.hook_range:
			jump(false); hook(str(row.anchor_id_map.lower_window_ring)); set_phase("varied_lower_hook")
		elif age > 30: fail("varied_lower_window_launch_range_missed")
	elif phase == "varied_lower_hook":
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]: fail("varied_lower_window_actual_H_miss"); return
		controller.router.set_move_axis(0)
		if controller.traversal.state == &"free" and last_hook == "free" and age > 12:
			request(&"shoot_release",Vector2.LEFT); set_phase("varied_lower_receive")
	elif phase == "varied_lower_receive":
		controller.router.set_move_axis(clampf((goal.x-player.global_position.x)/12.0,-1.0,1.0))
		stable = stable+1 if at_destination(goal,receiver) else 0
		if stable >= 12: complete_leg()

var reward_transactions: Array[Dictionary] = []
var _reward_before: Dictionary = {}
var _duplicate_before_full: Dictionary = {}

func reward_snapshot() -> Dictionary:
	return {"claimed":stage.region_state.claimed.duplicate(true),"items":app.build.item_ids(),"coins":app.wallet.balance,"notes":app.meta.snapshot().get("notes",0)}

func drive_cache() -> void:
	if not cache_pending: _reward_before = reward_snapshot()
	if cache_claimed and duplicate_tick < 0 and not app.reward_modal.opened: _duplicate_before_full = reward_snapshot()
	super.drive_cache()
	if duplicate_checked and reward_transactions.is_empty():
		var after := reward_snapshot()
		if _duplicate_before_full != after: fail("varied_duplicate_reward_changed_full_wallet"); return
		var coins := int(after.coins)-int(_reward_before.coins)
		var notes := int(after.notes)-int(_reward_before.notes)
		if claim_local_id == "varied_l_elbow_cache" and not ((coins == 4 and notes == 0) or (coins == 0 and notes == 1)):
			fail("varied_L_reward_not_actual_OR_settlement"); return
		reward_transactions.append({"claim_id":claim_local_id,"before":_reward_before.duplicate(true),"after":after,"duplicate_before":_duplicate_before_full.duplicate(true),"duplicate_after":after.duplicate(true),"tick":tick})
		event("varied_reward_transaction",reward_transactions[-1])

func observe() -> void:
	var before := frames.size()
	super.observe()
	if frames.size() == before: return
	var size := (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size
	frames[-1].body = [player.global_position.x-size.x*.5,player.global_position.y-size.y*.5,size.x,size.y]
	frames[-1].hook_start = pair(controller.traversal.hook_start)
	frames[-1].hook_tip = pair(controller.traversal.hook_tip)

var _reverse_weaver_started := -1
var _reverse_weaver_shots := 0
func _drive_bible_weaver_clearance(leg: Dictionary) -> bool:
	if str(leg.get("edge_id","")) != "bible_web_lower_cross": return super._drive_bible_weaver_clearance(leg)
	var actor: EnemyActor
	for index: int in stage.enemy_manifest.size():
		if str(stage.enemy_manifest[index].id) == "bible_double_window_weaver": actor = stage.enemies[index].get_node("Actor") as EnemyActor
	if not is_instance_valid(actor): fail("varied_reverse_weaver_actual_actor_missing"); return true
	if actor.health.terminal:
		if _reverse_weaver_started >= 0:
			event("varied_reverse_weaver_terminal",{"actual_shot_requests":_reverse_weaver_shots})
			_reverse_weaver_started = -1
		return false
	if _reverse_weaver_started < 0:
		_reverse_weaver_started = tick
		event("varied_reverse_weaver_bank_choice",{"enemy_id":"bible_double_window_weaver","position":pair(player.global_position),"supports":supports()})
	if tick-_reverse_weaver_started > 600: fail("varied_reverse_weaver_600_frame_budget"); return true
	var bank := Vector2(1620,1182)
	controller.router.set_move_axis(clampf((bank.x-player.global_position.x)/12.0,-1.0,1.0))
	jump(false)
	if not player.is_on_floor(): fail("varied_reverse_weaver_left_grounded_bank"); return true
	if not _aim_kind.is_empty() or controller.shoot_ability.cooldown_remaining > 0.0 or player.recoil_burst_remaining > 0.0 or not at_destination(bank,"bible_weaver_lower"): return true
	_reverse_weaver_shots += 1
	if _reverse_weaver_shots > 12: fail("varied_reverse_weaver_12_shot_budget"); return true
	request(&"shoot_release",(actor.motor.global_position-player.global_position).normalized())
	return true

var reward_choice_index := 0
func send_pointer(pressed: bool) -> void:
	if pressed and reward_choice_index != 0:
		var buttons: Array[Button] = []
		for button: Button in app.reward_modal.find_children("*","Button",true,false):
			if button.visible and not button.disabled: buttons.append(button)
		if reward_choice_index < 0 or reward_choice_index >= buttons.size(): fail("varied_actual_reward_choice_missing"); return
		modal_button = buttons[reward_choice_index]
		modal_point = modal_button.get_global_rect().get_center()
	super.send_pointer(pressed)
