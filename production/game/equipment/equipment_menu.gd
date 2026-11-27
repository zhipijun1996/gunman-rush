class_name EquipmentMenu
extends CanvasLayer

const UI_FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
var session: OrdinaryRoomSession
var mode := ""
var shortcut := Button.new()
var panel := PanelContainer.new()
var list := ItemList.new()
var detail := Label.new()
var portrait := TextureRect.new()
var item_name := Label.new()
var ledger_summary := Label.new()
var title := Label.new()
var apply := Button.new()
var rest := Button.new()
var weapons := OptionButton.new()
var selected := ""
var quote := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var theme := Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 18
	panel.theme = theme
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := StyleBoxFlat.new()
	background.bg_color = Color("201e22")
	background.border_color = Color("857047")
	background.set_border_width_all(2)
	background.content_margin_left = 20
	background.content_margin_right = 20
	background.content_margin_top = 16
	background.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel",background)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -424
	panel.offset_top = -248
	panel.offset_right = 424
	panel.offset_bottom = 248
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size",24)
	title.add_theme_color_override("font_color",Color("f2d394"))
	header.add_child(title)
	header.add_child(weapons)
	weapons.item_selected.connect(func(index: int): session.select_world_weapon(weapons.get_item_metadata(index),quote); refresh())
	header.add_child(ledger_summary)
	layout.add_child(HSeparator.new())
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",20)
	layout.add_child(content)
	list.custom_minimum_size.x = 342
	list.fixed_icon_size = Vector2i(32,32)
	list.add_theme_constant_override("v_separation",4)
	content.add_child(list)
	list.item_selected.connect(func(index: int): selected = str(list.get_item_metadata(index)); show_detail())
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",12)
	content.add_child(info)
	portrait.custom_minimum_size = Vector2(80,80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(portrait)
	item_name.add_theme_font_size_override("font_size",24)
	item_name.add_theme_color_override("font_color",Color("f2d394"))
	info.add_child(item_name)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation",10)
	layout.add_child(actions)
	actions.add_child(rest)
	rest.text = "休息并恢复"
	rest.pressed.connect(func(): submit("rest",""))
	actions.add_child(apply)
	apply.pressed.connect(accept)
	var close_button := Button.new()
	close_button.text = "返回"
	actions.add_child(close_button)
	close_button.pressed.connect(close)
	panel.hide()
	shortcut.theme = theme
	shortcut.text = "装备"; shortcut.position = Vector2(12,12); add_child(shortcut)
	shortcut.pressed.connect(func(): if not panel.visible: open("select"))
	shortcut.focus_mode = Control.FOCUS_NONE

func _input(event: InputEvent) -> void:
	var toggle: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I
	if panel.visible and (toggle or event.is_action_pressed("ui_cancel")):
		close()
	elif toggle and not get_tree().paused:
		open("select")
	else:
		return
	get_viewport().set_input_as_handled()

func open(context: String) -> void:
	if not session.controller.active or (get_tree().paused and not panel.visible): return
	mode = context
	panel.show()
	session.controller.router.clear("equipment")
	get_tree().paused = true
	refresh(); list.grab_focus()

func close() -> void:
	if not panel.visible: return
	panel.hide()
	get_tree().paused = false
	session.controller.router.clear("equipment")

func refresh() -> void:
	var services := session.services
	quote = session.state.revision
	title.text = {"smith":"装备强化","rest":"休息区装配","select":"快捷功能"}[mode]
	ledger_summary.text = "负荷 %d / %d    金币 %d" % [EquipmentCatalog.load_used(services.ledger().equipped),services.capacity(),services.ledger().gold]
	weapons.clear()
	if session.content_catalog!=null:
		var available:=session.world_weapon_loadouts()
		for flag: String in available:
			var definition: WeaponDefinition=available[flag]
			weapons.add_item(definition.display_name)
			weapons.set_item_metadata(weapons.item_count-1,flag)
			if definition==session.controller.shoot_ability.weapon: weapons.select(weapons.item_count-1)
	weapons.visible=weapons.item_count>1
	var remembered := selected
	list.clear(); selected = ""
	for id: String in EquipmentCatalog.DATA.data.items:
		if not services.ledger().owned.has(id): continue
		var item := EquipmentCatalog.item(id)
		var level := int(services.ledger().owned[id])
		var index := list.add_item("%s  %s  Lv%d  ·  负荷 %d" % ["◆" if services.active(id) else "◇",item.name,level,item.load],EquipmentCatalog.ICONS[id])
		list.set_item_metadata(index,id)
		if selected == "" or remembered == id: list.select(index); selected = id
	if not selected.is_empty(): list.ensure_current_is_visible.call_deferred()
	rest.visible = mode == "rest"
	show_detail()

func show_detail() -> void:
	portrait.visible = not selected.is_empty()
	item_name.visible = not selected.is_empty()
	if selected.is_empty():
		portrait.texture = null
		item_name.text = ""
		detail.text = "尚未获得装备"; apply.hide(); return
	var gear := session.services.ledger()
	var item := EquipmentCatalog.item(selected)
	var level := int(gear.owned[selected])
	portrait.texture = EquipmentCatalog.ICONS[selected]
	item_name.text = item.name
	detail.text = "%s\n\n%s" % [item.description,item.bounds]
	apply.show(); apply.disabled = false
	match mode:
		"smith":
			if item.max_level == 1: apply.hide(); detail.text += "\n固定效果"
			elif level >= item.max_level: apply.hide(); detail.text += "\n已强化至最高等级"
			else:
				var upgrade_quote := session.services.equipment_upgrade_quote(selected, level + 1)
				if not upgrade_quote.get("ok", false):
					apply.text = "强化不可用"
					apply.disabled = true
					detail.text += "\n当前装备的强化报价不可用。"
					return
				apply.text = "强化至 Lv%d · %d 金币" % [level+1,int(upgrade_quote.price)]
				apply.disabled = gear.gold < int(upgrade_quote.price)
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
	if kind == "rest":
		if not session.begin_station_rest(quote): detail.text = "请在充电站旁站稳后休息。"
		return
	var accepted := session.equipment_transaction(kind,id,quote)
	refresh()
	if not accepted: detail.text += "\n操作未完成，请检查负荷、互斥装备或金币。"

func _exit_tree() -> void:
	if panel.visible and is_inside_tree(): get_tree().paused = false
