extends Node
## Standalone experiment entrance; formal entry and content are untouched.
const World = preload("res://game/experiments/paper_theater/paper_world.gd")
var app: FixedWorldApp
var paper: Node2D
var mode := "A"
var ready_for_play := false
var controls: CanvasLayer
var description: Label
var original_art: PlainsRoomArt
var initial_room: FixedWorldRoom

func _ready() -> void:
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://paper_theater_unused.json"
	app.save_profile = "paper_theater_unused"
	app.settings_path = "user://paper_theater_settings.json"
	add_child(app)
	# Existing review lifecycle swaps in MemorySave before a player is created.
	await app.review.begin("P-R04","","base")
	initial_room = app.room
	original_art = app.room.get_node("RegionalArt") as PlainsRoomArt
	_build_controls()
	var requested := "A"
	if OS.has_feature("web"):
		requested = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('paper') || 'A'"))
	else:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--paper="): requested = arg.trim_prefix("--paper=")
	set_mode(requested)
	ready_for_play = true
	print("PAPER LAB READY room=P-R04 mode=",mode," zoom=",app.camera.zoom," save=MemorySave")

func _build_controls() -> void:
	controls = CanvasLayer.new()
	controls.layer = 50
	add_child(controls)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,73)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0e6ce",.94)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	style.border_color = Color("b8b39b")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	controls.add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var title := Label.new()
	title.text = "失序之钟 / 纸艺剧场 · P04"
	title.add_theme_color_override("font_color",Color("244d4c"))
	rows.add_child(title)
	var buttons := HBoxContainer.new()
	rows.add_child(buttons)
	for spec: Array in [["0 当前","0"],["1 轻剪纸","A"],["2 抽象拼贴","B"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(106,42)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(set_mode.bind(spec[1]))
		buttons.add_child(button)
	description = Label.new()
	description.add_theme_font_size_override("font_size",16)
	description.add_theme_color_override("font_color",Color("45665c"))
	rows.add_child(description)
	var retry := Button.new()
	retry.text = "重新进入 P04"
	retry.focus_mode = Control.FOCUS_NONE
	retry.custom_minimum_size.y = 36
	retry.pressed.connect(restart)
	rows.add_child(retry)

func set_mode(value: String) -> void:
	if value not in ["0","A","B"]:value = "A"
	mode = value
	if is_instance_valid(paper):
		remove_child(paper)
		paper.queue_free()
	app.room.visible = mode=="0"
	app.player.visible = mode=="0"
	original_art.set_process(mode=="0")
	# CanvasModulate can affect the canvas even while its room is hidden.
	original_art.ambient.visible = mode=="0"
	if mode!="0":
		paper = World.new()
		paper.app = app
		paper.bold = mode=="B"
		add_child(paper)
	description.text = {"0":"现有像素美术 / 相同镜头与碰撞","A":"A / 轻剪纸水彩 · 柔和纸层","B":"B / 抽象拼贴 · 裁切色块"}[mode]
	if is_instance_valid(app.controller): app.controller.router.clear(&"paper_mode_switch")

func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_play or not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode in [KEY_0,KEY_1,KEY_2]:
		set_mode({KEY_0:"0",KEY_1:"A",KEY_2:"B"}[event.physical_keycode])

func _process(_delta: float) -> void:
	if not ready_for_play:return
	# The independent study stays in P04. Crossing a real exit simply offers a
	# restart; no adjacent-room replacement art or topology is introduced.
	if app.room != initial_room:
		ready_for_play = false
		if is_instance_valid(paper):paper.hide()
		restart.call_deferred()
		return

func restart() -> void:
	if app.busy:
		await get_tree().physics_frame
		restart.call_deferred()
		return
	ready_for_play = false
	if is_instance_valid(paper):
		remove_child(paper)
		paper.queue_free()
	await app.review.begin("P-R04","","base",app.review.invincible)
	initial_room = app.room
	original_art = app.room.get_node("RegionalArt") as PlainsRoomArt
	set_mode(mode)
	ready_for_play = true
