extends SceneTree
## Normal-speed movie, driven by shared input. Resets only start labeled practice sections.
var studio: ActionStudio
var frame := 0
var trace: Array[Dictionary] = []
var screenshots := [45,65,170,310,410,550,565,700,830,980,1080,1230,1360,1480]
func _initialize() -> void:
	call_deferred("start")
func start() -> void:
	root.size=Vector2i(1280,720)
	var audio := GameAudio.new()
	root.add_child(audio)
	studio = preload("res://scenes/demo/action_studio.tscn").instantiate()
	root.add_child(studio)
	studio.controller.air_focus_ability.enabled=false
	physics_frame.connect(drive)
func drive() -> void:
	frame+=1
	var c := studio.controller
	if frame==1: c.router.set_move_axis(1)
	if frame==20: c.router.request_action(&"jump")
	if frame==33: c.router.request_action(&"shoot_release",Vector2(-.6,1).normalized())
	if frame==60: c.router.request_action(&"jump")
	if frame==65: c.router.request_action(&"jump_release")
	if frame==90: c.router.set_move_axis(0)
	if frame==120:
		studio.restart(0)
		c.shoot_ability.equip(preload("res://resources/weapons/triple_machine_gun.tres"))
		c.router.set_move_axis(1)
	if frame==140: c.router.request_action(&"jump")
	if frame==151: c.router.request_action(&"shoot_release",Vector2(-.55,1).normalized())
	if frame==155: c.router.set_aim(&"keyboard_mouse",Vector2.RIGHT)
	if frame==162: c.router.set_aim(&"keyboard_mouse",Vector2(.6,1).normalized())
	if frame==200: c.router.set_move_axis(0)
	if frame==240:
		studio.restart(1)
		c.router.set_move_axis(1)
	if frame==258: c.router.request_action(&"jump")
	if frame>260 and frame<460 and c.traversal.state==&"wall_attach": c.router.request_action(&"jump")
	if frame==470: c.router.set_move_axis(0)
	if frame==500: studio.restart(2)
	if frame==520: c.router.request_action(&"grapple",Vector2.RIGHT)
	if frame==550: c.router.request_action(&"jump")
	if frame==553: c.router.request_action(&"jump_release")
	if frame==610: studio.restart(3)
	if frame==625: c.router.set_move_axis(1)
	if frame==660: c.router.request_action(&"jump")
	if frame==680: c.router.request_action(&"shoot_release",Vector2.RIGHT)
	if frame==715: c.router.set_move_axis(0)
	if frame==750:
		studio.restart(3)
		# Initialize a separate labeled encounter view, not a route-completion claim.
		c.reset_at(Vector2(4750,602))
		studio.camera.position=c.motor.position+Vector2(120,-100)
	if frame==805: c.router.request_action(&"jump")
	if frame==830: c.router.request_action(&"shoot_release",Vector2.RIGHT)
	if frame==900:
		c.reset_at(Vector2(5850,602))
		studio.camera.position=c.motor.position+Vector2(120,-100)
	if frame==945: c.router.request_action(&"jump")
	if frame==1000:
		c.reset_at(Vector2(6750,602))
		studio.camera.position=c.motor.position+Vector2(120,-100)
	if frame==1050: c.router.request_action(&"jump")
	if frame==1140:
		c.reset_at(Vector2(7850,602))
		studio.camera.position=c.motor.position+Vector2(120,-100)
	if frame==1190: c.router.request_action(&"jump")
	if frame==1320:
		c.reset_at(Vector2(300,602))
		studio.camera.position=c.motor.position+Vector2(120,-100)
		var danger := DemoContactEmitter.new()
		danger.controller=c
		danger.policy=studio.policy
		danger.source_id=&"studio_damage_capture"
		danger.position=Vector2(390,602)
		danger.half_size=Vector2(60,20)
		danger.amount=2
		studio.add_child(danger)
		c.router.set_move_axis(1)
	if frame==1340: c.router.set_move_axis(0)
	trace.append({"frame":frame,"tick":Engine.get_physics_frames(),"position":[c.motor.position.x,c.motor.position.y],"visual":str((c.motor.get_node("CourierVisual") as CourierVisual).state),"traversal":str(c.traversal.state),"screen":[(root.get_canvas_transform()*c.motor.position).x,(root.get_canvas_transform()*c.motor.position).y],"jump_used":c.jump_ability.used_jumps,"hook_used":c.traversal.hook_used,"shots":c.action_resources.shot_charges,"packet":c.shoot_ability.packet_id,"energy":c.actor_resources.stamina.current,"motion_steps":c.motor.motion_steps})
	if frame in screenshots: capture.call_deferred(frame)
	if frame>=1530:
		physics_frame.disconnect(drive)
		finish.call_deferred()
func capture(number: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/actor_actions/frame-%04d.png" % number)
func finish() -> void:
	var file := FileAccess.open("res://build/actor_actions/trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"normal-speed input-driven practice sections; reset locations are initialization, not continuous route proof","trace":trace,"events":studio._events},"\t"))
	file.close()
	studio.leave()
	studio.queue_free()
	await process_frame
	await process_frame
	print("ACTOR MOVIE: 1530 input-driven ticks recorded")
	quit()
