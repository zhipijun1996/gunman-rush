class_name ShotAimAssist
extends RefCounted
## A bounded correction at release; never rewrites input or recoil intent.
static var settings:Dictionary={}
static func resolve(controller:PlayerController,origin:Vector2,raw:Vector2,reach:float)->Vector2:
	if raw.is_zero_approx() or reach<=0:return raw
	if settings.is_empty():settings=JSON.parse_string(FileAccess.get_file_as_string("res://config/player_aim_assist.json"))
	var direction:=raw.normalized()
	var shape:=CircleShape2D.new();shape.radius=reach
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape
	query.transform=Transform2D(0,origin);query.collide_with_areas=true
	query.exclude=[controller.motor.get_rid()]
	var space:=controller.motor.get_world_2d().direct_space_state
	var best_angle:=INF
	var best_id:=0
	var correction:=0.0
	for hit:Dictionary in space.intersect_shape(query,96):
		var target:=hit.collider as CollisionObject2D
		if target==null:continue
		var receiver:=target.get_node_or_null("Damageable") as Damageable
		if receiver==null or not receiver.active or not receiver.can_receive_effects() or receiver.faction not in [&"enemy",&"mechanism"]:continue
		if receiver.aim_eligibility.is_valid() and not receiver.aim_eligibility.call():continue
		var offset:=target.global_position-origin
		if offset.length()>reach or offset.length()<float(settings.minimum_distance):continue
		var angle:=direction.angle_to(offset.normalized())
		if absf(angle)>deg_to_rad(float(settings.cone_degrees)):continue
		if not visible(space,controller.motor,origin,target):continue
		var id:=target.get_instance_id()
		if absf(angle)<best_angle or (is_equal_approx(absf(angle),best_angle) and id<best_id):
			best_angle=absf(angle);best_id=id;correction=angle
	var limit:=deg_to_rad(float(settings.max_correction_degrees))
	return direction.rotated(clampf(correction*float(settings.strength),-limit,limit))

static func visible(space:PhysicsDirectSpaceState2D,owner_body:CollisionObject2D,origin:Vector2,target:CollisionObject2D)->bool:
	var ray:=PhysicsRayQueryParameters2D.create(origin,target.global_position,0xFFFFFFFF,[owner_body.get_rid()])
	ray.collide_with_areas=true;ray.hit_from_inside=true
	for i:int in 16:
		var hit:=space.intersect_ray(ray)
		if hit.is_empty():return true
		var collider:=hit.collider as Node
		if collider==target:return true
		var receiver:=collider.get_node_or_null("Damageable") as Damageable
		if (collider is Area2D and receiver==null) or (receiver!=null and receiver.faction==&"player"):
			var excluded:=ray.exclude;excluded.append(hit.rid);ray.exclude=excluded;continue
		return false
	return false
