class_name EquipmentMenu
extends CanvasLayer

const UI_FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
var session: OrdinaryRoomSession
var mode := ""
var panel := PanelContainer.new()
var list := ItemList.new()
var detail := Label.new()
var title := Label.new()
var apply := Button.new()
var rest := Button.new()
var selected := ""
var quote := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var theme := Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 18
	panel.theme = theme
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -305; panel.offset_top = -245
	panel.offset_right = 305; panel.offset_bottom = 245
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(title); box.add_child(list)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(index: int): selected = str(list.get_item_metadata(index)); show_detail())
	box.add_child(detail); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(apply); apply.pressed.connect(accept)
	box.add_child(rest); rest.text = "休息并恢复"; rest.pressed.connect(func(): submit("rest",""))
	var close_button := Button.new()
	close_button.text = "返回"; box.add_child(close_button); close_button.pressed.connect(close)
	panel.hide()
	var shortcut := Button.new()
	shortcut.theme = theme
	shortcut.text = "装备"; shortcut.position = Vector2(12,12); add_child(shortcut)
	shortcut.pressed.connect(func(): if not panel.visible: open("select"))
	shortcut.focus_mode = Control.FOCUS_NONE

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I):
		if panel.visible: close()
		elif not get_tree().paused: open("select")
		get_viewport().set_input_as_handled()

func open(context: String) -> void:
	if not session.controller.active: return
	mode = context
	panel.show()
	session.controller.router.clear("equipment")
	get_tree().paused = true
	refresh(); list.grab_focus()

func close() -> void:
	panel.hide()
	get_tree().paused = false
	session.controller.router.clear("equipment")

func refresh() -> void:
	var services := session.services
	quote = session.state.revision
	title.text = "%s    负荷 %d / %d    金币 %d" % [{"smith":"装备强化","rest":"休息区装配","select":"快捷功能"}[mode],EquipmentCatalog.load_used(services.ledger().equipped),services.capacity(),services.ledger().gold]
	var remembered := selected
	list.clear(); selected = ""
	for id: String in EquipmentCatalog.DATA.data.items:
		if not services.ledger().owned.has(id): continue
		var item := EquipmentCatalog.item(id)
		var level := int(services.ledger().owned[id])
		var index := list.add_item("%s  %s  Lv%d  ·  负荷 %d" % ["◆" if services.active(id) else "◇",item.name,level,item.load])
		list.set_item_metadata(index,id)
		if selected == "" or remembered == id: list.select(index); selected = id
	rest.visible = mode == "rest"
	show_detail()

func show_detail() -> void:
	if selected.is_empty():
		detail.text = "尚未获得装备"; apply.hide(); return
	var gear := session.services.ledger()
	var item := EquipmentCatalog.item(selected)
	var level := int(gear.owned[selected])
	detail.text = "%s\n%s" % [item.description,item.bounds]
	apply.show(); apply.disabled = false
	match mode:
		"smith":
			if item.max_level == 1: apply.hide(); detail.text += "\n固定效果"
			elif level >= item.max_level: apply.hide(); detail.text += "\n已强化至最高等级"
			else:
				apply.text = "强化至 Lv%d · %d 金币" % [level+1,item.upgrade_prices[level-1]]
				apply.disabled = gear.gold < item.upgrade_prices[level-1]
				var effects := PackedStringArray()
				for key: String in item.parameters:
					var values: Variant = item.parameters[key]
					if values is Array:
						effects.append("%s → %s" % [values[level-1],values[level]])
				detail.text += "\nLv%d → Lv%d   %s" % [level,level+1,"  /  ".join(effects)]
		"rest": apply.text = "卸下" if session.services.active(selected) else "装配"
		"select":
			apply.visible = item.get("active",false) and selected in gear.equipped
			apply.text = "已选为快捷功能" if selected == gear.selected else "选为快捷功能"
			apply.disabled = selected == gear.selected
	if selected == "G05": detail.text += "\n钟卫 HP %d / 6    冷却 %.1f 秒" % [session.equipment.fx.guard_hp,session.equipment.fx.cooldowns.get("G05",0)]

func accept() -> void:
	var kind := mode
	if mode == "smith": kind = "upgrade"
	if mode == "rest": kind = "unequip" if session.services.active(selected) else "equip"
	submit(kind,selected)

func submit(kind: String, id: String) -> void:
	var accepted := session.equipment_transaction(kind,id,quote)
	refresh()
	if not accepted: detail.text += "\n操作未完成，请检查负荷、互斥装备或金币。"

func _exit_tree() -> void:
	if panel.visible and is_inside_tree(): get_tree().paused = false
