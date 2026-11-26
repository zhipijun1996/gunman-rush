class_name ProjectileFlight
extends RefCounted
## Integrate native motion in travel-time order. The original projectile still owns
## walls, damage, lifetime and attack identity, including piercing and equipment.
const EPS := 0.0005
var frame_start := 0.0
var frame_length := 1.0
var reflections := 0
var reflection_normal := Vector2.ZERO
var mirror_contacts := {}
var grate_excludes: Array[RID] = []

class Probe extends Node2D:
	var spent := false
	var direction := Vector2.RIGHT
	var radius := 0.0
	func dispose() -> void: spent = true
	func sweep(motion: Vector2) -> void: position += motion

var projecting := false
var projected_button := INF

func button_time(round: PlayerProjectile, step: float) -> float:
	var estimate := ProjectileFlight.new()
	estimate.projecting = true
	estimate.reflections = reflections
	estimate.mirror_contacts = mirror_contacts.duplicate()
	var probe := Probe.new()
	probe.position = round.global_position
	probe.radius = round.radius
	probe.direction = round.direction
	if not round.launch_motion.is_zero_approx():
		estimate.advance(probe,round.owner_controller,"player",round.launch_motion,1,probe.sweep,{},INF,true)
		if is_finite(estimate.projected_button): estimate.projected_button = 0
	if not probe.spent:
		var budget := maxf(0,round.max_distance-round.traveled_distance) if round.max_distance>0 else INF
		estimate.advance(probe,round.owner_controller,"player",probe.direction*round.speed,step,probe.sweep,{},budget)
	probe.free()
	return estimate.projected_button

static func register_at(projectile: Node2D, owner_node: Node, faction: String) -> void:
	var group := StringName("ordinary_flight_"+faction)
	if projectile.is_in_group(group): return
	projectile.add_to_group(group)
	for field: ProjectileField in ProjectileField.fields_for(owner_node):
		if field is ProjectileBarrier and field.consume_inside(projectile,faction): return

static func slab(point: Vector2, unit: Vector2, rect: Rect2) -> Vector2:
	var near := -INF
	var far := INF
	for axis: int in 2:
		if absf(unit[axis]) < 0.0000001:
			if point[axis] < rect.position[axis] or point[axis] > rect.end[axis]: return Vector2(INF,-INF)
			continue
		var a: float = (rect.position[axis]-point[axis])/unit[axis]
		var b: float = (rect.end[axis]-point[axis])/unit[axis]
		near = maxf(near,minf(a,b))
		far = minf(far,maxf(a,b))
	return Vector2(near,far)

func advance(projectile: Node2D, owner_node: Node, faction: String, velocity: Vector2, delta: float, sweep: Callable, packet: Dictionary = {}, distance_limit := INF, placement := false) -> void:
	if not projecting: register_at(projectile,owner_node,faction)
	if projectile.spent: return
	var fields := ProjectileField.fields_for(owner_node)
	grate_excludes.clear()
	for field: ProjectileField in fields:
		if field is ProjectileGrate and field.body != null: grate_excludes.append(field.body.get_rid())
	var motion_speed := velocity.length()
	var unit := velocity.normalized()
	var left := delta
	var budget := distance_limit
	var loops := 0
	while not projectile.spent and left > 0.0000001 and budget > EPS:
		loops += 1
		if loops > 8 + fields.size()*5:
			# A stable field has at most two boundaries per straight leg; a bullet can reflect once.
			projectile.dispose()
			return
		var at := projectile.global_position
		var multiplier := 1.0
		var boundary := INF
		for field: ProjectileField in fields:
			if placement or not field is ProjectileDrag or faction not in field.factions: continue
			var interval := slab(field.to_local(at), field.to_local(at+unit)-field.to_local(at), field.bounds)
			if interval.y <= EPS or interval.x >= interval.y: continue
			if interval.x <= EPS:
				multiplier = minf(multiplier,field.speed_scale)
				boundary = minf(boundary,interval.y)
			else: boundary = minf(boundary,interval.x)
		var speed := motion_speed*multiplier
		var distance := minf(budget,minf(boundary,speed*left))
		var elapsed := distance/speed if speed > EPS else left
		var contact: Dictionary = {}
		for field: ProjectileField in fields:
			if not field.has_method("contact"): continue
			var candidate: Dictionary = field.contact(at, unit*distance, projectile.radius, faction, delta-left, elapsed, delta)
			if candidate.is_empty(): continue
			candidate.field = field
			if contact.is_empty() or candidate.t < contact.t-EPS or (absf(candidate.t-contact.t)<=EPS and candidate.priority < contact.priority):
				contact = candidate
		frame_start = 0.0 if placement else (delta-left)/delta
		frame_length = 0.0 if placement else elapsed/delta
		if contact.is_empty():
			var previous_direction: Vector2 = projectile.direction
			sweep.call(unit*distance)
			if not previous_direction.is_equal_approx(projectile.direction): return
			if motion_speed <= EPS: return
			budget -= distance
			left -= elapsed
			continue
		var travel := distance*float(contact.t)
		var point := at+unit*travel
		# The field wins a tie. Stop native collision infinitesimally before its face.
		frame_length *= float(contact.t)
		if travel > EPS:
			var previous_direction: Vector2 = projectile.direction
			sweep.call(unit*(travel-EPS))
			if not previous_direction.is_equal_approx(projectile.direction): return
		if projectile.spent: return
		projectile.global_position = point
		if contact.get("kind") == "mirror":
			var key: int = contact.field.get_instance_id()
			mirror_contacts[key] = true
			if reflections == 0 and contact.reflect:
				reflections += 1
				reflection_normal = contact.normal
				unit = unit.bounce(reflection_normal)
				projectile.direction = projectile.direction.bounce(reflection_normal)
				projectile.global_position += reflection_normal*EPS*4.0
				left -= elapsed*float(contact.t)
				budget -= travel
				continue
		elif contact.get("kind") == "button":
			if faction == "player" and not mirror_contacts.has(contact.field.get_instance_id()):
				packet.hit_fraction = 0.0 if placement else (delta-left+elapsed*float(contact.t))/delta
				if projecting: projected_button = packet.hit_fraction
				else: contact.field.command_turn(packet)
		elif not projecting:
			contact.field.dissipate(point)
		projectile.dispose()
