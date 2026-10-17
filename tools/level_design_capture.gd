extends SceneTree
## Exit only after the original complete capture has returned and its Node freed.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var script: Script=load("res://tools/level_design_capture_case.gd")
	var capture: Node=script.new()
	root.add_child(capture)
	await capture.run()
	var code: int=capture.exit_code
	var capture_ref: WeakRef=weakref(capture)
	capture.free()
	capture=null
	script=null
	if capture_ref.get_ref()!=null:
		push_error("LEVEL DESIGN CAPTURE: owner retained after complete return")
		code=1
	quit(code)
