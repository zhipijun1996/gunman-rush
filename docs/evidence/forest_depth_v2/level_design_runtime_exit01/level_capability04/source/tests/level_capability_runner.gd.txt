extends SceneTree
## Keep the capability case inside a real Node lifetime, after normal App setup.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var script: Script=load("res://tests/level_capability_case.gd")
	var case: Node=script.new()
	root.add_child(case)
	await case.run()
	var failed: bool=case.failures!=0 or case.assertions!=41 or not case.lifecycle_ok
	var case_ref: WeakRef=weakref(case)
	case.free()
	case=null
	script=null
	if case_ref.get_ref()!=null:
		push_error("LEVEL CAPABILITY: case retained after complete return")
		failed=true
	quit(1 if failed else 0)
