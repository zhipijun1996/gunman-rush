extends SceneTree
## Read-only diagnostic fixture using unchanged Router/controller/Motor.
## Deliberate wall stalls demonstrate input age, never content reachability.
var player:PlayerMotor
var controller:PlayerController
var shots:Array=[]
var rejections:Array=[]
var cases:Array=[]
func _initialize()->void:run.call_deferred()
func frame()->void:
	await physics_frame
	await process_frame
func run()->void:
	var body:=StaticBody2D.new();body.position=Vector2(0,320)
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=Vector2(2000,40);shape.shape=rectangle;body.add_child(shape);root.add_child(body)
	player=load("res://scenes/player/player.tscn").instantiate();player.position=Vector2(0,282);root.add_child(player);controller=player.get_node("Controller");controller.enable_shot_energy()
	controller.shoot_ability.shot_fired.connect(func(direction:Vector2,id:int):shots.append({"time_usec":Time.get_ticks_usec(),"controller_tick":controller._tick,"direction":[direction.x,direction.y],"shot_id":id}))
	controller.shoot_ability.shot_rejected.connect(func(reason:StringName):rejections.append({"reason":str(reason),"controller_tick":controller._tick}))
	for unused:int in 30:await frame()
	for mode:String in ["physics_boundary_fresh","process_queued_then_140ms_stall","physics_boundary_after_140ms_stall"]:
		for unused:int in 30:await frame()
		var before_shots:=shots.size();var before_rejections:=rejections.size();var before_energy:=controller.actor_resources.stamina.current;var before_tick:=controller._tick
		if mode=="physics_boundary_after_140ms_stall":OS.delay_msec(140)
		if mode!="process_queued_then_140ms_stall":await physics_frame
		var requested:=controller.router.request_action(&"shoot_release",Vector2.UP)
		var queue:Dictionary=controller.router._queue.back().duplicate(true)
		if mode=="process_queued_then_140ms_stall":OS.delay_msec(140);await physics_frame
		var age:=Time.get_ticks_usec()/1000000.0-float(queue.timestamp)
		var consuming_tick:=controller._tick+1
		await process_frame
		cases.append({"mode":mode,"requested":requested,"sequence":queue.sequence,"queued_epoch":queue.epoch,"current_epoch":controller.router.epoch,"age_at_physics_boundary_seconds":age,"max_age_seconds":InputRouter.MAX_AGE_SECONDS,"controller_before":before_tick,"consuming_tick":consuming_tick,"controller_after":controller._tick,"accepted_count":shots.size()-before_shots,"rejected_signal_count":rejections.size()-before_rejections,"energy_before":before_energy,"energy_after":controller.actor_resources.stamina.current})
	var ok:bool=cases[0].accepted_count==1 and cases[1].accepted_count==0 and cases[1].age_at_physics_boundary_seconds>InputRouter.MAX_AGE_SECONDS and cases[1].rejected_signal_count==0 and cases[2].accepted_count==1
	var files:Dictionary={}
	for path:String in ["res://scripts/input/input_router.gd","res://scripts/player/player_controller.gd","res://scripts/player/player_motor.gd","res://build/plains_redesign/render_timing_diagnosis/router_ttl_probe.gd"]:files[path]=FileAccess.get_sha256(path)
	var file:=FileAccess.open("res://build/plains_redesign/render_timing_diagnosis/router_ttl_probe.json",FileAccess.WRITE);file.store_string(JSON.stringify({"scope":"Actual normally scheduled player fixture; deliberate wall stall, not a formal route or performance/fun proof","passed":ok,"cases":cases,"shots":shots,"source_files":files}));file.close()
	print("ROUTER TTL DIAGNOSTIC: ",ok);quit(0 if ok else 1)
