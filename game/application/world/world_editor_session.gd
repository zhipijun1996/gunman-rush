class_name WorldEditorSession
extends Node
## Native host writes an atomic private JSON file; the resident game consumes it
## through the normal isolated review lifecycle, never the player's save slot.
var app: FixedWorldApp
var path := ""
var seen_hash := ""
var loading := false
var elapsed := 0.0

static func requested_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--editor-project="): return argument.trim_prefix("--editor-project=")
	return ""

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25 or loading or app.busy or path.is_empty(): return
	elapsed = 0
	if not FileAccess.file_exists(path): return
	var hash := FileAccess.get_file_as_string(path+".marker") if FileAccess.file_exists(path+".marker") else FileAccess.get_sha256(path)
	if hash == seen_hash: return
	seen_hash = hash
	_load.call_deferred()

func _load() -> void:
	loading = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("project") is Dictionary:
		app.status = "编辑器项目无效"
		loading = false
		return
	var id := str(parsed.get("room_id", ""))
	Engine.set_meta("world_editor_graybox", bool(parsed.get("graybox", true)))
	var previous := app.content.workbench_snapshot()
	var error := app.content.install_editor_project(parsed.project, id, str(parsed.get("verified_behavior_hash", "")))
	if not error.is_empty():
		app.status = "编辑器预览："+error
		loading = false
		return
	app.services.definitions = app.content.data.get("demo_services", {})
	var success := await app.review.begin(id, str(parsed.get("entry", "")), "base", bool(parsed.get("invincible", true)), parsed.get("stage", []), parsed.get("flags", []))
	if not success:
		app.content.restore_workbench_snapshot(previous)
		app.status = "编辑器预览装载失败，保留原草稿"
	loading = false
