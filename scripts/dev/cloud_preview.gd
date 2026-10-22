class_name CloudPreviewBootstrap
extends Node
## Explicit development entry; ordinary project main scene never loads this file.
var app: DemoApp
var banner: PanelContainer
var task_id := "CLOUD-PRODUCTION-01"
var review_seed := "cloud-review-01"
var entry := "actions"
var entry_scene := ""
var custom_scene: Node
var custom_audio: GameAudio

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--task="): task_id = argument.trim_prefix("--task=")
		if argument.begins_with("--seed="): review_seed = argument.trim_prefix("--seed=")
		if argument.begins_with("--entry="): entry = argument.trim_prefix("--entry=")
		if argument.begins_with("--scene="): entry_scene = argument.trim_prefix("--scene=")
	seed(review_seed.hash())
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	# Set before DemoApp._ready: same-origin preview must not read/write main meta.
	app.meta_persistence_enabled = false
	app.set_meta("cloud_preview_host", true)
	add_child(app)
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	banner = PanelContainer.new()
	banner.position = Vector2(16, 220)
	layer.add_child(banner)
	var row := HBoxContainer.new()
	banner.add_child(row)
	var label := Label.new()
	label.text = "DEV · %s · seed %s · session only" % [task_id, review_seed]
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
	var menu_button := Button.new()
	menu_button.text = "FULL GAME / MENU"
	menu_button.pressed.connect(return_to_menu)
	row.add_child(menu_button)
	if entry == "actions": app.call_deferred("_open_action_studio")
	elif entry == "scene": call_deferred("open_test_scene")
	elif entry != "menu": push_error("Unsupported cloud preview entry: " + entry)
	print("CLOUD PREVIEW: ", task_id, " entry=", entry, " persistence=false seed=", review_seed)

func open_test_scene() -> void:
	if not entry_scene.begins_with("res://scenes/") or not entry_scene.ends_with(".tscn") or ".." in entry_scene or "\\" in entry_scene or entry_scene == "res://scenes/dev/cloud_preview.tscn":
		push_error("Invalid standalone preview scene")
		return
	var packed := load(entry_scene) as PackedScene
	if packed == null:
		push_error("Standalone preview scene is not in the real export")
		return
	remove_child(app)
	app.queue_free()
	app = null
	custom_audio = GameAudio.new()
	add_child(custom_audio)
	custom_scene = packed.instantiate()
	add_child(custom_scene)
	print("CLOUD PREVIEW: standalone scene=", entry_scene)

func return_to_menu() -> void:
	# Recreate the real title/Home entry with persistence still disabled.
	if get_tree().paused: get_tree().paused = false
	if is_instance_valid(custom_scene):
		remove_child(custom_scene)
		custom_scene.queue_free()
	if is_instance_valid(custom_audio):
		remove_child(custom_audio)
		custom_audio.queue_free()
	if is_instance_valid(app):
		remove_child(app)
		app.queue_free()
	app = preload("res://scenes/demo/demo.tscn").instantiate()
	app.meta_persistence_enabled = false
	app.set_meta("cloud_preview_host", true)
	add_child(app)
	entry = "menu"
	print("CLOUD PREVIEW: returned to full game menu; persistence=false")
