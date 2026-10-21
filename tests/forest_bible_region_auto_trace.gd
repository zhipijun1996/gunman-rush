extends "res://tests/forest_depth_region_trace.gd"
## Explicit v15 admission, retaining the original fixed-fps Router strategy.
## The separate v14 generation is evidence, never a rewritten v15 manifest.
const LAYOUT := "forest-bible-world-v15"
class GrovePilot extends "res://tests/forest_depth_grove_combat_case.gd":
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
var reference_manifest: Dictionary = {}
var actual_validated := false
var reference_validated := false
var unexpected_modal_frames := 0

func canopy_layout() -> bool:
	return manifest.get("layout_version")==LAYOUT or super.canopy_layout()
func interwoven_layout() -> bool:
	return manifest.get("layout_version")==LAYOUT or super.interwoven_layout()
func woven_layout() -> bool:
	return manifest.get("layout_version")==LAYOUT or super.woven_layout()

func begin() -> void:
	grove_combat_case=GrovePilot.new()
	interwoven_crown_case=CrownPilot.new()
	await super.begin()
	if not initialized or not failures.is_empty(): return
	var selected: String=recorded_layout_version if not recorded_layout_version.is_empty() else ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT
	if selected!=LAYOUT or manifest.get("layout_version")!=LAYOUT:
		fail("Bible_auto_requires_actual_explicit_v15");return
	var registry := ThornForestRegionGenerator.new()
	var reference := registry.generate_version(ThornForestRegionGenerator.DEPTH_VERSION,str(manifest.seed),player.tuning,map_index,{"grapple":true,"abilities":["grapple"],"forest_layout_version":"forest-fruit-routes-v14"})
	if not reference.get("ok",false): fail("Bible_auto_v14_reference_generation_failed");return
	reference_manifest=reference.manifest.duplicate(true)
	actual_validated=registry.validate(manifest,player.tuning)
	reference_validated=registry.validate(reference_manifest,player.tuning)
	if not actual_validated or not reference_validated: fail("Bible_auto_strict_manifest_rejected")
	controller.shoot_ability.projectile_impacted.connect(func(at: Vector2,unit: Vector2) -> void:
		event("v15_actual_projectile_impact",{"impact_position":pair(at),"direction":pair(unit)}))

func observe_actual_projectile(serial: int) -> void:
	super.observe_actual_projectile(serial)
	event("v15_actual_projectile_muzzle",{"serial":serial,"muzzle":pair(controller.shoot_ability.last_muzzle),"body_origin":pair(player.global_position)})

func _process(delta: float) -> void:
	if initialized and not finished and is_instance_valid(app) and is_instance_valid(stage):
		var reader := stage.get("discoveries") as ForestBibleDiscoveries
		if cache_claimed and duplicate_tick>=0 and is_instance_valid(reader) and reader.is_open():
			# The same real interact now offers an optional discovery after the
			# old cache is claimed. Dismiss it through ordinary input, then keep
			# the inherited eight-tick duplicate-cache transaction assertion.
			var before := _duplicate_reader_snapshot()
			var reader_id := str(reader.get("_current"))
			var page := reader.get("_root") as Control
			var visible: bool=is_instance_valid(page) and page.is_visible_in_tree()
			var was_paused: bool=get_tree().paused
			for pressed: bool in [true,false]:
				var key := InputEventKey.new()
				key.physical_keycode=KEY_ESCAPE;key.keycode=KEY_ESCAPE;key.pressed=pressed
				get_viewport().push_input(key,true)
			var after := _duplicate_reader_snapshot()
			event("v15_duplicate_cache_reader_dismissed",{"reader_id":reader_id,"visible_before":visible,"paused_before":was_paused,"reader_closed":not reader.is_open(),"paused_after":get_tree().paused,"keys":["Escape_press","Escape_release"],"before":before,"after":after})
			if not visible or not was_paused or reader.is_open() or get_tree().paused or before!=after:
				fail("v15_duplicate_cache_reader_not_neutral")
		if get_tree().paused and not app.reward_modal.opened:
			unexpected_modal_frames+=1
			if unexpected_modal_frames>90:fail("v15_unexpected_modal_process_frame_budget")
		else:unexpected_modal_frames=0
	super._process(delta)

func _duplicate_reader_snapshot() -> Dictionary:
	return {"claimed":stage.region_state.claimed.duplicate(true),"items":app.build.item_ids(),"coins":app.wallet.balance,"position":pair(player.global_position),"motion_steps":player.motion_steps}

func admission_evidence() -> Dictionary:
	return {"strategy":"original_fixed_fps_Router_no_human_hold","actual_validated":actual_validated,"reference_validated":reference_validated,"reference_manifest":reference_manifest.duplicate(true)}
