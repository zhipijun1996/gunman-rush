extends SceneTree
## Frozen historical H-only route, not coverage of the default short grapple.
## Real normal physics; negative cases change actual nodes/capabilities.
const CONSUMER := preload("res://scripts/demo/thorn_forest_h_slice.gd")
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")
const HISTORICAL_TRAVERSAL := preload("res://tests/fixtures/forest_h_legacy_traversal.tres")

class HistoricalConsumer extends "res://scripts/demo/thorn_forest_h_slice.gd":
	func _ready() -> void:
		super._ready()
		# Before the first physics tick only; preserve the original route geometry,
		# Router driver, Motor, abilities and all historical route assertions.
		controller.traversal.definition = HISTORICAL_TRAVERSAL
		initial_snapshot = capture_capability_snapshot()

	func capture_capability_snapshot() -> Dictionary:
		var value: Dictionary = super.capture_capability_snapshot()
		var definition: TraversalDefinition = controller.traversal.definition
		var actual_hash := FileAccess.get_sha256(definition.resource_path)
		# SNAPSHOT normally reports the production default. This fixture must name
		# the resource actually consumed rather than impersonating that default.
		value["config_hashes"]["traversal"] = actual_hash
		value["traversal_definition"] = {"resource_path": definition.resource_path,
			"sha256": actual_hash, "scope": "frozen_historical_H_only_route",
			"hook_range": definition.hook_range, "hook_kick": SNAPSHOT.pair(definition.hook_kick),
			"hook_launch_seconds": definition.hook_launch_seconds,
			"contact_settlement_phase": "post_motor"}
		return value

var assertions := 0
var failures: Array[String] = []
var variant := "positive"
var output := ""
var source_commit := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--case="): variant = arg.trim_prefix("--case=")
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--source-commit="): source_commit = arg.trim_prefix("--source-commit=")
	run.call_deferred()

func verify(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func run() -> void:
	var world = HistoricalConsumer.new()
	world.include_anchor = variant != "missing-anchor"
	world.grant_hook = variant != "no-hook"
	root.add_child(world)
	while not world.finished:
		await process_frame
	var actor: PlayerController = world.controller
	var start: Dictionary = world.initial_snapshot
	var finish: Dictionary = world.capture_capability_snapshot()
	verify(start.traversal_definition.resource_path == HISTORICAL_TRAVERSAL.resource_path
		and start.traversal_definition.sha256 == FileAccess.get_sha256(HISTORICAL_TRAVERSAL.resource_path), "actual_frozen_historical_traversal_binding")
	verify(start.traversal_definition == finish.traversal_definition, "historical_traversal_unchanged_during_route")
	verify(actor.is_physics_processing(), "normal_controller_physics_enabled")
	verify(SNAPSHOT.matches_tuning(actor, PlayerTuning.load_default()), "unchanged_default_tuning")
	verify(start.granted_actions == ["jump", "shot_recoil", "grapple"], "H_only_entry_capability")
	verify(not actor.traversal.wall_enabled and not actor.traversal.double_enabled, "no_W_D_grant")
	verify(start.equipped_weapon.id == "pulse_gun" and start.equipped_weapon.tier == 1 and finish.equipped_weapon.id == "pulse_gun", "one_current_PulseLv1")
	verify(world.requests.size() == 1 and world.requests[0].queued, "actual_router_H_request_queued")
	var kinds: Array[String] = []
	for event: Dictionary in world.events:
		kinds.append(String(event.kind))
	for state: String in ["hook_cast", "hook_fly", "hook_pull", "hook_contact_kick", "hook_kick"]:
		verify(state in kinds, "accepted_" + state)
	var last_tick := 0
	for frame: Dictionary in world.frames:
		verify(int(frame.tick) == last_tick + 1 and int(frame.motor_steps_this_tick) == 1, "continuous_single_Motor_step_%s" % frame.tick)
		last_tick = int(frame.tick)
	verify(world.branch_landed, "whole_body_stable_branch_landing")
	verify(world.returned, "continuous_safe_return_to_entry")
	verify(start.shot_energy.current == finish.shot_energy.current and start.shot_energy.capacity == finish.shot_energy.capacity, "no_resource_refill_needed")
	verify(start.config_hashes == finish.config_hashes and start.tuning == finish.tuning, "configuration_unchanged_during_route")
	verify(start.effective_max_jumps == 1 and finish.effective_max_jumps == 1, "no_extra_jump")
	var abilities: Array[String] = []
	if "grapple" in start.granted_actions: abilities.append("H")
	if "wall_climb" in start.granted_actions: abilities.append("W")
	if "double_jump" in start.granted_actions: abilities.append("D")
	var data := {"schema_version": 1, "artifact_kind": "region_production_capture", "region_id": "thorn_forest",
		"proof_kind": "golden", "scope": "actual_region_prototype", "consumer": "scripts/demo/thorn_forest_h_slice.gd",
		"source_commit": source_commit, "engine": Engine.get_version_info().string,
		"case": variant, "assertions": assertions, "failures": failures,
		"body_size": SNAPSHOT.pair(world.body_size),
		"capability_snapshot": {"abilities": abilities, "equipped_weapon": String(start.equipped_weapon.id), "current_weapon_count": 1, "raw": start},
		"final_capability_snapshot": finish, "observations": world.frames, "events": world.events, "input_requests": world.requests,
		"entry": {"spawn": SNAPSHOT.pair(CONSUMER.SPAWN), "scope": "development_initialization_only"},
		"geometry": {"root": [CONSUMER.ROOT_RECT.position.x, CONSUMER.ROOT_RECT.position.y, CONSUMER.ROOT_RECT.size.x, CONSUMER.ROOT_RECT.size.y],
			"branch": [CONSUMER.BRANCH_RECT.position.x, CONSUMER.BRANCH_RECT.position.y, CONSUMER.BRANCH_RECT.size.x, CONSUMER.BRANCH_RECT.size.y],
			"anchor_present": world.include_anchor, "anchor": SNAPSHOT.pair(CONSUMER.ANCHOR_POINT)},
		"historical_fixture": {"scope": "frozen_historical_H_only_route", "default_short_hook_covered": false,
			"traversal_definition_path": start.traversal_definition.resource_path,
			"traversal_definition_sha256": start.traversal_definition.sha256},
		"captured_scope": {"normal_controller_physics": true, "manual_motor_or_controller_step": false, "midroute_position_or_resource_injection": false,
			"formal_region_opened": false, "formal_H_grant": false, "visual_acceptance": "unverified"},
		"branch_landed": world.branch_landed, "returned": world.returned}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not write native capture")
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("REGION PRODUCTION: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)
