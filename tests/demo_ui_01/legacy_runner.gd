extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func run() -> void:
	await preload("res://tests/menu_tests.gd").new().run(self, check)
	await preload("res://tests/resource_tests.gd").new().run(self, check)
	print("DEMO UI LEGACY: %s checks, %s failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
