extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL "+label)
func _initialize()->void:run.call_deferred()
func frames(n:int)->void:
	for i:int in n:await physics_frame
func run()->void:
	# General geometry contract: extremal lengths/materials and joined boundaries.
	for width:float in [8,24,70,160,375,1000]:
		for wood:bool in [false,true]:
			var r:=Rect2(43,75,width,24)
			var pieces:=PlainsCohesionArt.surface_pieces(r,wood)
			var cursor:=r.position.x
			for piece:Dictionary in pieces:
				check(absf(piece.destination.position.x-cursor)<.01,"surface covers without gaps/overlap")
				check(piece.destination.end.x<=r.end.x+.01,"visual terminal does not exceed collision end")
				check(absf(piece.destination.size.x/piece.source.size.x-piece.destination.size.y/piece.source.size.y)<.001,"uniform scale independent of length")
				cursor=piece.destination.end.x
			check(absf(cursor-r.end.x)<.01,"whole slab covered")
			var joined:=PlainsCohesionArt.surface_pieces(r,wood,true,true)
			check(joined.all(func(p:Dictionary)->bool:return p.kind=="middle"),"joined slabs never repeat terminal caps")
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v3/enemies/meadow_actions/manifest.json"))
	for data:Dictionary in manifest.species.values():
		var scale:=EnemyPresentation.fitted_action_scale(data,Vector2(28,32))
		for frame:Dictionary in data.frames:
			var b:Array=frame.visible_bounds_alpha128_xyxy
			var a:Array=frame.anchor_px
			check((float(b[2])-float(a[0]))*scale<=14.01 and (float(a[0])-float(b[0]))*scale<=14.01,"visible enemy body matches hurtbox across poses")
			check((float(a[1])-float(b[1]))*scale<=32.01,"visible enemy head can be hit")
	boundary_contract()
	await moving_support()
	await pause_encounter()
	await enemy_candidates()
	print("QUALITY REVIEW: %s assertions, %s failures"%[checks,failures]);quit(1 if failures else 0)

func moving_support()->void:
	var world:=Node2D.new();root.add_child(world)
	var module:=PlatformingModule.new()
	module.definition=PlatformingModuleDefinition.new()
	# Platform node uses its actual bell-controlled clock; no actor translations.
	module.set_physics_process(false)
	var platform:=ModuleMovingPlatform.new()
	platform.module=module
	platform.definition=ModuleMovingPlatformDefinition.new()
	platform.definition.start=Vector2(0,200);platform.definition.finish=Vector2(320,200)
	platform.definition.travel_duration=1.5;platform.definition.dwell_duration=.5
	platform.bell_controlled=true
	world.add_child(platform)
	var player:PlayerMotor=preload("res://scenes/player/player.tscn").instantiate()
	player.position=Vector2(0,170);world.add_child(player)
	var camera:=StageCameraRig.new();world.add_child(camera)
	camera.configure(player,Rect2(-3000,-3000,6000,6000))
	await frames(100)
	var previous_player:=player.position
	var previous_camera:=camera.position
	var peak:=0.0
	var carried:=0.0
	for i:int in 240:
		await frames(1)
		if player.is_on_floor():
			var dp:=player.position-previous_player
			var dc:=camera.position-previous_camera
			peak=maxf(peak,absf(dp.x-dc.x));carried+=absf(dp.x)
		previous_player=player.position;previous_camera=camera.position
	check(carried>450,"actual collision carries player through travel, dwell and reversal")
	check(peak<.3,"support/camera common motion stays aligned; measured peak="+str(peak))
	var controller:PlayerController=player.get_node("Controller")
	controller.router.set_jump_held(&"review_jump",true);controller.router.request_action(&"jump")
	await frames(8)
	check(not player.is_on_floor() and camera._support==null,"real jump detaches support frame")
	controller.router.set_jump_held(&"review_jump",false)
	world.free();module.free();await process_frame

func pause_encounter()->void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	await frames(2);check(app.start_plains("quality-review-pause"),"real formal region initializes")
	await frames(8)
	var stage:=app.stage as PlainsRegionStage
	var attack:EnemyAttackBehavior
	for enemy:EnemyMotor in stage.enemies:
		var actor:EnemyActor=enemy.get_node("Actor")
		if actor.attack_behavior!=null:attack=actor.attack_behavior;break
	check(attack!=null,"formal generated consumer binds attack behavior")
	if attack!=null:
		# State-invariance probe; not a claim of gameplay traversal/actual shots.
		attack._set_state(&"telegraph");attack.state_time=.23;attack.cooldown=.41
		app._pause_for_menu();await process_frame;await process_frame
		check(attack.state==&"telegraph" and is_equal_approx(attack.state_time,.23) and is_equal_approx(attack.cooldown,.41),"pause preserves enemy warning, elapsed time and recovery debt")
		app._resume_from_menu()
	var encounter:WindkeeperEncounter=stage.boss.get_node("Encounter")
	encounter.active=true
	for mode:StringName in [&"intro",&"phase_transition",&"observe",&"roll_warning",&"roll",&"neck"]:
		encounter.mode=mode
		check(encounter.body_contact_enabled()==(mode not in [&"intro",&"phase_transition"]),"boss contact contract mode "+str(mode))
	encounter.active=false;check(not encounter.body_contact_enabled(),"inactive boss body is safe")
	app.free();paused=false;await process_frame

func boundary_contract()->void:
	var left:=Rect2(0,0,100,80)
	var right:=Rect2(100,0,140,80)
	var adjacent:Array[Rect2]=[left,right]
	var boundary:=PlainsTerrainBorders.plan(left,adjacent)
	check(not boundary.faces.any(func(f:Dictionary)->bool:return f.side=="right"),"module seam is not an exposed right edge")
	check(boundary.corners.all(func(c:Dictionary)->bool:return c.point.x==0),"internal joined corners suppressed")
	var elbow:Array[Rect2]=[Rect2(0,0,60,180),Rect2(60,120,120,60)]
	var concave:=PlainsTerrainBorders.plan(elbow[0],elbow)
	check(concave.corners.any(func(c:Dictionary)->bool:return c.kind=="inner" and c.point==Vector2(60,120)),"L union produces actual concave corner")
	for size:Vector2 in [Vector2(8,8),Vector2(1100,24),Vector2(30,600),Vector2(200,300)]:
		var rect:=Rect2(Vector2(-173,97),size)
		var isolated:Array[Rect2]=[rect]
		var plan:=PlainsTerrainBorders.plan(rect,isolated)
		check(plan.faces.size()==4 and plan.corners.size()==4,"all eight outside boundaries exist at arbitrary dimensions")
		check(plan.corners.all(func(c:Dictionary)->bool:return c.kind=="outer"),"isolated solid has no fabricated concave border")

func enemy_candidates()->void:
	var lab:=ModuleLab.new();root.add_child(lab)
	lab.request_module(&"enemy_prototypes");await frames(5)
	check(is_instance_valid(lab.enemy_prototypes) and lab.enemy_prototypes.actors.size()==2,"candidate menu binds two real EnemyActor consumers")
	var guard:EnemyActor=lab.enemy_prototypes.actors[0]
	var moth:EnemyActor=lab.enemy_prototypes.actors[1]
	# Explicit fixture setup, then actual player control/projectiles. Not formal pool validation.
	lab.player.reset_at(Vector2(guard.motor.position.x-80,582))
	guard.set_physics_process(false);moth.set_physics_process(false)
	guard.brain.direction=-1;guard.attack_behavior.state=&"telegraph"
	var initial:=guard.health.current
	lab.controller.router.request_action(&"shoot_release",Vector2.RIGHT);await frames(20)
	check(guard.health.current==initial,"actual front projectile is rejected by closed shield")
	guard.attack_behavior.state=&"recovery"
	lab.controller.router.request_action(&"shoot_release",Vector2.RIGHT);await frames(20)
	check(guard.health.current<initial,"actual projectile damages open recovery")
	var behavior:=moth.attack_behavior as PrototypeMothBehavior
	behavior.state=&"attack";behavior.state_time=.01;behavior.locked_direction=Vector2.LEFT
	behavior._fire()
	var first:=behavior._projectiles[-1].direction
	behavior.state_time=.49;behavior.advance(.02)
	check(behavior._serial==2 and behavior._projectiles[-1].direction.y*first.y<0,"second actual projectile changes lane after delay without re-aim")
	lab.leave_lab();await frames(3)
	check(not lab.lifetime.active,"leaving candidate attempt cancels lifetime")
	lab.free();await process_frame
