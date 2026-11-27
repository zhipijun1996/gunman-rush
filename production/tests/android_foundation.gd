extends SceneTree
## Drive real raw touch and the same notifications Android delivers to the shell.
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL Android foundation ", label)

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func drag(index: int, start: Vector2, end: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = end
	event.relative = end - start
	root.push_input(event, true)

func ticks(count: int) -> void:
	for tick in count: await physics_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_LANDSCAPE, "landscape viewport is explicit")
	check(not Input.emulate_mouse_from_touch and not Input.emulate_touch_from_mouse, "touchscreen and real mouse use independent physical devices")
	var bounds := Rect2(0,0,1280,720)
	var projection := Transform2D(Vector2(2,0), Vector2(0,2), Vector2(80,0))
	var cutout_safe := DemoUiModalMetrics.project_safe_area(bounds, Rect2i(190,80,2350,1300), Vector2i(30,20), projection)
	check(cutout_safe == Rect2(40,30,1175,650), "physical notch and system bars convert through window offset and stretch")
	check(DemoUiModalMetrics.project_safe_area(bounds, Rect2i(), Vector2i.ZERO, projection) == bounds, "no reported insets preserves usable full viewport")
	var base := "user://android_base_" + str(OS.get_process_id())
	var prefs := WorldSettings.new()
	prefs.open(base + "_settings.json","foundation")
	WorldSettings._current = prefs
	var slot := PlayableWorldSave.new()
	slot.configure_world(base + ".json", false, "android_foundation")
	var shell := (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate() as WorldShell
	shell.storage = slot
	root.add_child(shell)
	await ticks(5)
	var bridge := shell.get_node("WorldShellInput")
	var gear_button := shell.page_host.find_child("Settings",true,false) as Button
	var tap_at := gear_button.get_global_rect().get_center()
	touch(0, tap_at, true)
	touch(0, tap_at, false)
	check(shell.page == &"settings", "raw finger reaches title settings once")
	bridge.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(shell.page == &"title" and not quit_on_go_back, "Android back returns from settings to the title")
	var start := shell.page_host.find_child("BeginAdventure",true,false) as Button
	await ticks(2)
	tap_at = start.get_global_rect().get_center()
	touch(0, tap_at, true)
	touch(0, tap_at, false)
	await ticks(160)
	var scene := shell.world
	check(scene != null and scene.active != null, "tap starts an ordinary real P01")
	if not is_instance_valid(scene):
		quit(1)
		return
	var session := scene.active
	var controls := session.touch_controls
	var router := session.controller.router
	controls.set_enabled(true)
	controls._configure_layout(cutout_safe, bounds.size)
	check(cutout_safe.encloses(controls.pause_button) and cutout_safe.encloses(controls.map_button) and cutout_safe.has_point(controls.jump_center), "game controls stay inside the cutout-safe rectangle")
	controls.update_layout()
	var left := controls.left_center
	var right := controls.right_center
	touch(1,left,true)
	drag(1,left,left + Vector2.RIGHT*controls.radius)
	touch(2,right,true)
	drag(2,right,right + Vector2.RIGHT*controls.radius)
	check(router.sample_axes() > .9 and router.aim_engaged and controls._captures.size() == 2, "two real contact IDs independently walk and aim")
	var audio := shell.get_node("WorldAudio") as PlayableWorldAudio
	var starts := audio.music.starts.duplicate()
	var beds := audio.ambience.starts.duplicate()
	var revision := prefs.revision
	shell.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await ticks(3)
	check(controls._captures.is_empty() and router.sample_axes() == 0 and not router.has_application_focus, "suspending without a focus event clears both fingers")
	check(AudioServer.is_bus_mute(0) and audio.music._voices.any(func(v: AudioStreamPlayer): return v.stream != null and v.stream_paused), "backgrounds mute Master and suspend the active score")
	check(audio.ambience._beds.any(func(v: AudioStreamPlayer): return v.stream != null and v.stream_paused), "the active environmental bed is suspended")
	shell.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not router.has_application_focus, "a focus-in before resume cannot rearm gameplay")
	shell.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await ticks(3)
	var song_live := audio.music._voices.any(func(v: AudioStreamPlayer): return v.stream != null and not v.stream_paused)
	check(song_live and not AudioServer.is_bus_mute(0) and audio.music.starts == starts and audio.ambience.starts == beds and prefs.revision == revision, "foreground resumes the same voices without writing preferences")
	touch(1,left,false)
	touch(2,right,false)
	check(router.has_application_focus and router.sample_axes() == 0 and not router.aim_engaged, "late releases cannot rearm a pre-suspend stick")
	shell.open_pause()
	var quiet := prefs.value.duplicate(true)
	quiet.volume = 0
	check(prefs.save(quiet), "muted preference commits")
	shell.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	shell.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	await ticks(2)
	check(AudioServer.is_bus_mute(0) and paused and audio.ambience._beds.any(func(v: AudioStreamPlayer): return v.stream != null and v.stream_paused), "resume respects the user's mute and the open pause menu")
	bridge.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(shell.page == &"play" and not paused, "system back from gameplay pause resumes the room")
	scene.enter_room("P08","")
	var content := scene.active.content_sites.menu
	content.notice("告示","路牌")
	bridge.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not content.visible_panel() and not paused and shell.page == &"play", "system back dismisses world content without opening a second menu")
	if "--packed" in OS.get_cmdline_user_args():
		check(not FileAccess.file_exists("res://tests/fixtures/plains_receivers/P01.json") and not ResourceLoader.exists("res://rooms/world/P02.tscn"), "runtime uses the exported pack, with the old review scene excluded")
	shell.queue_free()
	await ticks(12)
	for suffix: String in ["", ".backup", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(base + ".json" + suffix)
		DirAccess.remove_absolute(base + "_settings.json" + suffix)
	print("ANDROID FOUNDATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
