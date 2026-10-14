class_name WeaponEntity
extends Node2D
## A bounded physical blade/mine. Player displacement belongs exclusively to Motor.
var runtime: WeaponActionRuntime
var kind: StringName
var direction := Vector2.RIGHT
var phase: StringName = &"outbound"
var age := 0.0
var skill := false
var spent := false
var manual_recall := false
var session := 0
var packet := 0
var serial := 0
var start_point := Vector2.ZERO
var attached: Node2D
var attachment := Vector2.ZERO
var _return_direction := Vector2.ZERO
var _ignored: Array[RID] = []
var trail: Array[Vector2] = []
func _ready() -> void:
	z_index=7
	process_mode=Node.PROCESS_MODE_PAUSABLE
func valid_owner() -> bool:
	return is_instance_valid(runtime) and runtime.valid_session(session) and not spent
func recall() -> bool:
	if kind != &"boomerang" or phase not in [&"outbound",&"auto_return"] or not valid_owner(): return false
	var center := runtime.actor().motor.global_position
	_return_direction=(center-global_position).normalized()
	direction=_return_direction
	manual_recall=true;phase=&"returning";_ignored.clear()
	runtime.entity_transition.emit(self,&"returning")
	# Same accepted tick, swept against the world along the locked return line.
	var start := global_position
	if _sweep(center-start):
		trail.append(start);trail.append(global_position)
		runtime.return_flash(start,global_position)
		runtime.caught(self,_return_direction)
	return true
func _physics_process(delta: float) -> void:
	if not valid_owner(): dispose();return
	age+=delta
	var def := runtime.definition()
	if age >= def.entity_lifetime:runtime.entity_failed(self);dispose();return
	trail.append(global_position)
	if trail.size()>12:trail.pop_front()
	if phase == &"attached":
		if not is_instance_valid(attached) or not attached.is_inside_tree():dispose();return
		global_position=attached.to_global(attachment)
	elif kind == &"bomb":
		if age>=def.fuse_seconds:runtime.explode(self)
	elif kind == &"mine":
		var remaining := maxf(0,def.range_limit-start_point.distance_to(global_position))
		if remaining<=.01:runtime.entity_failed(self);dispose();return
		_sweep(direction*minf(remaining,def.projectile_speed*delta))
	elif kind == &"boomerang":
		var speed := def.steering_speed
		if phase==&"outbound":
			var remaining := maxf(0,def.range_limit-start_point.distance_to(global_position))
			if remaining<=.01:
				phase=&"auto_return";_ignored.clear();runtime.entity_transition.emit(self,&"auto_return")
			else:
				direction=runtime.steer_direction(self,direction)
				_sweep(direction*minf(remaining,speed*delta))
		if phase==&"auto_return" and not spent:
			var center := runtime.actor().motor.global_position
			direction=(center-global_position).normalized()
			var motion := direction*speed*delta
			var nearest := Geometry2D.get_closest_point_to_segment(center,global_position,global_position+motion)
			if nearest.distance_to(center)<=def.catch_radius:
				if _sweep(nearest-global_position):runtime.caught(self,direction)
			else:_sweep(motion)
	queue_redraw()
func _sweep(motion: Vector2) -> bool:
	var start := global_position
	var finish := start+motion
	var exclusions: Array[RID]=[runtime.actor().motor.get_rid()]
	exclusions.append_array(_ignored)
	for attempt: int in 32:
		var ray := PhysicsRayQueryParameters2D.create(start,finish,0xFFFFFFFF,exclusions)
		ray.collide_with_areas=true
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():global_position=finish;return true
		var collider := hit.collider as Node2D
		var receiver := collider.get_node_or_null("Damageable") as Damageable if collider!=null else null
		if kind==&"bomb" and (collider is PhysicsBody2D or (receiver!=null and receiver.faction==&"enemy")):
			global_position=hit.position-direction*.5;return true
		if kind==&"mine" and collider is PhysicsBody2D and (receiver==null or receiver.active):
			# Keep the attached blast origin just outside the contacted solid.
			# A ray beginning exactly inside its face can miss that same wall.
			global_position=hit.position+hit.normal*.5
			attached=collider;attachment=collider.to_local(global_position);phase=&"attached";runtime.entity_attached(self);return false
		if receiver!=null and receiver.active and receiver.faction==&"enemy":
			if kind==&"mine":
				global_position=hit.position;attached=collider;attachment=collider.to_local(global_position);phase=&"attached";runtime.entity_attached(self);return false
			runtime.hit(receiver,packet,serial,String(phase),skill,hit.position,direction)
			_ignored.append(hit.rid);exclusions.append(hit.rid)
		elif collider is Area2D:
			exclusions.append(hit.rid)
		else:
			global_position=hit.position;runtime.entity_failed(self);dispose();return false
	runtime.entity_failed(self);dispose();return false
func dispose() -> void:
	if spent:return
	spent=true;set_physics_process(false);queue_free()
func _draw() -> void:
	for i: int in range(1,trail.size()):
		draw_line(to_local(trail[i-1]),to_local(trail[i]),Color(.3,.85,1,float(i)/trail.size()*.65),3 if skill else 1.5,true)
	var art_index := 2 if kind==&"boomerang" else 4 if kind==&"mine" else 3
	var catalog := runtime.art_catalog()
	if catalog.is_empty():return
	var region: Array=catalog.regions[art_index]
	var width := 36.0 if kind==&"boomerang" else 24.0
	if skill:width*=1.45
	var texture := PlainsActorAssets.region_texture(catalog.texture,region)
	var size := Vector2(width,width*float(region[3])/float(region[2]))
	draw_set_transform(Vector2.ZERO,age*14 if kind==&"boomerang" else 0)
	draw_texture_rect(texture,Rect2(-size/2,size),false)
	draw_set_transform(Vector2.ZERO)
	if kind==&"mine":
		draw_arc(Vector2.ZERO,18,0,TAU*minf(1,age/.25),24,Color(1,.48,.3,.5+.25*sin(age*8)),1.5,true)
