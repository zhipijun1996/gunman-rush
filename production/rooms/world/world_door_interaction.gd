extends Node
## A door's handle is an authored world position. A knock, an unlock and a
## passage each retain their own input and committed result.
var host: Node
var session: OrdinaryRoomSession
var handles: Array[Dictionary] = []
var hint: Label
var message := ""
var message_time := 0.0

func install(owner_node: Node, document: Dictionary) -> void:
	host = owner_node
	session = host.active
	for door: Dictionary in session.content_context.connections:
		var discovery: Dictionary = door.get("discovery",{})
		var inside: bool = door.connection_type == "interior"
		var covered: bool = discovery.get("source_room") == document.room_id and discovery.get("runtime_plan",{}).get("kind") == "interact_cover"
		if not inside and not covered: continue
		var id: String = door.id if inside else discovery.event
		var site: Dictionary = document.get("sites",{}).get(id,{})
		if not WorldRoomValidation.vector(site.get("at")): continue
		handles.append({"at":FixedWorldProvider.point(site.at),"door":door,"covered":covered,"inside":inside})
	if handles.is_empty():
		queue_free()
		return
	session.add_child(self)
	hint = Label.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -310
	hint.offset_right = 310
	hint.offset_top = -96
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	hint.add_theme_font_size_override("font_size",22)
	hint.add_theme_constant_override("outline_size",5)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	session.controller.interact_requested.connect(interact)
	session.controller.router.set_meta(&"world_up_interaction",true)

func nearby() -> Dictionary:
	if host.crossing or not session.lifetime.active or not session.controller.active or not session.player.is_on_floor() or session.controller.has_pending_damage():
		return {}
	var best := {}
	var reach := 44.0 * 44.0
	for handle: Dictionary in handles:
		var distance := session.player.position.distance_squared_to(handle.at)
		if distance <= reach:
			reach = distance
			best = handle
	return best

func _physics_process(delta: float) -> void:
	var handle := nearby()
	hint.text = ""
	message_time = maxf(0.0,message_time-delta)
	if handle.is_empty(): return
	if message_time > 0:
		hint.text = message
		return
	var door: Dictionary = handle.door
	if handle.covered and not session.state.has(door.discovery.event):
		var event := session.content_catalog.lookup("events",door.discovery.event)
		hint.text = session.controller.router.interact_prompt(event.row.label)
	elif handle.inside:
		hint.text = session.controller.router.interact_prompt(door.entrances[session.room.room_id].label)

func interact() -> void:
	var handle := nearby()
	if handle.is_empty(): return
	var door: Dictionary = handle.door
	if handle.covered and not session.state.has(door.discovery.event):
		var event: Dictionary = session.content_catalog.lookup("events",door.discovery.event).row
		if not session.content_catalog.condition_match(event,session.state.value.flags,session.state.value.services.equipped).matches:
			return
		var next := session.state.candidate()
		next.flags.append(event.id)
		next.receipts[event.id] = {"source":event.id,"source_hash":MetaSaveService.canonical_json(event).sha256_text(),"revision":session.state.revision+1}
		if session.state.commit(next,session.state.revision):
			GameAudio.cue(session,&"door")
			message = event.completion_text
		else:
			message = "没能记下这次发现，请重试。"
		message_time = 2.5
		return
	if handle.inside:
		if not session.content_catalog.condition_match(door,session.state.value.flags,session.state.value.services.equipped).matches:
			message = "入口暂未开启。"
			message_time = 2.5
			return
		host.enter_interior(door)
