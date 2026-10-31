extends SceneTree
## Exercise real opt-in scenes and menu reconstruction, including save isolation.
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	for entry_id: String in ["actions", "scene", "demo"]:
		var preview := preload("res://experiments/platform/entries/cloud_preview.tscn").instantiate() as CloudPreviewBootstrap
		preview.entry = "actions" if entry_id == "actions" else "scene"
		preview.entry_scene = "res://game/application/demo.tscn" if entry_id == "demo" else "res://experiments/motion/entries/action_studio.tscn"
		root.add_child(preview)
		await process_frame
		await process_frame
		expect(preview.banner.visible, "Development version/menu affordance must remain visible")
		if entry_id == "actions":
			expect(is_instance_valid(preview.app._action_studio), "Actual App must enter ActionStudio")
			expect(not preview.app.meta_persistence_enabled, "Preview must never configure main save")
		elif entry_id == "scene":
			expect(preview.app == null, "Standalone consumer must not leave default App running")
			expect(preview.custom_scene is ActionStudio, "Standalone entry must instantiate actual packed consumer")
		else:
			expect(preview.custom_scene is DemoApp, "Standalone full App must remain the real consumer")
			expect(preview.custom_scene.has_meta("cloud_preview_host"), "Standalone full App must not redirect recursively")
			expect(not (preview.custom_scene as DemoApp).meta_persistence_enabled, "Standalone full App must not access main save")
		preview.return_to_menu()
		await process_frame
		await process_frame
		expect(is_instance_valid(preview.app), "Return must recreate actual full App")
		expect(not preview.app.meta_persistence_enabled, "Returning to full menu must preserve save isolation")
		expect(not is_instance_valid(preview.app._action_studio), "Full menu must not retain test scene")
		expect(not paused, "Return must clear preview pause")
		expect(await preload("res://tests/audio_teardown.gd").drain_world(preview), "Audio must drain before world release")
		preview.free()
		await process_frame
	print("CLOUD PREVIEW TESTS: ", assertions, " assertions, ", failures, " failures")
	quit(1 if failures else 0)
