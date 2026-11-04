extends SceneTree
## Real SDK-generated pairs, unchanged native collision and automatic Controller /
## Motor. Each isolated fixture has one initial spawn; no mid-trace pose writes.
const READY=preload("res://tests/formal_region_test_support.gd")
const PLAYER=preload("res://game/player/player.tscn")
var app: DemoApp
var player: PlayerMotor
var controller: PlayerController
var failures:=0
var checks:=0
var trace: Array=[]
var records: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	records.append({"check":label,"passed":ok})
	if not ok: failures+=1;push_error(label)
func frames(n: int) -> void:
	for i: int in n:
		await physics_frame
		if is_instance_valid(player): trace.append({"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"floor":player.is_on_floor()})
func port_bank(placement: LevelModulePlacement,id: String) -> Vector2:
	for row: Dictionary in placement.definition.get_meta("runtime_map_v2_port_admission").used_ports:
		if row.port_id==id:return placement.position+Vector2(row.body_center_pixels[0],row.body_center_pixels[1])
	return Vector2.INF
func fixture(pair: Array,start: Vector2) -> Node2D:
	var world:=Node2D.new();root.add_child(world)
	for placement: LevelModulePlacement in pair:
		var module:=PlatformingModule.new()
		module.definition=placement.definition;module.position=placement.position;module.authoring_debug=false
		world.add_child(module)
	player=PLAYER.instantiate();player.position=start;world.add_child(player)
	controller=player.get_node("Controller")
	player.get_node("KeyboardMouseAdapter").process_mode=Node.PROCESS_MODE_DISABLED
	return world
func run() -> void:
	app=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();app.meta_persistence_enabled=false;root.add_child(app)
	await frames(3);app.menu._start_title_adventure();await frames(2);app.start_plains("ci-smoke")
	if not await READY.ready(app,self):check(false,"formal source ready");await finish();return
	var plan: LevelPlan=app.stage.level_plan
	var by: Dictionary={}
	for placement: LevelModulePlacement in plan.modules:by[placement.instance_id]=placement
	var vertical: Dictionary={};var horizontal: Dictionary={}
	for edge: Dictionary in plan.connections:
		if edge.surface!="ONE_WAY_PLATFORM":continue
		var a: LevelModulePlacement=by[str(edge.a.instance_id)];var b: LevelModulePlacement=by[str(edge.b.instance_id)]
		if not a.definition.saws.is_empty() or not b.definition.saws.is_empty() or not a.definition.ferries.is_empty() or not b.definition.ferries.is_empty():continue
		var face: String=""
		for port: Dictionary in a.definition.get_meta("runtime_map_v2_instance").ports:
			if port.id==edge.a.port_id:face=port.face
		if face in ["TOP","BOTTOM"] and vertical.is_empty():vertical={"edge":edge,"a":a,"b":b,"face":face}
		if face in ["LEFT","RIGHT"] and horizontal.is_empty():horizontal={"edge":edge,"a":a,"b":b,"face":face}
	check(not vertical.is_empty() and not horizontal.is_empty(),"actual generated map contains vertical and horizontal one-way pairs")
	app.abandon_run();await frames(8)
	if not vertical.is_empty():
		var lower: LevelModulePlacement=vertical.a if vertical.face=="TOP" else vertical.b
		var upper: LevelModulePlacement=vertical.b if vertical.face=="TOP" else vertical.a
		var lower_id: String=vertical.edge.a.port_id if vertical.face=="TOP" else vertical.edge.b.port_id
		var upper_id: String=vertical.edge.b.port_id if vertical.face=="TOP" else vertical.edge.a.port_id
		var start:=port_bank(lower,lower_id);var landing:=port_bank(upper,upper_id)
		var world:=fixture([lower,upper],start);var identity:=player.get_instance_id()
		await frames(6)
		check(player.is_on_floor(),"native lower one-way supports initial body")
		controller.router.request_action(&"jump")
		for i: int in 90:
			controller.router.set_source_axis(&"seam",clampf((landing.x-player.position.x)/8,-1,1),true)
			if i==20:controller.router.request_action(&"jump_release")
			await frames(1)
		controller.router.set_source_axis(&"seam",0)
		check(player.is_on_floor() and absf(player.position.y-landing.y)<2,"native jump crosses upward and lands in upper module")
		controller.router.request_action(&"drop_through")
		for i: int in 70:
			controller.router.set_source_axis(&"seam",clampf((start.x-player.position.x)/8,-1,1),true)
			await frames(1)
		check(player.is_on_floor() and absf(player.position.y-start.y)<2,"native active drop crosses downward and lands in lower module")
		check(player.get_instance_id()==identity and player.tuning.max_jumps==1 and player.tuning.max_air_shots==1 and not controller.traversal.hook_enabled,"same native player preserves actual basic abilities")
		world.free();player=null;await frames(2)
	if not horizontal.is_empty():
		var start:=port_bank(horizontal.a,horizontal.edge.a.port_id)
		var target:=port_bank(horizontal.b,horizontal.edge.b.port_id)
		var world:=fixture([horizontal.a,horizontal.b],start)
		await frames(6)
		for i: int in 80:
			controller.router.set_source_axis(&"seam",clampf((target.x-player.position.x)/8,-1,1),true)
			await frames(1)
		check(player.is_on_floor() and player.position.distance_to(target)<3,"native walking crosses horizontal one-way module seam")
		world.free();player=null;await frames(2)
	await finish()
func finish() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/mapgen_review")
	var file:=FileAccess.open("res://build/mapgen_review/native_seams.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":records,"failures":failures,"trace":trace,"scope":"isolated actual generated module pairs, original geometry, automatic native Controller/Motor, initial spawn only; not full-map playthrough"},"\t"));file.close()
	await preload("res://tests/audio_teardown.gd").drain_world(app);app.queue_free();await frames(4)
	print("MAPGEN NATIVE SEAMS: ",checks," assertions, ",failures," failures")
	quit(1 if failures else 0)
