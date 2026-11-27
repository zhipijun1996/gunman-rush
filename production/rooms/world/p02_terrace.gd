class_name FieldTerracePilot
extends OrdinaryRoomSession
## One complete preview room. Its four physical endpoints keep their world-map
## identities and the associated room names, without loading neighbouring rooms.
const DOCUMENT := "res://rooms/world/P02.json"
const DISCOVERY := "discover_p02_low_slope"

const CHIME_SHADER := preload("res://rooms/world/p02_chime.gdshader")
const ROOM_Z := {"p02_terrace_facing":0,"p02_reed_screen":5,"windchime_plains_v2_chime_span":-2}

var panorama := Sprite2D.new()
var follow_camera: Camera2D
var look_direction := 1.0
var veil: Sprite2D
var launch_surface := Rect2()
var bell_surface := Rect2()
var grounded_on_west := false
var west_jump := false
var west_recoil := false
var exits := {}
var opening := Vector2.ZERO
var notice := Label.new()
var landed_on_terrace := false
var was_airborne := false
var bell_mount: Sprite2D
var chime_time := 0.0
var active_edge := ""
var retry_hint_shown := false
var hint_remaining := 0.0

func _ready() -> void:
	var source := WorldRoomDocument.read(DOCUMENT)
	var error := open_content("P02")
	if not error.is_empty():
		push_error(error)
		return
	exits = source.exits
	opening = FixedWorldProvider.point(source.sites[DISCOVERY].at)
	var bounds := FixedWorldProvider.rect(source.bounds)
	launch_surface = FixedWorldProvider.rect(source.entities.west_field.properties.rect)
	bell_surface = FixedWorldProvider.rect(source.entities.bell_terrace_pier.properties.rect).merge(FixedWorldProvider.rect(source.entities.bell_terrace_cap.properties.rect))
	controller.jump_ability.accepted_jump.connect(_jumped)
	controller.shoot_ability.shot_fired.connect(_shot)
	install_room_edges(bounds)
	follow_camera = get_viewport().get_camera_2d()
	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = int(bounds.end.x)
	follow_camera.limit_bottom = int(bounds.end.y)
	follow_camera.zoom = Vector2.ONE * 1.40
	follow_camera.position.x = 78.0
	install_scenery(source)
	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice.offset_top = 14
	notice.offset_bottom = 55
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_font_override("font",preload("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf"))
	notice.add_theme_font_size_override("font_size",24)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_constant_override("outline_size",5)
	notice.add_theme_color_override("font_outline_color", Color("232a2b"))
	notice.hide()

func install_room_edges(bounds: Rect2) -> void:
	# Only this room is available in the pilot. Bound the ends beyond their
	# real, reachable doorway aprons, so a player can always turn back.
	for x: float in [bounds.position.x-12.0, bounds.end.x+12.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(x, bounds.get_center().y)
		wall.collision_layer = 1
		wall.collision_mask = 0
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24.0, bounds.size.y)
		collider.shape = shape
		wall.add_child(collider)
		room.add_child(wall)

func install_scenery(source: Dictionary) -> void:
	panorama.texture = load(str(source.scenery.backdrop))
	panorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panorama.centered = false
	panorama.z_index = -90
	add_child(panorama)
	for part: Dictionary in source.scenery.pieces:
		var sprite := Sprite2D.new()
		sprite.texture = load("res://assets/scenery/p02/"+str(part.asset)+".png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false
		sprite.offset = Vector2(-floorf(sprite.texture.get_width()*.5),-sprite.texture.get_height())
		sprite.position = FixedWorldProvider.point(part.at)
		sprite.z_index = int(ROOM_Z.get(part.asset,-3))
		sprite.flip_h = part.get("flip",false)
		room.add_child(sprite)
		if part.get("discover","") == DISCOVERY: veil = sprite
		if part.asset == "windchime_plains_v2_chime_span":
			bell_mount = sprite
			var ringing := ShaderMaterial.new()
			ringing.shader = CHIME_SHADER
			sprite.material = ringing
	place_panorama()

func place_panorama() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	var eye := camera.get_screen_center_position()
	var view_size := camera.get_viewport_rect().size / camera.zoom
	# The overview viewport can show the whole room, while a player camera
	# needs only enough image to cover the current view after parallax.
	var cover := maxf(1.0,maxf(view_size.x/panorama.texture.get_width(),view_size.y/panorama.texture.get_height()))
	panorama.scale = Vector2.ONE * cover
	var image_width := panorama.texture.get_width() * cover
	var left := eye.x - view_size.x*.5
	var top := eye.y - view_size.y*.5
	var desired_x := (1648.0-image_width)*.5 + (eye.x-824.0)*.43
	var x := clampf(desired_x,left+view_size.x-image_width,left)
	var y := clampf(-19.0+(eye.y-380.0)*.12,top+view_size.y-panorama.texture.get_height()*cover,top)
	panorama.position = Vector2(x,y).round()

func _process(delta: float) -> void:
	if room == null: return
	place_panorama()
	if veil != null:
		var target := .17 if state.has(DISCOVERY) else 1.0
		veil.modulate.a = move_toward(veil.modulate.a,target,delta*1.8)
	chime_time = maxf(0,chime_time-delta)
	if bell_mount != null and bell_mount.material is ShaderMaterial:
		bell_mount.material.set_shader_parameter("age",1.0-chime_time)

func _jumped(kind: StringName, _serial: int, _center: Vector2) -> void:
	if kind == &"ground":
		west_jump = grounded_on_west
		west_recoil = false

func _shot(direction: Vector2, _packet: int) -> void:
	if west_jump and not player.is_on_floor() and direction.x < -0.1:
		west_recoil = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if room == null or not controller.active: return
	var at := player.position
	if absf(player.velocity.x) > 18:
		look_direction = signf(player.velocity.x)
	follow_camera.position.x = move_toward(follow_camera.position.x,look_direction*78.0,delta*180.0)
	if not state.has(DISCOVERY) and at.distance_to(opening)<=54:
		var event := content_catalog.lookup("events",DISCOVERY)
		if event.ok and content_catalog.condition_match(event.row,state.value.flags).matches:
			var candidate := state.action_candidate(DISCOVERY,"P02")
			if not candidate.is_empty(): state.commit(candidate,state.revision)
	var on_floor := player.is_on_floor()
	hint_remaining = maxf(0.0,hint_remaining-delta)
	if was_airborne and on_floor and not landed_on_terrace and not retry_hint_shown and at.x>515 and at.x<736 and absf(at.y-554)<5:
		retry_hint_shown = true
		hint_remaining = 3.4
	if on_floor:
		grounded_on_west = at.x<=launch_surface.end.x+12 and absf(at.y+18-launch_surface.position.y)<3
	if was_airborne and on_floor and west_recoil and not landed_on_terrace and at.x>=bell_surface.position.x and at.x<=bell_surface.end.x and absf(at.y+18-bell_surface.position.y)<5:
		landed_on_terrace = true
		chime_time = 1.0
		GameAudio.cue(bell_mount,&"mechanism_bell")
	if was_airborne and on_floor:
		west_jump = false
		west_recoil = false
	was_airborne = not on_floor
	var nearest := ""
	for edge: String in exits:
		if at.distance_to(FixedWorldProvider.point(exits[edge].point))<58:
			nearest=edge
			break
	if nearest != active_edge:
		active_edge=nearest
		if not nearest.is_empty():
			var door: Dictionary=content_catalog.lookup("doors",nearest).row
			var destination: String=door.b if door.a=="P02" else door.a
			notice.text = str(content_catalog.lookup("rooms",destination).row.name) + "  ·  样板边界"
	if active_edge.is_empty() and hint_remaining>0:
		notice.text = "回到田埂，跳起后朝身后偏下开枪。"
	notice.visible = not active_edge.is_empty() or hint_remaining>0
