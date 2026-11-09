extends SceneTree
## Fast load and the continuous lower guide route, not a full-room proof.
var app: FixedWorldApp
var failures := 0
var refills: Dictionary = {"wall_attach":0,"hook_hit":0}
var output := "res://build/stargate_basic"
var capture := false

func _initialize() -> void: run.call_deferred()
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func check(ok: bool,label: String) -> bool:
	print("STARGATE BASIC ",ok," ",label)
	if not ok: failures+=1
	return ok
func jump() -> void:
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	await ticks(1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
func picture(name: String) -> void:
	if not capture:return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func finish() -> void:
	var report: Dictionary={"schema":1,"room_id":"V-R12","scope":"Scene load and continuous entry-to-inner-wall route; no full-room completion claim.","scene_sha256":FileAccess.get_sha256("res://game/world/regions/V/rooms/V-R12.tscn"),"failures":failures,"refill_events":refills}
	var file:=FileAccess.open(output+"/basic.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	await WorldAudioLifecycle.drain_world(app)
	app.queue_free();await process_frame;await process_frame
	print("STARGATE BASIC: ",failures," failures");quit(failures)

func run() -> void:
	root.size=Vector2i(1280,720)
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://stargate_basic_isolated.json"
	root.add_child(app);app.workbench.enabled=true
	var source:=preload("res://game/world/regions/V/rooms/V-R12.tscn").instantiate() as FixedWorldRoom
	var draft:=WorldRoomDraft.extract(source)
	check(WorldRoomDraft.validate(source,draft).is_empty(),"current scene uses the normal editable codec")
	check(source.hook_points.size()==2 and source.climbable_walls.size()==6,"two H turn points and six wall recovery surfaces")
	var chute:=Rect2(108,340,24,1490)
	var clear:=true
	for solid: Rect2 in source.platforms+source.climbable_walls:
		if solid.intersects(chute):clear=false
	for strip: Dictionary in source.spike_strips:
		if FixedWorldProvider.rect(strip.bounds).intersects(chute):clear=false
	check(clear,"the existing left return drop remains free of new solid and thorn geometry")
	source.free()
	draft.base_content_version=app.content.workbench_base_version();draft.revision=1
	var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.WORKBENCH_CATALOG))
	var row: Dictionary=catalog.rooms["V-R12"]
	draft.geometry={"bounds":row.world_geometry.bounds_world_units,"space_rects":row.world_geometry.space_rects,"doors":row.doors}
	await app.workbench._handle({"channel":"gunman-workbench","type":"load_draft","request_id":"stargate_basic","revision":1,"draft":draft,"stage":"hwdq","paused":false})
	if not check(app.workbench.last_event.get("type")=="draft_loaded","current draft loads through the real bridge with hwdq"):await finish();return
	check(app.player.is_on_floor() and app.controller.traversal.hook_enabled and app.controller.traversal.double_enabled and app.controller.traversal.wall_enabled and app.q_guard.owned,"real entry support and H/W/D/Q consumers")
	app.controller.traversal.traversal_resources_refilled.connect(func(kind: StringName) -> void: refills[str(kind)]=int(refills.get(str(kind),0))+1)
	await ticks(10)
	await picture("entry-normal-camera")
	# Segment 1: real entry -> oblique recoil -> D -> first qualified wall.
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	await jump();await ticks(8)
	app.controller.router.request_action(&"shoot_release",Vector2(-0.8,0.6))
	await ticks(10)
	await jump()
	var wall_reached:=false
	for i: int in 45:
		await ticks(1)
		if app.controller.traversal.state==&"wall_attach":wall_reached=true;break
	check(wall_reached and int(refills.wall_attach)>0 and app.controller.action_resources.shot_charges==app.player.tuning.max_air_shots,"entry recoil + D reaches W1 and the actual contact restores the next shot")
	await picture("entry-recoil-d-wall")
	# Continue from the actual first wall: slide below its foot, recoil across,
	# then hook upward. This is the same lower route shown by markers 1--3.
	for i: int in 360:
		if app.player.position.y >= 1798: break
		await ticks(1)
	check(app.player.position.y >= 1798 and app.player.position.y < 1820,"first wall has a reachable opening below its foot")
	app.controller.router.request_action(&"shoot_release",Vector2.LEFT)
	await ticks(12)
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	await jump();await ticks(2)
	app.controller.router.request_action(&"grapple",(Vector2(544,1648)-app.player.position-Vector2(0,-6)).normalized())
	var ring_reached:=false
	for i: int in 60:
		await ticks(1)
		if app.controller.traversal.state==&"hook_hang":ring_reached=true;break
	if not check(ring_reached and int(refills.hook_hit)>0,"the continuous entry route goes around the wall foot and hooks H1"):await finish();return
	while app.q_guard.cooldown>0:await ticks(1)
	var health_before: float=app.controller.actor_resources.health.current
	app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
	await ticks(10)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	await jump()
	var lift_reached:=false
	for i: int in 45:
		await ticks(1)
		if app.controller.traversal.state==&"wall_attach" and app.player.position.x>560:lift_reached=true;break
	check(lift_reached and app.controller.actor_resources.health.current==health_before,"H recovery -> upward recoil through Q curtain -> D sidestep reaches W3 without damage")
	await picture("lift-recoil-d-wall")
	# Upper curtain uses an explicit local fixture; do not claim a full ascent.
	app.controller.router.clear("upper_curtain_local_fixture")
	app.player.reset_at(Vector2(640,864))
	await ticks(1)
	app.controller.router.request_action(&"grapple",(Vector2(624,704)-app.player.position-Vector2(0,-6)).normalized())
	var upper_ring := false
	for i: int in 60:
		await ticks(1)
		if app.controller.traversal.state==&"hook_hang":upper_ring=true;break
	if not check(upper_ring,"upper local fixture hooks the second ring from below"):await finish();return
	while app.q_guard.cooldown>0:await ticks(1)
	health_before=app.controller.actor_resources.health.current
	app.controller.router.request_action(&"shoot_release",Vector2(0.94,-0.34))
	await ticks(12)
	check(app.player.position.x<500 and app.controller.actor_resources.health.current==health_before,"left-down recoil exits the upper golden curtain without damage")
	await finish()
