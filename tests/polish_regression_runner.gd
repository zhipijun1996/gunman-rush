extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	for test in [preload("res://tests/menu_tests.gd").new(), preload("res://tests/dynamic_lab_tests.gd").new(), preload("res://tests/boss_approach_lab_tests.gd").new(), preload("res://tests/random_preview_tests.gd").new()]:
		await test.run(self, check)
	print("POLISH REGRESSION: %s assertions, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
