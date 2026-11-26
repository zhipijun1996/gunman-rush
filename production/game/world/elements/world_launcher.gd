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
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint := Color("a69788") if spawn_wait else Color.WHITE
	if launch_mode == "surface_normal":
		var diameter := Vector2.ONE*sphere_radius*2
		MechanismRegionArt.stamp(self,"mount",Vector2(0,sphere_radius*.72),diameter*Vector2(.9,.40),tint)
		TraversalMechanismArt.sprite(self,TraversalMechanismArt.FUNGUS,Vector2.ZERO,diameter,tint)
		if latched: draw_arc(Vector2.ZERO,sphere_radius-1,PI*1.12,PI*1.77,18,Color("f9d99a"),2)
	elif launch_mode == "contact":
		var body := Rect2(-face_size/2,face_size)
		MechanismRegionArt.panel(self,body,tint)
		TraversalMechanismArt.sprite(self,TraversalMechanismArt.SPRING,Vector2.ZERO,face_size,tint)
		var direction := launch_direction.normalized()
		var point := direction*minf(face_size.x,face_size.y)*.36
		for i: int in 2:
			var tip := point+direction*(5+5*i)
			var back := tip-direction*4
			draw_polyline(PackedVector2Array([(back+direction.orthogonal()*4).round(),tip.round(),(back-direction.orthogonal()*4).round()]),Color("ffe69b") if not latched else Color("d38d56"),2)
	else:
		var warning := clampf((elapsed-(pulse_interval_s-pulse_warning_s))/pulse_warning_s,0,1)
		MechanismRegionArt.stamp(self,"mount",Vector2.ZERO,Vector2(48,42))
		TraversalMechanismArt.sprite(self,TraversalMechanismArt.EMITTER,Vector2.ZERO,Vector2(35,35))
		var pulse := Color("c7edc6")
		for sector: int in 12:
			var angle := float(sector)*TAU/12.0
			draw_arc(Vector2.ZERO,pulse_radius,angle,angle+.21,8,Color(pulse,.26+.50*warning),1)
			if warning>0:
				draw_arc(Vector2.ZERO,lerpf(16,pulse_radius,warning),angle,angle+.34,8,Color(pulse,.42+.4*warning),2)
