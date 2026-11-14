class_name BossRoarScreen
extends CanvasLayer
## One viewport pass beneath HUD; no independent timer or camera offset writes.
var overlay: ColorRect
var surface: ShaderMaterial
var updates := 0

func _ready() -> void:
	layer=20
	overlay=ColorRect.new()
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface=ShaderMaterial.new()
	surface.shader=preload("res://game/presentation/actors/art/boss_roar_screen.gdshader")
	surface.set_shader_parameter("release_progress",BossRoarTimeline.RELEASE)
	overlay.material=surface
	add_child(overlay)
	overlay.visible=false

func present(progress: float, mouth: Vector2, reduced: bool) -> void:
	updates+=1
	overlay.visible=progress>0 and progress<1
	surface.set_shader_parameter("progress",progress)
	surface.set_shader_parameter("mouth",mouth)
	surface.set_shader_parameter("strength",.27 if reduced else 1.0)

func clear() -> void:
	if is_instance_valid(overlay):overlay.visible=false
