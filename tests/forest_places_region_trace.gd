extends "res://tests/forest_bible_world_trace.gd"
## New-version consumer; the old v15 route corpus and its reader stay explicit.
func canopy_layout() -> bool:
	return manifest.get("layout_version")=="forest-exploration-places-v18" or super.canopy_layout()

func interwoven_layout() -> bool:
	return manifest.get("layout_version")=="forest-exploration-places-v18" or super.interwoven_layout()

func woven_layout() -> bool:
	return manifest.get("layout_version")=="forest-exploration-places-v18" or super.woven_layout()

func begin() -> void:
	stop_after_legs = 10000
	await super.begin()
	air_chain_case = preload("res://tests/forest_places_air_case.gd").new()
	if not initialized or not failures.is_empty(): return
	if manifest.get("layout_version")!="forest-exploration-places-v18" or not ThornForestRegionGenerator.new().validate(manifest,player.tuning):
		fail("places_formal_identity_or_manifest_rejected")

func admission_evidence() -> Dictionary:
	return {"scope":"new_v18_actual_App_input_not_historical_corpus_or_FUN","source_layout":str(manifest.get("layout_version","")),"actual_validated":ThornForestRegionGenerator.new().validate(manifest,player.tuning)}

func release_jump_after_clearance(support_id: String) -> void:
	var leg: Dictionary = itinerary[leg_index]
	var same_surface := str(leg.get("from_support_id","")) == support_id
	if not same_surface or not bool(leg.get("hold_to_receiver",false)) or not support_id.begins_with("places_"):
		super.release_jump_after_clearance(support_id)
		return
	# Crossing a thorn patch on the SAME root is not already horizontally
	# clear merely because the body is above that broad root. Keep the real
	# held jump until the receiving side, just as the local place pilot does.
	var target := platform(support_id)
	if target.is_empty(): fail("jump_target_support_missing/"+support_id); return
	var rect := Rect2(target.rect[0],target.rect[1],target.rect[2],target.rect[3])
	var foot := player.global_position+Vector2(0,18)
	var full_x := player.global_position.x-12>=rect.position.x-.1 and player.global_position.x+12<=rect.end.x+.1
	var receiver := point(leg.landing)
	if not jump_released and age>=int(ceil(player.tuning.jump_hold_duration*Engine.physics_ticks_per_second)) and foot.y<=rect.position.y-1 and full_x and absf(player.global_position.x-receiver.x)<=12.0:
		event("same_root_receiving_side_jump_release",{"support_id":support_id,"foot":pair(foot),"receiver":pair(receiver)})
		jump(false); jump_released = true
	if age>120: fail("bounded_jump_clearance_timeout/"+support_id); return
	if age>3:
		for index: int in player.get_slide_collision_count():
			if player.get_slide_collision(index).get_normal().y>.7 and not full_support(support_id):
				fail("jump_ceiling_blocked/"+support_id); return
	if age>8 and not player.is_on_floor() and player.velocity.y>0 and foot.y>rect.position.y+1:
		fail("jump_descending_below_target/"+support_id)
	elif age>20 and player.is_on_floor() and support_id not in supports():
		fail("jump_landed_on_wrong_support/"+support_id)

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
		if _duplicate_before_full != after: fail("places_duplicate_reward_changed_full_wallet"); return
		var coins := int(after.coins)-int(_reward_before.coins)
		var notes := int(after.notes)-int(_reward_before.notes)
		if claim_local_id == "places_seven_backside_cache" and not ((coins == 4 and notes == 0) or (coins == 0 and notes == 1)):
			fail("places_seven_reward_not_actual_OR_settlement"); return
		reward_transactions.append({"claim_id":claim_local_id,"before":_reward_before.duplicate(true),"after":after,"duplicate_before":_duplicate_before_full.duplicate(true),"duplicate_after":after.duplicate(true),"tick":tick})
		event("places_reward_transaction",reward_transactions[-1])

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
	if not is_instance_valid(actor): fail("places_reverse_weaver_actual_actor_missing"); return true
	if actor.health.terminal:
		if _reverse_weaver_started >= 0:
			event("places_reverse_weaver_terminal",{"actual_shot_requests":_reverse_weaver_shots})
			_reverse_weaver_started = -1
		return false
	if _reverse_weaver_started < 0:
		_reverse_weaver_started = tick
		event("places_reverse_weaver_bank_choice",{"enemy_id":"bible_double_window_weaver","position":pair(player.global_position),"supports":supports()})
	if tick-_reverse_weaver_started > 600: fail("places_reverse_weaver_600_frame_budget"); return true
	var bank := Vector2(1620,1182)
	controller.router.set_move_axis(clampf((bank.x-player.global_position.x)/12.0,-1.0,1.0))
	jump(false)
	if not player.is_on_floor(): fail("places_reverse_weaver_left_grounded_bank"); return true
	if not _aim_kind.is_empty() or controller.shoot_ability.cooldown_remaining > 0.0 or player.recoil_burst_remaining > 0.0 or not at_destination(bank,"bible_weaver_lower"): return true
	_reverse_weaver_shots += 1
	if _reverse_weaver_shots > 12: fail("places_reverse_weaver_12_shot_budget"); return true
	request(&"shoot_release",(actor.motor.global_position-player.global_position).normalized())
	return true

var reward_choice_index := 0
func send_pointer(pressed: bool) -> void:
	if pressed and reward_choice_index != 0:
		var buttons: Array[Button] = []
		for button: Button in app.reward_modal.find_children("*","Button",true,false):
			if button.visible and not button.disabled: buttons.append(button)
		if reward_choice_index < 0 or reward_choice_index >= buttons.size(): fail("places_actual_reward_choice_missing"); return
		modal_button = buttons[reward_choice_index]
		modal_point = modal_button.get_global_rect().get_center()
	super.send_pointer(pressed)
