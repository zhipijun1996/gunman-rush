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
	for entry_id: String in ["actions", "scene"]:
		var preview := preload("res://scenes/dev/cloud_preview.tscn").instantiate() as CloudPreviewBootstrap
		preview.entry = entry_id
		preview.entry_scene = "res://scenes/demo/action_studio.tscn" if entry_id == "scene" else ""
		root.add_child(preview)
		await process_frame
		await process_frame
		expect(preview.banner.visible, "Development version/menu affordance must remain visible")
		if entry_id == "actions":
			expect(is_instance_valid(preview.app._action_studio), "Actual App must enter ActionStudio")
			expect(not preview.app.meta_persistence_enabled, "Preview must never configure main save")
		else:
			expect(preview.app == null, "Standalone consumer must not leave default App running")
			expect(preview.custom_scene is ActionStudio, "Standalone entry must instantiate actual packed consumer")
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
