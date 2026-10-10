extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
func _run() -> void:
	await preload("res://tests/recoil_recovery_tests.gd").new().run(self, check)
	if "--intentional-failure" in OS.get_cmdline_user_args():
		check(false, "intentional failure verifies runner exit")
	print("RECOIL RECOVERY: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures > 0 else 0)
