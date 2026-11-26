class_name WorldLauncher
extends TraversalMechanism

@export_enum("contact","surface_normal","radial_pulse") var launch_mode := "contact"
@export var face_size := Vector2(64,20)
@export var launch_direction := Vector2.UP
@export var sphere_radius := 32.0
@export var rearm_distance := 4.0
@export var launch_speed := 640.0
@export var pulse_radius := 128.0
@export var pulse_interval_s := 2.0
@export var pulse_warning_s := 0.40
var body: StaticBody2D
var geometry: CollisionShape2D
var latched := false
var elapsed := 0.0
var serial := 0
var spawn_wait := true

func _ready() -> void:
	process_physics_priority = 800
	if launch_mode == "radial_pulse":
		spawn_wait = false
		return
	body = StaticBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	add_child(body)
	if launch_mode == "contact":
		geometry = rectangle(body,face_size)
	else:
		geometry = CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = sphere_radius
		geometry.shape = shape
		body.add_child(geometry)

func element_bind(context: Dictionary) -> void:
	super.element_bind(context)
	controller.motor.repositioned.connect(reset_contact)
	reset_contact()

func reset_attempt() -> void:
	elapsed = 0
	serial = 0
	reset_contact()

func reset_contact() -> void:
	latched = false
	if body != null:
		body.collision_layer = 0
		spawn_wait = true

func _physics_process(delta: float) -> void:
	if not live(): return
	var motor := controller.motor
	if launch_mode == "radial_pulse":
		elapsed += delta
		if elapsed >= pulse_interval_s:
			elapsed = fposmod(elapsed,pulse_interval_s)
			serial += 1
			var offset := player_shape.global_position-global_position
			var ray := PhysicsRayQueryParameters2D.create(global_position,player_shape.global_position,1,[motor.get_rid()])
			if offset.length() <= pulse_radius and get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				launch(Vector2.UP if offset.is_zero_approx() else offset.normalized())
		queue_redraw()
		return
	if spawn_wait:
		if geometry.shape.collide(geometry.global_transform,player_shape.shape,player_shape.global_transform): return
		if launch_mode == "surface_normal" and overlap(self,geometry.shape,geometry.global_transform,[motor.get_rid(),body.get_rid()]): return
		spawn_wait = false
		body.collision_layer = 1
	var touching := false
	for i: int in motor.get_slide_collision_count():
		var hit := motor.get_slide_collision(i)
		if hit.get_collider() != body: continue
		touching = true
		if not latched:
			latched = true
			serial += 1
			launch(hit.get_normal() if launch_mode=="surface_normal" else launch_direction.normalized())
		break
	if latched and not touching:
		var box := player_box()
		if launch_mode == "surface_normal":
			if global_position.distance_to(global_position.clamp(box.position,box.end)) >= sphere_radius+rearm_distance: latched=false
		elif not box.intersects(geometry.global_transform * geometry.shape.get_rect(),true): latched = false
	queue_redraw()

func launch(direction: Vector2) -> void:
	controller.traversal.cancel()
	controller.motor.world_launch(direction*launch_speed)

func element_state() -> Dictionary:
	return {"phase":"waiting" if spawn_wait else "ready","latched":latched,"elapsed":elapsed,"serial":serial}

func element_restore(data: Dictionary) -> void:
	latched = data.latched
	elapsed = data.elapsed
	serial = data.serial

func _draw() -> void:
	var amber := Color("bbdb89") if not latched else Color("f1c36d")
	if launch_mode == "surface_normal":
		draw_circle(Vector2.ZERO,sphere_radius,Color("59684d"))
		draw_arc(Vector2.ZERO,sphere_radius-1,0,TAU,32,amber,3)
	elif launch_mode == "contact":
		draw_rect(Rect2(-face_size/2,face_size),Color("536554"))
		var dir := launch_direction.normalized()
		draw_line(-dir*6,dir*11,amber,3)
		draw_line(dir*11,dir*11-dir.rotated(.55)*7,amber,2)
		draw_line(dir*11,dir*11-dir.rotated(-.55)*7,amber,2)
	else:
		draw_circle(Vector2.ZERO,11,Color("546954"))
		var warning := clampf((elapsed-(pulse_interval_s-pulse_warning_s))/pulse_warning_s,0,1)
		draw_arc(Vector2.ZERO,pulse_radius,0,TAU,48,Color(amber,.20+warning*.75),2)
		draw_circle(Vector2.ZERO,5+warning*5,amber)
