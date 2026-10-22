extends SceneTree
## Initial-position combat fixture. All damage/deaths below come from the real
## Router -> ShootAbility -> swept PlayerProjectile -> FrameDamagePolicy chain.
const CASES: Array[Dictionary] = [
	{"id":"underworld_root_bell","behavior":"root_bell","formal":true},
	{"id":"underworld_diver","behavior":"diver","formal":true},
	{"id":"legacy_diver","behavior":"diver","formal":false},
	{"id":"legacy_patrol","behavior":"patrol","formal":false}
]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var output := "res://build/enemy-feedback-01/trace.json"
var candidate := false
var frame_rows: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
		if argument=="--candidate": candidate=true
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("FAIL: ",label)

func rect_body(parent: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new();body.position=rect.get_center()
	var collision := CollisionShape2D.new();var shape := RectangleShape2D.new()
	shape.size=rect.size;collision.shape=shape;body.add_child(collision);parent.add_child(body)
	var fill := Polygon2D.new()
	fill.polygon=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
	fill.color=Color("34473e");parent.add_child(fill)
	var line := Line2D.new();line.points=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0)])
	line.width=4;line.default_color=Color("9da77b");parent.add_child(line)

func run_case(spec: Dictionary) -> void:
	var world := Node2D.new();root.add_child(world)
	world.set_meta("underworld_formal_style",true)
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	var title := Label.new();title.position=Vector2(70,72);title.add_theme_font_size_override("font_size",26)
	title.text="ENEMY FEEDBACK / "+str(spec.id).to_upper();world.add_child(title)
	var note := Label.new();note.position=Vector2(70,116)
	note.text="Actual Router + projectiles / existing AI + HP / initial-position fixture";world.add_child(note)
	rect_body(world,Rect2(40,550,1200,140));rect_body(world,Rect2(20,200,20,350))
	var player: PlayerMotor=load("res://scenes/player/player.tscn").instantiate()
	player.position=Vector2(360,512);world.add_child(player)
	player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	player.get_node("PlayerVisualAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	player.get_node("CourierVisual").hide();player.get_node("PlayerFeedback").hide()
	var controller := player.get_node("Controller") as PlayerController
	var player_art := UnderworldPlayer.new();player_art.motor=player;player_art.controller=controller;player.add_child(player_art)
	var policy := FrameDamagePolicy.new();policy.lifetime=DemoLifetime.new();world.add_child(policy)
	check(policy.register_target(&"player",controller.actor_resources.health,true),"register player "+str(spec.id))
	policy.register_player_controller(controller)
	var audio := GameAudio.new();world.add_child(audio)
	var enemy: EnemyMotor=load("res://scenes/enemies/patrol_drone.tscn").instantiate()
	var actor := enemy.get_node("Actor") as EnemyActor
	actor.definition=load("res://resources/enemies/patrol_drone.tres") if str(spec.behavior)=="patrol" else PlainsEncounterPlanner.definition_for_behavior(str(spec.behavior))
	enemy.position=Vector2(720,435 if actor.definition.aerial else 550-actor.definition.collision_size.y*.5)
	world.add_child(enemy)
	if bool(spec.formal): load("res://scripts/underworld_plains/underworld_actor_installer.gd").install(world)
	var art := enemy.get_node("Presentation") as Node2D
	check((art is UnderworldEnemy) if bool(spec.formal) else (art is EnemyPresentation),"actual expected renderer "+str(spec.id))
	check(policy.bind_damageable(&"sample",actor.damageable,actor.health),"register real receiver "+str(spec.id))
	actor.bind_encounter(controller,policy,policy.lifetime,&"sample",[])
	var shots: Array[Dictionary]=[]
	var hits: Array[Dictionary]=[]
	var health_events: Array[Dictionary]=[]
	var deaths := [0]
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2,id: int) -> void:
		shots.append({"tick":Engine.get_physics_frames(),"shot_id":id,"direction":direction,"muzzle":controller.shoot_ability.last_muzzle}))
	actor.damageable.damaged.connect(func(context: Dictionary) -> void:
		hits.append({"tick":Engine.get_physics_frames(),"event_id":str(context.event_id),"shot_id":context.get("shot_id",-1),"hp":actor.health.current,"position":enemy.position}))
	actor.health.changed.connect(func(result: ActorResourceResult) -> void:
		health_events.append({"tick":Engine.get_physics_frames(),"operation":str(result.operation),"status":result.status,"event_id":str(result.event_id),"epoch":result.snapshot.epoch,"hp":result.snapshot.current}))
	actor.defeated.connect(func(_actor: EnemyActor) -> void:deaths[0]+=1)
	var started_tick := Engine.get_physics_frames()
	for frame: int in 300:
		# Live target lead uses current real velocity and the authored projectile
		# speed; no target pause, health injection or midfight repositioning.
		if frame in [30,80,130,180,230] and not actor.health.terminal:
			var travel: float = player.global_position.distance_to(enemy.global_position)/controller.shoot_ability.tuning.projectile_speed
			var aim: Vector2 = (enemy.global_position+enemy.velocity*travel-player.global_position).normalized()
			controller.router.aim_direction=aim
			controller.router.request_action(&"shoot_release",aim)
		await physics_frame;await process_frame
		var feedback: Dictionary=art.call("feedback_receipt") if art.has_method("feedback_receipt") else {}
		frame_rows.append({"case":str(spec.id),"case_frame":frame,"physics_tick":Engine.get_physics_frames(),"draw_frame":Engine.get_frames_drawn(),"player":player.position,"enemy":enemy.position,"hp":actor.health.current,"state":str(actor.attack_behavior.state) if actor.attack_behavior!=null else "patrol","visible":art.is_visible_in_tree(),"feedback":feedback})
		if frame==55:
			var frozen := feedback.duplicate(true)
			paused=true
			for pause_frame: int in 6: await process_frame
			if candidate: check(art.call("feedback_receipt")==frozen,"pause freezes actual sample "+str(spec.id))
			paused=false
	check(hits.size()==3 and actor.health.terminal,"three real projectile HP commits reach death "+str(spec.id))
	check(deaths[0]==1,"one accepted defeat "+str(spec.id))
	check(shots.size()>=3 and shots.size()<=5,"bounded legal Router shots "+str(spec.id))
	if candidate:
		var receipt: Dictionary=art.call("feedback_receipt")
		check(receipt.get("hurt_count")==2 and receipt.get("death_count")==1,"shared sample counts only accepted hurt/death "+str(spec.id))
		if bool(spec.formal): check(not art.visible,"original 0.65 parent hide retained "+str(spec.id))
		check(actor.restore_instance_health(0),"restore terminal accepts existing snapshot "+str(spec.id))
		check(art.call("feedback_receipt").get("death_count")==1 and not art.call("feedback_receipt").get("death_active"),"restored corpse does not replay "+str(spec.id))
	cases.append({"case":spec,"definition":actor.definition.resource_path,"shots":shots,"hits":hits,"health_events":health_events,"defeats":deaths[0],"start_tick":started_tick,"end_tick":Engine.get_physics_frames(),"final_hp":actor.health.current,"player_hp":controller.actor_resources.health.current})
	controller.shoot_ability.clear_projectiles()
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"audio teardown "+str(spec.id))
	world.queue_free();await process_frame;await process_frame

func run() -> void:
	RenderingServer.set_default_clear_color(Color("1c2928"))
	for spec: Dictionary in CASES: await run_case(spec)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"candidate":candidate,"seed":"enemy-feedback-01-m1","scope":"initial-position fixture; real Router/projectile/AI/HP; not natural full-stage or user/device acceptance","cases":cases,"frames":frame_rows},"\t"))
	print("ENEMY_FEEDBACK_01 checks=%d cases=%d failures=%d"%[checks,cases.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
