@tool
extends EditorPlugin

const EXPORTER := preload("res://addons/runtime_raw_export/raw_exporter.gd")
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = EXPORTER.new()
	exporter.editor_tree = get_tree()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
