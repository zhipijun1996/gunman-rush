extends Node2D
## The same solid inspection plate can be released from either authored handle.
var session: OrdinaryRoomSession
var event: Dictionary
var handles := PackedVector2Array()
var bounds: Rect2
var plate := StaticBody2D.new()
var hint := Label.new()
var open := false
var failed := false

func install(owner_session: OrdinaryRoomSession, row: Dictionary, site: Dictionary) -> void:
	session = owner_session
	event = row
	bounds = FixedWorldProvider.rect(site.hatch_rect)
	handles.append(FixedWorldProvider.point(site.at))
	for extra: Array in site.get("other_approaches",[]): handles.append(FixedWorldProvider.point(extra))
	session.room.add_child(self)
	plate.collision_mask = 0
	plate.position = bounds.get_center()
	var shape := RectangleShape2D.new()
	shape.size = bounds.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	plate.add_child(collision)
	add_child(plate)
	hint.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_constant_override("outline_size",4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hint.hide()
	session.controller.interact_requested.connect(_interact)
	session.state.committed.connect(refresh)
	refresh(session.state.revision)

func refresh(_revision: int) -> void:
	open = session.state.has(event.id)
	plate.collision_layer = 0 if open else 1
	hint.visible = false
	queue_redraw()

func _nearest() -> Vector2:
	if open or not session.lifetime.active or not session.controller.active or session.controller.has_pending_damage() or not session.player.is_on_floor(): return Vector2.INF
	for at: Vector2 in handles:
		if session.player.position.distance_to(at)<44: return at
	return Vector2.INF

func _physics_process(_delta: float) -> void:
	var at := _nearest()
	hint.visible = at.is_finite()
	if hint.visible:
		hint.position = at + Vector2(-45,-65)
		hint.text = session.controller.router.interact_prompt("再试一次" if failed else "拉动释放柄")

func _interact() -> void:
	if not _nearest().is_finite() or not session.content_catalog.condition_match(event,session.state.value.flags,session.state.value.services.equipped).matches: return
	var next := session.state.candidate()
	next.flags.append(event.id)
	next.receipts[event.id] = {"source":event.id,"source_hash":MetaSaveService.canonical_json(event).sha256_text(),"revision":session.state.revision+1}
	failed = not session.state.commit(next,session.state.revision)
	if not failed: GameAudio.cue(self,&"door")

func _draw() -> void:
	if not open: MechanismRegionArt.panel(self,bounds)
	for at: Vector2 in handles:
		MechanismRegionArt.stamp(self,"mount",at+Vector2(0,12),Vector2(31,13))
		draw_line(at+Vector2(0,8),at+Vector2(8 if open else -8,-8),Color("#dfb477"),4)
