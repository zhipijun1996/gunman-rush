extends SceneTree
var checks:=0
var failures:Array[String]=[]
var room:PixelPlainsRoom
var trace:Array[Dictionary]=[]
func _init() -> void:_run.call_deferred()
func expect(value:bool,msg:String) -> void:
	checks+=1
	if not value:failures.append(msg);printerr("FAIL: "+msg)
func step(phase:String) -> void:
	await physics_frame
	trace.append({"phase":phase,"x":room.player.position.x,"y":room.player.position.y,"grounded":room.player.is_on_floor(),"epoch":room.lifetime.epoch,"health":room.controller.actor_resources.health.current,"motion_steps":room.player.motion_steps})
func walk(x:float) -> void:
	for i:int in 200:
		var dx:=x-room.player.position.x
		room.controller.router.set_move_axis(signf(dx) if absf(dx)>3 else 0)
		await step("walk_to_"+str(x))
		if absf(dx)<=3:break
func jump(x:float) -> Vector2:
	room.controller.router.set_jump_held(&"independent_branch",true)
	var airborne:=false
	for i:int in 150:
		var dx:=x-room.player.position.x
		room.controller.router.set_move_axis(signf(dx) if absf(dx)>3 else 0)
		if i==26:room.controller.router.set_jump_held(&"independent_branch",false)
		await step("jump_to_"+str(x))
		if not room.player.is_on_floor():airborne=true
		if airborne and room.player.is_on_floor():break
	room.controller.router.clear("independent_branch_settle")
	for i:int in 3:await step("settle")
	return room.player.position
func _run() -> void:
	var preview:=preload("res://scenes/demo/pixel_plains_preview.tscn").instantiate() as PixelPlainsPreview
	root.add_child(preview);room=preview.room
	for i:int in 30:await step("spawn")
	var initial_epoch:=room.lifetime.epoch
	var hp:=room.controller.actor_resources.health.current
	await walk(150)
	var first:=await jump(272)
	expect(absf(first.x-272)<8 and absf(first.y-366)<3,"first ordinary jump reaches upper ledge: "+str(first))
	await walk(300)
	var second:=await jump(480)
	expect(absf(second.x-480)<8 and absf(second.y-334)<3,"second ordinary jump reaches returned branch: "+str(second))
	var wood:=await jump(620)
	expect(absf(wood.x-620)<8 and absf(wood.y-366)<3,"branch naturally lands on real thin one-way: "+str(wood))
	expect(room.player.request_drop_through(),"actual wood collision accepts Motor drop-through")
	for i:int in 60:await step("wood_drop_to_court")
	expect(room.player.is_on_floor() and absf(room.player.position.y-494)<3,"drop-through safely returns to actual stone court")
	expect(initial_epoch==room.lifetime.epoch,"branch never reset or teleported")
	expect(hp==room.controller.actor_resources.health.current,"branch has no forced damage")
	expect(not room.controller.traversal.hook_enabled and not room.controller.traversal.wall_enabled and not room.controller.traversal.double_enabled,"ordinary jump branch requires no ungranted abilities")
	var file:=FileAccess.open("res://build/pixel-review/branch-trace.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace))
	preview.queue_free()
	for i:int in 10:await process_frame
	print("INDEPENDENT_BRANCH checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
