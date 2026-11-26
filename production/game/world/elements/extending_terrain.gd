class_name WorldExtendingTerrain
extends MechanismSolid

@export_enum("centered","rooted") var growth_mode := "centered"
@export var growth_axis := Vector2.UP
@export var thickness := 24.0
@export var initial_length := 96.0
@export var max_length := 224.0
@export var growth_per_hit := 32.0
@export var growth_speed := 128.0
@export var retract_delay_s := 1.5
@export var retract_speed := 64.0
var length_now := 96.0
var target_length := 96.0
var age := 0.0
var axis := Vector2.RIGHT

func _ready() -> void:
	axis = growth_axis.normalized() if growth_mode == "rooted" else Vector2.RIGHT
	make_solid(Vector2(initial_length,thickness))
	install_length(initial_length)
	target_length = initial_length
	shot_part(-axis*8 if growth_mode == "rooted" else Vector2.DOWN*(thickness/2+7),12)

func offset_for(length_value: float) -> Vector2:
	return axis*length_value/2 if growth_mode == "rooted" else Vector2.ZERO

func install_length(value: float) -> void:
	length_now = value
	body.rotation = axis.angle()
	body.position = offset_for(value)
	rect_shape.size = Vector2(value,thickness)
	body.force_update_transform()
	queue_redraw()

func mechanism_shot(context: Dictionary) -> bool:
	if not accept_shot(context): return false
	target_length = minf(max_length,maxf(length_now,target_length)+growth_per_hit)
	age = 0
	return true

func _physics_process(delta: float) -> void:
	if controller == null or not lifetime.active: return
	age += delta
	if age >= retract_delay_s: target_length = initial_length
	var next := move_toward(length_now,target_length,delta*(growth_speed if target_length > length_now else retract_speed))
	if next == length_now: return
	var shift := Vector2.ZERO
	var ignore: Array[RID] = [body.get_rid()]
	var contact := rider_contact(true)
	if not contact.is_empty():
		var outward := axis.dot(contact.normal)
		if absf(outward) > 0.9:
			shift = offset_for(next)-offset_for(length_now)+axis*signf(outward)*(next-length_now)/2
		ignore.append(controller.motor.get_rid())
	var probe := RectangleShape2D.new()
	probe.size = (Vector2(next,thickness)-Vector2.ONE*0.07).max(Vector2.ONE*0.001)
	blocked = not fits(probe,global_transform*Transform2D(axis.angle(),offset_for(next)),ignore) or not rider_fits(shift)
	if not blocked:
		move_rider(shift)
		install_length(next)
	queue_redraw()

func element_state() -> Dictionary:
	return {"length":length_now,"target":target_length,"age":age,"blocked":blocked,"receipts":shot_receipts.duplicate()}

func element_restore(data: Dictionary) -> void:
	install_length(data.length)
	target_length = data.target
	age = data.age
	blocked = data.blocked
	shot_receipts = data.receipts.duplicate()

func _draw() -> void:
	draw_set_transform(offset_for(length_now),axis.angle())
	BeamHardware.growth(self,length_now,thickness,growth_mode == "rooted")
	draw_set_transform(Vector2.ZERO)
	if hit_part != null:
		BeamHardware.growth_bud(self,hit_part.position,blocked)
