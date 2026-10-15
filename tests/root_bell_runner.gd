extends SceneTree
var assertions := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		print("ROOT BELL FAILURE: ", label)
func run() -> void:
	var output_dir := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output_dir = argument.trim_prefix("--output-dir=")
	if output_dir.is_empty(): output_dir = "res://build/root_bell/direct/%s-%s" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	if not output_dir.begins_with("res://build/root_bell/") or output_dir.contains(".."):
		push_error("Root bell output must be a new build/root_bell child")
		quit(1)
		return
	var mode := "movie" if "--showcase" in OS.get_cmdline_user_args() else "technical"
	var marker := output_dir + "/" + mode + "_producer_started.json"
	if FileAccess.file_exists(marker) or FileAccess.file_exists(output_dir + ("/showcase.json" if mode == "movie" else "/capture.json")):
		push_error("Root bell native producer refuses existing output; original bytes retained")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	var lease := FileAccess.open(marker, FileAccess.WRITE)
	lease.store_string(JSON.stringify({"mode": mode, "started_epoch": Time.get_unix_time_from_system()}))
	lease.close()
	var suite := preload("res://tests/root_bell_tests.gd").new()
	suite.output_dir = output_dir
	if "--showcase" in OS.get_cmdline_user_args(): await suite.showcase(self, check)
	else: await suite.run(self, check)
	print("ROOT BELL: %s assertions, %s failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
