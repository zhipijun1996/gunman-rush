class_name StageExitModal
extends CanvasLayer
## Confirmation presentation only; the App owns route, epoch and reward settlement.
signal entered
signal stayed
var opened := false
var _root: Control
var _shell: DemoUiModalShell
var _submitted := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 29

func show_exit(next_label: String, reward_summary: String) -> void:
	close()
	opened = true
	_submitted = false
	_shell = DemoUiModalShell.new()
	_shell.preferred_width = 620
	_shell.preferred_height = 350
	_root = _shell
	add_child(_root)
	_shell.heading("NEXT / " + next_label, reward_summary, "旅程继续  /  THE NEXT CHIME")
	_shell.text("现在前往，或留下继续探索。 / Enter now, or stay and keep exploring.", 17, DemoClockworkTheme.MUTED)
	_shell.button("ENTER / CLAIM REWARD", func() -> void:
		if _submitted: return
		_submitted = true
		entered.emit())
	var stay := _shell.button("STAY / 继续探索", _stay)
	_shell.cancel_requested.connect(_stay)
	stay.grab_focus()

func _stay() -> void:
	if _submitted: return
	_submitted = true
	stayed.emit()

func close() -> void:
	opened = false
	if is_instance_valid(_root):
		if is_instance_valid(_shell): _shell.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_shell = null
