extends SceneTree
## Diagnostic only: dynamically load one dependency graph, release the local
## reference, then exit without ever constructing actors or calling capture.
var requested_path := ""
func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--load="): requested_path=argument.trim_prefix("--load=")
	call_deferred("run")
func run() -> void:
	if requested_path.is_empty():
		quit(2)
		return
	var loaded: Resource=load(requested_path)
	if loaded == null:
		quit(3)
		return
	print("FOREST LOAD ONLY: loaded ", requested_path, " sha256=", FileAccess.get_sha256(requested_path))
	loaded=null
	for unused: int in 4: await process_frame
	print("FOREST LOAD ONLY: released local reference; no instances constructed")
	quit(0)
