extends SceneTree
## Shared accepted inputs only; restarts explicitly separate practice demonstrations.
const IDS := ["pulse_gun","triple_machine_gun","recoil_bomb","magnetic_mine","sustained_laser"]
var studio: ActionStudio
var index := -1
var frame := 0
var total := 0
var trace: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("start")
func start() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/action_budget/upward")
	root.size=Vector2i(1280,720);root.add_child(GameAudio.new())
	studio=preload("res://scenes/demo/action_studio.tscn").instantiate();root.add_child(studio)
	studio.set_training_static(true)
	studio.controller.air_focus_ability.enabled=false
	process_frame.connect(drive)
func next() -> void:
	index+=1;frame=0
	if index>=IDS.size():finish.call_deferred();return
	studio.restart(2 if IDS[index].begins_with("hook_") else 4)
	studio.controller.shoot_ability.equip(load("res://resources/weapons/%s.tres" % ("pulse_gun" if IDS[index].begins_with("hook_") else IDS[index])))
	studio.controller.router.activate_device(&"gamepad")
func drive() -> void:
	total+=1;frame+=1
	if index<0:next();return
	if index>=IDS.size():return
	var c := studio.controller
	if IDS[index].begins_with("hook_"):
		var hook_aim := Vector2.UP if IDS[index]=="hook_hit" else Vector2(1,-.5).normalized()
		c.router.set_aim(&"gamepad",hook_aim,frame<20)
		if frame==20:c.router.request_action(&"grapple",hook_aim)
		if frame in [12,26,32,40,50,60,70]:capture.call_deferred("%s-%03d" % [IDS[index],frame])
		trace.append({"frame":total,"demo_frame":frame,"demo":IDS[index],"position":[c.motor.position.x,c.motor.position.y],"velocity":[c.motor.velocity.x,c.motor.velocity.y],"traversal":String(c.traversal.state),"guide":c.traversal.guide_active,"guide_valid":c.traversal.guide_target_valid,"tip":[c.traversal.hook_tip.x,c.traversal.hook_tip.y],"visual":String((c.motor.get_node("CourierVisual") as CourierVisual).state)})
		if frame>=230:next()
		return
	if frame==1:c.router.set_move_axis(1)
	if frame==24:c.router.set_move_axis(0)
	if frame==28:c.router.request_action(&"jump")
	if frame==36:c.router.request_action(&"jump_release")
	var aim := Vector2.DOWN
	if IDS[index]=="fan_shuriken" and frame>=52:aim=Vector2.LEFT
	if IDS[index]=="remote_boomerang" and frame>=70 and frame<95:aim=Vector2.UP
	c.router.set_aim(&"gamepad",aim,frame>=40 and frame<95)
	if frame==40 and IDS[index]!="sustained_laser":c.router.request_action(&"shoot_release",aim)
	if frame==110 and IDS[index]=="remote_boomerang":c.router.request_action(&"weapon_context")
	if frame in [44,50,62,82,112]:capture.call_deferred("%s-%03d" % [IDS[index],frame])
	trace.append({"frame":total,"demo_frame":frame,"weapon":IDS[index],"position":[c.motor.position.x,c.motor.position.y],"velocity":[c.motor.velocity.x,c.motor.velocity.y],"recoil":[c.motor.recoil_velocity.x,c.motor.recoil_velocity.y],"visual":String((c.motor.get_node("CourierVisual") as CourierVisual).state),"phase":String(c.shoot_ability.behavior().phase),"entities":c.shoot_ability.behavior().current_entities().map(func(e: WeaponEntity)->Dictionary:return {"phase":String(e.phase),"position":[e.global_position.x,e.global_position.y]}),"blink_pause":c.motor.weapon_pause_remaining,"apex":c.motor.weapon_apex_remaining,"motion_steps":c.motor.motion_steps,"hp":c.actor_resources.health.current})
	if frame>=230:next()
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/action_budget/upward/%s.png" % name)
func finish() -> void:
	process_frame.disconnect(drive)
	var file := FileAccess.open("res://build/action_budget/upward/movie_trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"five upward primary chains with actual Router/Controller/Motor; explicit practice resets, focus off, no result/energy injection","trace":trace}));file.close()
	print("UPWARD MOVIE: ",total," frames")
	studio.free();await process_frame;quit()
