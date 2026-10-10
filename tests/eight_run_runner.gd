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
	await preload("res://tests/run_loop_tests.gd").new().run(self, check)
	await preload("res://tests/ten_route_tests.gd").new().run(self, check)
	if "--failure-probe" in OS.get_cmdline_user_args():
		check(false, "intentional failure confirms the runner returns nonzero")
	print("EIGHT RUN: %s assertions, %s failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
