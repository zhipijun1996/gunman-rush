class_name WorldRisingBubble
extends TraversalMechanism

@export var bubble_radius := 40.0
@export var rise_speed := 80.0
@export var rise_distance := 256.0
@export var respawn_delay_s := 2.0
var origin := Vector2.ZERO
var stage := "ready"
var wait_left := 0.0
var envelope := CircleShape2D.new()
var ride_speed := Vector2.ZERO
var arrived := false

func _ready() -> void:
	origin = position
	envelope.radius = bubble_radius
	process_physics_priority = 950

func element_bind(context: Dictionary) -> void:
	super.element_bind(context)
	controller.motor.repositioned.connect(func(): controller.motor.exit_bubble() if controller.motor.bubble_carrier == self else false)

func _physics_process(delta: float) -> void:
	if not live():
		if is_instance_valid(controller) and controller.motor.bubble_carrier == self: controller.motor.exit_bubble()
		return
	var motor := controller.motor
	if stage == "rising":
		position = get_parent().to_local(player_shape.global_position)
		if arrived or origin.y-position.y >= rise_distance-.01 or (ride_speed.y < 0 and motor.is_on_ceiling()): motor.exit_bubble()
	elif stage == "cooldown":
		wait_left = maxf(0,wait_left-delta)
		if wait_left <= 0:
			stage = "spawn_wait"
			position = origin
	elif stage == "spawn_wait":
		if not envelope.collide(global_transform,player_shape.shape,player_shape.global_transform) and not overlap(self,envelope,global_transform,[motor.get_rid()]):
			stage = "ready"
	elif envelope.collide(global_transform,player_shape.shape,player_shape.global_transform):
		if is_instance_valid(motor.bubble_carrier) or motor.last_action_step == Engine.get_physics_frames(): return
		var at := player_shape.global_transform
		at.origin = global_position
		if overlap(self,envelope,global_transform,[motor.get_rid()]) or overlap(self,player_shape.shape,at,[motor.get_rid()]) or motor.test_move(motor.global_transform,global_position-player_shape.global_position): return
		controller.traversal.cancel()
		motor.clear_recoil()
		motor.normal_velocity = Vector2.ZERO
		arrived = false
		motor.bubble_carrier = self
		stage = "rising"
		ride_speed = Vector2.ZERO
	queue_redraw()

func passenger_velocity(motor: PlayerMotor, delta: float) -> Vector2:
	var target := global_position
	var rise := minf(rise_speed*delta,maxf(0,rise_distance+position.y-origin.y))
	var move := Vector2.UP*rise
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = envelope
	q.transform = global_transform
	q.motion = move
	q.exclude = [motor.get_rid()]
	q.collision_mask = 1
	var space := get_world_2d().direct_space_state
	# A moving wall may enter the envelope from the side between two ticks.
	var current := space.get_rest_info(q)
	if not current.is_empty() and absf(current.normal.x) > .65:
		ride_speed = Vector2.ZERO
		return ride_speed
	var safe := space.cast_motion(q)
	if safe[0] < 1.0:
		q.transform.origin += move*minf(1.0,safe[1]+.001)
		q.motion = Vector2.ZERO
		var contact := space.get_rest_info(q)
		arrived = contact.is_empty() or contact.normal.y > .5
		move *= safe[0]
	ride_speed = (target+move-player_shape.global_position)/delta
	return ride_speed

func release_passenger(motor: PlayerMotor) -> void:
	if stage != "rising": return
	motor.normal_velocity = ride_speed.limit_length(rise_speed)
	stage = "cooldown"
	wait_left = respawn_delay_s
	queue_redraw()

func reset_attempt() -> void:
	if is_instance_valid(controller) and controller.motor.bubble_carrier == self: controller.motor.exit_bubble()
	stage = "spawn_wait"
	wait_left = 0
	ride_speed = Vector2.ZERO
	position = origin
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(controller) and controller.motor.bubble_carrier == self: controller.motor.exit_bubble()

func element_state() -> Dictionary:
	return {"phase":stage,"position":[position.x,position.y],"remaining":wait_left}

func element_restore(data: Dictionary) -> void:
	stage = data.phase
	position = FixedWorldProvider.point(data.position)
	wait_left = data.remaining
	if stage == "rising" and controller.motor.bubble_carrier != self:
		stage = "cooldown"
		wait_left = respawn_delay_s

func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var socket := origin-position+Vector2.DOWN*(bubble_radius*.81)
	var base_size := Vector2(bubble_radius*1.14,bubble_radius*.34)
	MechanismRegionArt.stamp(self,"mount",socket,base_size)
	MechanismRegionArt.stamp(self,"finial",socket+Vector2.UP*2,base_size*Vector2(.66,.85))
	if stage in ["cooldown","spawn_wait"]:
		for i: int in 3:
			var p := socket+Vector2(sin(wait_left*3+i*2.3)*5,-5-i*5)
			draw_rect(Rect2(p.round(),Vector2(2,2)),Color("84b8ab"))
		return
	var diameter := Vector2.ONE*bubble_radius*2
	TraversalMechanismArt.sprite(self,TraversalMechanismArt.BUBBLE,Vector2.ZERO,diameter)
	if stage=="rising":
		for i: int in 3:
			var p := Vector2(sin(position.y*.035+i*2.2)*bubble_radius*.50,bubble_radius+2+i*5)
			draw_rect(Rect2(p.round(),Vector2(2,2)),Color("b0e1ce"))
