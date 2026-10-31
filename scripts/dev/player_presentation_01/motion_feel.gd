class_name PlayerMotionFeel
extends Node
## Unique task consumer of accepted movement events; legacy cues delegated OFF.
var visual: PlayerMotionCandidateVisual
var audio: PlayerMotionAudio
var legacy: PlayerFeedback
var _screen: ColorRect
var _material: ShaderMaterial
var _age := 0.0
var _remaining := 0.0
var _owner := 0
var _disconnected := false
var shake_count := 0

func _ready() -> void:
	_owner = visual.motor.get_instance_id()
	legacy = visual.motor.get_node("PlayerFeedback") as PlayerFeedback
	if visual.controller.jump_ability.jumped.is_connected(legacy._jump): visual.controller.jump_ability.jumped.disconnect(legacy._jump)
	if visual.controller.landed.is_connected(legacy._land): visual.controller.landed.disconnect(legacy._land)
	_disconnected = true
	visual.motion_jump.connect(_jump)
	visual.motion_land.connect(_land)
	visual.motion_reset.connect(clear)
	visual.controller.died.connect(clear)
	visual.controller.segment_returned.connect(clear)
	var layer := CanvasLayer.new()
	layer.layer = 1 # world only; formal HUD is layer2,Home HUD10
	add_child(layer)
	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = preload("res://resources/player_presentation_01/landing_screen.gdshader")
	_screen.material = _material
	layer.add_child(_screen)
	_screen.hide()

func _jump() -> void:
	clear()
	if not visual.candidate_enabled:
		legacy._jump()
		return
	audio.motion_cue(&"jump",.3,_owner)
	if visual.controller.jump_ability.used_jumps>=2: GameAudio.cue(self,&"focus_start")

func _land(drop: float, speed: float, heavy: bool, airborne: bool) -> void:
	if not visual.candidate_enabled:
		legacy._land()
		return
	# The delegated legacy consumer still observes airborne speed while hidden.
	# Keep its presentation accumulator at the same accepted-land boundary.
	legacy._fall_speed = 0
	if not airborne or visual._dead or visual._hurt_remaining>0: return
	var strength := clampf(speed/visual.motor.tuning.max_normal_fall_speed,0,1)
	audio.motion_cue(&"heavy" if heavy else &"land",strength,_owner)
	if heavy:
		_age = 0
		_remaining = visual.profile.heavy_shake_seconds
		shake_count += 1
		_screen.show()

func clear() -> void:
	_remaining = 0
	if is_instance_valid(_screen): _screen.hide()
	if is_instance_valid(audio): audio.stop_motion(_owner)

func _process(delta: float) -> void:
	if not is_instance_valid(visual) or not visual.candidate_enabled or visual._dead or visual._hurt_remaining>0:
		clear()
		return
	if _remaining<=0: return
	_age += delta
	_remaining = maxf(0,_remaining-delta)
	var fade := pow(_remaining/visual.profile.heavy_shake_seconds,2)
	var amount := visual.profile.heavy_shake_pixels * fade
	var displacement := Vector2(sin(_age*135)*.35,cos(_age*110))*amount
	_material.set_shader_parameter("displacement_px",displacement.snapped(Vector2.ONE))
	if _remaining<=0: _screen.hide()

func _exit_tree() -> void:
	clear()
	# If this task component alone is removed, restore exactly the old consumer.
	if _disconnected and is_instance_valid(legacy) and is_instance_valid(visual) and is_instance_valid(visual.controller):
		if not visual.controller.jump_ability.jumped.is_connected(legacy._jump): visual.controller.jump_ability.jumped.connect(legacy._jump)
		if not visual.controller.landed.is_connected(legacy._land): visual.controller.landed.connect(legacy._land)
