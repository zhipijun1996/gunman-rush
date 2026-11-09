class_name WindkeeperPhaseScreen
extends CanvasLayer
## Read-only accepted stage clock; additive camera offset is removed on teardown.
var encounter: WindkeeperPressureEncounter
var overlay: ColorRect
var camera: Camera2D
var applied_offset := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	overlay = ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://game/presentation/actors/art/windkeeper_phase_screen.gdshader")
	overlay.material = surface
	add_child(overlay)
	overlay.visible = false

static func shake(progress: float) -> Vector2:
	var pulse := exp(-pow((progress-.54)*10.0,2.0))
	var tension := sin(clampf(progress,0,1)*PI)*.75
	return Vector2(sin(progress*131),cos(progress*103))*(pulse*5.0+tension)

func _process(_delta: float) -> void:
	var playing := is_instance_valid(encounter) and encounter.active and not encounter.health.terminal and encounter.mode==&"phase_transition" and encounter.stage_phase==2
	overlay.visible = playing
	if not playing:
		_clear_camera()
		return
	if get_tree().paused: return
	_clear_camera()
	var progress := clampf(encounter._state_age/maxf(.001,encounter._state_duration),0,1)
	(overlay.material as ShaderMaterial).set_shader_parameter("progress",progress)
	camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		applied_offset = shake(progress)
		camera.offset += applied_offset

func _clear_camera() -> void:
	if is_instance_valid(camera): camera.offset -= applied_offset
	applied_offset = Vector2.ZERO

func _exit_tree() -> void:
	_clear_camera()
