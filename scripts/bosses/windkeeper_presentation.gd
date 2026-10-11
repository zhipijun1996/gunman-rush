class_name WindkeeperPresentation
extends Node2D
@export var encounter: WindkeeperEncounter
const BODY := preload("res://assets/plains_v4/windkeeper/body_actions.png")
const PARTS := preload("res://assets/plains_v4/windkeeper/parts.png")
const BODY_REGIONS := [Rect2(8,45,482,463),Rect2(520,35,450,473),Rect2(985,105,543,403),Rect2(10,575,512,390),Rect2(515,550,490,420),Rect2(1010,590,515,378)]
const FOOT_ANCHORS := [Vector2(240,457),Vector2(230,467),Vector2(271,397),Vector2(256,382),Vector2(245,413),Vector2(258,368)]
var visual_clock := 0.0
var hurt_flash := 0.0
var _previous_frame := 0
var _frame := 0
var _blend := 1.0
var _mode: StringName = &""
var _mode_age := 0.0
var _stride := 0.0
var _weight := Vector2.ONE
var _lean := 0.0
var _secondary := 0.0
var _last_position := Vector2.ZERO
var _actual_speed := 0.0
var _armour_flash := 0.0
var _armour_point := Vector2.ZERO
var _audio: AudioStreamPlayer2D
const CORE_SOUND := preload("res://assets/audio/plains_core.wav")
const ARMOUR_SOUND := preload("res://assets/audio/plains_armour.wav")
const ROAR_SOUND := preload("res://assets/audio/windkeeper_roar.wav")
func _ready() -> void:
	_audio = AudioStreamPlayer2D.new()
	_audio.volume_db = -12
	_audio.max_polyphony = 1
	add_child(_audio)
	if encounter != null:
		encounter.armour_hit.connect(func(point: Vector2) -> void:
			_armour_point = to_local(point)
			_armour_flash = .10
			play_cue(ARMOUR_SOUND))
		_last_position = encounter.motor.global_position
		encounter.health.changed.connect(func(result: ActorResourceResult) -> void:
			if result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
				hurt_flash = .14
				play_cue(CORE_SOUND))
func _process(delta: float) -> void:
	if encounter == null or get_tree().paused: return
	visual_clock += delta
	_actual_speed = (encounter.motor.global_position.x - _last_position.x) / maxf(delta, .001)
	_last_position = encounter.motor.global_position
	_stride += absf(_actual_speed) * delta / 24.0
	if _mode != encounter.mode:
		_mode = encounter.mode
		if _mode in [&"intro", &"phase_transition"]: play_cue(ROAR_SOUND)
		_mode_age = 0
	_mode_age += delta
	_blend = minf(1, _blend + delta / .09)
	var desired := Vector2.ONE
	var lean := 0.0
	if _mode in [&"stomp_warning", &"charge_warning", &"pier_warning", &"phase_transition"]:
		var anticipation := minf(1, _mode_age / .8)
		desired = Vector2(1 + anticipation * .045, 1 - anticipation * .065)
		lean = anticipation * .07 * encounter.direction
	elif _mode in [&"stomp", &"pier_impact"]:
		desired = Vector2(1.07, .91)
		lean = -.09 * encounter.direction
	elif _mode in [&"charge", &"chase"]:
		desired = Vector2(1 + sin(_stride * 2) * .012, 1 - absf(sin(_stride)) * .024)
		lean = .035 * encounter.direction
	elif encounter.core_open:
		desired.y = 1 + sin(_mode_age * 4) * .007
	elif _mode == &"intro":
		desired.y = 1 + sin(minf(1, _mode_age / 1.5) * PI) * .04
	_weight = _weight.lerp(desired, 1 - exp(-delta / .055))
	_lean = lerpf(_lean, lean, 1 - exp(-delta / .07))
	_secondary = lerpf(_secondary, _lean, 1 - exp(-delta / .13))
	hurt_flash = maxf(0,hurt_flash-delta)
	_armour_flash = maxf(0,_armour_flash-delta)
	queue_redraw()
func _draw() -> void:
	if encounter == null: return
	var frame := 0
	if encounter.health.terminal: frame = 5
	elif encounter.mode in [&"stomp_warning", &"stomp", &"intro", &"phase_transition"]: frame = 1
	elif encounter.mode in [&"charge",&"charge_warning",&"chase", &"pier_warning", &"pier_impact"]: frame = 2
	elif encounter.core_open: frame = 3
	elif encounter.stage_phase == 2: frame = 4
	var facing := 1.0 if encounter.direction > 0 else -1.0
	if frame != _frame:
		_previous_frame = _frame
		_frame = frame
		_blend = 0
	var tint := Color(1.3,1.15,.8) if hurt_flash > 0 else Color.WHITE
	# Piecewise shear around the common foot origin; feet never bob off floor.
	var transform := Transform2D(Vector2(facing * .35 * _weight.x,0), Vector2(_lean * .35, .35 * _weight.y), Vector2(0,65))
	draw_set_transform_matrix(transform)
	if _blend < 1:
		draw_texture_rect_region(BODY,Rect2(-FOOT_ANCHORS[_previous_frame],BODY_REGIONS[_previous_frame].size),BODY_REGIONS[_previous_frame],Color(tint,1-_blend))
	if _mode in [&"charge", &"chase"] and absf(_actual_speed) > 2:
		_draw_stride(frame, Color(tint,_blend))
	else:
		draw_texture_rect_region(BODY,Rect2(-FOOT_ANCHORS[frame],BODY_REGIONS[frame].size),BODY_REGIONS[frame],Color(tint,_blend))
	draw_set_transform(Vector2.ZERO)
	if not encounter.health.terminal:
		# Independent genuine painted rotor rotates around measured hub.
		var angle := encounter.blade_angle if encounter.stage_phase == 2 else visual_clock*.4
		draw_set_transform(Vector2(_secondary * -75,-75),angle,Vector2.ONE*.34)
		draw_texture_rect_region(PARTS,Rect2(-Vector2(323,286),Vector2(640,605)),Rect2(5,5,640,605))
		draw_set_transform(Vector2.ZERO)
	if encounter.mode in [&"charge_warning",&"stomp_warning",&"blade_warning",&"pier_warning",&"phase_transition"]:
		draw_arc(Vector2(0,65),88,PI,TAU,24,Color(1,.65,.23,.7),4)
	if encounter.core_open:
		var core := encounter.core_offset()
		draw_circle(core,25+sin(visual_clock*9)*2,Color(1,.83,.33,.3))
		draw_texture_rect_region(PARTS,Rect2(core-Vector2(11,14),Vector2(22,29)),Rect2(735,20,435,575))

	if encounter.stage_phase == 2 and encounter.mode in [&"blade_warning", &"blades"]:
		for arm: int in 4:
			var axis := Vector2.from_angle(encounter.blade_angle + arm * PI / 2)
			draw_line(Vector2(0,-75) + axis * 15, Vector2(0,-75) + axis * 115, Color(1,.65,.3,.65 if encounter.mode == &"blades" else .25), 3)
	if encounter.mode == &"phase_transition" and encounter.stage_phase == 3:
		for x: float in [245,510,745]:
			var point := Vector2(encounter.arena.left_x+x-encounter.motor.global_position.x,65)
			draw_line(point-Vector2(25,0),point+Vector2(25,0),Color(1,.75,.35,.75),3)

	if _armour_flash > 0:
		var point := _armour_point
		for spark: int in 4:
			var axis := Vector2.from_angle(spark * PI / 2 + .4)
			draw_line(point + axis * 7,point + axis * 15,Color("bac8c4"),2)
	if hurt_flash > 0:
		var point := encounter.core_offset()
		draw_line(point + Vector2(-14,-7), point + Vector2(3,0),Color("fff1be"),3)
		draw_line(point + Vector2(3,0), point + Vector2(-5,10),Color("fff1be"),3)

func play_cue(stream: AudioStream) -> void:
	_audio.stream = stream
	_audio.play()

func _draw_stride(frame: int, tint: Color) -> void:
	# Existing master art is split at the ankle band into four leg sections.
	# Stance sections stay planted, swing sections lift in measured gait cadence.
	var source: Rect2 = BODY_REGIONS[frame]
	var ankle_height := 65.0
	var torso := Rect2(source.position, source.size - Vector2(0,ankle_height))
	draw_texture_rect_region(BODY,Rect2(-FOOT_ANCHORS[frame],torso.size),torso,tint)
	for leg: int in 4:
		var width := source.size.x / 4
		var phase: float = _stride + (PI if leg % 2 == 0 else 0)
		var lift := maxf(0,sin(phase)) * 7
		var step := sin(phase * 2) * 3
		var crop := Rect2(source.position + Vector2(leg * width,source.size.y-ankle_height),Vector2(width,ankle_height))
		var at: Vector2 = -FOOT_ANCHORS[frame] + Vector2(leg * width + step,source.size.y-ankle_height-lift)
		draw_texture_rect_region(BODY,Rect2(at,crop.size),crop,tint)

func _exit_tree() -> void:
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
