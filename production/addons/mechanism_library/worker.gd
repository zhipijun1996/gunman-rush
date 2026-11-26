extends SceneTree
const Edit := preload("res://addons/mechanism_library/room_edit.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		quit(1)
		return
	var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var result := Edit.execute(request.path,request.hash,request.operation,request.save)
	var report := FileAccess.open(args[1],FileAccess.WRITE)
	if not report:
		quit(1)
		return
	report.store_string(JSON.stringify(result))
	report.close()
	quit(0)
