class_name PlainsMapLoading
extends CanvasLayer
## Scene-owned view/ticker. Freeing the App removes this callback and its signal;
## no coroutine awaits a global frame on a destroyed generation service.
signal completed
signal cancel_requested
var source: PlainsMapGeneration
var lifetime: DemoLifetime
var map_index := 1

func _ready() -> void:
	layer=30
	process_mode=Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	panel.position=Vector2(440,250)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var label := Label.new()
	label.text="正在生成平原地图 %s / 2…" % map_index
	column.add_child(label)
	var cancel := Button.new()
	cancel.text="返回家园"
	cancel.pressed.connect(func() -> void: cancel_requested.emit())
	column.add_child(cancel)
	UnderworldUI.style_canvas(self)

func _process(_delta: float) -> void:
	source.advance_map(lifetime)
	if source.phase!="loading":
		set_process(false)
		completed.emit()
