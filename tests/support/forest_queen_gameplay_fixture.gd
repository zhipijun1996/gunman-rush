extends SceneTree
## Shared actual Queen fixture and real inputs. Scenario producers live only in canonical sweep runner.
const AUDIO := preload("res://tests/audio_teardown.gd")
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var queen: ThornQueenV2
var policy: FrameDamagePolicy
var life: DemoLifetime
var geometry: Dictionary
var tick := 0
var assertions := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var events: Array[Dictionary] = []
var frames_data: Array[Dictionary] = []
var current := ""
var selected := "all"
var actual_body_half := Vector2.ZERO
var output_dir := "res://build/forest_depth/queen/native"
var caption: Label
class ContactGate extends Node:
	var source: DemoContactEmitter
	var encounter: ThornQueenV2
	func _physics_process(_delta: float) -> void:
		source.enabled=is_instance_valid(encounter) and encounter.body_contact_enabled()
class Ink extends Node2D:
	var geometry: Dictionary
	func _draw() -> void:
		draw_rect(Rect2(-100,-100,1100,800),Color("172b30"))
		for row: Dictionary in geometry.platforms:
			var a: Array=row.rect
			draw_rect(Rect2(a[0],a[1],a[2],a[3]),Color("536d5b"))

var _ordinary_shape_traces: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir=arg.trim_prefix("--output-dir=")
		if arg.begins_with("--case="): selected=arg.trim_prefix("--case=")
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	assertions+=1
	if not ok: failures.append(current+"/"+message);printerr("FAIL: "+current+"/"+message)

func frames(count: int) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
		tick+=1
		if is_instance_valid(player):
			frames_data.append({"case":current,"tick":tick,"player":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"air_shots":controller.action_resources.shot_charges,"hook":String(controller.traversal.state),"hook_used":controller.traversal.hook_used,"grounded":player.is_on_floor(),"boss_hp":queen.health.current,"core_open":queen.core_open,"knot_hp":queen.knot.health.current,"growth":queen.band.growth,"severed":queen.band.severed,"axis":controller.router.axis,"motor_steps":player.motion_steps})
			caption.text="QUEEN WEAVE FIRST GOLDEN | "+current+" | tick "+str(tick)+"\nPlayer "+str(controller.actor_resources.health.current)+" | Knot "+str(queen.knot.health.current)+" | Queen "+str(queen.health.current)+" | "+str(queen.mode)
			if is_instance_valid(queen):
				var row: Dictionary=frames_data.back()
				row.boss_position=[queen.motor.position.x,queen.motor.position.y]
				row.motion_mode=queen.motion_mode;row.perch=queen.perch_index;row.migrations=queen.migrations
				row.fields=queen.combat_snapshot().fields

func slab(row: Dictionary) -> void:
	var a: Array=row.rect
	var body := StaticBody2D.new()
	body.name=str(row.id)
	body.position=Vector2(a[0]+a[2]*.5,a[1]+a[3]*.5)
	var shape := CollisionShape2D.new()
	shape.name="CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size=Vector2(a[2],a[3]);shape.shape=rect
	shape.one_way_collision=bool(row.one_way)
	body.add_child(shape)
	if row.one_way: body.add_to_group(&"one_way_platform")
	world.add_child(body)

func fixture_spawn(hazard_probe: bool,body_probe: bool) -> Vector2:
	if current=="explicit_mature_band_landing": return Vector2(180,382)
	return Vector2(geometry.boss_position[0],geometry.boss_position[1]) if body_probe else (Vector2(475,182) if hazard_probe else Vector2(geometry.player_spawn[0],geometry.player_spawn[1]))

func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await cleanup()
	current=id;tick=0
	world=Node2D.new();root.add_child(world)
	geometry=ForestBossArenaFactory.new().queen_golden()
	check(bool(geometry.get("ok",false)),"factory contract")
	var ink := Ink.new();ink.geometry=geometry;world.add_child(ink)
	for row: Dictionary in geometry.platforms: slab(row)
	for row: Dictionary in geometry.hook_anchors:
		var anchor := GrappleAnchor.new();anchor.position=Vector2(row.position[0],row.position[1]);world.add_child(anchor)
	var camera := Camera2D.new();camera.position=Vector2(400,250);world.add_child(camera);camera.make_current()
	var canvas := CanvasLayer.new();world.add_child(canvas);caption=Label.new();caption.position=Vector2(16,16);canvas.add_child(caption)
	player=load("res://game/player/player.tscn").instantiate() as PlayerMotor
	player.position=fixture_spawn(hazard_probe,body_probe) # Initial fixture spawn only.
	world.add_child(player)
	controller=player.get_node("Controller") as PlayerController
	actual_body_half=(player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
	controller.enable_shot_energy()
	if h_enabled: controller.traversal.grant(&"grapple")
	controller.shoot_ability.shot_fired.connect(func(aim: Vector2,serial: int) -> void: events.append({"case":current,"tick":tick+1,"event":"accepted_shot","serial":serial,"aim":[aim.x,aim.y]}))
	controller.traversal.action_changed.connect(func(state: StringName) -> void: events.append({"case":current,"tick":tick+1,"event":"hook_state","state":String(state)}))
	controller.traversal.hook_contact.connect(func(at: Vector2) -> void:
		var target := controller.traversal.hook_target
		events.append({"case":current,"tick":tick+1,"event":"actual_hook_target_contact","point":[at.x,at.y],"target_name":String(target.name) if is_instance_valid(target) else "","target_position":[target.global_position.x,target.global_position.y] if is_instance_valid(target) else []}))
	life=DemoLifetime.new();policy=FrameDamagePolicy.new();policy.lifetime=life;world.add_child(policy)
	check(policy.register_target(&"player",controller.actor_resources.health,true),"player policy bound")
	policy.batch_resolved.connect(func(results: Array[DamageResult]) -> void:
		for result: DamageResult in results:
			events.append({"case":current,"tick":tick+1,"event":"policy_result","target":String(result.request.target_id),"source":String(result.request.source_id),"id":String(result.request.event_id),"amount":result.request.amount,"hp":result.health.current}))
	var motor := load("res://scenes/bosses/thorn_queen_v2.tscn").instantiate() as BossMotor
	motor.position=Vector2(geometry.boss_position[0],geometry.boss_position[1]);world.add_child(motor)
	queen=motor.get_node("Encounter") as ThornQueenV2
	check(policy.bind_damageable(&"boss",queen.damageable,queen.health),"one boss policy bound")
	check(queen.bind_duel(geometry,controller,policy,life),"actual knot and growing band bound")
	var arena_row: Array=geometry.boss_arena
	var arena_rect := Rect2(arena_row[0],arena_row[1],arena_row[2],arena_row[3])
	check(queen.configure_arena(arena_rect.position.x,arena_rect.end.x,player),"arena configured")
	queen.configure_forest_floor(arena_rect.end.y)
	queen.weave_event.connect(func(row: Dictionary) -> void:
		var event := row.duplicate(true);event["case"]=current;event["tick"]=tick+1;events.append(event))
	check(queen.activate(),"Queen activated")
	var contact := DemoContactEmitter.new()
	contact.policy=policy;contact.controller=controller;contact.source_id=&"queen_body_contact"
	contact.half_size=queen.definition.collision_size*.5
	motor.add_child(contact)
	var gate := ContactGate.new();gate.source=contact;gate.encounter=queen;gate.process_physics_priority=850
	world.add_child(gate)
	var seal := BossArenaSeal.new();world.add_child(seal)
	seal.setup(arena_rect,arena_rect.grow(100),controller,queen,life)
	check(seal.arm(),"normal full-body arena entry arms real seal")
	await frames(3)
	var seal_check: BossArenaSeal
	for node: Node in world.get_children():
		if node is BossArenaSeal: seal_check=node as BossArenaSeal
	for index: int in 50:
		if is_instance_valid(seal_check) and seal_check.closed: break
		await frames(1)
	check(is_instance_valid(seal_check) and seal_check.closed,"normal delayed arena walls actually close before control begins")
	for child: Node in world.get_children():
		if child is Camera2D: (child as Camera2D).position=Vector2(450,300);(child as Camera2D).zoom=Vector2(.9,.9)

func walk(x: float,budget := 180) -> bool:
	for i: int in budget:
		if absf(player.position.x-x)<7:
			controller.router.set_move_axis(0);return true
		controller.router.set_move_axis(signf(x-player.position.x));await frames(1)
	controller.router.set_move_axis(0);return false

func hook(point: Vector2,budget := 90) -> bool:
	var start := tick
	var queued := controller.router.request_action(&"grapple",(point-(player.position+Vector2(0,-6))).normalized())
	events.append({"case":current,"tick":tick,"event":"hook_request","queued":queued,"point":[point.x,point.y]})
	for i: int in budget:
		await frames(1)
		if controller.traversal.state==&"free" and tick>start+10:
			return events.any(func(event: Dictionary) -> bool: return event.get("case")==current and int(event.get("tick",-1))>=start and event.get("event")=="hook_state" and event.get("state")=="hook_kick")
	return false

func cleanup() -> void:
	if not is_instance_valid(world): return
	controller.router.clear("queen_golden_cleanup");controller.active=false;life.end();queen.cancel()
	var receipt: Dictionary=AUDIO.stop_fallback_voices(world)
	world.free();world=null;player=null;queen=null;controller=null;policy=null;life=null
	check(await AUDIO.wait_fallback_release(receipt),"owned audio drained")

func ordinary_surface_aim() -> Dictionary:
	_ordinary_shape_traces.clear()
	# All strategies share these actual-body samples and radius-three projectile clearance.
	# This is a finite fair-driver sample, never proof of all possible shot angles.
	var half := queen.definition.collision_size*.5-Vector2(2,2)
	var samples: Array[Vector2]=[Vector2.ZERO,Vector2(0,-half.y),Vector2(-half.x,0),Vector2(half.x,0),Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(-half.x,half.y),Vector2(half.x,half.y),Vector2(0,half.y)]
	var velocity := queen.motor.velocity
	var speed := controller.shoot_ability.tuning.projectile_speed
	var circle := CircleShape2D.new()
	circle.radius=controller.shoot_ability.tuning.projectile_radius
	for surface: Vector2 in samples:
		var offset := queen.motor.global_position+surface-player.global_position
		var aa := velocity.length_squared()-speed*speed
		var bb := 2*offset.dot(velocity)
		var cc := offset.length_squared()
		var disc := bb*bb-4*aa*cc
		var travel := 0.0
		if disc>=0 and absf(aa)>.001:
			var first := (-bb+sqrt(disc))/(2*aa)
			var second := (-bb-sqrt(disc))/(2*aa)
			travel=maxf(first,second) if minf(first,second)<=0 else minf(first,second)
		var target_point := queen.motor.global_position+surface+velocity*maxf(0,travel)
		var aim := (target_point-player.global_position).normalized()
		var visual := player.get_node("CourierVisual") as CourierVisual
		# Same live visual API used by ShootAbility._emit_round; this only poses candidate aim.
		var muzzle := visual.muzzle_position(aim)
		for iteration: int in 2:
			aim=(target_point-muzzle).normalized()
			muzzle=visual.muzzle_position(aim)
		if not clear_ordinary_segment(player.global_position,muzzle,circle): continue
		if not clear_ordinary_segment(muzzle,target_point,circle): continue
		return {"aim":aim,"surface":surface,"predicted_body_point":target_point,"muzzle":muzzle}

	return {}

func clear_ordinary_segment(first: Vector2,last: Vector2,circle: CircleShape2D) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape=circle;query.transform=Transform2D(0,first)
	query.collision_mask=0xFFFFFFFF;query.collide_with_areas=true
	query.exclude=[player.get_rid(),queen.motor.get_rid()]
	var space := player.get_world_2d().direct_space_state
	var overlaps := space.intersect_shape(query,1)
	if not overlaps.is_empty():
		_ordinary_shape_traces.append({"start":[first.x,first.y],"end":[last.x,last.y],"radius":circle.radius,"overlap_count":overlaps.size(),"safe_fraction":[]})
		return false
	query.motion=last-first
	var sweep := space.cast_motion(query)
	_ordinary_shape_traces.append({"start":[first.x,first.y],"end":[last.x,last.y],"radius":circle.radius,"overlap_count":0,"safe_fraction":Array(sweep)})
	return sweep.size()==2 and sweep[0]>=.99999

func continuous_fire() -> void:
	if controller.shoot_ability.cooldown_remaining>0: return
	var shot := ordinary_surface_aim()
	if shot.is_empty(): return
	var aim: Vector2=shot.aim
	if player.is_on_floor():
		# Fire at the actual maximum cadence once the real recoil has a receiving bank.
		var distance := player.weapon_motion.base_distance(controller.shoot_ability.tuning,true)
		var landing_x := player.global_position.x-aim.x*distance
		for bank: Dictionary in geometry.platforms:
			var a: Array=bank.rect
			if absf(player.global_position.y+actual_body_half.y-float(a[1]))>1: continue
			if player.global_position.x-actual_body_half.x<float(a[0]) or player.global_position.x+actual_body_half.x>float(a[0])+float(a[2]): continue
			if landing_x-actual_body_half.x<float(a[0]) or landing_x+actual_body_half.x>float(a[0])+float(a[2]):
				controller.router.set_move_axis(signf(aim.x))
				return
			break
	else:
		var distance := player.weapon_motion.base_distance(controller.shoot_ability.tuning,false)
		var predicted := player.global_position-aim*distance
		var a: Array=geometry.boss_arena
		var allowed := Rect2(a[0],a[1],a[2],a[3])
		if not allowed.encloses(Rect2(predicted-actual_body_half,actual_body_half*2)): return
	var surface: Vector2=shot.surface
	var queued := controller.router.request_action(&"shoot_release",aim)
	events.append({"case":current,"tick":tick,"event":"shot_request","queued":queued,"aim":[aim.x,aim.y],"aim_surface_local":[surface.x,surface.y],"projectile_radius":controller.shoot_ability.tuning.projectile_radius,"visibility_method":"actual_barrel_then_muzzle_circle_except_target","predicted_muzzle":[shot.muzzle.x,shot.muzzle.y]})

func queen_definition() -> Resource: return load("res://resources/bosses/thorn_queen_v2.tres")

func field_healths() -> Array:
	var result: Array=[]
	for item: ThornQueenWeaveKnot in queen.knots: result.append(item.health.current if is_instance_valid(item) else null)
	return result

func accepted_hook(point: Vector2) -> bool:
	var start := tick
	if not await hook(point): return false
	var contacts := events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="actual_hook_target_contact" and int(event.get("tick",-1))>start)
	return not contacts.is_empty() and Vector2(contacts.back().target_position[0],contacts.back().target_position[1]).distance_to(point)<1

func right_gap_approach() -> bool:
	# Normal jump over suspended root nodule, then approach the forty-wide branch gap.
	if player.position.x<500:
		if not await walk(360): return false
		controller.router.set_move_axis(1)
		controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if not await walk(620): return false
	for index: int in 80:
		if player.is_on_floor(): return true
		await frames(1)
	return false

func enter_upper(use_hook: bool) -> bool:
	if not await right_gap_approach(): return false
	controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if use_hook and not queen.knot.health.terminal:
		var accepted := await accepted_hook(queen.knot.global_position)
		check(accepted,"actual H reaches the intended living knot, not merely any completed cast")
		if not accepted: return false
	else:
		# Same ordinary jump/R path remains legal after all live knots are cut.
		controller.router.request_action(&"shoot_release",Vector2.DOWN);await frames(15)
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(15)
	for index: int in 100:
		controller.router.set_move_axis(0 if absf(player.position.x-750)<7 else signf(750-player.position.x))
		if player.is_on_floor():
			controller.router.set_move_axis(0)
			return player.position.y<400
		await frames(1)
	controller.router.set_move_axis(0)
	return false

func move_to_middle() -> bool:
	# Stabilize the ordinary takeoff on the inner branch before committing the jump.
	if player.position.x>700 and not await walk(700): return false
	controller.router.set_move_axis(-1 if player.position.x>450 else 1)
	controller.router.set_jump_held(&"queen_network",true);await frames(23);controller.router.set_jump_held(&"queen_network",false)
	if not await walk(450): return false
	for index: int in 100:
		if player.is_on_floor(): return player.position.y<360
		await frames(1)
	return false

func cut_field(index: int) -> bool:
	var target: ThornQueenWeaveKnot=queen.knots[index]
	if not is_instance_valid(target): return false
	for index_tick: int in 180:
		if target.health.terminal: return true
		if controller.actor_resources.health.terminal: return false
		controller.router.set_move_axis(0 if absf(player.position.x-450)<7 else signf(450-player.position.x))
		if player.is_on_floor() and controller.shoot_ability.cooldown_remaining<=0:
			var aim := (target.global_position-player.global_position).normalized()
			var queued := controller.router.request_action(&"shoot_release",aim)
			events.append({"case":current,"tick":tick,"event":"normal_cut_shot_request","field":index,"queued":queued})
		await frames(1)
	return target.health.terminal
