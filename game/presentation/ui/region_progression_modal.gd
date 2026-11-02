class_name RegionProgressionModal
extends CanvasLayer
signal ability_selected(id: StringName)
signal region_selected(id: StringName)
signal finish_requested
var opened := false
var _root: Control
var _shell: DemoUiModalShell
var _boundary := false
var _submitted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35

func show_abilities(offers: Array[Dictionary], boundary: bool) -> void:
	_begin("CHOOSE A CORE ABILITY / 选择核心能力", "本局能力持续到旅程结束；核心能力与金色道具是两份独立奖励。")
	for offer: Dictionary in offers:
		var id := StringName(offer.id)
		var choose := _shell.button(str(offer.label), func() -> void:
			if _submitted: return
			_submitted = true
			ability_selected.emit(id))
		choose.disabled = not offer.available
	if boundary:
		_shell.text("FOREST COMPLETE / 森林之后的地区尚未制作。领取能力后返回家园。", 15, DemoClockworkTheme.BRASS)
	_shell.focus_first()

func show_regions() -> void:
	_begin("CHOOSE THE NEXT REGION / 下一站", "H acquired / 钩索已获得。保留生命、金币和构筑，进入需要钩索的荆棘森林。")
	_shell.button("ENTER / THORN FOREST / 2 RANDOM MAPS", func() -> void:
		if _submitted: return
		_submitted = true
		region_selected.emit(&"thorn_forest"))
	for title: String in ["CANYON / Locked: region not built; requires W", "SWAMP / Locked: region not built; requires U1"]:
		_shell.button(title, func() -> void: pass).disabled = true
	_shell.focus_first()

func show_boundary() -> void:
	_begin("THORN FOREST COMPLETE / 森林旅程完成", "核心能力已领取。后续地区尚在制作。返回家园结束本局并清除本局能力、金币和道具；已存入的音符保留。")
	_boundary = true
	_shell.cancelable = true
	_shell.button("END THIS RUN / RETURN HOME", _finish)
	_shell.focus_first()

func _finish() -> void:
	if not _boundary or _submitted: return
	_submitted = true
	finish_requested.emit()

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		if is_instance_valid(_shell): _shell.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_shell = null

func _begin(title: String, detail: String) -> void:
	close()
	opened = true
	_submitted = false
	_boundary = false
	_shell = DemoUiModalShell.new()
	_shell.preferred_width = 680
	_shell.preferred_height = 480
	_shell.cancelable = false
	_root = _shell
	add_child(_root)
	_shell.heading(title, detail, "新的余音  /  THE JOURNEY CONTINUES")
	_shell.cancel_requested.connect(_finish)
