extends SceneTree
## Shared fixtures and current tutorial checks. Declared local starts, not a continuous first-visit proof.
var app: FixedWorldApp
var failures:=0
var require_preview:=false
var replay_save_path:="user://plains_intro_replay.json"
func _initialize() -> void:run.call_deferred()
func ticks(n: int) -> void:
	for i: int in n:await physics_frame
func settle() -> void:
	for i: int in 240:
		await physics_frame
		if not app.busy:return
func check(ok: bool,label: String) -> void:
	print("INTRO ",ok," ",label)
	if not ok:failures+=1
func visible_before_action(point: Vector2,label: String) -> void:
	if not require_preview:return
	var half:=app.camera.get_viewport_rect().size/(2*app.camera.zoom)
	var view:=Rect2(app.camera.get_screen_center_position()-half,half*2).grow(-8)
	var visible_point:=point+Vector2(0,18)
	for door: Dictionary in app.room.doors:
		var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
		if door.direction in ["up","down"] and portal.distance_to(visible_point)<40:
			var edge:=app.camera.get_screen_center_position().y+half.y*(1 if door.direction=="down" else -1)
			print("DOOR PREVIEW ",label," player=",app.player.position," camera=",app.camera.position," edge=",edge," portal=",portal)
			check(absf(edge-portal.y)<2,"continuous approach sees edge-aligned doorway "+label);return
	check(view.has_point(visible_point),"continuous approach sees "+label+" "+str(point))

func walk(point: Vector2,rid: String) -> bool:
	var held:=0
	var preview_checked:=false
	for i: int in 700:
		await physics_frame
		if app.busy:continue
		if app.room.room_id!=rid:print("WALK TRANSITION ",rid," -> ",app.room.room_id," at ",app.player.position);return true
		var at:=app.player.position
		if i%120==0:print("WALK ",rid," ",at," -> ",point," hp=",app.controller.actor_resources.health.current)
		if absf(at.x-point.x)<8 and absf(at.y-point.y)<12 and app.player.is_on_floor():
			app.controller.router.clear("waypoint");return true
		var dx:=point.x-at.x
		if require_preview and not preview_checked and app.player.is_on_floor() and point.y>at.y+100:
			var ahead:=at+Vector2(signf(dx)*32,0)
			var ray:=PhysicsRayQueryParameters2D.create(ahead,ahead+Vector2(0,24),1)
			if app.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
				visible_before_action(point,rid+" next descent at last safe edge");preview_checked=true
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
		if point.y>at.y+40 and absf(dx)<30 and app.player.is_on_floor():app.controller.router.request_action(&"drop_through")
		if app.player.is_on_floor() and point.y<at.y-30 and absf(dx)<300:
			if not preview_checked:visible_before_action(point,rid+" next ascent");preview_checked=true
			app.controller.router.set_jump_held(&"keyboard_mouse",false);app.controller.router.set_jump_held(&"keyboard_mouse",true);held=32
		elif held>0:
			held-=1
			if held==0:app.controller.router.set_jump_held(&"keyboard_mouse",false)
	printerr("STUCK ",rid," ",app.player.position," -> ",point," ",app.status);return false
func path(points: Array,rid: String) -> bool:
	for p: Vector2 in points:
		if not await walk(p,rid):return false
	return true
func recoil_jump(direction: Vector2) -> void:
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(9);app.controller.router.request_action(&"shoot_release",direction)
	await ticks(7);app.controller.router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 100:
		await physics_frame
		if app.player.is_on_floor():break
	app.controller.router.clear("landing")
	print("RECOIL LAND ",app.player.position)
func cross(at: Vector2,aim: Vector2=Vector2.ZERO,shot_frame: int=9) -> bool:
	visible_before_action(at,app.room.room_id+" next jump landing")
	app.controller.router.clear("approach")
	app.controller.router.set_source_axis(&"keyboard_mouse",signf(at.x-app.player.position.x))
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	for i: int in 160:
		await physics_frame
		if i==shot_frame and aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim.normalized())
		var dx:=at.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i==32:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor():break
	app.controller.router.clear("cross_landed")
	print("CROSS ",app.room.room_id," ",app.player.position," -> ",at)
	if absf(app.player.position.y-at.y)>8:return false
	return await walk(at,app.room.room_id)
func ride(name: String,origin: Vector2,leave_y: float,destination: Vector2) -> bool:
	var lift:=app.room.get_node(name) as WorldMovingPlatform
	app.controller.router.clear("wait_for_cage")
	var previous:=lift.position.distance_to(origin)
	for i: int in 1800:
		await physics_frame
		if not is_instance_valid(lift):return false
		var current:=lift.position.distance_to(origin)
		if current<1 or (current<160 and current<previous):break
		previous=current
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var boarded:=false
	for i: int in 180:
		await physics_frame
		if not is_instance_valid(lift):return false
		var dx:=lift.position.x-app.player.position.x
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>4 else 0)
		if i==32:app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if i>8 and app.player.is_on_floor() and absf(app.player.position.y-lift.position.y+28)<8:boarded=true;break
	app.controller.router.clear("boarded")
	if not boarded:printerr("BOARD FAILED ",name," ",app.player.position," ",lift.position);return false
	for i: int in 1800:
		await physics_frame
		if not is_instance_valid(lift):return false
		if i%60==0:print("RIDE ",name," rider=",app.player.position," lift=",lift.position," floor=",app.player.is_on_floor())
		if lift.position.y<leave_y:break
	return await cross(destination)
func station_hall() -> bool:
	return await ride("StationLift",Vector2(544,1744),1344,Vector2(1328,1262))
func finish() -> void:
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5);print("PLAINS INTRO: ",failures," failures");quit(failures)

func load_review(id: String) -> void:
	await app.review.begin(id,"","base")
	await ticks(3)
func fixture(at: Vector2) -> void:
	app.controller.router.clear("declared local fixture")
	app.player.reset_at(at)
	await ticks(3)
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://plains_revision_isolated.json";root.add_child(app)
	for id: String in ["P-R03","P-R21","P-R22","P-R23","P-R24"]:
		var room:=load("res://game/world/regions/P/rooms/"+id+".tscn").instantiate() as FixedWorldRoom
		var errors:=WorldRoomDraft.validate(room,WorldRoomDraft.extract(room))
		check(errors.is_empty(),id+" editable codec "+str(errors));room.free()
	await load_review("P-R03")
	for frame:int in 180:
		if app.introduction.dialogue_active:break
		await ticks(1)
	check(app.introduction.dialogue_active and not app.controller.shoot_ability.enabled,"wake blocks shooting before gun pickup")
	app.introduction.advance();await ticks(3)
	await fixture(Vector2(288,1774))
	app.introduction.pickup()
	check(app.state.has("intro_gun") and app.controller.shoot_ability.enabled,"ground pickup grants gun")
	while app.introduction.dialogue_active:app.introduction.advance()
	await load_review("P-R21")
	await fixture(Vector2(560,526));await ticks(10)
	check(not app.introduction.dialogue_active and WorldTraveler.chapter(app.state,"P-R21").is_empty(),"traveler content deferred without blocking tutorial")
	await load_review("P-R22")
	# Remove incidental encounters only for repeatable traversal measurement.
	for enemy: EnemyActor in app.room.enemies.values():enemy.queue_free()
	app.room.enemies.clear();await ticks(2)
	for bay: Array in [[Vector2(830,1486),1024,1408],[Vector2(1854,1390),2080,1344]]:
		for recoil: bool in [false,true]:
			await settle() # A failed attempt now completes its covered return first.
			await fixture(bay[0])
			app.controller.router.set_source_axis(&"keyboard_mouse",1)
			app.controller.router.set_jump_held(&"keyboard_mouse",true)
			var reached:=false
			var best:=0.0
			for i: int in 70:
				if i==8 and recoil:app.controller.router.request_action(&"shoot_release",Vector2(-.94,.34))
				await ticks(1)
				if app.player.position.y+18<=float(bay[2])+2:
					best=maxf(best,app.player.position.x)
					if best>=float(bay[1])-8:reached=true
			app.controller.router.clear("fixture finished")
			print("PIT ",bay[1]," recoil=",recoil," best=",best," end=",app.player.position)
			check(reached==recoil,"pit crosses with recoil only")
	await fixture(Vector2(2528,1294))
	var shutter:=app.room.mechanisms["P-R22:practice_shutter"] as WorldShotLatch
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(11)
	app.controller.router.request_action(&"shoot_release",(shutter.to_global(shutter.bell_position)-app.player.position).normalized())
	await ticks(50);app.controller.router.clear("shutter landing");await ticks(25)
	check(shutter.open_count==1 and app.player.position.x>2828 and app.player.position.y<1200,"P22 exposed bell and recoil clear tutorial shutter "+str(app.player.position))
	await load_review("P-R23")
	await fixture(Vector2(1584,526))
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(11)
	app.controller.router.request_action(&"shoot_release",Vector2(.6,.8))
	var landed:=false
	for i: int in 90:
		await ticks(1)
		if app.player.is_on_floor() and app.player.position.y<340:landed=true;break
	check(landed,"P23 down-right shot lands on upper-left platform "+str(app.player.position))
	await load_review("P-R24")
	await fixture(Vector2(1984,1102));await ticks(75)
	for index: int in 3:
		var encounter:=app.wave_encounter
		check(encounter.wave==index and encounter.active_ids.size()==([3,4,5][index]),"wave count "+str(index+1))
		for id: String in encounter.active_ids:
			var enemy:=app.room.enemies[id] as EnemyActor
			enemy.damageable.receive_damage({"amount":1000.0,"source_actor_id":app.player.get_instance_id(),"event_id":StringName(id+":test"),"source_faction":&"player","target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch})
		await ticks(80)
	check(app.state.has("intro_arena_cleared") and app.wave_encounter.finished,"three waves open exit")
	await fixture(Vector2(1456,1102))
	var lift:=app.room.get_node("OverlookLift") as WorldMovingPlatform
	var bell:=app.room.mechanisms["P-R24:station_lift"] as WorldShotLatch
	check(not lift.motion_running,"lift waits for bell after arena")
	app.controller.router.request_action(&"shoot_release",(Vector2(1440,1080)-app.player.position).normalized())
	await ticks(30)
	check(lift.motion_running,"real shot starts station lift")
	var height:=lift.position.y;await ticks(180)
	check(lift.position.y<height-100,"activated lift ascends")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(2)
	print("PLAINS REVISION: ",failures," failures");quit(failures)
