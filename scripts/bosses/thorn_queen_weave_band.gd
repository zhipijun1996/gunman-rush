class_name ThornQueenWeaveBand
extends Node2D
## Non-solid visible thorn thread; whole-body damage via Policy, never pushes or blocks actors/shots.
signal weave_event(event: Dictionary)
var config: ThornQueenWeaveDefinition
var controller: PlayerController
var policy: FrameDamagePolicy
var lifetime: DemoLifetime
var start := Vector2.ZERO
var tip := Vector2.ZERO
var age := 0.0
var growth := 0.0
var severed := false
var suspended := false
var body: StaticBody2D
var shape: CollisionShape2D
var _rect: RectangleShape2D
var _previous_player := Vector2.ZERO
var _next_damage := 0.0
var _pulse := 0
var _epoch := 0
var field_id := "0"
var initial_angle := 0.0
var _previous_strip := PackedVector2Array()
var _danger_polygon := PackedVector2Array()
func configure(definition: ThornQueenWeaveDefinition,first: Vector2,last: Vector2,target: PlayerController,damage_policy: FrameDamagePolicy,life: DemoLifetime) -> void:
	config=definition;start=first;tip=last;controller=target;policy=damage_policy;lifetime=life
	_epoch=life.actor_epoch
	_previous_player=target.motor.global_position
	body=StaticBody2D.new()
	body.name="NonSolidWeaveReference"
	body.collision_layer=0
	body.collision_mask=0
	shape=CollisionShape2D.new()
	_rect=RectangleShape2D.new()
	_rect.size=Vector2(1,config.strand_radius*2)
	shape.shape=_rect
	shape.disabled=true
	body.add_child(shape)
	add_child(body)
	process_physics_priority=850
	set_physics_process(false)
func begin() -> bool:
	if severed or lifetime==null or not lifetime.active: return false
	age=0;growth=0;suspended=false
	initial_angle=(tip-start).angle() if rotating() else 0.0
	_previous_strip=PackedVector2Array();_danger_polygon=PackedVector2Array()
	_epoch=lifetime.actor_epoch
	_previous_player=controller.motor.global_position
	body.collision_layer=0
	shape.set_deferred("disabled",true)
	set_physics_process(true)
	return true
func _physics_process(delta: float) -> void:
	if severed or suspended or lifetime==null or not lifetime.active or not is_instance_valid(controller): return
	if lifetime.actor_epoch!=_epoch:
		# Actor recovery invalidates old damage, never erases/restarts the persistent field.
		_epoch=lifetime.actor_epoch
		_previous_player=controller.motor.global_position
	if not controller.active or controller.actor_resources.health.terminal: return
	age+=delta
	var next := clampf((age-config.preview_seconds)/config.grow_seconds,0,1)
	if growth==0 and next>0: weave_event.emit({"event":"weave_growth_started","age":age})
	growth=next
	var segment := current_segment(growth)
	var current_strip := strip_corners(segment[0],segment[1]) if growth>0 else PackedVector2Array()
	var swept := current_strip.duplicate()
	if rotating() or rising(): swept.append_array(_previous_strip)
	_danger_polygon=Geometry2D.convex_hull(swept) if swept.size()>=3 else PackedVector2Array()
	var player_at := controller.motor.global_position
	if growth>0:
		var player_shape := (controller.motor.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
		if polygon_body_sweep_hits(_danger_polygon,_previous_player,player_at,player_shape) and policy.clock>=_next_damage:
			var request := DamageRequest.new()
			request.token=lifetime.token();request.actor_epoch=lifetime.actor_epoch
			request.health_epoch=controller.actor_resources.health.epoch
			request.target_id=&"player";request.source_id=&"queen_growing_weave"
			request.event_id=StringName("queen/weave/%s/%s/%s"%[field_id,_epoch,_pulse])
			request.amount=config.strand_damage;request.kind=DamageRequest.Kind.MONSTER
			request.physics_tick=Engine.get_physics_frames()
			var accepted := policy.submit(request)
			weave_event.emit({"event":"weave_sweep","accepted":accepted,"id":String(request.event_id),"growth":growth,"actual_physical_contact":false,"solid":false,"geometry":"visible_interval_sweep_polygon","initial_angle":initial_angle,"player":[player_at.x,player_at.y]})
			_next_damage=policy.clock+config.strand_interval;_pulse+=1
	_previous_player=player_at
	_previous_strip=current_strip
	queue_redraw()
func cut() -> void:
	severed=true
	shape.set_deferred("disabled",true)
	body.collision_layer=0
	weave_event.emit({"event":"weave_severed","growth":growth,"age":age})
	queue_redraw()
func pause_battle() -> void:
	# Owner deactivation preserves persistent state; activation resumes the same clock.
	set_physics_process(false)
	if is_instance_valid(shape): shape.set_deferred("disabled",true)
	if is_instance_valid(body): body.collision_layer=0
func cancel() -> void:
	suspended=true
	set_physics_process(false)
	if is_instance_valid(shape): shape.set_deferred("disabled",true)
	if is_instance_valid(body): body.collision_layer=0
	queue_redraw()
func rotating() -> bool:
	return field_id==str(config.rotating_field_index)
func rising() -> bool:
	return field_id==str(config.rising_field_index)
func rise_offset(at_age: float) -> Vector2:
	var travel := fposmod(maxf(0,at_age-config.preview_seconds-config.grow_seconds),config.rising_travel*2/config.rising_speed)*config.rising_speed
	return Vector2(0,-minf(travel,config.rising_travel*2-travel))
func current_segment(amount: float) -> Array[Vector2]:
	if rising():
		var offset := rise_offset(age)
		return [start+offset,start.lerp(tip,amount)+offset]
	if not rotating(): return [start,start.lerp(tip,amount)]
	# Hold the announced direction throughout growth, then sweep at a bounded authored rate.
	var angle := initial_angle+deg_to_rad(config.rotating_degrees_per_second)*maxf(0,age-config.preview_seconds-config.grow_seconds)
	var direction := Vector2.from_angle(angle)
	var inner := config.rotating_inner_radius
	var outer := start.distance_to(tip)
	return [start+direction*inner,start+direction*lerpf(inner,outer,amount)]
func strip_corners(first: Vector2,last: Vector2) -> PackedVector2Array:
	var normal := (last-first).normalized().orthogonal()*config.strand_radius
	return PackedVector2Array([first-normal,first+normal,last+normal,last-normal])
func _draw() -> void:
	if config==null or severed or suspended: return
	var preview := current_segment(1)
	draw_line(to_local(preview[0]),to_local(preview[1]),Color("dfb684"),2,true)
	if rising():
		# Authored full travel and the next second are readable, without inventing an unseen hazard.
		var center := (start+tip)*.5
		var upper := Vector2(0,-config.rising_travel)
		draw_line(to_local(start+upper),to_local(tip+upper),Color("696c60"),1,true)
		draw_line(to_local(center),to_local(center-Vector2(0,config.rising_travel)),Color("847d69"),1,true)
		for index: int in 5:
			draw_circle(to_local(center+rise_offset(age+float(index)/4)),2,Color("efc499"))
	if rotating():
		# Direction and the next second of motion are visible before entering the thread.
		var angle := (preview[1]-preview[0]).angle()
		for index: int in 5:
			var future := angle+deg_to_rad(config.rotating_degrees_per_second)*float(index)/4
			var point := start+Vector2.from_angle(future)*start.distance_to(tip)
			draw_circle(to_local(point),2,Color("efc499"))
	if growth>0 and _danger_polygon.size()>=3:
		var local := PackedVector2Array()
		for point: Vector2 in _danger_polygon: local.append(to_local(point))
		draw_colored_polygon(local,Color("ab616c"))
		var current := current_segment(growth)
		draw_line(to_local(current[0]),to_local(current[1]),Color("e8a9a0"),2,true)
static func polygon_body_sweep_hits(hazard: PackedVector2Array,old_center: Vector2,new_center: Vector2,half: Vector2) -> bool:
	if hazard.size()<3: return false
	var sums := PackedVector2Array()
	for corner: Vector2 in hazard:
		for x: int in [-1,1]:
			for y: int in [-1,1]: sums.append(corner+Vector2(half.x*x,half.y*y))
	var polygon := Geometry2D.convex_hull(sums)
	if Geometry2D.is_point_in_polygon(old_center,polygon) or Geometry2D.is_point_in_polygon(new_center,polygon): return true
	for index: int in polygon.size()-1:
		if Geometry2D.segment_intersects_segment(old_center,new_center,polygon[index],polygon[index+1])!=null: return true
	return false
static func body_sweep_hits(first: Vector2,last: Vector2,radius: float,old_center: Vector2,new_center: Vector2,half: Vector2) -> bool:
	var axis := (last-first).normalized()
	if axis.is_zero_approx(): return false
	var normal := axis.orthogonal()*radius
	var corners: Array[Vector2]=[first-normal,first+normal,last+normal,last-normal]
	var sums := PackedVector2Array()
	for corner: Vector2 in corners:
		for x: int in [-1,1]:
			for y: int in [-1,1]: sums.append(corner+Vector2(half.x*x,half.y*y))
	var polygon := Geometry2D.convex_hull(sums)
	if Geometry2D.is_point_in_polygon(old_center,polygon) or Geometry2D.is_point_in_polygon(new_center,polygon): return true
	for index: int in polygon.size()-1:
		if Geometry2D.segment_intersects_segment(old_center,new_center,polygon[index],polygon[index+1])!=null: return true
	return false

func snapshot() -> Dictionary:
	return {"initial_angle":initial_angle,"age":age,"growth":growth,"severed":severed,"suspended":suspended,"pulse":_pulse,
		"next_damage_in":maxf(0,_next_damage-policy.clock)}
func valid_snapshot(data: Dictionary) -> bool:
	if not valid_snapshot_for(data,config): return false
	var expected := (tip-start).angle() if rotating() else 0.0
	return absf(float(data.initial_angle)-expected)<.000001
static func valid_snapshot_for(data: Dictionary,definition: ThornQueenWeaveDefinition) -> bool:
	if typeof(data.get("initial_angle")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.initial_angle)) or absf(float(data.initial_angle))>PI: return false
	for key: String in ["age","growth","next_damage_in","pulse"]:
		if typeof(data.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])) or float(data[key])<0: return false
	if float(data.pulse)!=floorf(float(data.pulse)) or float(data.growth)>1 or float(data.next_damage_in)>definition.strand_interval+.00001: return false
	if typeof(data.get("severed"))!=TYPE_BOOL or typeof(data.get("suspended"))!=TYPE_BOOL: return false
	return absf(float(data.growth)-clampf((float(data.age)-definition.preview_seconds)/definition.grow_seconds,0,1))<.00001
func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data): return false
	initial_angle=float(data.initial_angle)
	age=float(data.age);growth=float(data.growth);severed=bool(data.severed);suspended=bool(data.suspended)
	_pulse=int(data.pulse);_next_damage=policy.clock+float(data.next_damage_in)
	_epoch=lifetime.actor_epoch
	_previous_player=controller.motor.global_position
	_refresh_restored_collision()
	set_physics_process(false) # Encounter activates this instance after binding/restoration.
	return true
func resume_restored() -> void:
	_epoch=lifetime.actor_epoch
	_previous_player=controller.motor.global_position
	_refresh_restored_collision()
	set_physics_process(not severed and not suspended and lifetime.active)
func _refresh_restored_collision() -> void:
	# No actor/shot collision is ever enabled, including restore or reactivation.
	body.collision_layer=0;shape.set_deferred("disabled",true)
	var segment := current_segment(growth)
	_previous_strip=strip_corners(segment[0],segment[1]) if growth>0 else PackedVector2Array()
	_danger_polygon=Geometry2D.convex_hull(_previous_strip) if _previous_strip.size()>=3 else PackedVector2Array()
	queue_redraw()
