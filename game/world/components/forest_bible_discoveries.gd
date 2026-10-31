class_name ForestBibleDiscoveries
extends CanvasLayer
## Local reader only. The app must queue commit_pending after its damage batch.
signal opened
signal closed
signal confirm_requested
signal acquired(receipt: Dictionary)
const INTERACT_DISTANCE := 90.0
var last_error := ""
var _rows: Dictionary = {}
var _state: PlainsRegionState
var _lifetime: DemoLifetime
var _health: HealthState
var _wallet: RunWallet
var _rewards: RewardService
var _root: Control
var _body: Label
var _status: Label
var _confirm: Button
var _current := ""
var _token: DemoToken
var _health_epoch := 0
var _opened_frame := 0
var _pending := false
var _committing := false
var _configured := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 32

func configure(rows: Array, state: PlainsRegionState, lifetime: DemoLifetime, health: HealthState, wallet: RunWallet, rewards: RewardService) -> bool:
	if _configured or state == null or state.manifest_hash.is_empty() or lifetime == null or not lifetime.active or health == null or health.terminal or wallet == null or rewards == null:
		return false
	if rewards.lifetime != lifetime or rewards.build == null or not ForestBibleDiscoveryCatalog.valid_rows(rows): return false
	for row: Dictionary in rows:
		_rows[str(row.id)] = row.duplicate(true)
	_state = state
	_lifetime = lifetime
	_health = health
	_wallet = wallet
	_rewards = rewards
	_configured = true
	return true

func nearby(point: Vector2) -> String:
	if not _configured or not point.is_finite(): return ""
	var closest := ""
	var distance := INTERACT_DISTANCE
	for id: String in _rows:
		var row: Dictionary = _rows[id]
		var next_distance := point.distance_to(Vector2(row.position[0], row.position[1]))
		if next_distance < distance:
			distance = next_distance
			closest = id
	return closest

func is_claimed(id: String) -> bool:
	return _state != null and _state.claimed.get(id, false) == true

func interact(point: Vector2, token: DemoToken) -> bool:
	if not is_inside_tree() or is_open() or not _configured or not _lifetime.accepts(token) or _health.terminal: return false
	var id := nearby(point)
	if id.is_empty(): return false
	_current = id
	# Retain our own token; caller mutation cannot change the opened read's scope.
	_token = _lifetime.token()
	_health_epoch = _health.epoch
	_opened_frame = Engine.get_process_frames()
	_pending = false
	last_error = ""
	_show_page(ForestBibleDiscoveryCatalog.definition(str(_rows[id].definition_id)))
	opened.emit()
	return true

func is_open() -> bool:
	return is_instance_valid(_root)

func _process(_delta: float) -> void:
	if is_open() and not _committing and not _scope_valid(): close()

func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _scope_valid() -> bool:
	return _configured and _lifetime.accepts(_token) and not _health.terminal and _health.epoch == _health_epoch

func _page_matches() -> bool:
	if not is_open() or not is_instance_valid(_body) or not _body.is_visible_in_tree() or not _root.is_visible_in_tree(): return false
	if Engine.get_process_frames() <= _opened_frame or not _rows.has(_current): return false
	return _body.text == str(ForestBibleDiscoveryCatalog.definition(str(_rows[_current].definition_id)).text)

func _show_page(definition: Dictionary) -> void:
	_root = Control.new()
	_root.name = "ForestDiscoveryPage"
	_root.theme = UnderworldUI.create_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.03, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_root.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var viewport_size := get_viewport().get_visible_rect().size
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(620.0, maxf(220.0, viewport_size.x - 40.0)), 0.0)
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	panel.add_child(rows)
	var title := Label.new()
	title.text = str(definition.title)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	rows.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "ReadingScroll"
	scroll.custom_minimum_size = Vector2(0.0, clampf(viewport_size.y - 270.0, 80.0, 250.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var reading := VBoxContainer.new()
	reading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reading.add_theme_constant_override("separation", 12)
	scroll.add_child(reading)
	_body = Label.new()
	_body.name = "StoryText"
	_body.text = str(definition.text)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reading.add_child(_body)
	var benefit := Label.new()
	benefit.text = "已记下，重复阅读不会再次获得奖励。" if is_claimed(_current) else ForestBibleDiscoveryCatalog.benefit_text(str(_rows[_current].definition_id))
	benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	benefit.add_theme_color_override("font_color", UnderworldUI.BRASS)
	reading.add_child(benefit)
	var route := Label.new()
	route.name = "ReturnRoute"
	route.text = "回程：" + str(_rows[_current].get("return_hint", definition.return_hint))
	route.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route.add_theme_color_override("font_color", UnderworldUI.MUTED)
	reading.add_child(route)
	_status = Label.new()
	_status.visible = false
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UnderworldUI.HURT)
	rows.add_child(_status)
	_confirm = Button.new()
	_confirm.name = "ConfirmDiscovery"
	_confirm.text = "继续探索" if is_claimed(_current) else "记下线索" if definition.kind == "story" else "取用物资并记下线索"
	_confirm.pressed.connect(_request_confirmation)
	rows.add_child(_confirm)
	var leave := Button.new()
	leave.name = "LeaveDiscovery"
	leave.text = "离开"
	leave.pressed.connect(close)
	rows.add_child(leave)
	# Focus starts on the text, so the interaction key cannot also claim the find.
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.grab_focus()

func _show_error(message: String) -> void:
	last_error = message
	_status.text = message
	_status.visible = true
	_confirm.disabled = false

func _request_confirmation() -> void:
	if _pending or _committing or not is_open(): return
	if not _scope_valid() or not _page_matches():
		close()
		return
	if is_claimed(_current):
		close()
		return
	var definition := ForestBibleDiscoveryCatalog.definition(str(_rows[_current].definition_id))
	if definition.kind == "heart" and _health.current >= _health.capacity:
		_show_error("当前生命已满，补给留在这里，回程时仍可取用。")
		return
	_pending = true
	_confirm.disabled = true
	confirm_requested.emit()

func commit_pending(point: Vector2) -> bool:
	if not _pending or _committing or not is_inside_tree() or not is_open(): return false
	_pending = false
	if not _scope_valid() or not _page_matches() or nearby(point) != _current or is_claimed(_current):
		close()
		return false
	var id := _current
	var row: Dictionary = _rows[id]
	var definition := ForestBibleDiscoveryCatalog.definition(str(row.definition_id))
	var source := StringName("forest_discovery:%d:%d:%s:%s" % [_token.run_epoch, _token.stage_epoch, _state.manifest_hash, id])
	var receipt := {"id":id, "definition_id":str(row.definition_id), "kind":str(definition.kind), "story_read":true, "amount":0.0, "item":"", "approach_route":str(row.approach_route), "return_route":str(row.return_route), "source_id":str(source)}
	_committing = true
	var accepted := false
	match str(definition.kind):
		"coin":
			accepted = _wallet.grant(int(definition.amount), source)
			if accepted: receipt.amount = int(definition.amount)
		"heart":
			if _health.current < _health.capacity:
				var result := SupplyHealEffect.apply(_health, float(definition.amount), source)
				accepted = result.accepted() and result.amount_applied > 0.0
				if accepted: receipt.amount = result.amount_applied
		"item":
			var equipment := ForestBibleDiscoveryCatalog.item(str(row.definition_id))
			if equipment != null:
				var items: Array[ItemDefinition] = [equipment]
				var offer := _rewards.create_cache_offer(source, items, source)
				if offer != null:
					var request := RewardClaimRequest.new()
					request.token = _token
					request.offer_id = offer.offer_id
					request.option_id = equipment.stable_id
					request.claim_id = StringName(str(source) + "/claim")
					accepted = _rewards.claim(request).accepted()
					if accepted: receipt.item = str(equipment.stable_id)
		"story": accepted = true
	_committing = false
	if not accepted:
		if is_open():
			_show_error("当前无法取用，物资仍留在原处。")
			# Root resumed to run this post-damage action. Restore the reading pause.
			opened.emit()
		return false
	_state.claimed[id] = true
	close()
	acquired.emit(receipt.duplicate(true))
	return true

func close() -> void:
	var was_open := is_open()
	_pending = false
	_current = ""
	_token = null
	if is_instance_valid(_root):
		remove_child(_root)
		_root.queue_free()
	_root = null
	_body = null
	_status = null
	_confirm = null
	if was_open: closed.emit()

func _exit_tree() -> void:
	close()
