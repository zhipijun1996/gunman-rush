class_name EmitterProjectile
extends EnemyAttackProjectile
var host: Dictionary
var settings: Dictionary
var source := ""

func launch(context: Dictionary, id: String, profile_data: Dictionary, origin: Vector2, velocity: Vector2) -> void:
	host = context
	source = id
	settings = profile_data
	token = context.lifetime.token()
	event_id = id
	radius = settings.radius
	_shape.radius = radius
	remaining = settings.lifetime
	direction = velocity.normalized()
	speed = velocity.length()
	context.room.add_child(self)
	global_position = origin
	if context.has("emitter"): context.emitter.reset_effects.connect(dispose)
	ProjectileFlight.register_at(self,context.controller,"enemy")

func _physics_process(delta: float) -> void:
	if spent: return
	if not host.controller.active or not host.lifetime.accepts(token):
		dispose()
		return
	var step := minf(delta,remaining)
	remaining -= delta
	var velocity := direction*speed
	var gravity := Vector2.DOWN*float(settings.gravity)
	var advance_velocity := velocity+gravity*step*0.5
	direction = advance_velocity.normalized()
	flight.advance(self,host.controller,"enemy",advance_velocity,step,_move_swept)
	if not spent:
		velocity = direction*advance_velocity.length()+gravity*step*.5
		direction = velocity.normalized()
		speed = velocity.length()
		if remaining<=0: dispose()
	queue_redraw()

func _move_swept(motion: Vector2) -> void:
	if spent: return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform.origin = global_position
	query.collision_mask = 1
	query.exclude = flight.grate_excludes
	var space := get_world_2d().direct_space_state
	var hit := space.get_rest_info(query)
	var fraction := 0.0
	if hit.is_empty():
		query.motion = motion
		var cast := space.cast_motion(query)
		fraction = cast[1] if cast.size()==2 else 1.0
		if fraction < 1:
			query.transform.origin += motion*minf(1,fraction+.00001)
			query.motion = Vector2.ZERO
			hit = space.get_rest_info(query)
	var gear: EquipmentRuntime = host.controller.item_runtime
	if gear != null and gear.scene.intercept(self,motion,fraction): return
	if hit.is_empty() and fraction>=1:
		global_position += motion
		return
	if not hit.is_empty():
		var body := instance_from_id(hit.collider_id) as PhysicsBody2D
		if body==host.controller.motor:
			ProjectileImpact.submit_hit(host,"player",source,str(event_id),direction,settings,false)
		elif body!=null and settings.impact_effect=="ember_pool":
			EmberPool.create(host,body,hit.point,hit.normal,settings.ember_pool,source+"/ember")
	dispose()

func advance_frozen_contact() -> void:
	if not spent and host.controller.active: _move_swept(Vector2.ZERO)
func _draw() -> void:
	draw_circle(Vector2.ZERO,radius,Color("ffd078") if settings.impact_effect=="ember_pool" else Color("e0be96"))
	draw_line(-direction*radius*2,Vector2.ZERO,Color("bf7648"),radius*0.8)
