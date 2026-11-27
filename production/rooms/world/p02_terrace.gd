class_name FieldTerracePilot
extends Node2D
## The opening rooms and their receiving passages use ordinary sessions and one
## world-state ledger. Crossings are taken by movement through an authored edge.
signal room_changed(room_id: String)
signal crossing_started(source: String, edge: String, destination: String)
signal crossing_finished(room_id: String, edge: String, ok: bool)

const Passage := preload("res://rooms/world/p02_passage_transition.gd")

const CONNECTIONS := "res://rooms/world/p02_connections/"
const CHIME_SHADER := preload("res://rooms/world/p02_chime.gdshader")
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const MAP := preload("res://rooms/world/p02_route_map.gd")
var catalog := WorldContentCatalog.new()
var active: OrdinaryRoomSession
var connection: Node
var active_doc := {}
var last_error := ""
var follow_camera: Camera2D
var passage_sky := {}
var panorama: Sprite2D
var bell_mount: Sprite2D
var look_direction := 1.0
var grounded_on_west := false
var west_jump := false
var west_recoil := false
var landed_on_terrace := false
var was_airborne := false
var retry_hint_shown := false
var chime_time := 0.0
var hint_remaining := 0.0
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
	var result := catalog.load_locked()
	if result.ok:
		result = catalog.load_bindings("res://config/imported_world/bindings.json")
	if not result.ok:
		push_error(result.error)
		return
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
	enter_room("P01","")
	if active != null:
		route_map = MAP.mount(self)

func read_destination(id: String) -> Dictionary:
	var bound := catalog.room_document(id)
	if bound.ok:
		return WorldRoomDocument.read(bound.path)
	if bound.error != "room_not_bound": return bound
	return WorldRoomDocument.read(CONNECTIONS + id + ".json")

func enter_room(id: String, edge: String, prepared: Dictionary = {}, received := Vector2.INF, respawning := false) -> void:
	var doc := read_destination(id) if prepared.is_empty() else prepared
	if doc.has("error"):
		last_error = doc.error
		if active==null: push_error(last_error)
		return
	var next := OrdinaryRoomSession.new()
	add_child(next)
	last_error = next.open(doc,null,active,catalog,edge,respawning)
	if not last_error.is_empty():
		next.queue_free()
		if active==null: push_error(last_error)
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
	active_doc = doc
	# Enter on the destination's receiving apron before its first physics tick.
	# Keep its document unchanged so every door has the same content identity.
	if not edge.is_empty():
		active.player.reset_at(received if received.is_finite() else FixedWorldProvider.point(doc.exits[edge].spawn))
	previous_center = active.player.position
	active.player.repositioned.connect(_reset_sample)
	var cameras := active.player.find_children("*","Camera2D",false,false)
	follow_camera = cameras.front()
	follow_camera.make_current()
	var bounds := FixedWorldProvider.rect(doc.bounds)
	follow_camera.limit_left = roundi(bounds.position.x)
	follow_camera.limit_top = roundi(bounds.position.y)
	follow_camera.limit_right = roundi(bounds.end.x)
	follow_camera.limit_bottom = roundi(bounds.end.y)
	follow_camera.zoom = Vector2.ONE * 1.40
	grounded_on_west = false
	west_jump = false
	west_recoil = false
	was_airborne = false
	chime_time = 0.0
	hint_remaining = 0.0
	notice.hide()
	connection = null
	panorama = null
	bell_mount = null
	if id=="P02":
		# A vertical doorway has no horizontal approach to look ahead of.
		look_direction = 1.0 if edge.is_empty() else -signf(float(doc.exits[edge].direction[0]))
		follow_camera.position.x = look_direction * 78
		active.controller.jump_ability.accepted_jump.connect(_jumped)
		active.controller.shoot_ability.shot_fired.connect(_shot)
		install_field_art()
	else:
		connection = active.room_dressing
	if crossing: _lock_session(true)
	follow_camera.force_update_scroll()
	panorama = preload("res://rooms/world/p02_passage_scenery.gd").mount(active,doc,passage_sky,sky_offset).panorama
	var room_name := str(catalog.lookup("rooms",id).row.name)
	room_title.text = id+" · "+room_name+("" if catalog.binding("rooms", id).ok else " · 接入段")
	title_remaining = 2.5
	room_title.modulate.a = 1.0
	room_changed.emit(id)

func install_field_art() -> void:
	for piece: Dictionary in active_doc.scenery.pieces:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/scenery/p02/"+str(piece.asset)+".png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = Vector2(-floorf(sprite.texture.get_width()*.5),-sprite.texture.get_height())
		sprite.position = FixedWorldProvider.point(piece.at)
		sprite.z_index = 5 if piece.layer=="front" else -3
		sprite.flip_h = piece.get("flip",false)
		active.room.add_child(sprite)
		if piece.asset=="windchime_plains_v2_chime_span":
			bell_mount = sprite
			var ringing := ShaderMaterial.new()
			ringing.shader = CHIME_SHADER
			sprite.material = ringing

func _process(delta: float) -> void:
	title_remaining = maxf(0.0,title_remaining-delta)
	room_title.modulate.a = clampf(title_remaining/.5,0.0,1.0)
	if issue_remaining>0:
		issue_remaining = maxf(0.0,issue_remaining-delta)
		notice.visible = issue_remaining>0
	if active == null or active.room.room_id!="P02":
		return
	chime_time = maxf(0.0,chime_time-delta)
	if bell_mount != null:
		bell_mount.material.set_shader_parameter("age",1.0-chime_time)

func _jumped(kind: StringName, _serial: int, _center: Vector2) -> void:
	if kind==&"ground":
		west_jump = grounded_on_west
		west_recoil = false

func _shot(direction: Vector2, _packet: int) -> void:
	if west_jump and not active.player.is_on_floor() and direction.x<-.1:
		west_recoil = true

func update_field(delta: float) -> void:
	var at := active.player.position
	if absf(active.player.velocity.x)>18:
		look_direction = signf(active.player.velocity.x)
	follow_camera.position.x = move_toward(follow_camera.position.x,look_direction*78,delta*180)
	var west := FixedWorldProvider.rect(active_doc.entities.west_field.properties.rect)
	var basin := FixedWorldProvider.rect(active_doc.entities.retry_basin_floor.properties.rect)
	var pier := FixedWorldProvider.rect(active_doc.entities.bell_terrace_pier.properties.rect)
	var cap := FixedWorldProvider.rect(active_doc.entities.bell_terrace_cap.properties.rect)
	var floor_contact := active.player.is_on_floor()
	var feet := at+Vector2.DOWN*18
	hint_remaining = maxf(0.0,hint_remaining-delta)
	if floor_contact:
		grounded_on_west = false
		for id: String in ["west_field","west_upper_return","west_lower_return"]:
			var tread := FixedWorldProvider.rect(active_doc.entities[id].properties.rect)
			if feet.x>=tread.position.x-10 and feet.x<=tread.end.x+10 and absf(feet.y-tread.position.y)<3:
				grounded_on_west = true
				break
	if was_airborne and floor_contact:
		if not landed_on_terrace and not retry_hint_shown and feet.x>west.end.x and feet.x<basin.end.x and absf(feet.y-basin.position.y)<4:
			retry_hint_shown = true
			notice.text = "回到田埂，跳起后朝身后偏下开枪。"
			hint_remaining = 3.4
		if west_recoil and not landed_on_terrace and feet.x>=pier.position.x and feet.x<=cap.end.x and absf(feet.y-pier.position.y)<4:
			landed_on_terrace = true
			chime_time = 1.0
			GameAudio.cue(bell_mount,&"mechanism_bell")
		west_jump = false
		west_recoil = false
	was_airborne = not floor_contact
	if issue_remaining>0: return
	notice.visible = hint_remaining>0
	notice.modulate.a = clampf(hint_remaining/.4,0,1)

func _reset_sample() -> void:
	previous_center = active.player.position

func _physics_process(delta: float) -> void:
	if active==null or crossing or not active.controller.active or active.controller.has_pending_damage(): return
	if active.room.room_id=="P02": update_field(delta)
	var before := previous_center
	var at := active.player.position
	previous_center = at
	if not waiting_for_clearance.is_empty():
		if Passage.is_inside(active_doc.exits[waiting_for_clearance],at):
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
	if not catalog.passage_access(from,edge,active.state.value.flags,active.state.value.services.equipped).matches:
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
