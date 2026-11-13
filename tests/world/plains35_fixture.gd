extends SceneTree
## Declared local approach fixtures use the current preview controller and PlayerMotor.
## They prove contacts/actions at those starts, not full-route traversal.
var app: FixedWorldApp
var failures:=0
var exercise_story:=false
func _initialize() -> void:run.call_deferred()
func run() -> void:
	push_error("Run a concrete plains35 test, not the shared fixture")
	quit(1)
func ticks(n: int) -> void:
	for i: int in n:await physics_frame
func check(ok: bool,label: String) -> void:
	print("PLAINS35 ",ok," ",label)
	if not ok:failures+=1
func load_room(id: String, stage: String = "base") -> void:
	for wait_frame:int in 600:
		if not app.busy:break
		await ticks(1)
	var source:=load("res://game/world/regions/"+id.substr(0,1)+"/rooms/"+id+".tscn").instantiate() as FixedWorldRoom
	check(WorldRoomValidation.validate_room(source).is_empty(),id+" codec")
	source.free()
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FixedWorldProvider.PREVIEW_CATALOG))
	for field:String in ["rooms","actions","demo_services","npcs","map_rooms"]: app.content.data[field]=catalog[field].duplicate(true)
	app.content._index_actions()
	await app.review.begin(id,"",stage)
	await ticks(4)
	if app.room==null:
		printerr("Room load failed: ",app.status," provider ",app.content.preview_catalog_error," status ",app.status);quit(1);return
	if not exercise_story and is_instance_valid(app.story) and app.story.active:app.story.finish();await ticks(2)
	check(app.room.room_id==id and app.player.is_on_floor(),id+" bridge and entry contact "+str(app.player.position))
func fixture(at:Vector2) -> void:
	app.controller.router.clear("declared approach fixture");app.player.reset_at(at)
	app.lifetime.invalidate_actor();app.controller.session_id+=1
	(app.camera as WorldCamera).reset_view();await ticks(4)
func hop(start: Vector2, target: Vector2, aim: Vector2, label: String, delay: int = 16) -> void:
	await fixture(start)
	var axis := signf(target.x-start.x)
	app.controller.router.set_source_axis(&"keyboard_mouse",axis)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(delay)
	if aim != Vector2.ZERO: app.controller.router.request_action(&"shoot_release",aim)
	var landed := false
	for frame: int in 100:
		await ticks(1)
		if absf(app.player.position.x-target.x)<18 or (app.player.position.x-target.x)*axis>0:
			app.controller.router.set_source_axis(&"keyboard_mouse",0)
		if app.player.is_on_floor():
			landed = absf(app.player.position.y-target.y)<5 and absf(app.player.position.x-target.x)<80
			break
	check(landed,label+" at "+str(app.player.position))
	app.controller.router.clear("hop complete")
func hook(start:Vector2, target:Vector2, label:String, delay:int=0)->void:
	await fixture(start)
	if delay>0:
		app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(delay)
	app.controller.router.request_action(&"grapple",(target-app.player.position-Vector2(0,-6)).normalized())
	var reached:=false
	for i:int in 90:
		await ticks(1)
		if app.controller.traversal.state==&"hook_hang":reached=true;break
	check(reached,label+" "+str(app.player.position))
	app.controller.router.clear("hook check complete")
