class_name FieldTerracePilot
extends Node2D
## The field and its four receiving passages use actual room sessions and one
## world-state ledger. Crossings are taken by movement through an authored edge.
signal room_changed(room_id: String)

const DOCUMENT := "res://rooms/world/P02.json"
const CONNECTIONS := "res://rooms/world/p02_connections/"
const DISCOVERY := "discover_p02_low_slope"
const CHIME_SHADER := preload("res://rooms/world/p02_chime.gdshader")
const FONT := preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
const MAP := preload("res://rooms/world/p02_route_map.gd")
var catalog := WorldContentCatalog.new()
var active: OrdinaryRoomSession
var connection: Node
var active_doc := {}
var last_error := ""
var follow_camera: Camera2D
var panorama: Sprite2D
var veil: Sprite2D
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
	enter_room("P01","")
	if active != null:
		route_map = MAP.mount(self)

func enter_room(id: String, edge: String) -> void:
	var path := DOCUMENT if id=="P02" else CONNECTIONS + id + ".json"
	var doc := WorldRoomDocument.read(path)
	if doc.has("error"):
		last_error = doc.error
		push_error(last_error)
		return
	var next := OrdinaryRoomSession.new()
	add_child(next)
	last_error = next.open(doc,null,active,catalog)
	if not last_error.is_empty():
		next.queue_free()
		push_error(last_error)
		return
	if active != null:
		active.hide()
	active = next
	active_doc = doc
	# Enter on the destination's receiving apron before its first physics tick.
	# Keep its document unchanged so every door has the same content identity.
	if not edge.is_empty():
		active.player.reset_at(FixedWorldProvider.point(doc.exits[edge].spawn))
	var candidate := active.state.candidate()
	candidate.entry = edge
	if id not in candidate.explored:
		candidate.explored.append(id)
	active.state.commit(candidate,active.state.revision)
	var cameras := active.player.find_children("*","Camera2D",false,false)
	follow_camera = cameras.front()
	follow_camera.make_current()
	var bounds := FixedWorldProvider.rect(doc.bounds)
	follow_camera.limit_left = roundi(bounds.position.x)
	follow_camera.limit_top = roundi(bounds.position.y)
	follow_camera.limit_right = roundi(bounds.end.x)
	follow_camera.limit_bottom = roundi(bounds.end.y)
	follow_camera.zoom = Vector2.ONE * maxf(1.40,get_viewport_rect().size.x/bounds.size.x)
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
	veil = null
	if id=="P02":
		if not edge.is_empty() and doc.exits[edge].direction[0] != 0:
			look_direction = -signf(float(doc.exits[edge].direction[0]))
		follow_camera.position.x = look_direction * 78
		active.controller.jump_ability.accepted_jump.connect(_jumped)
		active.controller.shoot_ability.shot_fired.connect(_shot)
		install_field_art()
	else:
		connection = preload("res://rooms/world/p02_connections/connection_room.gd").install(active,doc,catalog)
	follow_camera.force_update_scroll()
	var room_name := str(catalog.lookup("rooms",id).row.name)
	room_title.text = id+" · "+room_name+(" · 接入段" if id!="P02" else "")
	title_remaining = 2.5
	room_title.modulate.a = 1.0
	room_changed.emit(id)

func install_field_art() -> void:
	panorama = Sprite2D.new()
	panorama.texture = load(str(active_doc.scenery.backdrop))
	panorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panorama.centered = false
	panorama.z_index = -90
	active.add_child(panorama)
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
		if piece.get("discover","")==DISCOVERY:
			veil = sprite
			if active.state.has(DISCOVERY):
				veil.modulate.a = .17
		if piece.asset=="windchime_plains_v2_chime_span":
			bell_mount = sprite
			var ringing := ShaderMaterial.new()
			ringing.shader = CHIME_SHADER
			sprite.material = ringing
	place_panorama()

func place_panorama() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or panorama == null:
		return
	var eye := camera.get_screen_center_position()
	var view_size := camera.get_viewport_rect().size/camera.zoom
	var texture_size := panorama.texture.get_size()
	var cover := maxf(1.0,maxf(view_size.x/texture_size.x,view_size.y/texture_size.y))
	panorama.scale = Vector2.ONE*cover
	var size := texture_size*cover
	var corner := eye-view_size*.5
	var center_x := float(active_doc.bounds[2])*.5
	var desired := Vector2(center_x-size.x*.5+(eye.x-center_x)*.43,-19+(eye.y-380)*.12)
	panorama.position = desired.clamp(corner+view_size-size,corner).round()

func _process(delta: float) -> void:
	title_remaining = maxf(0.0,title_remaining-delta)
	room_title.modulate.a = clampf(title_remaining/.5,0.0,1.0)
	if active == null or active.room.room_id!="P02":
		return
	place_panorama()
	if veil != null:
		veil.modulate.a = move_toward(veil.modulate.a,.17 if active.state.has(DISCOVERY) else 1.0,delta*1.8)
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
	var site := FixedWorldProvider.point(active_doc.sites[DISCOVERY].at)
	if not active.state.has(DISCOVERY) and at.distance_to(site)<=40:
		var event := catalog.lookup("events",DISCOVERY)
		if event.ok and catalog.condition_match(event.row,active.state.value.flags).matches:
			var candidate := active.state.action_candidate(DISCOVERY,"P02")
			if not candidate.is_empty():
				active.state.commit(candidate,active.state.revision)
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
			hint_remaining = 3.4
		if west_recoil and not landed_on_terrace and feet.x>=pier.position.x and feet.x<=cap.end.x and absf(feet.y-pier.position.y)<4:
			landed_on_terrace = true
			chime_time = 1.0
			GameAudio.cue(bell_mount,&"mechanism_bell")
		west_jump = false
		west_recoil = false
	was_airborne = not floor_contact
	notice.visible = hint_remaining>0
	notice.modulate.a = clampf(hint_remaining/.4,0,1)

func _physics_process(delta: float) -> void:
	if active==null or crossing or not active.controller.active:
		return
	if active.room.room_id=="P02":
		update_field(delta)
	for id: String in active_doc.exits:
		var gate: Dictionary = active_doc.exits[id]
		var direction := FixedWorldProvider.point(gate.direction)
		var to_player := active.player.position-FixedWorldProvider.point(gate.point)
		# Supporting floors are continuous on walk-in edges. The well crosses
		# on descent and its receiving passage returns only on a real ascent.
		var across := active.player.position.y if direction.x!=0 else active.player.position.x
		var within := absf(to_player.dot(direction.orthogonal()))<=32
		if gate.has("span"):
			within = across>=float(gate.span[0]) and across<=float(gate.span[1])
		if active.player.velocity.dot(direction)<=0 or to_player.dot(direction)<0 or not within:
			continue
		var door := catalog.lookup("doors",id)
		if not door.ok or not catalog.condition_match(door.row,active.state.value.flags,active.state.value.services.equipped).matches:
			continue
		var destination: String = door.row.b if door.row.a==active.room.room_id else door.row.a
		crossing = true
		enter_room(destination,id)
		crossing = false
		return
