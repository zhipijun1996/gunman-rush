class_name EmberPool
extends Node2D
var host: Dictionary
var support: PhysicsBody2D
var surface_shape: Node2D
var start := Vector2.ZERO
var end := Vector2.ZERO
var depth := 12.0
var remaining := 2.0
var source_id := ""
var resource: Dictionary
var due := {}
var elapsed := 0.0

static func create(context: Dictionary, collider: PhysicsBody2D, point: Vector2, normal: Vector2, settings: Dictionary, id: String) -> void:
	if not is_instance_valid(collider) or collider is EnemyMotor or collider is PlayerMotor or normal.dot(Vector2.UP)<cos(context.controller.motor.floor_max_angle): return
	var best := INF
	var edge := PackedVector2Array()
	var surface: Node2D
	for shape_node: Node in collider.get_children():
		var polygon := PackedVector2Array()
		if shape_node is CollisionShape2D and not shape_node.disabled and shape_node.shape is RectangleShape2D:
			var rect: Rect2 = shape_node.shape.get_rect()
			polygon = PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
		elif shape_node is CollisionPolygon2D and not shape_node.disabled: polygon = shape_node.polygon
		else: continue
		for i in polygon.size():
			var a: Vector2 = shape_node.to_global(polygon[i])
			var b: Vector2 = shape_node.to_global(polygon[(i+1)%polygon.size()])
			var right := a.direction_to(b)
			if absf(right.dot(normal))>0.1: continue
			var at := Geometry2D.get_closest_point_to_segment(point,a,b)
			var dist := at.distance_to(point)
			if dist>=best: continue
			best = dist
			surface = shape_node
			if right.orthogonal().dot(normal)<0:
				var swap := a
				a = b
				b = swap
				right = -right
			edge = PackedVector2Array([at-right*minf(at.distance_to(a),settings.width/2),at+right*minf(at.distance_to(b),settings.width/2)])
	if edge.size()!=2 or edge[0].distance_to(edge[1])<0.001: return
	var pool := EmberPool.new()
	pool.host = context
	pool.support = collider
	pool.surface_shape = surface
	pool.transform = collider.global_transform.affine_inverse()*surface.global_transform
	pool.start = surface.to_local(edge[0])
	pool.end = surface.to_local(edge[1])
	pool.source_id = id
	pool.depth = settings.depth
	pool.remaining = settings.duration_s
	pool.resource = WorldHazardArea.profile(settings.hazard_profile)
	collider.add_child(pool)
	if context.has("emitter"): context.emitter.reset_effects.connect(pool.expire)

func expire() -> void:
	set_physics_process(false)
	hide()
	queue_free()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(surface_shape) or surface_shape.disabled:
		expire()
		return
	transform = support.global_transform.affine_inverse()*surface_shape.global_transform
	var n := start.direction_to(end).orthogonal()
	if not host.lifetime.active or not host.controller.active or support.collision_layer==0 or n.rotated(global_rotation).dot(Vector2.UP)<cos(host.controller.motor.floor_max_angle):
		queue_free()
		return
	var live_delta := minf(remaining,delta)
	remaining -= delta
	elapsed += live_delta
	var points := global_transform * PackedVector2Array([start,end,end+n*depth,start+n*depth])
	var bodies := ProjectileImpact.bodies(host)
	for id: String in bodies:
		var rect := ProjectileImpact.bounds_of(bodies[id])
		if not ProjectileImpact.overlaps(points,rect): continue
		if elapsed < float(due.get(id,0)): continue
		due[id] = elapsed+resource.interval
		ProjectileImpact.submit_hit(host,id,source_id,source_id+"/"+str(Engine.get_physics_frames()),n,resource)
	if remaining<=0: queue_free()
	queue_redraw()
func _draw() -> void:
	var n := start.direction_to(end).orthogonal()
	draw_colored_polygon(PackedVector2Array([start,end,end+n*depth,start+n*depth]),Color(Color(resource.color),.72))
	draw_line(start+n*2,end+n*2,Color("ffd081"),3)
