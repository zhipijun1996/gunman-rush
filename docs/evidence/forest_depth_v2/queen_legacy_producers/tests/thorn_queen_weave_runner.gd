extends SceneTree
## Local Queen first-mechanism golden. Explicit initial hazard probe is not a route.
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
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir=arg.trim_prefix("--output-dir=")
		if arg.begins_with("--case="): selected=arg.trim_prefix("--case=")
	run.call_deferred()
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
func shoot(point: Vector2) -> void:
	var aim := (point-player.position).normalized()
	var queued := controller.router.request_action(&"shoot_release",aim)
	events.append({"case":current,"tick":tick,"event":"shot_request","queued":queued,"aim":[aim.x,aim.y]})
	await frames(28)
func intended() -> void:
	await fixture("borrow_knot_H")
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_knot_hp":queen.knot.health.current,"initial_energy":controller.actor_resources.stamina.current,"explicit_initial_hazard_probe":false}
	check(await walk(235),"walk real approach")
	controller.router.set_jump_held(&"queen_golden",true);await frames(23);controller.router.set_jump_held(&"queen_golden",false)
	for i: int in 70:
		if player.is_on_floor() and player.position.y<400: break
		await frames(1)
	check(player.is_on_floor() and player.position.y<400,"first branch actual landing")
	check(await hook(queen.knot.global_position),"real H contact and kick off 2HP knot")
	check(queen.knot.health.current==row.initial_knot_hp-controller.traversal.definition.hook_damage,"H causes ordinary configured knot damage")
	check(not queen.band.severed and queen.knot.is_in_group(&"grapple_target"),"first H preserves weak live knot and active route")
	check(await hook(Vector2(geometry.hook_anchors[0].position[0],geometry.hook_anchors[0].position[1])),"second H static upper ring")
	controller.router.request_action(&"shoot_release",Vector2.LEFT);await frames(15)
	for i: int in 90:
		if player.is_on_floor(): break
		await frames(1)
	row.upper_landed=player.is_on_floor() and player.position.x>=450 and player.position.x<=680 and absf(player.position.y-182)<3
	check(row.upper_landed,"H-H-R reaches actual upper receiving branch")
	await shoot(queen.motor.global_position)
	row.boss_damage=row.initial_boss_hp-queen.health.current
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.ticks=tick;row.knot_health=queen.knot.health.current;row.severed=queen.band.severed
	check(row.player_damage==0,"intended whole-body passage requires no damage")
	check(row.boss_damage>0,"normal bullet hits always-vulnerable Queen")
	cases.append(row)
func cutting() -> void:
	await fixture("cut_knot_bullets")
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_knot_hp":queen.knot.health.current,"initial_energy":controller.actor_resources.stamina.current}
	check(await walk(350),"walk into visible knot firing lane")
	for i: int in 4:
		if queen.knot.health.terminal: break
		await shoot(queen.knot.global_position)
	check(queen.knot.health.terminal and queen.band.severed,"actual bullets sever knot and physical band")
	await frames(2)
	check(not queen.knot.is_in_group(&"grapple_target") and queen.band.body.collision_layer==0,"cut removes H target and collision, not a counter trigger")
	row.ticks=tick;row.knot_health=queen.knot.health.current;row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	cases.append(row)
func ground_control(h_enabled: bool) -> void:
	await fixture("ground_walk_shoot" if h_enabled else "no_H_ground",h_enabled)
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_knot_hp":queen.knot.health.current,"initial_energy":controller.actor_resources.stamina.current}
	await walk(760,240)
	for i: int in 25:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		await shoot(queen.motor.global_position)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current;row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.boss_defeated=queen.health.terminal;row.knot_health=queen.knot.health.current;row.severed=queen.band.severed
	row.final_position=[player.position.x,player.position.y]
	var arena_row: Array=geometry.boss_arena
	var arena_rect := Rect2(arena_row[0],arena_row[1],arena_row[2],arena_row[3])
	row.retained_in_arena=arena_rect.encloses(Rect2(player.position-actual_body_half,actual_body_half*2))
	check(row.retained_in_arena and not controller.actor_resources.health.terminal,"ground control ends alive in actual arena, not below map")
	cases.append(row)
func hazard() -> void:
	await fixture("explicit_initial_whole_body_hazard",true,true)
	var before := controller.actor_resources.health.current
	await frames(150)
	check(controller.actor_resources.health.current<before,"whole-body growing strand commits actual player damage")
	cases.append({"id":current,"explicit_initial_hazard_probe":true,"hp_before":before,"hp_after":controller.actor_resources.health.current,"ticks":tick})
func no_H_alternative(recoil_route: bool) -> void:
	await fixture("no_H_two_R_upper" if recoil_route else "no_H_right_jump",false)
	var row := {"id":current,"initial_player_hp":controller.actor_resources.health.current,"initial_boss_hp":queen.health.current,"initial_knot_hp":queen.knot.health.current,"initial_energy":controller.actor_resources.stamina.current}
	if not recoil_route: await walk(760,240)
	controller.router.set_move_axis(1 if recoil_route else 0)
	controller.router.set_jump_held(&"queen_counterfactual",true);await frames(23)
	controller.router.set_jump_held(&"queen_counterfactual",false)
	if recoil_route:
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(15)
		controller.router.request_action(&"shoot_release",Vector2(-1,1).normalized());await frames(10)
	for i: int in 100:
		if recoil_route and player.position.x>540: controller.router.set_move_axis(0)
		if player.is_on_floor(): break
		await frames(1)
	controller.router.set_move_axis(0)
	row.landed=player.is_on_floor();row.attack_stand=[player.position.x,player.position.y]
	for i: int in 6:
		if queen.health.terminal or controller.actor_resources.health.terminal: break
		await shoot(queen.motor.global_position)
	row.ticks=tick;row.boss_damage=row.initial_boss_hp-queen.health.current
	row.player_damage=row.initial_player_hp-controller.actor_resources.health.current
	row.final_position=[player.position.x,player.position.y];row.knot_health=queen.knot.health.current
	check(not controller.traversal.hook_enabled,"no-H alternative stays actually ungranted")
	cases.append(row)
func body_probe() -> void:
	await fixture("explicit_initial_body_contact",true,false,true)
	await frames(12)
	var hits: Array=events.filter(func(event: Dictionary) -> bool: return event.get("case")==current and event.get("event")=="policy_result" and event.get("source")=="queen_body_contact" and event.get("target")=="player")
	check(not hits.is_empty(),"Definition-sized Boss body causes normal contact damage")
	cases.append({"id":current,"explicit_initial_body_probe":true,"hp_after":controller.actor_resources.health.current,"actual_half_size":[queen.definition.collision_size.x*.5,queen.definition.collision_size.y*.5]})
func persistence() -> void:
	await fixture("restore_source")
	await walk(350)
	await shoot(queen.knot.global_position)
	check(queen.knot.health.current==1,"snapshot source knot is weakened by actual normal bullet")
	var saved := queen.combat_snapshot()
	check(queen.valid_duel_snapshot(saved),"live mid-growth snapshot validates")
	var row := {"id":"state_persistence","source_snapshot":saved.duplicate(true),"explicit_unload_rebuild":true}
	await fixture("restore_partial_instance")
	queen.restore_combat_state(saved)
	check(queen.last_restore_accepted and queen.knot.health.current==1,"fresh bound Queen restores weakened knot")
	check(queen.band.age==saved.weave.age and queen.band.growth==saved.weave.growth,"growth clock and actual partial collision preserve")
	check(queen.motor.position==Vector2(saved.body_position[0],saved.body_position[1]),"snapshot body position is restored without moving Player")
	var intact := queen.combat_snapshot()
	for variant: String in ["hp","age","growth","pulse","mode","severed","body","generic_position","nan"]:
		var bad := saved.duplicate(true)
		match variant:
			"hp": bad.knot_health=999
			"age": bad.weave.age=-1
			"growth": bad.weave.growth=.123456
			"pulse": bad.weave.pulse=.5
			"mode": bad.mode="heart_open"
			"severed": bad.weave.severed=true
			"body": bad.body_position[0]+=10
			"generic_position": bad.position=[1,2]
			"nan": bad.weave.age=NAN
		queen.restore_combat_state(bad)
		check(not queen.last_restore_accepted and RandomStageGenerator.new()._same_data(intact,queen.combat_snapshot()),"invalid snapshot cleanly rejected "+variant)
	queen.restore_combat_state(saved)
	await walk(350)
	await shoot(queen.knot.global_position)
	check(queen.knot.health.terminal and queen.band.severed,"weakened restored knot dies from one actual bullet")
	var cut_saved := queen.combat_snapshot()
	await fixture("restore_cut_instance")
	queen.restore_combat_state(cut_saved)
	check(queen.last_restore_accepted and queen.knot.health.current==0 and queen.band.severed,"cut field restores as cut, no free regrowth")
	check(not queen.knot.is_in_group(&"grapple_target") and queen.band.body.collision_layer==0,"restored dead knot and field remain physically disabled")
	var cut_clock := queen.band.age
	await frames(30)
	check(queen.band.age==cut_clock and queen.band.severed,"restored severed field cannot tick into regrowth")
	row.restored_partial=intact;row.restored_cut=queen.combat_snapshot();row.completed=true
	cases.append(row)
func cleanup() -> void:
	if not is_instance_valid(world): return
	controller.router.clear("queen_golden_cleanup");controller.active=false;life.end();queen.cancel()
	var receipt: Dictionary=AUDIO.stop_fallback_voices(world)
	world.free();world=null;player=null;queen=null;controller=null;policy=null;life=null
	check(await AUDIO.wait_fallback_release(receipt),"owned audio drained")
func run() -> void:
	check(not ThornQueenWeaveBand.body_sweep_hits(Vector2(370,330),Vector2(490,180),6,Vector2(478,147),Vector2(492,149),Vector2(12,18)),"diagonal endpoint outside actual body is not damage")
	check(ThornQueenWeaveBand.body_sweep_hits(Vector2(370,330),Vector2(490,180),6,Vector2(430,255),Vector2(430,255),Vector2(12,18)),"actual strand inside body is damage")
	check(ThornQueenWeaveBand.body_sweep_hits(Vector2(370,330),Vector2(490,180),6,Vector2(300,255),Vector2(600,255),Vector2(12,18)),"swept crossing cannot tunnel")
	if selected in ["all","intended"]: await intended()
	if selected in ["all","cut"]: await cutting()
	if selected in ["all","ground"]:
		await ground_control(true);await ground_control(false)
	if selected in ["all","hazard"]: await hazard()
	if selected in ["all","alternatives"]:
		await no_H_alternative(true);await no_H_alternative(false)
	if selected in ["all","body"]: await body_probe()
	if selected in ["all","persistence"]: await persistence()
	await cleanup()
	DirAccess.make_dir_recursive_absolute(output_dir)
	var report := {"capture_schema":2,"event_tick_semantics":"accepted callbacks bind the incoming normal physics frame; requests bind the last completed frame","task_id":"FOREST-DEPTH-02","scope":"Queen isolated first weaving mechanism NOT map2 admission","selected":selected,"assertions":assertions,"failures":failures,"cases":cases,"events":events,"frames":frames_data,"geometry":geometry,"definition_path":"res://resources/bosses/thorn_queen_v2.tres","definition_sha256":FileAccess.get_sha256("res://resources/bosses/thorn_queen_v2.tres"),"player_tuning_sha256":FileAccess.get_sha256("res://config/player_tuning.json"),"actual_body_half_extents":[actual_body_half.x,actual_body_half.y],"manual_motor_step":false,"midroute_player_position_or_resource_writes":false,"player_acceptance":"unverified","design_verdict":"unverified_requires_comparison_review"}
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("QUEEN WEAVE GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
