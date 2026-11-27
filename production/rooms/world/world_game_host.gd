class_name WorldGameHost
extends Node2D
## Registered world rooms use ordinary sessions and one
## world-state ledger. Crossings are taken by movement through an authored edge.
signal room_changed(room_id: String)
signal crossing_started(source: String, edge: String, destination: String)
signal crossing_finished(room_id: String, edge: String, ok: bool)

const Passage := preload("res://rooms/world/world_passage.gd")

const TerraceLesson := preload("res://rooms/world/terrace_lesson.gd")
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const MAP := preload("res://rooms/world/world_map.gd")
var catalog := WorldContentCatalog.new()
var active: OrdinaryRoomSession
var active_doc := {}
var last_error := ""
var follow_camera: WorldCamera
var passage_sky := {}
var panorama: Sprite2D
var terrace: TerraceLesson
var lesson_progress := {}
var storage: WorldSaveService
var reset_dialog: WorldNewGameDialog
var startup_panel: VBoxContainer
var notice := Label.new()
var room_title := Label.new()
var title_remaining := 0.0
var route_map: Control
var crossing := false
var curtain := ColorRect.new()
var previous_center := Vector2.ZERO
var waiting_for_clearance := ""
var passage_attempts := 0
var issue_remaining := 0.0
var entry_trace: Array[Vector2] = []

func _ready() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.offset_top = 14
	notice.offset_bottom = 55
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font",FONT)
	notice.add_theme_font_size_override("font_size",24)
	notice.add_theme_constant_override("outline_size",5)
	notice.add_theme_color_override("font_outline_color",Color("232a2b"))
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.text = "回到田埂，跳起后朝身后偏下开枪。"
	notice.hide()
	ui.add_child(room_title)
	room_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	room_title.offset_left = -520
	room_title.offset_right = -20
	room_title.offset_top = 17
	room_title.offset_bottom = 48
	room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	room_title.add_theme_font_override("font",FONT)
	room_title.add_theme_font_size_override("font_size",18)
	room_title.add_theme_constant_override("outline_size",4)
	room_title.add_theme_color_override("font_outline_color",Color("232a2b"))
	room_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_layer := CanvasLayer.new()
	cover_layer.layer = 100
	add_child(cover_layer)
	cover_layer.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	curtain.hide()
	start_world()

func start_world() -> void:
	if is_instance_valid(startup_panel):
		startup_panel.hide()
		startup_panel.queue_free()
		startup_panel = null
	var result := catalog.load_locked()
	if result.ok:
		result = catalog.load_bindings(binding_path())
	if result.ok:
		result = startup_destination()
	if storage is PlayableWorldSave and reset_dialog == null:
		reset_dialog = WorldNewGameDialog.mount(self)
		reset_dialog.progress_replaced.connect(func(): get_tree().reload_current_scene())
	if result.ok:
		enter_room(result.room,"")
	if active != null:
		route_map = MAP.mount(self)
		return
	last_error = last_error if result.ok else str(result.error)
	startup_panel = VBoxContainer.new()
	notice.get_parent().add_child(startup_panel)
	startup_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var message := Label.new()
	message.text = "无法打开游戏进度　" + last_error
	message.add_theme_font_override("font",FONT)
	startup_panel.add_child(message)
	var retry := Button.new()
	retry.text = "重试"
	retry.add_theme_font_override("font",FONT)
	retry.pressed.connect(start_world)
	startup_panel.add_child(retry)
	if reset_dialog != null: startup_panel.add_child(new_game_button())

func new_game_button() -> Button:
	var button := Button.new()
	button.text = "重新开局"
	button.custom_minimum_size = Vector2(145,46)
	button.add_theme_font_override("font",FONT)
	button.pressed.connect(reset_dialog.open)
	return button

func binding_path() -> String:
	return "res://config/imported_world/bindings.json"

func startup_destination() -> Dictionary:
	if storage == null:
		var profile := PlayableWorldSave.new()
		profile.configure_world()
		storage = profile
	return (storage as PlayableWorldSave).startup_room()

func has_room(id: String) -> bool:
	return catalog.binding("rooms",id).ok

func read_destination(id: String) -> Dictionary:
	var bound := catalog.room_document(id)
	if not bound.ok: return bound
	return WorldRoomDocument.read(bound.path)

func enter_room(id: String, edge: String, prepared: Dictionary = {}, received := Vector2.INF, respawning := false) -> void:
	var doc := read_destination(id) if prepared.is_empty() else prepared
	if doc.has("error"):
		last_error = doc.error
		if active==null: push_warning(last_error)
		return
	var next := OrdinaryRoomSession.new()
	add_child(next)
	last_error = next.open(doc,storage if active == null else null,active,catalog,edge,respawning)
	if not last_error.is_empty():
		next.queue_free()
		if active==null: push_warning(last_error)
		return
	var sky_offset := Vector2.INF
	if active != null:
		if not edge.is_empty() and active_doc.exits.has(edge):
			sky_offset = passage_sky.get("offset",Vector2.ZERO) + FixedWorldProvider.point(active_doc.exits[edge].point) - FixedWorldProvider.point(doc.exits[edge].point)
		else:
			passage_sky.clear()
		active.hide()
	active = next
	active.respawn_requested.connect(_respawn)
	if active.content_sites != null: active.content_sites.station_departure.connect(travel_station)
	active_doc = doc
	# Enter on the destination's receiving apron before its first physics tick.
	# Keep its document unchanged so every door has the same content identity.
	if received.is_finite():
		active.player.reset_at(received)
	previous_center = active.player.position
	active.player.repositioned.connect(_reset_sample)
	follow_camera = active.camera
	notice.hide()
	terrace = null
	var handles := preload("res://rooms/world/world_door_interaction.gd").new()
	handles.install(self,doc)
	if doc.get("scenery",{}).has("terrace_lesson"):
		terrace = TerraceLesson.new()
		terrace.install(self,doc)
	if crossing: _lock_session(true)
	follow_camera.force_update_scroll()
	panorama = preload("res://rooms/world/world_backdrop.gd").mount(active,doc,passage_sky,sky_offset).panorama
	var room_name := str(catalog.lookup("rooms",id).row.name)
	room_title.text = id+" · "+room_name+("" if catalog.binding("rooms", id).ok else " · 接入段")
	title_remaining = 2.5
	room_title.modulate.a = 1.0
	room_changed.emit(id)

func _process(delta: float) -> void:
	title_remaining = maxf(0.0,title_remaining-delta)
	room_title.modulate.a = clampf(title_remaining/.5,0.0,1.0)
	if issue_remaining>0:
		issue_remaining = maxf(0.0,issue_remaining-delta)
		notice.visible = issue_remaining>0

func _reset_sample() -> void:
	previous_center = active.player.position

func _physics_process(delta: float) -> void:
	if active==null or crossing or not active.controller.active or active.controller.has_pending_damage(): return
	if terrace != null: terrace.update_field(delta)
	var before := previous_center
	var at := active.player.position
	previous_center = at
	if not waiting_for_clearance.is_empty():
		if not active_doc.exits.has(waiting_for_clearance) or Passage.is_inside(active_doc.exits[waiting_for_clearance],at):
			waiting_for_clearance = ""
	for id: String in active_doc.exits:
		var gate: Dictionary = active_doc.exits[id]
		if not gate.has("span") or waiting_for_clearance==id or not Passage.crossed(gate,before,at):
			continue
		var passage := catalog.physical_passage(active.room.room_id,id)
		if not passage.ok: continue
		transfer(id,passage.destination)
		break

func _lock_session(value: bool) -> void:
	active.controller.router.clear("world_handoff" if value else "world_control_restored")
	active.controller.active = not value
	active.equipment_menu.set_process_input(not value)
	if is_instance_valid(route_map):
		route_map.set_process_input(not value)
	if value:
		active.controller.shoot_ability.clear_projectiles()

func _uncover(seconds := Passage.REVEAL_SECONDS) -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(curtain,"color:a",0.0,seconds)
	await tween.finished
	curtain.hide()

func _respawn() -> void:
	crossing = true
	waiting_for_clearance = ""
	_lock_session(true)
	var source := active
	var settings := source.player.damage_feedback
	var dt := 1.0 / Engine.physics_ticks_per_second
	# Let the original body finish its death pose and fall onto real terrain.
	var age := 0.0
	while age < settings.death_body_seconds + settings.death_conceal_seconds:
		await get_tree().physics_frame
		if not source.controller.router.has_application_focus: continue
		if not source.player.is_on_floor(): source.player.step(0.0,dt)
		age += dt
		if age > settings.death_body_seconds:
			curtain.color = Color(0,0,0,clampf((age-settings.death_body_seconds)/settings.death_conceal_seconds,0,1))
			curtain.show()
	var rest: Dictionary = source.state.value.rest
	var doc := read_destination(rest.room)
	var at := FixedWorldProvider.point(rest.point)
	while active == source:
		last_error = str(doc.get("error",""))
		if last_error.is_empty():
			last_error = await Passage.validate_landing(self,doc,{"spawn":rest.point},at,source.player)
		if last_error.is_empty():
			enter_room(rest.room,"",doc,at,true)
		if active != source: break
		# A storage failure leaves the original ledger authoritative. Retry the
		# same death after a delay, without spending a second cycle or receipt.
		curtain.hide()
		notice.text = "复活点暂时无法恢复，稍后自动重试。"
		notice.modulate.a = 1.0
		notice.show()
		await get_tree().create_timer(1.0,false,true).timeout
		curtain.color = Color.BLACK
		curtain.show()
	for frame in 30:
		await get_tree().physics_frame
		active.player.step(0.0,dt)
		if active.player.is_on_floor(): break
	await _uncover(settings.death_reveal_seconds)
	active.policy.protect_player()
	_lock_session(false)
	crossing = false

func enter_interior(door: Dictionary) -> void:
	if crossing or door.connection_type != "interior": return
	var from := active.room.room_id
	if from not in [door.a,door.b] or not active_doc.get("sites",{}).has(door.id): return
	var destination: String = door.b if from == door.a else door.a
	await _transfer_to_site(from,door.id,destination,door.id)

func travel_station(origin: String, target: String, revision: int) -> void:
	if crossing or revision != active.state.revision or origin == target: return
	var sites := active.content_sites
	if sites == null or not sites.near(origin) or not active.player.is_on_floor(): return
	if not active.state.value.receipts.has(origin) or not active.state.value.receipts.has(target): return
	var stations: Array = catalog.object("transport").value.stations
	var from := active.room.room_id
	var departure := stations.filter(func(s: Dictionary): return s.id == origin and s.room == from)
	var arrivals := stations.filter(func(s: Dictionary): return s.id == target)
	if departure.size() != 1 or arrivals.size() != 1 or not has_room(arrivals[0].room): return
	await _transfer_to_site(from,origin,arrivals[0].room,target)

func _transfer_to_site(from: String, departure: String, destination: String, arrival: String) -> void:
	crossing = true
	passage_attempts += 1
	_lock_session(true)
	curtain.color = Color.BLACK
	curtain.show()
	crossing_started.emit(from,departure,destination)
	await get_tree().process_frame
	await get_tree().process_frame
	var doc := read_destination(destination)
	var at := Vector2.ZERO
	var site: Dictionary = doc.get("sites",{}).get(arrival,{})
	last_error = "receiving_site_missing"
	if WorldRoomValidation.vector(site.get("at")):
		at = FixedWorldProvider.point(site.at)
		last_error = await Passage.validate_landing(self,doc,{"spawn":site.at},at,active.player)
	if last_error.is_empty():
		enter_room(destination,arrival,doc,at)
		if last_error.is_empty():
			for i: int in 12:
				await get_tree().physics_frame
				active.player.step(0,get_physics_process_delta_time())
				if active.player.is_on_floor(): break
	await _uncover()
	if not last_error.is_empty():
		issue_remaining = 2.5
		notice.text = "无法进入房间，请重试。"
		notice.modulate.a = 1.0
		notice.show()
	previous_center = active.player.position
	_lock_session(false)
	crossing = false
	crossing_finished.emit(active.room.room_id,arrival,last_error.is_empty())

func transfer(edge: String, destination: String) -> void:
	var from: String = active.room.room_id
	var source_gate: Dictionary = active_doc.exits[edge]
	var incoming := active.player.velocity
	var current := active.player.position
	var rollback := FixedWorldProvider.point(source_gate.spawn)
	crossing = true
	waiting_for_clearance = edge
	passage_attempts += 1
	last_error = ""
	_lock_session(true)
	curtain.color = Color.BLACK
	curtain.show()
	crossing_started.emit(from,edge,destination)
	# Keep one complete covered frame before moving the camera or changing worlds.
	await get_tree().process_frame
	await get_tree().process_frame
	var doc := read_destination(destination)
	var at := Vector2.ZERO
	var contract: Dictionary = catalog.lookup("doors",edge).row
	var cover: String = contract.get("discovery",{}).get("runtime_plan",{}).get("kind","")
	if cover == "breakable_cover" and not active.state.value.receipts.has("passage_break:"+edge):
		last_error = "passage_requirements_unmet"
	elif not catalog.passage_access(from,edge,active.state.value.flags,active.state.value.services.equipped).matches:
		last_error = "passage_requirements_unmet"
	elif doc.has("error") or not doc.get("exits") is Dictionary or not doc.exits.has(edge):
		last_error = "passage_destination_missing"
	elif not WorldRoomValidation.passage_error(doc.exits).is_empty() or not doc.exits[edge].has("span"):
		last_error = "passage_geometry_invalid"
	else:
		var receiving: Dictionary = doc.exits[edge]
		if FixedWorldProvider.point(receiving.direction)!=-FixedWorldProvider.point(source_gate.direction):
			last_error = "passage_direction_mismatch"
		else:
			at = Passage.mapped_position(source_gate,receiving,current)
			last_error = await Passage.validate_landing(self,doc,receiving,at,active.player)
	if last_error.is_empty():
		enter_room(destination,edge,doc,at)
	if not last_error.is_empty():
		active.player.reset_at(rollback+Vector2.UP)
		for frame: int in 30:
			await get_tree().physics_frame
			active.player.step(0,get_physics_process_delta_time())
			if active.player.is_on_floor(): break
		follow_camera.force_update_scroll()
		await _uncover()
		issue_remaining = 2.5
		notice.text = "入口暂不可通行。可离开门口，再走回来重试。"
		if last_error == "passage_requirements_unmet":
			var door: Dictionary = catalog.lookup("doors",edge).row
			if door.get("one_way_from") != null and not active.state.has(door.unlock_flag):
				var latch_side: Dictionary = catalog.lookup("rooms",door.one_way_from).row
				notice.text = "门闩需要从「%s」一侧开启。" % latch_side.name
		notice.modulate.a = 1.0
		notice.show()
		_lock_session(false)
		crossing = false
		crossing_finished.emit(from,edge,false)
		return
	var direction := FixedWorldProvider.point(source_gate.direction)
	follow_camera.force_update_scroll()
	await _uncover()
	var target := FixedWorldProvider.point(doc.exits[edge].spawn)
	entry_trace = [at]
	var stable := await land_after_crossing(direction,incoming,target)
	if not stable:
		# The fallback was checked in the destination physics world before the
		# commit. Re-cover any interrupted entry before restoring its safe apron.
		curtain.color = Color.BLACK
		curtain.show()
		active.player.reset_at(target+Vector2.UP)
		for i: int in 30:
			await get_tree().physics_frame
			active.player.step(0,get_physics_process_delta_time())
			if active.player.is_on_floor(): break
		follow_camera.force_update_scroll()
		await _uncover()
		last_error = "arrival_motion_interrupted"
	active.player.reset_motion()
	active.controller.jump_ability.on_landed()
	previous_center = active.player.position
	_lock_session(false)
	crossing = false
	crossing_finished.emit(destination,edge,true)

func land_after_crossing(direction: Vector2, incoming: Vector2, target: Vector2) -> bool:
	var body := active.player
	var dt := 1.0/Engine.physics_ticks_per_second
	var stride_frames := ceili(Passage.WALK_SECONDS/dt)
	body.normal_velocity.y = incoming.y
	if direction.y<0:
		# A paired upward door shows a short, steered physical hop out of the
		# opening. Its nearest safe shoulder was checked before committing.
		# Use the incoming ascent with a short arc calculated from the nearest
		# lip. A long held jump would enter the next recess before this landing.
		var half_height := ((body.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size.y*.5
		var rise := maxf(half_height,body.position.y-target.y) + half_height
		var speed := sqrt(2.0*body.tuning.gravity*rise)
		body.normal_velocity.y = -clampf(-incoming.y,speed,speed+65.0)
	for frame: int in ceili(1.4/dt):
		await get_tree().physics_frame
		var axis := 0.0
		if direction.x!=0 and frame<stride_frames:
			axis = direction.x*Passage.WALK_AXIS
		elif direction.y<0:
			axis = clampf((target.x-body.position.x)/12.0,-1.0,1.0)
		body.step(axis,dt)
		entry_trace.append(body.position)
		if direction.y<0:
			if absf(target.x-body.position.x)>4 or absf(target.y-body.position.y)>4: continue
		if (direction.x==0 or frame+1>=stride_frames) and body.is_on_floor(): return true
	return false
