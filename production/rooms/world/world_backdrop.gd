class_name WorldBackdrop
extends Node2D
## Retain the outgoing crop when the two connected rooms share a backdrop.
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

static func mount(session: OrdinaryRoomSession, doc: Dictionary, sky_state: Dictionary, offset := Vector2.INF) -> WorldBackdrop:
	var scenery: Dictionary = doc.get("scenery",{})
	var result := WorldBackdrop.new()
	result.name = "PassageScenery"
	result.host = session
	result.phase = sky_state
	result.field_center = FixedWorldProvider.rect(doc.bounds).get_center()
	result.door_offset = offset if offset.is_finite() else Vector2.ZERO
	var backdrop: String = scenery.get("backdrop","")
	if backdrop.is_empty():
		sky_state.clear()
		session.add_child(result)
		result.set_process(false)
		return result
	if sky_state.get("backdrop","") != backdrop:
		sky_state.erase("center_native")
	sky_state.backdrop = backdrop
	sky_state.offset = result.door_offset
	result.panorama.texture = load(backdrop)
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
