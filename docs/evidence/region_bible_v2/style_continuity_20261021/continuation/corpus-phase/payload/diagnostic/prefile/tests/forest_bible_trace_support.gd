extends RefCounted
## Shared v15-only hooks act on the actual inherited Router trace and DemoApp.
## Historical traces and every physics/resource/strategy assertion stay inherited.
const LAYOUT := "forest-bible-world-v15"
const STATE := &"forest_bible_trace_support"
class GrovePilot extends "res://tests/forest_depth_grove_combat_case.gd":
	func drive(trace: Node,leg: Dictionary) -> bool:
		# A specialist owns only its declared comparison encounter. Ordinary
		# prefix combat and every inherited combat limit remain unchanged.
		if trace.has_method("owns_strategy_encounter") and trace.owns_strategy_encounter(leg):return false
		return super.drive(trace,leg)
	func _eligible_target(trace: Node,row: Dictionary,actor: EnemyActor) -> bool:
		# Reserve the specialist's exact live subject, including earlier legs;
		# every other enemy still uses the original acquisition and combat.
		if trace.has_method("preserves_strategy_target") and trace.preserves_strategy_target(str(row.id)):return false
		return super._eligible_target(trace,row,actor)
	func supports_layout(layout: String) -> bool:
		return layout=="forest-bible-world-v15" or super.supports_layout(layout)
	func _raised_body_aim(trace: Node) -> Vector2:
		# The ordinary pointer adapter aims from the actual barrel. A center-ray
		# clearance can disagree after a raised enemy's real hurt knockback.
		var adapter := trace.player.get_node("KeyboardMouseAdapter") as KeyboardMouseAdapter
		var visual := trace.player.get_node("CourierVisual") as CourierVisual
		var half: Vector2=target.definition.collision_size*.5
		for offset: float in [0.0,-half.y*.4,half.y*.4]:
			var body_point: Vector2=target.motor.global_position+Vector2(0,offset)
			var screen_point: Vector2=trace.player.get_canvas_transform()*body_point
			var unit: Vector2=adapter.world_direction(screen_point)
			if not _direction_hits_body(trace,unit):continue
			var muzzle: Vector2=visual.visible_muzzle_position()
			if not _circle_clear(trace,trace.player.global_position,muzzle-trace.player.global_position):continue
			if not _circle_clear(trace,muzzle,body_point-muzzle):continue
			return unit
		return Vector2.ZERO
	func _circle_clear(trace: Node,origin: Vector2,motion: Vector2) -> bool:
		var shape := CircleShape2D.new()
		shape.radius=trace.player.tuning.projectile_radius
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=shape;query.transform=Transform2D(0,origin)
		query.collision_mask=1;query.exclude=[trace.player.get_rid()]
		var space: PhysicsDirectSpaceState2D=trace.player.get_world_2d().direct_space_state
		if not space.intersect_shape(query).is_empty():return false
		query.motion=motion
		var fractions: PackedFloat32Array=space.cast_motion(query)
		return fractions.size()==2 and fractions[0]>=1.0
class CrownPilot extends "res://tests/forest_interwoven_crown_combat_case.gd":
	func supports_layout(layout: String) -> bool:
		return layout=="forest-bible-world-v15" or super.supports_layout(layout)

static func qualifies(trace: Node) -> bool:
	return trace.manifest.get("layout_version")==LAYOUT

static func install(trace: Node) -> void:
	trace.grove_combat_case=GrovePilot.new()
	trace.interwoven_crown_case=CrownPilot.new()
	trace.set_meta(STATE,{"actual_validated":false,"reference_validated":false,"reference_manifest":{},"unexpected_modal_frames":0})

static func bind(trace: Node) -> void:
	if not trace.initialized or not trace.failures.is_empty():return
	var selected: String=trace.recorded_layout_version if not trace.recorded_layout_version.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	if selected!=LAYOUT or not qualifies(trace):
		trace.fail("Bible_auto_requires_actual_explicit_v15");return
	var registry := ThornForestRegionGenerator.new()
	var reference := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,str(trace.manifest.seed),trace.player.tuning,trace.map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-fruit-routes-v14"})
	if not reference.get("ok",false):trace.fail("Bible_auto_v14_reference_generation_failed");return
	var state: Dictionary=trace.get_meta(STATE)
	state.reference_manifest=reference.manifest.duplicate(true)
	state.actual_validated=registry.validate(trace.manifest,trace.player.tuning)
	state.reference_validated=registry.validate(state.reference_manifest,trace.player.tuning)
	if not state.actual_validated or not state.reference_validated:trace.fail("Bible_auto_strict_manifest_rejected")
	trace.controller.shoot_ability.projectile_impacted.connect(func(at: Vector2,unit: Vector2) -> void:
		trace.event("v15_actual_projectile_impact",{"impact_position":trace.pair(at),"direction":trace.pair(unit)}))

static func observe_actual_projectile(trace: Node,serial: int) -> void:
	trace.event("v15_actual_projectile_muzzle",{"serial":serial,"muzzle":trace.pair(trace.controller.shoot_ability.last_muzzle),"body_origin":trace.pair(trace.player.global_position)})

static func process_reader(trace: Node) -> void:
	if not trace.initialized or trace.finished or not is_instance_valid(trace.app) or not is_instance_valid(trace.stage):return
	var reader := trace.stage.get("discoveries") as ForestBibleDiscoveries
	if trace.cache_claimed and trace.duplicate_tick>=0 and is_instance_valid(reader) and reader.is_open():
		# The old cache's ordinary duplicate interact can offer a discovery.
		# Real input closes it before the inherited eight-tick transaction check.
		var before := duplicate_reader_snapshot(trace)
		var reader_id := str(reader.get("_current"))
		var page := reader.get("_root") as Control
		var visible: bool=is_instance_valid(page) and page.is_visible_in_tree()
		var was_paused: bool=trace.get_tree().paused
		for pressed: bool in [true,false]:
			var key := InputEventKey.new()
			key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=pressed
			trace.get_viewport().push_input(key,true)
		var after := duplicate_reader_snapshot(trace)
		trace.event("v15_duplicate_cache_reader_dismissed",{"reader_id":reader_id,"visible_before":visible,"paused_before":was_paused,"reader_closed":not reader.is_open(),"paused_after":trace.get_tree().paused,"keys":["Escape_press","Escape_release"],"before":before,"after":after})
		if not visible or not was_paused or reader.is_open() or trace.get_tree().paused or before!=after:
			trace.fail("v15_duplicate_cache_reader_not_neutral")
	var state: Dictionary=trace.get_meta(STATE)
	if trace.get_tree().paused and not trace.app.reward_modal.opened:
		state.unexpected_modal_frames+=1
		if state.unexpected_modal_frames>90:trace.fail("v15_unexpected_modal_process_frame_budget")
	else:state.unexpected_modal_frames=0

static func duplicate_reader_snapshot(trace: Node) -> Dictionary:
	return {"claimed":trace.stage.region_state.claimed.duplicate(true),"items":trace.app.build.item_ids(),"coins":trace.app.wallet.balance,"position":trace.pair(trace.player.global_position),"motion_steps":trace.player.motion_steps}

static func admission_evidence(trace: Node) -> Dictionary:
	var state: Dictionary=trace.get_meta(STATE)
	return {"strategy":"original_fixed_fps_Router_no_human_hold","actual_validated":state.actual_validated,"reference_validated":state.reference_validated,"reference_manifest":state.reference_manifest.duplicate(true)}
