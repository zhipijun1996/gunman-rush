extends SceneTree
var fail := 0
func ck(ok:bool, label:String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: fail += 1
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["write", "read"]:
		printerr("Run check_player_settings_restart() with its isolated data directory")
		quit(1)
		return
	var write := args[0] == "write"
	var path := OS.get_user_data_dir()
	var data_home := args[1].simplify_path()
	ck(data_home.get_file().begins_with("gunman-settings-restart-") and path.begins_with(data_home + "/"), "isolated native data directory")
	if fail:
		quit(1)
		return
	if write:
		var old_dir := path.get_base_dir().path_join("Gunman Rush")
		DirAccess.make_dir_recursive_absolute(old_dir)
		var old := WorldSettings.new()
		old.open(old_dir.path_join("player_settings_v1.json"), WorldSettings.PROFILE)
		var c := old.value.duplicate(true)
		c.volume = .4
		ck(old.save(c), "legacy application folder holds checked old-format preference")
	var shell := (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate() as WorldShell
	root.add_child(shell)
	await process_frame
	ck(shell.page == &"title", "default scene opens title")
	shell.open_settings()
	var view := shell.subpage as WorldSettingsView
	if write:
		ck(is_equal_approx(view.volume.value,.4) and view.preferences.revision==1, "first boot imports checked legacy native settings from original folder")
		view.volume.value = .25
		view.reduced.button_pressed = true
		view.movement.select(2)
		view.save_draft()
		ck(shell.page == &"title" and shell.page_host.get_node("TitleBackdrop").reduced_effects, "save applies title's reduced animation and returns to title")
		shell.request_new_game()
	else:
		ck(is_equal_approx(view.volume.value,.25) and view.reduced.button_pressed and view.movement.selected==2 and view.preferences.revision==2, "second process restores edited preferences and no duplicate legacy import")
		shell.handle_back()
		shell.continue_game()
	ck(shell.page == &"play" and shell.world != null, "world enters normally")
	if shell.world != null:
		var session := shell.world.active
		ck(is_equal_approx(AudioServer.get_bus_volume_db(0),linear_to_db(.25)) and session.camera.reduced_effects and session.controller.router.profile.values.touch_move_mode=="analog", "real session inherits Master gain, camera and physical input profile")
		for i in 180: await physics_frame
		shell.open_pause()
		shell.open_settings()
		var pause_view := shell.subpage as WorldSettingsView
		pause_view.open_calibration()
		shell.handle_back()
		ck(shell.page==&"settings" and pause_view.calibration_modal == null, "system return from calibration preserves paused settings draft")
		shell.handle_back()
		ck(await session.audio_service.shutdown(), "room audio releases before returning to title")
		shell.return_title()
		ck(shell.page == &"title" and shell.world == null and shell.page_host.get_node("TitleBackdrop").reduced_effects, "save and return to title retains reduced presentation")
	ck(await preload("world_audio_cleanup.gd").drain(shell), "title audio releases before process restart")
	shell.free()
	print("SETTINGS RESTART failures=",fail)
	quit(1 if fail else 0)
