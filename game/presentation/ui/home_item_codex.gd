class_name HomeItemCodex
extends CanvasLayer
## Snapshot-only Home UI. The Home owner validates focus/lifetime/revision,
## owns notes/unlocks/loadout, and blocks gameplay input while this is open.
signal requested_close
signal requested_unlock(id: StringName, expected_revision: int)
signal requested_select(id: StringName, expected_revision: int)

const TOUCH_SCROLL := preload("res://game/presentation/ui/menu_scroll_touch_adapter.gd")
var opened := false
var _generation := 0
var _detail_generation := 0
var _submitted := false
var _close_pending := false
var _profile_revision := -1
var _notes := 0
var _selected_id: StringName = &""
var _focused_id: StringName = &""
var _rows: Dictionary = {}
var _order: Array[StringName] = []
var _tiles: Dictionary = {}
var _root: DemoUiModalShell
var _body: BoxContainer
var _catalog_scroll: ScrollContainer
var _grid: GridContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _status: Label
var _close_button: Button
var _clear_button: Button
var _action: Button
var _touch_adapters: Array[Node] = []
var _layout_signature: Array = []

func show_codex(rows: Array[Dictionary], notes: int, selected_id: StringName, profile_revision: int) -> void:
	var old_focus := _focused_id
	hide_codex()
	opened = true
	_submitted = false
	_close_pending = false
	_profile_revision = profile_revision
	_notes = maxi(0,notes)
	_selected_id = selected_id
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rows.clear()
	_order.clear()
	for supplied: Dictionary in rows:
		var id := StringName(supplied.get("id",&""))
		var item := supplied.get("item") as ItemDefinition
		if id.is_empty() or item == null or id != item.stable_id or _rows.has(id): continue
		# A local snapshot copy prevents later caller mutations changing a bound
		# button's displayed eligibility; item data remains a read-only reference.
		_rows[id] = supplied.duplicate()
		_order.append(id)
	_focused_id = old_focus if _rows.has(old_focus) else selected_id if _rows.has(selected_id) else _order[0] if not _order.is_empty() else &""
	_root = DemoUiModalShell.new()
	_root.name = "HomeCodexModal"
	_root.preferred_width = 1080
	_root.preferred_height = 620
	add_child(_root)
	var generation := _generation
	_root.cancel_requested.connect(func() -> void: _request_close(generation))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",12)
	_root.rows.add_child(header)
	var title := DemoClockworkTheme.label("局内道具图鉴",25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var notes_label := DemoClockworkTheme.label("音符 %s" % _notes,19,DemoClockworkTheme.BRASS)
	notes_label.name = "CodexNotes"
	header.add_child(notes_label)
	_clear_button = Button.new()
	_clear_button.name = "CodexClearSelection"
	_clear_button.text = "不携带道具"
	_clear_button.theme_type_variation = &"CompactButton"
	_clear_button.custom_minimum_size = Vector2(136,54)
	_clear_button.disabled = selected_id.is_empty()
	var revision := _profile_revision
	_clear_button.pressed.connect(func() -> void: _request_clear(generation,revision))
	header.add_child(_clear_button)
	_close_button = Button.new()
	_close_button.name = "CodexClose"
	_close_button.text = "关闭"
	_close_button.custom_minimum_size = Vector2(78,54)
	_close_button.pressed.connect(func() -> void: _request_close(generation))
	header.add_child(_close_button)
	var guidance := _root.text("音符永久解锁 · 每局最多带出1件 Lv1 道具。\n带出道具先进入本局背包，仍需装备才生效。",16,DemoClockworkTheme.MUTED)
	guidance.name = "CodexRules"
	_status = _root.text("",16,DemoClockworkTheme.CORAL)
	_status.name = "CodexStatus"
	_status.visible = false
	_body = BoxContainer.new()
	_body.name = "CodexBody"
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",16)
	_root.rows.add_child(_body)
	_catalog_scroll = _make_scroll("CodexCatalogScroll",1.35)
	_grid = GridContainer.new()
	_grid.name = "CodexGrid"
	_grid.add_theme_constant_override("h_separation",8)
	_grid.add_theme_constant_override("v_separation",8)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_scroll.add_child(_grid)
	for id: StringName in _order: _create_tile(id,generation)
	_detail_scroll = _make_scroll("CodexDetailScroll",1.0)
	_detail = VBoxContainer.new()
	_detail.name = "CodexDetail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation",12)
	_detail_scroll.add_child(_detail)
	_root.layout_changed.connect(_layout)
	_render_detail()
	_layout()
	_root.focus_first()
	if _tiles.has(_focused_id): (_tiles[_focused_id] as Button).grab_focus()

func _make_scroll(node_name: String, ratio: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = node_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = ratio
	_body.add_child(scroll)
	var adapter: Node = TOUCH_SCROLL.new()
	adapter.set("scroll",scroll)
	scroll.add_child(adapter)
	_touch_adapters.append(adapter)
	return scroll

func _create_tile(id: StringName, generation: int) -> void:
	var row: Dictionary = _rows[id]
	var discovered := bool(row.get("discovered",false))
	var item := row.item as ItemDefinition
	var tile := Button.new()
	tile.name = "CodexTile_"+String(id).validate_node_name()
	tile.set_meta(&"definition_id",id)
	tile.custom_minimum_size = Vector2(92,118)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.tooltip_text = item.display_name if discovered else "? · 尚未发现"
	tile.pressed.connect(func() -> void: _focus_item(id,generation))
	tile.focus_entered.connect(func() -> void: _focus_item(id,generation))
	_grid.add_child(tile)
	_tiles[id] = tile
	var contents := VBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 5
	contents.offset_right = -5
	contents.offset_top = 6
	contents.offset_bottom = -6
	contents.add_theme_constant_override("separation",3)
	tile.add_child(contents)
	if discovered:
		var image := TextureRect.new()
		image.texture = ItemPresentation.icon(item.icon_key)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size = Vector2(0,52)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(image)
	else:
		var unknown := DemoClockworkTheme.label("?",37,DemoClockworkTheme.MUTED)
		unknown.name = "CodexUnknownIcon"
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(unknown)
	var name_label := DemoClockworkTheme.label(item.display_name if discovered else "未发现",14)
	name_label.name = "CodexTileName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(name_label)
	var state_text := "已选择" if discovered and id == _selected_id else "已解锁" if discovered and bool(row.get("unlocked",false)) else "待解锁" if discovered else "?"
	var state := DemoClockworkTheme.label(state_text,13,DemoClockworkTheme.TEAL if discovered and id == _selected_id else DemoClockworkTheme.MUTED)
	state.name = "CodexTileState"
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(state)

func _view_current(generation: int) -> bool:
	return opened and is_inside_tree() and is_instance_valid(_root) and _root.is_visible_in_tree() and generation == _generation

func _focus_item(id: StringName, generation: int) -> void:
	if not _view_current(generation) or not _rows.has(id): return
	_reveal_catalog_tile.call_deferred(id,generation)
	if _focused_id == id and is_instance_valid(_detail) and _detail.get_child_count() > 0: return
	_focused_id = id
	_render_detail()

func _reveal_catalog_tile(id: StringName, generation: int) -> void:
	# Rendering detail changes label metrics and schedules container layout.
	# Follow the real focused Control after that layout, not its old bounds.
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame
	if not _view_current(generation) or id != _focused_id or not _tiles.has(id): return
	var tile := _tiles[id] as Button
	if not is_instance_valid(tile) or not tile.has_focus(): return
	_catalog_scroll.ensure_control_visible(tile)

func _detail_text(text: String, font_size: int = 17, color: Color = DemoClockworkTheme.PAPER) -> Label:
	var label := DemoClockworkTheme.label(text,font_size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(label)
	return label

func _render_detail() -> void:
	if not is_instance_valid(_detail): return
	_detail_generation += 1
	_action = null
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if not _rows.has(_focused_id):
		_detail_text("暂无道具记录。",19,DemoClockworkTheme.MUTED)
		return
	var id := _focused_id
	var row: Dictionary = _rows[id]
	var generation := _generation
	var revision := _profile_revision
	var detail_generation := _detail_generation
	var discovered := bool(row.get("discovered",false))
	var requires_discovered := bool(row.get("requires_discovered",true))
	if not discovered:
		var unknown := _detail_text("?",52,DemoClockworkTheme.MUTED)
		unknown.name = "CodexUnknownDetail"
		_detail_text("尚未发现\n在冒险中发现后，可在这里查看并永久解锁。" if requires_discovered else "尚未发现\n名称、图标与效果将在实际获得后显示。",17,DemoClockworkTheme.MUTED)
		if requires_discovered: return
	else:
		var item := row.item as ItemDefinition
		var card := ItemCard.new()
		card.name = "CodexDetailCard"
		card.item = item
		card.level = 1
		card.compact = true
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.add_child(card)
	var unlocked := bool(row.get("unlocked",false))
	var chosen := id == _selected_id
	_detail_text("已永久解锁" if unlocked else "尚未解锁 · 永久解锁需 %s 音符" % maxi(0,int(row.get("price",0))),16,DemoClockworkTheme.TEAL if unlocked else DemoClockworkTheme.BRASS)
	_action = Button.new()
	_action.name = "CodexSelect" if unlocked else "CodexUnlock"
	_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action.custom_minimum_size.y = 54
	_action.text = ("取消带出" if chosen else "选择带出 · Lv1") if unlocked else "永久解锁 · %s 音符" % maxi(0,int(row.get("price",0)))
	_action.pressed.connect(func() -> void: _request_item(id,unlocked,generation,revision,detail_generation))
	_detail.add_child(_action)
	_action.disabled = _submitted or (not bool(row.get("available",false)) and not (unlocked and chosen)) or (not unlocked and _notes < maxi(0,int(row.get("price",0))))
	if _action.disabled and not _submitted:
		var reason := _display_reason(str(row.get("reason","")))
		if reason.is_empty(): reason = "音符不足。" if not unlocked and _notes < maxi(0,int(row.get("price",0))) else "当前无法操作。"
		_detail_text(reason,16,DemoClockworkTheme.CORAL)
	_detail_text("每局最多1件；进入本局背包后，仍需装备才生效。",15,DemoClockworkTheme.MUTED)
	DemoUiModalMetrics.apply(_root)
	DemoUiModalMetrics.trap_focus(_root.rows)
	_wire_focus()
	_detail_scroll.scroll_vertical = 0

func _display_reason(reason: String) -> String:
	var labels := {"requires_discovered":"请先在冒险中发现这件道具。","not_discovered":"请先在冒险中发现这件道具。","insufficient_notes":"音符不足。","unavailable":"当前无法操作。","already_unlocked":"已经永久解锁。"}
	if labels.has(reason): return labels[reason]
	if reason.is_empty(): return ""
	return ItemPresentation.reason(reason,"条件尚未满足。")

func _request_item(id: StringName, selecting: bool, generation: int, revision: int, detail_generation: int) -> void:
	if not _view_current(generation) or _submitted or revision != _profile_revision or detail_generation != _detail_generation or id != _focused_id or not _rows.has(id): return
	var row: Dictionary = _rows[id]
	# Clearing an existing choice is valid even after its catalog entry was
	# disabled; the global action also handles a completely removed definition.
	if selecting and id == _selected_id:
		_request_clear(generation,revision)
		return
	if (not bool(row.get("discovered",false)) and bool(row.get("requires_discovered",true))) or not bool(row.get("available",false)): return
	if selecting != bool(row.get("unlocked",false)): return
	if not selecting and _notes < maxi(0,int(row.get("price",0))): return
	_submitted = true
	if is_instance_valid(_action): _action.disabled = true
	if is_instance_valid(_clear_button): _clear_button.disabled = true
	if selecting:
		requested_select.emit(&"" if id == _selected_id else id,revision)
	else:
		requested_unlock.emit(id,revision)

func _request_clear(generation: int, revision: int) -> void:
	if not _view_current(generation) or _submitted or revision != _profile_revision or _selected_id.is_empty(): return
	_submitted = true
	if is_instance_valid(_action): _action.disabled = true
	if is_instance_valid(_clear_button): _clear_button.disabled = true
	requested_select.emit(&"",revision)

func _request_close(generation: int) -> void:
	if not _view_current(generation) or _close_pending: return
	_close_pending = true
	requested_close.emit()

func set_status(message: String, is_error: bool = true) -> void:
	if not opened or not is_instance_valid(_status): return
	_status.text = message
	_status.visible = not message.is_empty()
	_status.add_theme_color_override("font_color",DemoClockworkTheme.CORAL if is_error else DemoClockworkTheme.TEAL)
	# Failure can be retried against the same still-current snapshot. Successful
	# transactions must refresh through show_codex to supply new authoritative state.
	if is_error:
		_submitted = false
		if is_instance_valid(_clear_button): _clear_button.disabled = _selected_id.is_empty()
		_render_detail()

func show_error(message: String) -> void:
	set_status(message,true)

func _layout() -> void:
	if not opened or not is_instance_valid(_body) or not is_instance_valid(_root): return
	var scale := DemoUiModalMetrics.ui_scale(get_viewport())
	var safe := DemoUiModalMetrics.safe_rect(get_viewport())
	var physical_width := safe.size.x*scale
	_body.vertical = physical_width < 740
	var available_height := safe.size.y-(80.0/scale if DemoUiModalMetrics.compact(get_viewport()) else 96.0)
	_body.custom_minimum_size.y = clampf(available_height-150.0/scale,210.0/scale,430.0/scale)
	_catalog_scroll.custom_minimum_size.x = 0 if _body.vertical else 340.0/scale
	_detail_scroll.custom_minimum_size.x = 0 if _body.vertical else 240.0/scale
	if _body.vertical:
		_catalog_scroll.custom_minimum_size.y = 220.0/scale
		_detail_scroll.custom_minimum_size.y = 240.0/scale
	else:
		_catalog_scroll.custom_minimum_size.y = 0
		_detail_scroll.custom_minimum_size.y = 0
	var width := _catalog_scroll.size.x if _catalog_scroll.size.x > 1 else safe.size.x*.48
	_grid.columns = maxi(1,int(floor((width-16)/(100.0/scale))))
	for id: StringName in _tiles:
		var tile := _tiles[id] as Button
		tile.custom_minimum_size = Vector2(92.0/scale,118.0/scale)
	_wire_focus()

func _wire_focus() -> void:
	if not is_instance_valid(_close_button) or not is_instance_valid(_grid): return
	var columns := maxi(1,_grid.columns)
	for index: int in _order.size():
		var tile := _tiles[_order[index]] as Button
		var left: Control = _tiles[_order[maxi(0,index-1)]]
		var right: Control = _tiles[_order[mini(_order.size()-1,index+1)]]
		var above: Control = _tiles[_order[index-columns]] if index >= columns else _close_button
		var below: Control = _tiles[_order[index+columns]] if index+columns < _order.size() else _action if is_instance_valid(_action) and not _action.disabled else _close_button
		tile.focus_neighbor_left = tile.get_path_to(left)
		tile.focus_neighbor_right = tile.get_path_to(right)
		tile.focus_neighbor_top = tile.get_path_to(above)
		tile.focus_neighbor_bottom = tile.get_path_to(below)

func _process(_delta: float) -> void:
	if not opened or not is_instance_valid(_body): return
	var signature := [get_viewport().get_visible_rect().size,get_viewport().get_screen_transform(),_catalog_scroll.size,DemoUiModalMetrics.safe_rect(get_viewport())]
	if signature != _layout_signature:
		_layout_signature = signature
		_layout()

func hide_codex() -> void:
	_generation += 1
	_detail_generation += 1
	opened = false
	_submitted = false
	_close_pending = false
	for adapter: Node in _touch_adapters:
		if is_instance_valid(adapter): adapter.call("cancel",&"codex_close")
	_touch_adapters.clear()
	if is_instance_valid(_root):
		_root.restore_focus()
		remove_child(_root)
		_root.queue_free()
	_root = null
	_body = null
	_catalog_scroll = null
	_grid = null
	_detail_scroll = null
	_detail = null
	_status = null
	_close_button = null
	_clear_button = null
	_action = null
	_tiles.clear()
	_rows.clear()
	_order.clear()
	_layout_signature.clear()
