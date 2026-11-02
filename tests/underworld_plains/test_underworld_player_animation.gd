extends SceneTree
## Input-driven real Motor animation fixture. Only initial spawn is assigned.
## Hurt/death are explicit accepted HealthState lifecycle fixtures, not combat.
var checks:=0
var failures:Array[String]=[]
var rows:Array[Dictionary]=[]
var events:Array[Dictionary]=[]
var world:Node2D
var motor:PlayerMotor
var controller:PlayerController
var art:UnderworldPlayer
var camera:Camera2D
var capture:=false
var seen:Dictionary={}
var right_frames:Dictionary={}
var left_frames:Dictionary={}
var shape_before:Vector2
var initial_tuning:String
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label);printerr("FAIL: ",label)
func ticks(phase:String,count:int)->void:
	for i:int in count:
		await physics_frame
		if capture:await RenderingServer.frame_post_draw
		var receipt:=art.animation_receipt()
		receipt["phase"]=phase;receipt["tick"]=rows.size();receipt["motion_steps"]=motor.motion_steps
		receipt["health"]=controller.actor_resources.health.current
		rows.append(receipt);seen[str(receipt.state)]=true
		if receipt.state=="run" and receipt.facing>0:right_frames[int(receipt.frame_index)]=true
		if receipt.state=="run" and receipt.facing<0:left_frames[int(receipt.frame_index)]=true
		var anchor:=motor.get_node("CourierVisual") as CourierVisual
		check(receipt.muzzle_world==anchor.visible_muzzle_position(),"readonly receipt preserves authoritative muzzle")
		if capture:
			camera.position=motor.position+Vector2(110,-70)
func run()->void:
	capture="--capture" in OS.get_cmdline_user_args()
	world=Node2D.new();root.add_child(world)
	var ground:=StaticBody2D.new();ground.position=Vector2(1000,380)
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(5000,60);shape.shape=box;ground.add_child(shape);world.add_child(ground)
	if capture:
		root.size=Vector2i(1280,720)
		var sky:=ColorRect.new();sky.position=Vector2(-2000,-1000);sky.size=Vector2(6000,3000);sky.color=Color("4a635e");sky.z_index=-10;world.add_child(sky)
		var soil:=ColorRect.new();soil.position=Vector2(-1500,350);soil.size=Vector2(5000,1000);soil.color=Color("182521");soil.z_index=-1;world.add_child(soil)
	motor=preload("res://game/player/player.tscn").instantiate();motor.position=Vector2(500,332);world.add_child(motor)
	controller=motor.get_node("Controller")
	for name:String in ["KeyboardMouseAdapter","PlayerVisualAdapter"]:motor.get_node(name).process_mode=Node.PROCESS_MODE_DISABLED
	motor.get_node("CourierVisual").hide();motor.get_node("PlayerFeedback").hide()
	art=UnderworldPlayer.new();art.motor=motor;art.controller=controller;motor.add_child(art)
	shape_before=(motor.get_node("CollisionShape2D").shape as RectangleShape2D).size
	initial_tuning=FileAccess.get_sha256("res://config/player_tuning.json")
	if capture:
		camera=Camera2D.new();camera.position=motor.position+Vector2(110,-70);world.add_child(camera)
	controller.router.aim_direction=Vector2.ZERO
	await ticks("idle",60)
	check(motor.is_on_floor(),"actual Motor supported on fixture")
	controller.router.set_move_axis(1)
	await ticks("run_right_no_aim",120)
	check(art.facing>0,"accepted D locomotion faces right with zero aim")
	controller.router.set_move_axis(0)
	await ticks("neutral_after_right",40)
	controller.router.set_move_axis(-1)
	await ticks("run_left_no_aim",120)
	check(art.facing<0,"accepted A locomotion faces left with zero aim")
	controller.router.aim_direction=Vector2.RIGHT
	await ticks("run_left_aim_right",30)
	check(art.facing<0,"left body remains left against right weapon aim")
	controller.router.set_move_axis(0)
	await ticks("neutral_left_aim_right",35)
	check(art.facing<0,"stationary body retains actual last move facing")
	var epoch_before:=controller.router.epoch
	controller.router.clear("explicit_animation_pause_fixture")
	var pause_before:=art.animation_receipt()
	var pause_position:=motor.position
	paused=true
	for frame:int in 10:await process_frame
	var pause_after:=art.animation_receipt()
	check(pause_before.state_age==pause_after.state_age and pause_before.frame_index==pause_after.frame_index,"paused actual actor freezes animation timeline")
	check(motor.position==pause_position,"paused actual Motor remains fixed")
	check(controller.router.epoch>epoch_before,"actual cancellation increments input epoch")
	paused=false
	controller.router.aim_direction=Vector2.RIGHT
	var shots:Array=[]
	controller.shoot_ability.shot_fired.connect(func(direction:Vector2,id:int)->void:shots.append({"direction":direction,"id":id,"tick":rows.size()}))
	controller.router.request_action(&"shoot_release",Vector2.RIGHT)
	await ticks("accepted_shot_right_body_left",20)
	check(shots.size()==1,"one real Router accepted shot independent of body facing")
	controller.router.set_jump_held(&"animation_fixture",true)
	await ticks("jump_hold",12)
	controller.router.set_jump_held(&"animation_fixture",false)
	await ticks("jump_fall_land",90)
	for state:String in ["idle","run","rise","fall","land"]:check(seen.has(state),"actual movement presents state "+state)
	check(right_frames.size()==8,"right actual run visits eight distinct authored frame indices")
	check(left_frames.size()==8,"left actual run visits eight mirrored authored frame indices")
	var health:=controller.actor_resources.health
	var applied:=health.apply_damage(ActorResourceRequest.new(&"explicit_animation_hurt",health.epoch,1,health.get_instance_id()))
	check(applied.status==ActorResourceResult.Status.APPLIED,"real accepted nonterminal damage lifecycle fixture")
	await ticks("accepted_health_hurt_fixture",16)
	check(seen.has("hurt"),"actual accepted damage presents generated hurt body")
	var before_stale:=health.current
	var stale:=health.apply_damage(ActorResourceRequest.new(&"stale_animation_hurt_fixture",health.epoch-1,1,health.get_instance_id()))
	check(stale.status!=ActorResourceResult.Status.APPLIED and health.current==before_stale,"stale health epoch cannot trigger new damage/animation")
	var terminal:=health.apply_damage(ActorResourceRequest.new(&"explicit_animation_death",health.epoch,health.current,health.get_instance_id()))
	check(terminal.status==ActorResourceResult.Status.APPLIED,"real accepted terminal damage lifecycle fixture")
	await ticks("accepted_health_death_fixture",40)
	check(seen.has("death") and art.animation_state=="death" and art.frame_index==1,"terminal generated collapse reaches held fallen final pose")
	check((motor.get_node("CollisionShape2D").shape as RectangleShape2D).size==shape_before,"body collision dimensions unchanged")
	check(FileAccess.get_sha256("res://config/player_tuning.json")==initial_tuning,"unique tuning unchanged")
	var build:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UnderworldPlayer.BUILD_PATH))
	var run_hashes:Dictionary={}
	for frame:Dictionary in build.frames:
		if frame.state=="run":run_hashes[frame.pixel_sha256]=true
	check(run_hashes.size()==8,"eight body keyframes contain eight different actual source RGBA patches")
	var result:={"checks":checks,"failures":failures,"frames":rows,"events":shots,"seen_states":seen.keys(),"run_right_frames":right_frames.keys(),"run_left_frames":left_frames.keys(),"capture":capture,"scope":"Actual Router/Motor movement and accepted shot in isolated 1x fixture. Damage/death explicitly submitted to real HealthState for lifecycle presentation. Only initial spawn assigned. No route completion, natural combat, audio/device or user animation approval."}
	DirAccess.make_dir_recursive_absolute("res://build/underworld_player_animation")
	FileAccess.open("res://build/underworld_player_animation/result_capture.json" if capture else "res://build/underworld_player_animation/result_headless.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	world.free()
	for frame:int in 4:await process_frame
	print("UNDERWORLD_PLAYER_ANIMATION checks=",checks," failures=",failures.size()," real_motor_frames=",rows.size()," states=",seen.size())
	quit(0 if failures.is_empty() else 1)
