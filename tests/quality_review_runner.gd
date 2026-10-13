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
			var pieces:=PlainsTerrainSkin.surface_pieces(r,"brass_wood_bridge" if wood else "grass_limestone")
			var cursor:=r.position.x
			for piece:Dictionary in pieces:
				check(absf(piece.destination.position.x-cursor)<.01,"surface covers without gaps/overlap")
				check(piece.destination.end.x<=r.end.x+.01,"visual terminal does not exceed collision end")
				check(absf(piece.destination.size.x/piece.source.size.x-piece.destination.size.y/piece.source.size.y)<.001,"uniform scale independent of length")
				cursor=piece.destination.end.x
			check(absf(cursor-r.end.x)<.01,"whole slab covered")
			var joined:=PlainsTerrainSkin.ground_edge_pieces(r,Vector2.ZERO,true,true)
			var middle:=PlainsV3Assets.rect(PlainsV3Assets.entry("terrain/manifest.json","grass_limestone").regions.middle)
			check(joined.all(func(p:Dictionary)->bool:return p.source.position.x>=middle.position.x-.01 and p.source.end.x<=middle.end.x+.01),"joined slab samples stay inside designated middle; no terminal caps")
	boundary_contract()
	tile_budget_contract()
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

	# Withdrawn border painter is not accepted. Exercise the replacement consumer.
	var tiles:=PlainsTileComposer.catalog()
	check(tiles.size()==47,"runtime loads complete 47-mask catalog")
	for input:int in 256:
		var cells:Dictionary={Vector2i.ZERO:true}
		for bit:int in 8:
			if input&(1<<bit):cells[PlainsTileComposer.OFFSETS[bit]]=true
		var mask:=PlainsTileComposer.mask_at(cells,Vector2i.ZERO)
		check(tiles.has(mask) and mask&15==input&15,"runtime normalizes all neighbourhoods without losing exposed sides")
	var gallery:=ModuleTerrainGallery.new();root.add_child(gallery)
	await process_frame
	check(gallery.body.get_child_count()>10,"actual candidate gallery instantiates shapes")
	for child:Node in gallery.body.get_children():
		if child is Button and child.text=="SHAPES / 47 MASKS":child.pressed.emit();break
	await process_frame;await process_frame
	check(gallery.body.get_child_count()>90,"actual gallery instantiates all 47 masks")
	gallery.free()
	for rolling:bool in [false,true]:
		check(BossArrivalPresentation.pose_offset(0,rolling,1).length()<.001,"intro starts at visible dormant pose")
		check(BossArrivalPresentation.pose_offset(1,rolling,1).length()<.001,"intro ends at combat pose without jump")

func tile_budget_contract()->void:
	# Surround a solid macro footprint with many disconnected boundaries; vary phase.
	for macro:Vector2i in [Vector2i.ONE,Vector2i(1,2),Vector2i(2,1),Vector2i(2,2),Vector2i(4,2),Vector2i(4,4)]:
		for phase:int in 2:
			var cells:Dictionary={}
			for y:int in range(-2,macro.y+2):
				for x:int in range(-2,macro.x+2):
					if (x>=0 and x<macro.x and y>=0 and y<macro.y) or posmod(x+y,2)==phase:cells[Vector2i(x,y)]=true
			var painted:=PlainsTileComposer.build(cells,macro)
			var seen:Dictionary={}
			for piece:Polygon2D in painted.get_children():
				var material:ShaderMaterial=piece.material
				check(material.get_shader_parameter("face_count")<=64,"complex hole boundary stays within GPU budget by subdividing")
				var size:Vector2i=piece.get_meta("macro_size")
				var start:=Vector2i(piece.polygon[0]/32)
				for dy:int in size.y:
					for dx:int in size.x:
						var cell:=start+Vector2i(dx,dy)
						check(not seen.has(cell) and cells.has(cell),"budget fallback neither overlaps nor fills a hole");seen[cell]=true
			check(seen.size()==cells.size(),"budget fallback preserves all occupied cells")
			painted.free()
