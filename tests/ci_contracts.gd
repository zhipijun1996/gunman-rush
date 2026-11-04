extends SceneTree

var failures := 0
var assertions := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _run() -> void:
	# Keep the existing suites intact; broad routes and visual reviews remain manual.
	await preload("res://tests/input_tests.gd").new().run(self, check)
	await preload("res://tests/variable_jump_tests.gd").new().run(self, check)
	await preload("res://tests/resource_tests.gd").new().run(self, check)
	await preload("res://tests/damage_tests.gd").new().run(self, check)
	await preload("res://tests/economy_tests.gd").new().run(self, check)
	print("CI CONTRACTS: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
