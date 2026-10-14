extends SceneTree
## Validate a captured live-runtime artifact. Invoke after the actual capture;
## this shape/observation test does not execute the route or certify completion.
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func verify(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		print("FORMAL CAPTURE TEST FAILURE: ", label)
func run() -> void:
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): path = arg.trim_prefix("--capture=")
	if not FileAccess.file_exists(path):
		verify(false, "capture artifact required")
	else:
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		verify(value is Dictionary, "capture is JSON object")
		if value is Dictionary:
			var data: Dictionary = value
			verify(data.get("artifact_kind") == "formal_level_capture" and data.get("schema_version") == 1, "formal schema")
			verify(data.get("capture_errors", ["missing"]).is_empty(), "no capture errors")
			verify(not data.get("frames", []).is_empty(), "nonempty actual observations")
			var scope: Dictionary = data.get("captured_scope", {})
			for key: String in ["enemies_instantiated", "enemy_attacks_enabled", "enemy_contacts_enabled", "environment_damage_enabled", "production_rewards_enabled", "production_camera_enabled"]:
				verify(scope.get(key, false) == true, "formal subsystem: " + key)
			for key: String in ["controller_manual_step", "actor_teleport_by_driver", "resource_injection", "enemy_disable"]:
				verify(scope.get(key, true) == false, "no observation bypass: " + key)
			verify(data.get("manifest_hash", "") == data.get("manifest", {}).get("manifest_hash", "missing"), "manifest identity")
			verify(data.get("initial_runtime", {}).get("enemy_count", 0) > 0, "actual enemies present")
			verify(not data.get("initial_runtime", {}).get("camera", {}).is_empty(), "actual camera captured")
			var initial: Dictionary = data.get("initial_capability", {})
			verify(initial.get("equipped_weapon", {}).get("id", "") == "pulse_gun", "formal baseline single equipped weapon")
			verify(not initial.get("granted_actions", []).has("grapple"), "future formal grant not injected")
			var last_controller_tick := -1
			for frame: Dictionary in data.get("frames", []):
				verify(frame.has("input_requests") and frame.has("accepted_events") and frame.has("health") and frame.has("collisions"), "requests distinct from observed events/resources/collision")
				var controller_tick := int(frame.get("controller_tick", -1))
				verify(controller_tick >= last_controller_tick and controller_tick <= last_controller_tick + 1 if last_controller_tick >= 0 else controller_tick >= 0, "normal controller advances at most once per frame; paused modal may not advance")
				last_controller_tick = controller_tick
			var died := false
			for event: Dictionary in data.get("events", []):
				if event.get("kind") == "died": died = true
			if died:
				verify(data.get("route_reached") == false and str(data.get("outcome", "")).begins_with("run_ended/"), "actual death is not passing traversal")
	print("LEVEL FORMAL CAPTURE TESTS: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
