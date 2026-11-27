class_name P02PassageScenery
extends Node2D
## The P02 approach, terraces and passage mouths share one distant view of the valley.
const FIELD := "res://rooms/world/P02.json"
const PARALLAX := Vector2(.26,.12)

var panorama := Sprite2D.new()
var center_native := Vector2.ZERO
var host: OrdinaryRoomSession
var phase: Dictionary
var door_offset := Vector2.ZERO
var field_center := Vector2.ZERO
var first_eye := Vector2.ZERO
var initial_correction := Vector2.ZERO
var fresh := true

static func mount(session: OrdinaryRoomSession, doc: Dictionary, sky_state: Dictionary) -> P02PassageScenery:
	var field := doc if doc.room_id == "P02" else WorldRoomDocument.read(FIELD)
	var result := P02PassageScenery.new()
	result.name = "PassageScenery"
	result.host = session
	result.phase = sky_state
	result.field_center = FixedWorldProvider.rect(field.bounds).get_center()
	for edge: String in doc.exits:
		if field.exits.has(edge):
			result.door_offset = FixedWorldProvider.point(field.exits[edge].point)-FixedWorldProvider.point(doc.exits[edge].point)
			break
	result.panorama.texture = load(field.scenery.backdrop)
	result.panorama.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.panorama.centered = false
	result.panorama.z_index = -90
	result.add_child(result.panorama)
	session.add_child(result)
	result.refresh()
	return result

func _process(_delta: float) -> void:
	if host.visible and host.lifetime.active:
		refresh()

func refresh() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	var eye := to_local(camera.get_screen_center_position())
	var view := get_viewport_rect().size/camera.zoom
	var native_size := panorama.texture.get_size()
	var cover := maxf(1.0,maxf(view.x/native_size.x,view.y/native_size.y))
	var half_view := view/(2.0*cover)
	var reference := native_size*.5 + (eye+door_offset-field_center)*PARALLAX
	reference = reference.clamp(half_view,native_size-half_view)
	if fresh:
		# The paired doorway supplies a world reference; the outgoing frame supplies
		# the actual crop. Both survive a camera reframe under the room curtain.
		first_eye = eye
		initial_correction = Vector2(phase.get("center_native",reference))-reference
		fresh = false
	var travel := eye.distance_to(first_eye)
	# As the new camera actually travels, resume the common valley coordinates.
	# A stationary landing camera cannot drag the background past a stationary observer.
	center_native = (reference+initial_correction*exp(-travel/190.)).clamp(half_view,native_size-half_view)
	panorama.scale = Vector2.ONE*cover
	panorama.position = (eye-center_native*cover).round()
	phase["center_native"] = center_native
