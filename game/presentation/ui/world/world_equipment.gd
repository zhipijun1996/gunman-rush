class_name WorldEquipment
extends DemoMenu
## The existing equipment grid/detail UI, fed only committed world read models.
var submit: Callable
func _pause_navigation(_active_page: StringName) -> void:
	_title(WorldText.text("equipment.heading"),WorldText.text("equipment.policy"))
	_button(_content,WorldText.text("equipment.close"),func() -> void: requested_resume.emit())
func _request_equipment(id: StringName,equip: bool) -> void:
	submit.call("equip" if equip else "unequip",str(id),int(_equipment_view.revision))
func _render_equipment_detail() -> void:
	super._render_equipment_detail()
	var selected:=_world_entry(_selected_instance_id)
	if selected.is_empty(): return
	var id:=str(_selected_instance_id)
	var equipped:=bool(selected.get("equipped",false))
	var action:=_equipment_detail.get_node_or_null("UnequipItem" if equipped else "EquipItem") as Button
	if action!=null:
		action.text=WorldText.text("world_services_view.28") if equipped else WorldText.text("world_services_view.29")
		if selected.get("unavailable",false) and not equipped: action.disabled=true
		action.set_meta(&"world_service","Service_"+("unequip_" if equipped else "equip_")+id)
	var replace:=_equipment_detail.get_node_or_null("SelectReplacement") as Button
	if replace!=null: replace.hide()
	if equipped and selected.get("usable",false):
		var use:=_detail_equipment_button(_equipment_detail,WorldText.text("equipment.use") % int(selected.get("remaining_uses",0)),func() -> void: submit.call("use",id,int(_equipment_view.revision)))
		use.name="UseWorldItem"
		use.set_meta(&"focus_key","world_use:"+id)
		use.set_meta(&"world_service","Service_use_"+id)
		if action!=null: _equipment_detail.move_child(use,action.get_index()+1)
	_layout_menu()

func _world_entry(id: StringName) -> Dictionary:
	for entry: Dictionary in _equipment_view.get("items",[]):
		if StringName(entry.instance_id)==id: return entry
	return {}

func _switch_pause_page(_direction: int) -> void:
	# This world adapter exposes only the actual world inventory, never old Run pages.
	pass
