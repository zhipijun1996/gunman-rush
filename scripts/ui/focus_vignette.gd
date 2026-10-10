class_name FocusVignette
extends CanvasLayer

@export var ability: AirFocusAbility
@export var enabled := true
@export var tint := Color(1.0, 0.73, 0.16)
@export_range(0.0, 1.0) var opacity := 0.32
@export_range(0.01, 0.49) var edge_width := 0.22
@export var fade_in_seconds := 0.12
@export var fade_out_seconds := 0.18
var _target := 0.0
var _strength := 0.0
var _rect: ColorRect
var _shader_material: ShaderMaterial

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Above the viewport world canvas; touch controls and HUD are layer 1.
	layer = 0
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://shaders/focus_vignette.gdshader")
	_rect.material = _shader_material
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(ability):
		ability.active_changed.connect(_on_active_changed)
		_on_active_changed(ability.active)

func _on_active_changed(value: bool) -> void:
	_target = 1.0 if value else 0.0

func _process(delta: float) -> void:
	var target := _target if enabled and is_instance_valid(ability) else 0.0
	var seconds := fade_in_seconds if target > _strength else fade_out_seconds
	# Fade in real time so the visual never takes four times longer in slow aim.
	_strength = move_toward(_strength, target, delta / maxf(Engine.time_scale, 0.001) / maxf(seconds, 0.001))
	_rect.visible = _strength > 0.0001
	if _rect.visible:
		_shader_material.set_shader_parameter("strength", _strength)
		_shader_material.set_shader_parameter("tint", tint)
		_shader_material.set_shader_parameter("opacity", clampf(opacity, 0.0, 1.0))
		_shader_material.set_shader_parameter("edge_width", clampf(edge_width, 0.01, 0.49))
