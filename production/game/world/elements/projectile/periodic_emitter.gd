class_name PeriodicEmitter
extends Node2D
signal reset_effects

@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export var time_profile := "incompatible"
@export_enum("projectile","stream") var emit_mode := "projectile"
@export_enum("fixed","track_lock","manual_index") var aim_mode := "fixed"
@export var base_direction := Vector2.RIGHT
@export var projectile_profile := "inherit"
@export var projectile_speed := 300.0
@export var warning_time := 0.50
@export var burst_count := 1
@export var shot_interval := 0.15
@export var cycle_cooldown := 1.50
@export var acquire_range := 480.0
@export var aim_arc_deg := 120.0
@export var track_duration := 0.80
@export var turn_speed_deg := 180.0
@export var manual_angles_deg: Array[float] = [0,90,180,270]
@export var initial_aim_index := 0
@export var manual_turn_s := 0.35
@export var stream_profile := "inherit"
@export var stream_range := 320.0
@export var stream_width := 24.0
@export var stream_duration_s := 1.0
@export var initial_active := true
var active := true
var phase := "warning"
var phase_time := 0.0
var angle := 0.0
var locked := Vector2.RIGHT
var index := 0
var turn_start := 0.0
var turn_arc := 0.0
var turn_age := 0.0
var turning := false
var rounds := 0
var serial := 0
var stream_length := 0.0
var stream_angle := 0.0
var clock := 0.0
var host: Dictionary
var profile_data: Dictionary
var due := {}
var receipts := {}
var ring: StaticBody2D

func _ready() -> void:
	active = initial_active
	index = initial_aim_index
	angle = base_direction.angle()
	if aim_mode=="manual_index":
		angle += deg_to_rad(manual_angles_deg[index])
		ring = StaticBody2D.new()
		ring.collision_layer = 8
		ring.collision_mask = 0
		var circle := CircleShape2D.new()
		circle.radius = 13
		var collider := CollisionShape2D.new()
		collider.shape = circle
		ring.add_child(collider)
		add_child(ring)
	begin_cycle()

func element_bind(context: Dictionary) -> void:
	host = context.duplicate()
	host.emitter = self
	var def: Dictionary = WorldElementCatalog.catalog().definitions["hazard.periodic_emitter"]
	if emit_mode=="stream":
		profile_data = WorldHazardArea.profile(def.bindings.stream_profile if stream_profile=="inherit" else stream_profile)
	else:
		profile_data = ProjectileImpact.profile(def.bindings.projectile_profile if projectile_profile=="inherit" else projectile_profile)

func cancel_pending() -> void:
	reset_effects.emit()
	receipts.clear()
	due.clear()

func begin_cycle() -> void:
	phase_time = 0
	phase = "idle" if aim_mode=="track_lock" else "warning"
	locked = Vector2.from_angle(angle+global_rotation)
	rounds = 0
	stream_length = 0

func mechanism_shot(packet: Dictionary) -> bool:
	if aim_mode!="manual_index" or host.is_empty() or packet.controller!=host.controller or receipts.has(packet.packet_id): return false
	receipts[packet.packet_id] = true
	if turning: return false
	index = (index+1)%manual_angles_deg.size()
	turn_start = angle
	turn_arc = fposmod(base_direction.angle()+deg_to_rad(manual_angles_deg[index])-angle,TAU)
	turn_age = 0
	turning = true
	return true

func target_visible() -> bool:
	var diff: Vector2 = host.controller.motor.global_position-global_position
	if diff.is_zero_approx() or diff.length()>acquire_range or absf(base_direction.rotated(global_rotation).angle_to(diff))>deg_to_rad(aim_arc_deg)*.5: return false
	var query := PhysicsRayQueryParameters2D.create(global_position,global_position+diff,1,[host.controller.motor.get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if host.is_empty(): return
	if not host.controller.active or not host.lifetime.active:
		begin_cycle()
		turning = false
		queue_redraw()
		return
	var old_angle := angle
	if turning:
		turn_age = minf(manual_turn_s,turn_age+delta)
		angle = turn_start+turn_arc*turn_age/manual_turn_s
		turning = turn_age<manual_turn_s
	clock += delta
	if not active:
		queue_redraw()
		return
	if phase=="idle" or phase=="tracking":
		if not target_visible():
			phase = "idle"
			phase_time = 0
		else:
			phase = "tracking"
			angle = rotate_toward(angle,to_local(host.controller.motor.global_position).angle(),deg_to_rad(turn_speed_deg)*delta)
			phase_time += delta
			if phase_time>=track_duration:
				locked = Vector2.from_angle(angle+global_rotation)
				phase = "warning"
				phase_time = 0
	elif phase=="warning":
		phase_time += delta
		if phase_time>=warning_time:
			phase_time = 0
			if emit_mode=="stream":
				phase = "streaming"
				stream_step(old_angle)
			else: fire_round()
	elif phase=="burst":
		phase_time += delta
		if phase_time>=shot_interval: fire_round()
	elif phase=="streaming":
		phase_time += delta
		stream_step(old_angle)
		if phase_time>=stream_duration_s:
			phase = "cooldown"
			phase_time = 0
			stream_length = 0
	elif phase=="cooldown":
		phase_time += delta
		if phase_time>=cycle_cooldown: begin_cycle()
	queue_redraw()

func fire_round() -> void:
	var projectile := EmitterProjectile.new()
	var dir := Vector2.from_angle(angle+global_rotation) if aim_mode=="manual_index" else locked
	serial += 1
	var id := "%s/%s/%d/%d" % [host.room.room_id,element_id,get_instance_id(),serial]
	projectile.launch(host,id,profile_data,global_position,dir*projectile_speed)
	rounds += 1
	phase_time = 0
	phase = "burst" if rounds<burst_count else "cooldown"

func stream_step(old: float) -> void:
	var from := old+global_rotation if aim_mode=="manual_index" else locked.angle()
	var to := angle+global_rotation if aim_mode=="manual_index" else from
	var bodies := ProjectileImpact.bodies(host)
	var exclude: Array[RID] = []
	for body: PhysicsBody2D in bodies.values(): exclude.append(body.get_rid())
	stream_angle = to-global_rotation
	var samples := maxi(1,ceili(absf(to-from)*stream_range/maxf(1,stream_width*.125)))
	for i: int in range(samples+1):
		var dir := Vector2.from_angle(lerpf(from,to,float(i)/samples))
		var side := dir.orthogonal()*stream_width/2
		var shape := SegmentShape2D.new()
		shape.a = -side
		shape.b = side
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform.origin = global_position
		query.exclude = exclude
		query.collision_mask = 1
		var space := get_world_2d().direct_space_state
		stream_length = 0
		if space.intersect_shape(query,1).is_empty():
			query.motion = dir*stream_range
			stream_length = space.cast_motion(query)[0]*stream_range
		if stream_length<=0: continue
		var tip := global_position+dir*stream_length
		var polygon := PackedVector2Array([global_position+side,tip+side,tip-side,global_position-side])
		for id: String in bodies:
			if clock<float(due.get(id,0)) or not ProjectileImpact.overlaps(polygon,ProjectileImpact.bounds_of(bodies[id])): continue
			due[id] = clock+profile_data.interval
			ProjectileImpact.submit_hit(host,id,element_id,element_id+"/"+str(Engine.get_physics_frames()),dir,profile_data)

func element_state() -> Dictionary:
	return {"active":active,"phase":phase,"phase_time":phase_time,"angle":angle,"index":index,"turn_start":turn_start,"turn_arc":turn_arc,"turn_age":turn_age,"turning":turning,"rounds":rounds,"locked":[locked.x,locked.y]}
func element_can_receive(input: String, value: Variant) -> bool: return input=="set_active" and value is bool
func element_propose(_input: String, value: bool) -> Dictionary:
	var data := element_state()
	if active != value:
		data.active = value
		data.phase = "idle" if aim_mode=="track_lock" else "warning"
		data.phase_time = 0.0
		data.rounds = 0
		var unit := Vector2.from_angle(angle+global_rotation)
		data.locked = [unit.x,unit.y]
	return data
func element_restore(data: Dictionary) -> void:
	active = data.active
	angle = data.angle
	index = int(data.index)
	turn_start = data.turn_start
	turn_arc = data.turn_arc
	turn_age = data.turn_age
	turning = data.turning
	phase = data.phase
	phase_time = data.phase_time
	rounds = int(data.rounds)
	locked = FixedWorldProvider.point(data.locked)
	if not active or phase!="streaming": stream_length = 0
	queue_redraw()

func _draw() -> void:
	var dir := Vector2.from_angle(angle)
	if phase=="streaming" and active and stream_length>0:
		draw_set_transform(Vector2.ZERO,stream_angle)
		var region := Rect2(0,-stream_width/2,stream_length,stream_width)
		var gas := stream_profile=="vent_gas"
		var ink := Color(profile_data.color)
		var source := ProjectileMechanismArt.MIST if gas else ProjectileMechanismArt.FLAME
		ProjectileMechanismArt.beam(self,region,source,16,false,Color.WHITE.lerp(ink,.22))
		var ripple := sin(clock*18.)*stream_width*.12
		var core := Rect2(0,-stream_width*.25+ripple,stream_length,stream_width*.5)
		ProjectileMechanismArt.beam(self,core,source,18,false,Color(ink, .56))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if active and phase in ["warning","tracking"]:
		var at := dir*23
		var progress := clampf(phase_time/maxf(.001,warning_time),0,1)
		if phase=="warning":
			var reach := stream_range if emit_mode=="stream" else 72.
			for i: int in range(1,6):
				var offset := dir*reach*i/6.
				PixelVfx.streak(self,offset,dir,maxf(2.,reach*.022),1.,Color(1,.68,.36,.35+.6*progress))
		PixelVfx.clip(self,&"charge",at,fmod(clock*1.9,.9),0.,Color("ffba78"),Vector2.ONE*.30)
	MechanismRegionArt.stamp(self,"mount",Vector2.ZERO,Vector2(39,37))
	draw_set_transform(Vector2.ZERO,angle)
	ProjectileMechanismArt.paint(self,Rect2(-11,-9,35,18),ProjectileMechanismArt.LENS if emit_mode=="projectile" else ProjectileMechanismArt.NOZZLE)
	MechanismRegionArt.panel(self,Rect2(7,-6,5,12))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if aim_mode=="manual_index":
		ProjectileMechanismArt.paint(self,Rect2(-13,-13,26,26),ProjectileMechanismArt.DIAL)
		for i: int in manual_angles_deg.size():
			var v := Vector2.from_angle(base_direction.angle()+deg_to_rad(manual_angles_deg[i]))
			draw_line((v*11).round(),(v*14).round(),Color("ffd393") if i==index else Color("887b66"),2)
	else:
		MechanismRegionArt.stamp(self,"finial",-dir*8,Vector2(15,17))
