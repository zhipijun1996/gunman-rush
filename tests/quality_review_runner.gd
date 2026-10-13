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
	rectangle_art_contract()
	await region_art_consumer()
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
		if child is Button and child.text=="NEXT SAMPLE":child.pressed.emit();break
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
			for piece:ColorRect in painted.get_children():
				var material:ShaderMaterial=piece.material
				check(material.get_shader_parameter("face_count")<=64,"complex hole boundary stays within GPU budget by subdividing")
				var size:Vector2i=piece.get_meta("macro_size")
				var start:=Vector2i(piece.position/32)
				for dy:int in size.y:
					for dx:int in size.x:
						var cell:=start+Vector2i(dx,dy)
						check(not seen.has(cell) and cells.has(cell),"budget fallback neither overlaps nor fills a hole");seen[cell]=true
			check(seen.size()==cells.size(),"budget fallback preserves all occupied cells")
			painted.free()

func rectangle_art_contract()->void:
	var cases:Array[Array]=[
		[Rect2(-13.5,7.25,113.75,8.5)],
		[Rect2(0,0,10,10),Rect2(10.005,0,10,10)],
		[Rect2(0,0,103,23),Rect2(73,13,67,113),Rect2(0,103,140,23)],
		[Rect2(0,0,101,13),Rect2(0,13,17,100),Rect2(84,13,17,100),Rect2(0,113,101,11)],
		[Rect2(0,0,32,32),Rect2(16,8,64,32),Rect2(64,20,16,100)]]
	for sample:Array in cases:
		var solids:Array[Rect2]=[];solids.assign(sample)
		var original:=solids.duplicate()
		var paint:=PlainsTileComposer.build_rectangles(solids)
		var pieces:Array[Rect2]=[]
		for quad:ColorRect in paint.get_children():
			var actual:=Rect2(quad.position,quad.size)
			check(actual==quad.get_meta("authored_piece"),"actual native quad matches recorded authored geometry")
			pieces.append(actual)
		var xs:Array[float]=[];var ys:Array[float]=[]
		for rect:Rect2 in solids+pieces:
			for x:float in [rect.position.x,rect.end.x]:
				if x not in xs:xs.append(x)
			for y:float in [rect.position.y,rect.end.y]:
				if y not in ys:ys.append(y)
			xs.sort();ys.sort()
		for i:int in xs.size()-1:
			for j:int in ys.size()-1:
				var point:=Vector2((xs[i]+xs[i+1])/2,(ys[j]+ys[j+1])/2)
				var count:=0
				for piece:Rect2 in pieces:
					if piece.has_point(point):count+=1
				check(count==(1 if PlainsTerrainBorders.occupied(point,solids) else 0),"non-grid overlapping solids are painted exactly once; gaps remain empty")
		check(paint!=null and paint.get_child_count()>0,"non-grid and thin authored rectangles get actual paint consumers")
		check(solids==original,"art adapter leaves authored geometry unchanged")
		paint.free()
	var whole:=corner_radius([Rect2(0,0,100,20)])
	check(is_equal_approx(whole,corner_radius([Rect2(0,0,2,20),Rect2(2,0,98,20)])),"unequal authoring partitions do not change outer contour")
	check(is_equal_approx(corner_radius([Rect2(0,0,1,10)]),corner_radius([Rect2(0,0,1,10),Rect2(4,0,10,10)])),"disconnected neighbour cannot affect local contour clearance")
	var strips:Array[Rect2]=[]
	for i:int in 100:strips.append(Rect2(i,0,1,20))
	var merged:=PlainsTileComposer.build_rectangles(strips)
	check(merged!=null,"boundary budget depends on actual union, not number of authoring pieces")
	if merged!=null:merged.free()
	var dense:Array[Rect2]=[]
	for i:int in 40:dense.append(Rect2(float(i%8)*.1,float(i/8)*.1,.025,.025))
	check(PlainsTileComposer.build_rectangles(dense)==null,"unsupported subpixel density refuses preview instead of truncating boundaries")

func corner_radius(solids:Array[Rect2])->float:
	var art:=PlainsTileComposer.build_rectangles(solids)
	var result:=-1.0
	for child:ColorRect in art.get_children():
		var material:ShaderMaterial=child.material
		var corners:PackedVector4Array=material.get_shader_parameter("outer_corners")
		for i:int in int(material.get_shader_parameter("corner_count")):
			if Vector2(corners[i].x,corners[i].y)==Vector2.ZERO:result=corners[i].w
	art.free();return result

func region_art_consumer()->void:
	var app:=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
	await frames(3);app._open_module_lab();await frames(3)
	app._lab.request_module(&"terrain_gallery");await frames(5)
	app._lab.terrain_gallery.region_requested.emit();await frames(6)
	check(app.stage is PlainsRegionStage and app._lab==null,"development study transitions to real region consumer and closes lab lifetime")
	var study:PlainsTerrainStudy
	for child:Node in app.stage.get_children():
		if child is PlainsTerrainStudy:study=child
	check(study!=null and study.enabled,"actual generated region installs candidate adapter")
	var manifest:=JSON.stringify((app.stage as PlainsRegionStage).generated.manifest)
	var bodies:=app.stage.find_children("*","CollisionShape2D",true,false).size()
	for value:bool in [false,true,false,true]:
		study.set_candidate(value)
		check(JSON.stringify((app.stage as PlainsRegionStage).generated.manifest)==manifest,"candidate comparison never changes Manifest or random result")
		check(app.stage.find_children("*","CollisionShape2D",true,false).size()==bodies,"candidate comparison creates/removes no collision objects")
	# Explicit outcome fixture advances map; this is lifecycle coverage, not a
	# claim that the player traversed or defeated either Boss through input.
	check(await load("res://tests/plains_campaign_fixture.gd").second_map(app,self),"existing outcome fixture advances study to actual second region")
	for child:Node in app.stage.get_children():
		if child is PlainsTerrainStudy:study=child
	var arenas:=app.stage.find_children("*","WindkeeperArena",true,false)
	check(not arenas.is_empty(),"actual region contains mutable Boss terrain consumer")
	if not arenas.is_empty():
		var arena:WindkeeperArena=arenas[0]
		var before:=study.authored_solids.duplicate()
		arena._phase_changed(3)
		await frames(4)
		check(arena.broken and study.authored_solids!=before,"deferred Boss terrain mutation refreshes candidate")
		check(study.authored_solids==study.collect_solids(),"candidate follows committed collision presentation geometry")
		var hole:=arena.module.position+Vector2(645,650)
		check(not PlainsTerrainBorders.occupied(hole,study.authored_solids),"broken bridge has no painted false landing")
		study.set_candidate(false);study.set_candidate(true)
		check(not PlainsTerrainBorders.occupied(hole,study.authored_solids),"comparison cannot resurrect removed terrain")
		var restored:=PlainsTerrainStudy.new();restored.stage=app.stage;app.stage.add_child(restored)
		check(restored.authored_solids==study.authored_solids,"new observer initializes from already-mutated terrain")
		restored.free()
	app.abandon_run();await frames(3)
	check(not app._terrain_study_requested,"leaving study clears opt-in; future normal runs retain baseline art")
	app.free();await process_frame
