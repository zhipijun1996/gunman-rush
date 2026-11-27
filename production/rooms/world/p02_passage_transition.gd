class_name P02PassageTransition
extends RefCounted
## A doorway is a finite oriented section; a position already beyond its plane
## (including a recovery teleport) is not a crossing.
const REVEAL_SECONDS := .08
const WALK_SECONDS := .4
const WALK_AXIS := .25
const REARM_DISTANCE := 18.0

static func crossed(gate: Dictionary, before: Vector2, after: Vector2) -> bool:
	var point := FixedWorldProvider.point(gate.point)
	var normal := FixedWorldProvider.point(gate.direction)
	var from := (before-point).dot(normal)
	var to := (after-point).dot(normal)
	if from >= 0.0 or to < 0.0: return false
	var intersection := before.lerp(after, -from/(to-from))
	var along := intersection.y if normal.x!=0 else intersection.x
	return along>=float(gate.span[0]) and along<=float(gate.span[1])

static func is_inside(gate: Dictionary, center: Vector2) -> bool:
	return (center-FixedWorldProvider.point(gate.point)).dot(FixedWorldProvider.point(gate.direction)) < -REARM_DISTANCE

static func mapped_position(source: Dictionary, destination: Dictionary, at: Vector2) -> Vector2:
	return FixedWorldProvider.point(destination.point) + at - FixedWorldProvider.point(source.point)

static func clearance(space: PhysicsDirectSpaceState2D, at: Vector2, collider: CollisionShape2D, mask: int) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = collider.shape
	q.collision_mask = mask
	q.transform = Transform2D(0,at+collider.position+Vector2.UP*.1)
	return space.intersect_shape(q,1).is_empty()

static func supported(space: PhysicsDirectSpaceState2D, at: Vector2, collider: CollisionShape2D, mask: int) -> bool:
	if not clearance(space,at,collider,mask): return false
	var half := (collider.shape as RectangleShape2D).size*.5
	var feet := at+collider.position+Vector2.DOWN*half.y
	for x: float in [1-half.x,0.0,half.x-1]:
		var ray := PhysicsRayQueryParameters2D.create(feet+Vector2(x,-.2),feet+Vector2(x,8),mask)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or Vector2(hit.normal).dot(Vector2.UP)<.7: return false
	return true

static func validate_landing(host: Node, doc: Dictionary, gate: Dictionary, at: Vector2, motor: PlayerMotor) -> String:
	# Instantiate the destination's actual authored collision in a separate
	# physics world. Overlapping local coordinates of the source cannot offer
	# false support or mask a blocked entrance.
	var made := WorldRoomDocument.instantiate(doc)
	if made.has("error"): return str(made.error)
	var sample := made.room as FixedWorldRoom
	sample.configure({"doors":[],"camera":{},"world_geometry":WorldRoomSpace.document_geometry(doc.bounds,doc.exits)})
	var probe := SubViewport.new()
	probe.world_2d = World2D.new()
	probe.disable_3d = true
	probe.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(probe)
	WorldRoomAssembly.build_collision(sample,probe)
	sample.free()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var space := probe.world_2d.direct_space_state
	var collider := motor.get_node("CollisionShape2D") as CollisionShape2D
	var mask := motor.collision_mask
	var result := ""
	if not clearance(space,at,collider,mask):
		result = "arrival_body_obstructed"
	elif not supported(space,FixedWorldProvider.point(gate.spawn),collider,mask):
		result = "arrival_support_missing"
	probe.queue_free()
	return result
