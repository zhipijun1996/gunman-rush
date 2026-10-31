extends SceneTree
## Actual current-default short H + recoil and landing recovery, development only.
## Real normal physics; negative cases change actual nodes/capabilities.
const CONSUMER_PATH := "res://game/world/levels/providers/thorn_forest_current_slice.gd"
const SNAPSHOT := preload("res://tools/level_capability_snapshot.gd")

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
	var consumer_script: Script = load(CONSUMER_PATH)
	var world = consumer_script.new()
	world.include_anchor = variant != "missing-anchor"
	world.grant_hook = variant != "no-hook"
	root.add_child(world)
	while not world.finished:
		await process_frame
	var actor: PlayerController = world.controller
	var start: Dictionary = world.initial_snapshot
	var finish: Dictionary = world.capture_capability_snapshot()
	verify(start.traversal_definition.resource_path == "res://resources/player/traversal.tres"
		and start.traversal_definition.sha256 == FileAccess.get_sha256("res://resources/player/traversal.tres"), "actual_current_default_traversal_binding")
	verify(start.traversal_definition == finish.traversal_definition, "current_default_traversal_unchanged_during_route")
	verify(actor.is_physics_processing(), "normal_controller_physics_enabled")
	verify(SNAPSHOT.matches_tuning(actor, PlayerTuning.load_default()), "unchanged_default_tuning")
	verify(start.granted_actions == ["jump", "shot_recoil", "grapple"], "H_only_entry_capability")
	verify(not actor.traversal.wall_enabled and not actor.traversal.double_enabled, "no_W_D_grant")
	verify(start.equipped_weapon.id == "pulse_gun" and start.equipped_weapon.tier == 1 and finish.equipped_weapon.id == "pulse_gun", "one_current_PulseLv1")
	verify(world.requests.any(func(r: Dictionary): return r.kind=="grapple" and r.queued), "actual_router_H_request_queued")
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
	verify("accepted_recoil_shot" in kinds, "actual_accepted_shot_recoil_after_H_landing")
	var spent := false
	var recovered := false
	var lowest: float = start.shot_energy.current
	for sample: Dictionary in world.frames:
		if float(sample.energy) < lowest:
			lowest = sample.energy
			spent = true
		if spent and sample.grounded and float(sample.energy) > lowest: recovered = true
	verify(spent and recovered, "real_shot_consumption_and_ground_recovery")
	verify(start.health.current == finish.health.current, "no_damage_or_health_injection")
	verify(start.config_hashes == finish.config_hashes and start.tuning == finish.tuning, "configuration_unchanged_during_route")
	verify(start.effective_max_jumps == 1 and finish.effective_max_jumps == 1, "no_extra_jump")
	var abilities: Array[String] = []
	if "grapple" in start.granted_actions: abilities.append("H")
	if "wall_climb" in start.granted_actions: abilities.append("W")
	if "double_jump" in start.granted_actions: abilities.append("D")
	var data := {"schema_version": 1, "artifact_kind": "region_production_capture", "region_id": "thorn_forest",
		"proof_kind": "technical_sample", "scope": "actual_region_prototype", "consumer": "game/world/levels/providers/thorn_forest_current_slice.gd",
		"source_commit": source_commit, "engine": Engine.get_version_info().string,
		"case": variant, "assertions": assertions, "failures": failures,
		"body_size": SNAPSHOT.pair(world.body_size),
		"capability_snapshot": {"abilities": abilities, "equipped_weapon": String(start.equipped_weapon.id), "current_weapon_count": 1, "raw": start},
		"final_capability_snapshot": finish, "observations": world.frames, "events": world.events, "input_requests": world.requests,
		"entry": {"spawn": SNAPSHOT.pair(world.layout().spawn), "scope": "development_initialization_only"},
		"geometry": {"root": [world.layout().root.position.x, world.layout().root.position.y, world.layout().root.size.x, world.layout().root.size.y],
			"branch": [world.layout().branch.position.x, world.layout().branch.position.y, world.layout().branch.size.x, world.layout().branch.size.y],
			"anchor_present": world.include_anchor, "anchor": SNAPSHOT.pair(world.layout().anchor)},
		"current_default_fixture": {"scope": "current_default_H_only_route", "default_short_hook_covered": true,
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
	controller_cleanup(actor)
	var released: WeakRef = weakref(world)
	world.queue_free()
	world = null
	actor = null
	consumer_script = null
	for unused: int in 6: await process_frame
	if released.get_ref() != null: push_error("Current forest world failed actual release")
	print("CURRENT FOREST CLEANUP: released=", released.get_ref() == null)
	print("REGION PRODUCTION: %d assertions, %d failures" % [assertions, failures.size()])
	quit.call_deferred(0 if failures.is_empty() else 1)

func controller_cleanup(actor: PlayerController) -> void:
	actor.router.set_move_axis(0)
	actor.set_physics_process(false)
