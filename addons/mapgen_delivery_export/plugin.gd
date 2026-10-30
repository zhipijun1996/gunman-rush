@tool
extends EditorPlugin
const EXPORTER = preload("res://addons/mapgen_delivery_export/raw_delivery_export.gd")
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	exporter = EXPORTER.new()
	exporter.editor_tree = get_tree()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
	exporter = null
