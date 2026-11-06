extends SceneTree
## Explicit W/D preconditions isolate late abilities; the normal first loop never grants them.
var app: FixedWorldApp
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("FAIL: ",label)
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func run() -> void:
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_traversal_contracts.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app);app.start_new();await ticks(15)
	check(not app.controller.traversal.double_enabled and not app.controller.traversal.wall_enabled,"fresh world does not grant late traversal")
	var candidate:=app.state.value.duplicate(true);candidate.flags.append_array(["W","D"])
	app.state.commit(candidate,app.state.revision);app._apply_capabilities()
	check(app.controller.traversal.double_enabled and app.controller.traversal.wall_enabled,"same world capability adapter enables declared W/D preconditions")
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
	app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(2)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(3)
	check(app.controller.jump_ability.used_jumps==2 and app.player.velocity.y<0,"real second jump uses existing Motor/JumpAbility")
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.load_room("P-R06","room-link-139:P-R06")
	for frame: int in 180:
		await physics_frame
		if not app.busy: break
	# Qualified position fixture only, on the existing approach platform.
	app.player.reset_at(Vector2(1030,614));await ticks(3)
	app.controller.router.set_source_axis(&"keyboard_mouse",1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	var attached:=false
	for i: int in 45:
		await physics_frame
		if app.controller.traversal.state==&"wall_attach": attached=true;break
	check(attached,"authored tagged wall accepts real wall adhesion")
	app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(1)
	app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(1)
	check(app.player.normal_velocity.x<0 and app.player.normal_velocity.y<0,"real wall kick separates from the wall")
	app.controller.router.set_source_axis(&"keyboard_mouse",0)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	app.queue_free();await ticks(5)
	print("WORLD TRAVERSAL: %d assertions, %d failures" % [checks,failures]);quit(failures)
