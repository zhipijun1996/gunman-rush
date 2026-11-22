class_name EquipmentField
extends Node2D
## Spatial effects share the room's actual geometry and live enemies.
var runtime: EquipmentRuntime
var clock := 0.0
var previous := Vector2.ZERO
var path := PackedVector2Array()
var rings: Array[Dictionary] = []
var motion_hits := {}
var air_recoil := false
var anchors: Array[Dictionary] = []
var decoy := {}
var winds: Array[Dictionary] = []
var drones: Array[Vector2] = []
var flash: Array[Dictionary] = []
var hint := 0.0
var hint_wait := 0.0
var aim_path := PackedVector2Array()
var recoil_ghost := Vector2.ZERO
var show_ghost := false
var locked_valid := false

func saved_field() -> Dictionary:
	var saved := {"clock":clock,"hint_wait":hint_wait,"anchors":[],"rings":[],"winds":[]}
	for anchor: Dictionary in anchors:
		if is_instance_valid(anchor.node) and not anchor.node.is_queued_for_deletion():
			var point: Vector2 = anchor.node.global_position
			saved.anchors.append({"point":[point.x,point.y],"life":anchor.life})
	for ring: Dictionary in rings:
		saved.rings.append({"point":[ring.point.x,ring.point.y],"life":ring.life,"hit":ring.hit.duplicate()})
	for wind: Dictionary in winds:
		var points := []
		for point: Vector2 in wind.path: points.append([point.x,point.y])
		saved.winds.append({"path":points,"life":wind.life})
	if not decoy.is_empty(): saved.decoy = {"point":[decoy.point.x,decoy.point.y],"life":decoy.life}
	return saved

func restore_field(saved: Dictionary) -> void:
	clock = saved.get("clock",0.0)
	hint_wait = saved.get("hint_wait",0.0)
	for row: Dictionary in saved.get("anchors",[]):
		add_anchor(Vector2(row.point[0],row.point[1]),row.life)
	for row: Dictionary in saved.get("rings",[]):
		rings.append({"point":Vector2(row.point[0],row.point[1]),"life":row.life,"hit":row.hit.duplicate()})
	for row: Dictionary in saved.get("winds",[]):
		var points := PackedVector2Array()
		for point: Array in row.path: points.append(Vector2(point[0],point[1]))
		winds.append({"path":points,"hit":{},"life":row.life})
	if saved.has("decoy"):
		var row: Dictionary = saved.decoy
		decoy = {"point":Vector2(row.point[0],row.point[1]),"life":row.life}

func remove_source(id: String) -> void:
	match id:
		"B23": rings.clear()
		"99": winds.clear()
		"89": decoy.clear()
		"84":
			for entry: Dictionary in anchors:
				if is_instance_valid(entry.node): entry.node.queue_free()
			anchors.clear()

func _ready() -> void:
	z_index = 4
	previous = runtime.actor.motor.global_position

func clear_line(start: Vector2, finish: Vector2) -> bool:
	var exclude: Array[RID] = [runtime.actor.motor.get_rid()]
	for enemy: EnemyActor in runtime.session.room.enemies.values():
		exclude.append(enemy.motor.get_rid())
	var query := PhysicsRayQueryParameters2D.create(start,finish,1,exclude)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func nearby(point: Vector2, radius: float) -> Array[String]:
	var ids: Array[String] = []
	for id: String in runtime.session.room.enemies:
		var actor: EnemyActor = runtime.session.room.enemies[id]
		if actor.health.terminal or not actor.damageable.can_receive_effects(): continue
		if point.distance_to(actor.motor.global_position) <= radius and clear_line(point,actor.motor.global_position): ids.append(id)
	ids.sort_custom(func(a: String,b: String):
		var enemies := runtime.session.room.enemies
		var left := point.distance_squared_to(enemies[a].motor.global_position)
		var right := point.distance_squared_to(enemies[b].motor.global_position)
		return a < b if is_equal_approx(left,right) else left < right)
	return ids

func area(point: Vector2, radius: float, damage: float, id: String) -> void:
	for target: String in nearby(point,radius): runtime.strike(runtime.session.room.enemies[target].damageable,damage,id)
	flash.append({"from":point,"to":point,"radius":radius,"life":0.15})

func chain(id: String, base: float, level: int) -> void:
	var enemies := runtime.session.room.enemies
	var point: Vector2 = enemies[id].motor.global_position
	var seen := [id]
	for jump: int in int(EquipmentCatalog.parameter("P29",level,"targets")):
		var candidates := nearby(point,EquipmentCatalog.parameter("P29",level,"radius"))
		for used: String in seen: candidates.erase(used)
		if candidates.is_empty(): break
		var target := candidates[0]
		var next: Vector2 = enemies[target].motor.global_position
		runtime.strike(enemies[target].damageable,base*EquipmentCatalog.parameter("P29",level,"damage"),"P29")
		flash.append({"from":point,"to":next,"radius":0,"life":0.15})
		seen.append(target)
		point = next

func set_target_time(id: String, scale: float) -> void:
	if runtime.session.room.enemies.has(id):
		runtime.session.room.enemies[id].damageable.equipment_time_scale = scale
	else:
		var mechanism := runtime.session.room.element_runtime.nodes.get(id) as Node
		if mechanism != null and mechanism.has_method("set_equipment_time"): mechanism.set_equipment_time(scale)

func direction(raw: Vector2, reach: float, hook: bool = false) -> Vector2:
	var locked := lock_direction(reach,hook)
	return raw if locked.is_zero_approx() else locked

func lock_direction(reach: float, hook: bool = false) -> Vector2:
	var fx := runtime.fx
	var target: Dictionary = fx.marks.get("memory",{}) if hook and runtime.has("119") else fx.target if not hook and runtime.has("117") else {}
	if target.is_empty(): return Vector2.ZERO
	var point: Vector2
	if target.has("point"): point = Vector2(target.point[0],target.point[1])
	else:
		var enemy := runtime.session.room.enemies.get(target.get("target","")) as EnemyActor
		if enemy == null or enemy.health.terminal:
			if not hook: fx.target = {}
			return Vector2.ZERO
		point = enemy.motor.global_position
	var from := runtime.actor.motor.global_position
	if point.distance_to(from) > reach or not clear_line(from,point): return Vector2.ZERO
	return from.direction_to(point)

func mark(point: Vector2, receiver: Damageable) -> void:
	if not runtime.fx.armed or not runtime.has("117"): return
	runtime.fx.armed = false
	runtime.fx.target = {"point":[point.x,point.y]} if receiver == null else {"target":runtime.target_id(receiver)}

func killed(point: Vector2) -> void:
	if not runtime.has("84") or not runtime.fx.in_air: return
	if anchors.size() >= int(runtime.p("84","limit")):
		var oldest: Dictionary = anchors.pop_front()
		if is_instance_valid(oldest.node): oldest.node.queue_free()
	add_anchor(point,runtime.p("84","duration"))

func add_anchor(point: Vector2, seconds: float) -> void:
	var anchor := GrappleAnchor.new()
	anchor.set_meta("consumable",true)
	add_child(anchor)
	anchor.global_position = point
	anchors.append({"node":anchor,"life":seconds})

func motion(start: Vector2, finish: Vector2) -> void:
	if not runtime.has("P12") or start.is_equal_approx(finish): return
	for id: String in runtime.session.room.enemies:
		if motion_hits.has(id): continue
		var enemy: EnemyActor = runtime.session.room.enemies[id]
		var point := enemy.motor.global_position
		var closest := Geometry2D.get_closest_point_to_segment(point,start,finish)
		if point.distance_to(closest) <= 22 and clear_line(closest,point):
			runtime.strike(enemy.damageable,runtime.base_damage()*runtime.p("P12","damage"),"P12"); motion_hits[id] = true

func advance(delta: float) -> void:
	clock += delta
	var motor := runtime.actor.motor
	var point := motor.global_position
	if motor.recoil_burst_remaining > 0:
		if path.is_empty():
			path.append(previous); motion_hits.clear()
			air_recoil = runtime.fx.in_air
			if runtime.has("89") and runtime.fx.in_air and runtime.ready("89"):
				decoy = {"point":previous,"life":runtime.p("89","duration")}; runtime.cooldown("89")
		path.append(point); motion(previous,point)
	elif not path.is_empty():
		path.append(point); motion(previous,point)
		if runtime.has("B23") and runtime.ready("B23"):
			rings.append({"point":point,"life":runtime.p("B23","duration"),"hit":{}}); runtime.cooldown("B23")
		if air_recoil and runtime.has("99") and runtime.ready("99"):
			winds.append({"path":path.duplicate(),"life":runtime.p("99","duration"),"hit":{}}); runtime.cooldown("99")
		path.clear()
	previous = point
	for ring in rings:
		for id in nearby(ring.point,runtime.p("B23","radius")):
			if not ring.hit.has(id):
				runtime.strike(runtime.session.room.enemies[id].damageable,runtime.base_damage()*runtime.p("B23","damage"),"B23"); ring.hit[id] = true
		ring.life -= delta
	rings = rings.filter(func(row): return row.life > 0 and runtime.has("B23"))
	for wind in winds: wind.life -= delta
	winds = winds.filter(func(row): return row.life > 0 and runtime.has("99"))
	if not decoy.is_empty():
		decoy.life -= delta
		if decoy.life <= 0 or not runtime.has("89"): decoy.clear()
	for anchor in anchors.duplicate():
		anchor.life -= delta
		if not is_instance_valid(anchor.node) or anchor.life <= 0 or not runtime.has("84"):
			if is_instance_valid(anchor.node): anchor.node.queue_free()
			anchors.erase(anchor)
	for effect in flash: effect.life -= delta
	flash = flash.filter(func(row): return row.life > 0)
	advance_companions(delta)
	hint = maxf(0,hint-delta); hint_wait = maxf(0,hint_wait-delta)
	if runtime.has("73") and hint_wait <= 0:
		for site: EquipmentSite in runtime.session.equipment_sites:
			if site.kind == "secret" and site.visible and runtime.services.state.holds(site.requirements) and point.distance_to(site.global_position) <= runtime.p("73","radius"):
				hint = .7; hint_wait = runtime.p("73","cooldown"); GameAudio.cue(self,&"confirm"); break
	queue_redraw()

func advance_companions(delta: float) -> void:
	drones.clear()
	var fx := runtime.fx
	for id: String in ["G05","P14","P15","G19"]:
		if not runtime.has(id) or (id == "G05" and fx.guard_hp <= 0):
			fx.companions.erase(id); continue
		var interval := runtime.p(id,"interval")
		var units: Array = fx.companions.get(id,[])
		if id in ["P14","G19"] and units.is_empty():
			for i in int(runtime.p(id,"count",1)): units.append({"next":interval})
		fx.companions[id] = units
		for unit: Dictionary in units.duplicate():
			var origin := runtime.actor.motor.global_position + Vector2.from_angle(clock*.8 + float(drones.size())*1.9)*36 + Vector2.UP*18
			drones.append(origin)
			var step := minf(delta,unit.life) if id == "P15" else delta
			unit.next -= step
			while unit.next <= .000001:
				var targets := nearby(origin,float(EquipmentCatalog.DATA.data.companion_range))
				if not targets.is_empty():
					var enemy: EnemyActor = runtime.session.room.enemies[targets[0]]
					runtime.strike(enemy.damageable,unit.get("base",runtime.base_damage())*runtime.p(id,"damage"),id)
					flash.append({"from":origin,"to":enemy.motor.global_position,"radius":0,"life":.12})
				unit.next += interval
			if id == "P15":
				unit.life -= delta
				if unit.life <= 0: units.erase(unit)

func shield_point() -> Vector2:
	return runtime.actor.motor.global_position + Vector2.from_angle(clock*2)*30

func _draw() -> void:
	if runtime == null: return
	if show_ghost:
		var body := PlayerPresentationRuntime.current_body(runtime.actor.motor)
		if body != null: body.draw_aim_afterimage(self,to_local(recoil_ghost))
	for i in range(1,aim_path.size()):
		draw_line(to_local(aim_path[i-1]),to_local(aim_path[i]),Color(.6,.85,.75,.55),1)
		draw_circle(to_local(aim_path[i]),2,Color.GOLD)
	if not runtime.fx.target.is_empty():
		var target: Dictionary = runtime.fx.target
		var point: Vector2
		if target.has("point"): point = Vector2(target.point[0],target.point[1])
		elif runtime.session.room.enemies.has(target.get("target","")): point = runtime.session.room.enemies[target.target].motor.global_position
		draw_arc(to_local(point),9,0,TAU,16,Color.AQUAMARINE if locked_valid else Color.GRAY,1.5)
	for point in drones: draw_circle(to_local(point),5,Color("9facbf"))
	for row in rings: draw_arc(to_local(row.point),runtime.p("B23","radius"),0,TAU,28,Color("d7b67b"),2)
	for row in winds: draw_polyline(row.path,Color("76c4b2"),3)
	if not decoy.is_empty(): draw_circle(to_local(decoy.point),12,Color(.6,.8,1,.35))
	for row in flash:
		if row.radius > 0: draw_arc(to_local(row.to),row.radius,0,TAU,24,Color("e4c476"),2)
		else: draw_line(to_local(row.from),to_local(row.to),Color("bfdecf"),2)
	if runtime.has("P16") and runtime.ready("P16"): draw_circle(to_local(shield_point()),8,Color("8dc7d0"))
	if hint > 0: draw_circle(to_local(runtime.actor.motor.global_position + Vector2.UP*38),4,Color.GOLD)

## Parametric entry on the swept segment; a collision behind a solid never wins.
static func circle_entry(start: Vector2, motion: Vector2, center: Vector2, radius: float) -> float:
	var offset := start-center
	if offset.length_squared() <= radius*radius: return 0
	var length := motion.length_squared()
	if length < 1e-9: return INF
	var b := offset.dot(motion)
	var discriminant := b*b-length*(offset.length_squared()-radius*radius)
	if discriminant < 0: return INF
	var t := (-b-sqrt(discriminant))/length
	return t if t >= 0 and t <= 1 else INF

static func band_entry(start: Vector2, motion: Vector2, a: Vector2, b: Vector2, radius: float) -> float:
	var t := minf(circle_entry(start,motion,a,radius),circle_entry(start,motion,b,radius))
	if a.is_equal_approx(b) or motion.is_zero_approx(): return t
	if Geometry2D.get_closest_point_to_segment(start,a,b).distance_to(start) <= radius: return 0
	var normal := a.direction_to(b).orthogonal()*radius
	for side: Vector2 in [normal,-normal]:
		var hit: Variant = Geometry2D.segment_intersects_segment(start,start+motion,a+side,b+side)
		if hit != null: t = minf(t,start.distance_to(hit)/motion.length())
	return t

func guard_hit(event: String, amount: float) -> void:
	if not runtime.has("G05") or runtime.fx.guard_hp <= 0 or not runtime.ready("guard_iframe"): return
	var hits: Array = runtime.fx.get("guard_hits",[])
	if event in hits: return
	hits.append(event)
	if hits.size() > 64: hits.pop_front()
	runtime.fx.guard_hits = hits
	runtime.fx.guard_hp = maxf(0,runtime.fx.guard_hp-amount)
	runtime.fx.cooldowns.guard_iframe = runtime.p("G05","iframe")

func intercept(projectile: EnemyAttackProjectile, motion: Vector2, solid_fraction: float) -> bool:
	var start := projectile.global_position
	var first := solid_fraction
	var outcome := ""
	var round_hit: PlayerProjectile
	var screen: Dictionary
	if runtime.has("P16") and runtime.ready("P16"):
		var t := circle_entry(start,motion,shield_point(),8+projectile.radius)
		if t < first: first = t; outcome = "shield"
	if runtime.has("87"):
		for shot in runtime.actor.shoot_ability.get_projectiles():
			if shot.spent or shot.skill_attack or shot.art_kind != &"bullet": continue
			var t := circle_entry(start,motion,shot.global_position,shot.radius+projectile.radius)
			if t < first: first = t; outcome = "cancel"; round_hit = shot
	for wind: Dictionary in winds:
		if wind.hit.has(projectile.get_instance_id()): continue
		for i in range(1,wind.path.size()):
			var t := band_entry(start,motion,wind.path[i-1],wind.path[i],runtime.p("99","width")*.5+projectile.radius)
			if t < first: first = t; outcome = "deflect"; screen = wind
	if runtime.fx.guard_hp > 0 and not drones.is_empty():
		if circle_entry(start,motion,drones[0],9+projectile.radius) < first: guard_hit(str(projectile.event_id),1.0)
	if outcome == "": return false
	projectile.global_position = start + motion*first
	if outcome == "deflect":
		screen.hit[projectile.get_instance_id()] = true
		var radians := deg_to_rad(runtime.p("99","angle"))
		var away := runtime.actor.motor.global_position.direction_to(projectile.global_position)
		var left := projectile.direction.rotated(radians)
		var right := projectile.direction.rotated(-radians)
		projectile.direction = left if left.dot(away) >= right.dot(away) else right
		projectile._move_swept(projectile.direction * motion.length()*(1-first))
	else:
		if round_hit != null: round_hit.dispose()
		projectile.dispose()
	return true

func update_aim() -> void:
	aim_path.clear()
	show_ghost = false
	var actor := runtime.actor
	locked_valid = not lock_direction(actor.motor.tuning.projectile_range*runtime.projectile_range_multiplier()).is_zero_approx()
	queue_redraw()
	if actor.motor.is_on_floor() or not actor.router.aim_engaged: return
	var start := actor.motor.global_position
	var reach := actor.motor.tuning.projectile_range*runtime.projectile_range_multiplier()
	var raw := direction(actor.router.aim_direction,reach)
	if raw.is_zero_approx(): return
	if runtime.has("80"):
		var length := actor.motor.tuning.shot_burst_speed*actor.motor.tuning.shot_burst_duration
		var collision := KinematicCollision2D.new()
		var displacement := -raw*length
		if actor.motor.test_move(actor.motor.global_transform,displacement,collision): displacement = collision.get_travel()
		show_ghost = true
		recoil_ghost = start + displacement
	if runtime.has("96"):
		var dir := ShotAimAssist.resolve(actor,start,raw,reach)
		var origin := start
		aim_path.append(origin)
		for segment in (2 if runtime.has("83") else 1):
			var ray := PhysicsRayQueryParameters2D.create(origin,origin+dir*reach,1,[actor.motor.get_rid()])
			var hit := get_world_2d().direct_space_state.intersect_ray(ray)
			var end: Vector2 = hit.get("position",origin+dir*reach)
			aim_path.append(end)
			if hit.is_empty() or hit.collider.get_node_or_null("Damageable") != null: break
			reach -= origin.distance_to(end)
			dir = dir.bounce(hit.normal); origin = end+dir*.1
