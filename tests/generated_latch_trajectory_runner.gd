extends "res://tests/branch_library_runner.gd"
## Uses the production latch installer; fixture placement is only the initial spawn.
func _run() -> void:
	var installer_script: Script = load("res://scripts/world/generated_shot_latch_encounter.gd")
	check(installer_script != null and installer_script.can_instantiate(), "production generated latch installer compiles")
	if installer_script == null or not installer_script.can_instantiate():
		quit(1)
		return
	for id: String in ["plains_windchime_lesson", "plains_windchime_well"]:
		for mirrored: bool in [false, true]:
			for combo: bool in ([false, true] if id == "plains_windchime_well" else [false]):
				for angle: float in [-0.05, 0.0, 0.05]:
					await fixture(id, mirrored, 0.0)
					var assembler := RandomStageAssembler.new()
					assembler.modules.append(module)
					world.add_child(assembler)
					var encounter = installer_script.new()
					world.add_child(encounter)
					var lifetime := DemoLifetime.new()
					var manifest := {"nodes": [{"id": "module_00", "module_id": id, "mirrored": mirrored, "reverse_traversal": false}]}
					manifest["shot_latch_plan"] = PlainsShotLatchPlanner.recorded_plan(manifest)
					check(encounter.setup(manifest, assembler, controller, lifetime), "production installer validates versioned authored bell/gate placement")
					await tick(2)
					var latch: ShotLatch = encounter.for_module(module)
					check(latch != null, "production consumer installs the recorded module's latch")
					if latch == null: continue
					var label := "%s mirrored=%s combo=%s angle=%s" % [id, mirrored, combo, angle]
					var driver = load("res://tests/shot_latch_module_driver.gd").new()
					check(await driver.traverse(module, motor, tick, check, latch, combo, angle), label + " actual action route completes")
					await finish(label, module.world_exit(), 1)
	if "--verify-failure" in OS.get_cmdline_user_args(): check(false, "intentional failure probe")
	if is_instance_valid(world): world.free()
	print("GENERATED LATCH TRAJECTORIES: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
