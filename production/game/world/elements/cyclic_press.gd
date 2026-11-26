class_name WorldCyclicPress
extends MechanismSolid

@export var body_size := Vector2(128,48)
@export var stroke := 192.0
@export var down_speed := 240.0
@export var up_speed := 120.0
@export var top_hold := 1.0
@export var warning_time := 0.45
@export var bottom_hold := 0.3
@export var hazard_depth := 6.0
@export var initial_running := true
var running := true
var clock := 0.0
var scale_time := 1.0
var phase := "top_hold"
var danger: DemoContactEmitter

func _ready() -> void:
	make_solid(body_size)
	running = initial_running

func element_bind(context: Dictionary) -> void:
	super(context)
	danger = make_hazard(Rect2(-body_size.x/2,body_size.y/2,body_size.x,hazard_depth))

func cycle() -> float:
	return top_hold+warning_time+stroke/down_speed+bottom_hold+stroke/up_speed

func sample(value: float) -> Dictionary:
	var t := fposmod(value,cycle())
	if t < top_hold: return {"phase":"top_hold","y":0.0}
	t -= top_hold
	if t < warning_time: return {"phase":"warning","y":0.0}
	t -= warning_time
	if t < stroke/down_speed: return {"phase":"down","y":t*down_speed}
	t -= stroke/down_speed
	if t < bottom_hold: return {"phase":"bottom_hold","y":stroke}
	t -= bottom_hold
	return {"phase":"up","y":maxf(0,stroke-t*up_speed)}

func _physics_process(delta: float) -> void:
	if controller == null or not lifetime.active or not running: return
	var next_clock := clock+delta*scale_time
	var next := sample(next_clock)
	var motion := Vector2.DOWN*(float(next.y)-body.position.y)
	var rider := rider_contact()
	# A player underneath meets the teeth. A safe top passenger is transported;
	# at either side the ordinary solid may not advance through the body.
	var below := controller.motor.global_position.y-player_half().y >= body.global_position.y+body_size.y/2-1
	blocked = travel_fraction(motion,not rider.is_empty() or below and motion.y>0) < 0.99999
	if not rider.is_empty(): blocked = blocked or not rider_fits(motion)
	if not blocked:
		if not rider.is_empty(): move_rider(motion)
		clock = fposmod(next_clock,cycle())
		body.position.y = next.y
		body.force_update_transform()
		if phase != "warning" and next.phase == "warning": GameAudio.cue(self,&"armour")
		phase = next.phase
		danger.position = body.position+Vector2.DOWN*(body_size.y+hazard_depth)/2
	queue_redraw()

func set_equipment_time(value: float) -> void: scale_time = value
func element_can_receive(input: String,value: Variant) -> bool: return input == "set_active" and value is bool
func element_state() -> Dictionary: return {"running":running,"clock":clock,"blocked":blocked}
func element_propose(_input: String,value: Variant) -> Dictionary:
	var data := element_state()
	data.running = value
	return data
func element_restore(data: Dictionary) -> void:
	running = data.running
	clock = data.clock
	blocked = data.blocked
	var rebuilt := sample(clock)
	phase = rebuilt.phase
	body.position.y = rebuilt.y
	if danger != null: danger.position = body.position+Vector2.DOWN*(body_size.y+hazard_depth)/2
	queue_redraw()

func _draw() -> void:
	if body == null: return
	var rect := Rect2(body.position-body_size/2,body_size)
	BeamHardware.press(self,rect,Vector2(0,-body_size.y/2-18),hazard_depth,phase=="warning" or blocked)
