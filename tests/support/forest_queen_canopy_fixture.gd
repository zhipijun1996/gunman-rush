extends SceneTree
## New canopy content consumer using the same real Player/Policy/Seal setup. Legacy fixture stays unchanged.
const AUDIO := preload("res://tests/audio_teardown.gd")
var world: Node2D
var player: PlayerMotor
var controller: PlayerController
var queen: ThornQueenCanopyEncounter
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
	var encounter: ThornQueenCanopyEncounter
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
			frames_data.append({"case":current,"tick":tick,"player":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"air_shots":controller.action_resources.shot_charges,"hook":String(controller.traversal.state),"hook_used":controller.traversal.hook_used,"grounded":player.is_on_floor(),"boss_hp":queen.health.current,"core_open":queen.core_open,"axis":controller.router.axis,"motor_steps":player.motion_steps})
			caption.text="CANOPY QUEEN V3 | "+current+" | tick "+str(tick)+"\nPlayer "+str(controller.actor_resources.health.current)+" | Phase "+str(queen.stage_phase)+" | Queen "+str(queen.health.current)+" | "+str(queen.mode)
			if is_instance_valid(queen):
				var row: Dictionary=frames_data.back()
				row.boss_position=[queen.motor.position.x,queen.motor.position.y]
				row.motion_mode=queen.motion_mode;row.section=queen.motion_section;row.leg=queen.motion_leg;row.cycles=queen.motion_cycles;row.motion_clock=queen.motion_clock;row.stage_phase=queen.stage_phase;row.last_receiver=queen.last_receiver_id;row.locked_receiver=queen.locked_receiver_id
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
	if false: return Vector2(180,382)
	return Vector2(geometry.player_spawn[0],geometry.player_spawn[1])

func queen_definition() -> ThornQueenCanopyDefinition:
	return load("res://resources/bosses/thorn_queen_canopy.tres") as ThornQueenCanopyDefinition
func make_queen_motor() -> BossMotor:
	return load("res://scenes/bosses/thorn_queen_canopy.tscn").instantiate() as BossMotor

func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await cleanup()
	current=id;tick=0
	world=Node2D.new();root.add_child(world)
	geometry=queen_definition().build_geometry(Vector2.ZERO)
	check(bool(geometry.get("ok",false)),"factory contract")
	var ink := Ink.new();ink.geometry=geometry;world.add_child(ink)
	for row: Dictionary in geometry.platforms: slab(row)
	for row: Dictionary in geometry.hook_anchors:
		var anchor := GrappleAnchor.new();anchor.position=Vector2(row.position[0],row.position[1]);world.add_child(anchor)
	var camera := Camera2D.new();camera.position=Vector2(400,250);world.add_child(camera);camera.make_current()
	var canvas := CanvasLayer.new();world.add_child(canvas);caption=Label.new();caption.position=Vector2(16,16);canvas.add_child(caption)
	player=load("res://scenes/player/player.tscn").instantiate() as PlayerMotor
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
	var motor := make_queen_motor()
	motor.position=Vector2(geometry.boss_position[0],geometry.boss_position[1]);world.add_child(motor)
	queen=motor.get_node("Encounter") as ThornQueenCanopyEncounter
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
		if child is Camera2D: (child as Camera2D).position=Vector2(680,300);(child as Camera2D).zoom=Vector2(.9,.9)

func cleanup() -> void:
	if not is_instance_valid(world): return
	controller.router.clear("canopy_golden_cleanup");controller.active=false;life.end();queen.cancel()
	var receipt: Dictionary=AUDIO.stop_fallback_voices(world)
	world.free();world=null;player=null;queen=null;controller=null;policy=null;life=null
	check(await AUDIO.wait_fallback_release(receipt),"owned audio drained")

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
