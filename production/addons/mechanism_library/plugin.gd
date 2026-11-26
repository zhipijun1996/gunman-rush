@tool
extends EditorPlugin

var dock: EditorDock

func _enter_tree() -> void:
	dock = EditorDock.new()
	dock.name = "MechanismLibraryDock"
	dock.title = "机关库"
	dock.layout_key = "MechanismLibrary"
	dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	dock.add_child(preload("res://addons/mechanism_library/dock.gd").new())
	add_dock(dock)

func _exit_tree() -> void:
	remove_dock(dock)
	dock.queue_free()
