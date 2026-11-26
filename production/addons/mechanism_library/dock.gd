@tool
extends VBoxContainer
const Info := preload("res://addons/mechanism_library/catalog_info.gd")
const Edit := preload("res://addons/mechanism_library/room_edit.gd")
const OPERATIONS := ["add","edit","move","copy","detach"]
var picker := EditorFileDialog.new()
var path_label := Label.new()
var current_path := ""
var original := {}
var action := OptionButton.new()
var search := LineEdit.new()
var choices := OptionButton.new()
var identity := LineEdit.new()
var point := LineEdit.new()
var external := LineEdit.new()
var field_box := VBoxContainer.new()
var inputs := {}
var preview := TextEdit.new()
var preview_button := Button.new()
var save_button := Button.new()
var job_pid := -1
var request_path := ""
var report_path := ""
var pending := {}
var staged := {}

func _ready() -> void:
	name = "MechanismLibraryPanel"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var open := Button.new()
	open.text = "打开房间 JSON…"
	open.pressed.connect(func(): picker.popup_file_dialog())
	add_child(open)
	picker.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	picker.access = EditorFileDialog.ACCESS_RESOURCES
	picker.filters = PackedStringArray(["*.json ; Schema 3 房间"])
	picker.file_selected.connect(open_room)
	add_child(picker)
	path_label.text = "选择要编辑的 schema 3 房间"
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(path_label)
	for label: String in ["放置机关或预组","编辑现有成员","移动整个预组","复制整个预组","解除分组"]:
		action.add_item(label)
	add_child(action)
	action.item_selected.connect(func(_index): refresh_choices())
	search.placeholder_text = "按编号、中文名或 ID 查找"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_s): refresh_choices())
	add_child(search)
	choices.fit_to_longest_item = false
	add_child(choices)
	choices.item_selected.connect(func(_index): build_fields())
	identity.placeholder_text = "新实例或新组的稳定 ID"
	add_child(identity)
	point.placeholder_text = "放置坐标／整体位移 [x,y]（px）"
	point.tooltip_text = "创建时为组合原点，移动或复制时为平移量，空为 [0,0]。"
	add_child(point)
	external.placeholder_text = "外部引用映射 JSON，可留空"
	external.tooltip_text = "从原外部实例 ID 映射至目标实例 ID。世界行动使用 action:<原行动 ID>。"
	add_child(external)
	for control: LineEdit in [identity,point,external]: control.text_changed.connect(func(_s): invalidate())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 120
	field_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(field_box)
	add_child(scroll)
	preview.editable = false
	preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	preview.custom_minimum_size.y = 110
	preview.placeholder_text = "校验后可查看派生值与生成的实际房间行"
	add_child(preview)
	var buttons := HBoxContainer.new()
	add_child(buttons)
	preview_button.text = "校验并预览"
	preview_button.pressed.connect(func(): begin(false))
	save_button.text = "写入房间"
	save_button.pressed.connect(func(): begin(true))
	for button: Button in [preview_button,save_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	refresh_choices()
	set_process(false)

func open_room(path: String) -> void:
	if job_pid != -1: return
	var snapshot := Edit.snapshot(path)
	if snapshot.has("error"):
		preview.text = str(snapshot.error)
		return
	original = snapshot
	current_path = path
	var region := str(snapshot.doc.root.properties.get("region_id",""))
	path_label.text = "%s · %s" % [snapshot.doc.get("room_id",""),region if region != "" else "公有库"]
	path_label.tooltip_text = path
	refresh_choices()

func invalidate() -> void:
	staged.clear()
	save_button.disabled = true
	preview.text = ""

func refresh_choices() -> void:
	choices.clear()
	var operation: String = OPERATIONS[action.selected]
	var creating := operation == "add"
	identity.visible = operation in ["add","copy"]
	point.visible = operation in ["add","move","copy"]
	external.visible = operation == "copy"
	if not original.is_empty():
		var doc: Dictionary = original.doc
		if creating:
			var region := str(doc.root.properties.get("region_id",""))
			for item: Dictionary in Info.palette(region,search.text):
				add_choice(item.caption + (" · 区域独有" if item.scope == "regional" else ""),item.id)
		else:
			var groups := {}
			for id: String in doc.entities:
				var row: Dictionary = doc.entities[id]
				var d: Dictionary = WorldElementCatalog.catalog().definitions.get(row.get("definition_id",""),{})
				if d.is_empty(): continue
				if operation == "edit":
					if d.get("library") != "mechanisms" and not row.has("assembly_id"): continue
					if (id+" "+str(d.name)).to_lower().contains(search.text.to_lower()): add_choice(id+" · "+str(d.name),id)
				elif row.has("assembly_id"): groups[row.assembly_id] = true
			if not creating and operation != "edit":
				var ids := groups.keys()
				ids.sort()
				for group: String in ids:
					if group.to_lower().contains(search.text.to_lower()): add_choice(group,group)
	build_fields()

func add_choice(label: String, id: String) -> void:
	choices.add_item(label)
	choices.set_item_metadata(choices.item_count-1,id)

func selection() -> String:
	return "" if choices.selected < 0 else str(choices.get_selected_metadata())

func build_fields() -> void:
	invalidate()
	inputs.clear()
	for child: Node in field_box.get_children(): field_box.remove_child(child); child.queue_free()
	var selected := selection()
	preview_button.disabled = selected == "" or job_pid != -1
	if selected == "" or OPERATIONS[action.selected] not in ["add","edit"]: return
	var editing: bool = OPERATIONS[action.selected] == "edit"
	var row: Dictionary = original.doc.entities[selected] if editing else {}
	var id := str(row.get("definition_id",selected))
	var d: Dictionary = WorldElementCatalog.catalog().definitions[id]
	var display := Label.new()
	display.text = "%s  v%s" % [id,d.version]
	display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field_box.add_child(display)
	for mode: String in d.get("mode_defaults",{}):
		var description := Label.new()
		description.text = mode+"  "+JSON.stringify(d.mode_defaults[mode])
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field_box.add_child(description)
	var schema := Info.fields(d)
	for key: String in schema:
		var f: Dictionary = schema[key]
		var current: Variant = row.get("properties",{}).get(key,f.get("default"))
		var label := Label.new()
		label.text = str(f.label) + ("（"+str(f.unit)+"）" if str(f.unit) != "" else "")
		label.tooltip_text = key
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		field_box.add_child(label)
		var control: Control
		if f.has("choices") or f.type == "bool":
			var dropdown := OptionButton.new()
			dropdown.fit_to_longest_item = false
			dropdown.add_item("沿用默认")
			var items: Array = f.get("choices",[true,false])
			for value: Variant in items:
				dropdown.add_item(str(value))
				if value == current: dropdown.select(dropdown.item_count-1)
			dropdown.item_selected.connect(func(_i): invalidate())
			control = dropdown
		else:
			var edit := LineEdit.new()
			edit.placeholder_text = "沿用默认" if not f.get("required",false) else "必填"
			if current != null: edit.text = str(current) if f.type == "string" else JSON.stringify(current)
			edit.text_changed.connect(func(_s): invalidate())
			control = edit
		control.tooltip_text = key+" · "+str(f.hint)
		field_box.add_child(control)
		if str(f.hint) != "":
			var hint := Label.new()
			hint.text = f.hint
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.modulate.a = 0.75
			field_box.add_child(hint)
		inputs[key] = {"control":control,"field":f,"original":current}

func form_operation() -> Dictionary:
	var kind: String = OPERATIONS[action.selected]
	var at: Variant = [0,0] if point.text.strip_edges() == "" or not point.visible else JSON.parse_string(point.text)
	if not WorldRoomValidation.vector(at): return {"error":"坐标应为 [x,y]"}
	var operation := {"kind":kind,"at":at,"id":identity.text.strip_edges(),"fields":{}}
	if kind in ["add","copy"] and str(operation.id) == "": return {"error":"请填写新实例或新组的稳定 ID"}
	match kind:
		"add": operation.definition = selection()
		"edit": operation.id = selection()
		_: operation.group = selection()
	if kind == "copy" and external.text.strip_edges() != "":
		var mapping: Variant = JSON.parse_string(external.text)
		if not mapping is Dictionary: return {"error":"外部引用映射应为 JSON 对象"}
		operation.external_refs = mapping
	for key: String in inputs:
		var entry: Dictionary = inputs[key]
		var f: Dictionary = entry.field
		var value: Variant
		if entry.control is OptionButton:
			var dropdown := entry.control as OptionButton
			if dropdown.selected <= 0: continue
			value = f.get("choices",[true,false])[dropdown.selected-1]
		else:
			var raw := str(entry.control.text)
			if f.type == "string": value = raw
			elif raw.strip_edges() == "": continue
			else:
				var parse := JSON.new()
				if parse.parse(raw) != OK or parse.data == null: return {"error":"无法读取字段 "+key}
				value = parse.data
		if value != entry.original and not (value is String and value.is_empty() and entry.original == null):
			operation.fields[key] = value
	return operation

func begin(save: bool) -> void:
	if original.is_empty() or job_pid != -1: return
	var operation := form_operation()
	if operation.has("error"): preview.text = str(operation.error); return
	if save and staged != operation: return
	var base := "user://mechanism-editor-%s-%s"%[OS.get_process_id(),Time.get_ticks_usec()]
	request_path = base+".request.json"
	report_path = base+".response.json"
	var file := FileAccess.open(request_path,FileAccess.WRITE)
	if not file: preview.text = "无法创建校验请求"; return
	file.store_string(JSON.stringify({"path":current_path,"hash":original.hash,"operation":operation,"save":save}))
	file.close()
	pending = operation.duplicate(true)
	job_pid = OS.create_process(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://addons/mechanism_library/worker.gd","--",request_path,report_path])
	if job_pid == -1:
		DirAccess.remove_absolute(request_path)
		preview.text = "无法启动 Godot 校验器"
		return
	invalidate()
	preview.text = "正在装配房间…"
	preview_button.disabled = true
	set_process(true)

func _process(_delta: float) -> void:
	if job_pid < 0 or OS.is_process_running(job_pid): return
	job_pid = -1
	set_process(false)
	var result: Dictionary = {"error":"Godot 校验进程没有返回结果"}
	if FileAccess.file_exists(report_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if parsed is Dictionary: result = parsed
		DirAccess.remove_absolute(report_path)
	DirAccess.remove_absolute(request_path)
	preview_button.disabled = selection() == ""
	if result.has("error"):
		preview.text = "房间已被其他编辑修改，请重新打开后再应用。" if result.error == "room_changed_on_disk" else str(result.error)
		return
	if result.saved:
		EditorInterface.get_resource_filesystem().update_file(current_path)
		open_room(current_path)
	else:
		staged = pending.duplicate(true)
		save_button.disabled = staged != form_operation()
	var lines := PackedStringArray(["已写入房间" if result.saved else "已通过房间装配校验"])
	for id: String in result.changed:
		var data := Info.derived(result.changed[id])
		if not data.is_empty():
			lines.append(id)
			for key: String in data: lines.append("  %s  %s" % [key, str(data[key])])
	lines.append(JSON.stringify(result.changed,"  ",false))
	preview.text = "\n".join(lines)
