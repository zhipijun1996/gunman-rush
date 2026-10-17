extends SceneTree
## Real scheduled inputs, full-body danger contact and support-state comparison.
class Driver extends Node:
	var owner_tree
	func _physics_process(_delta: float) -> void: owner_tree.drive()
class Observer extends Node:
	var owner_tree
	func _physics_process(_delta: float) -> void: owner_tree.observe()
var room: Node2D
var player: PlayerMotor
var controller: PlayerController
var variant := "intended"
var layout := "arch"
var output := "res://build/forest_depth/traversal/capture.json"
var phase := "settle"
var age := 0
var tick := 0
var steps_before := 0
var stable := 0
var finished := false
var reached := false
var returned := false
var recovered := false
var airborne_relay := false
var shot_sent := false
var frames: Array = []
var events: Array = []
var requests: Array = []
var danger_contacts: Array = []
var failure := ""
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):variant=arg.trim_prefix("--variant=")
		if arg.begins_with("--layout="):layout=arg.trim_prefix("--layout=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func run() -> void:
	room=load("res://scripts/demo/forest_directional_golden.gd").new()
	room.layout=layout
	room.grant_hook=variant not in ["noH","naivejump","onlyR"]
	root.add_child(room)
	player=room.player;controller=room.controller
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.traversal.action_changed.connect(action_changed)
	controller.shoot_ability.shot_fired.connect(shot_fired)
	controller.jump_ability.jumped.connect(jumped)
	var driver:=Driver.new();driver.owner_tree=self;driver.process_physics_priority=-100;root.add_child(driver)
	var observer:=Observer.new();observer.owner_tree=self;observer.process_physics_priority=200;root.add_child(observer)
	while not finished:await process_frame
	driver.set_physics_process(false);observer.set_physics_process(false)
	controller.router.clear("golden_capture_complete")
	var data: Dictionary={"source_scope":"development_golden_not_formal_region_admission","variant":variant,"manifest":room.manifest,"frames":frames,"events":events,"requests":requests,"danger_contacts":danger_contacts,"reached":reached,"returned":returned,"recovered":recovered,"failure":failure,"manual_motor_step":false,"midroute_injection":false,"engine":Engine.get_version_info().string}
	var expected: bool = reached and returned and danger_contacts.is_empty() if variant=="intended" else not reached and not danger_contacts.is_empty() and recovered
	if layout=="narrow":
		data["layout"]=layout
		data["initial_health"]=room.initial_health
		data["final_health"]=controller.actor_resources.health.current
		data["max_health"]=controller.actor_resources.health.capacity
		data["damage_events"]=room.damage_events.duplicate(true)
		data["policy_returns"]=room.return_events.duplicate(true)
		data["segment_ready"]=room.segment_ready
		data["presentation_version"]="narrow-readable-overlay-v2"
		data["comparison_version"]="clean_miss_natural_recovery_v2"
		if variant=="intended":expected=reached and returned and room.damage_events.is_empty()
		elif variant=="onlyR":expected=not reached and recovered and not room.damage_events.is_empty() and not room.return_events.is_empty() and controller.actor_resources.health.current<room.initial_health
		else:expected=not reached and recovered and room.damage_events.is_empty() and room.return_events.is_empty() and controller.actor_resources.health.current==room.initial_health
	data["passed"]=expected
	var audio_ok: bool=await preload("res://tests/audio_teardown.gd").drain_world(room)
	data["audio_released"]=audio_ok
	driver.free();observer.free();room.free()
	await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	print("FOREST DIRECTIONAL: %s passed=%s reached=%s returned=%s recovered=%s contacts=%s ticks=%s"%[variant,expected,reached,returned,recovered,danger_contacts.size(),tick])
	quit(0 if expected and audio_ok else 1)
func set_phase(next: String) -> void:
	events.append({"kind":"phase","from":phase,"to":next,"tick":tick,"position":[player.position.x,player.position.y]})
	phase=next;age=0;stable=0;shot_sent=false
func action(kind: StringName, direction:=Vector2.ZERO) -> void:
	requests.append({"kind":String(kind),"tick":tick,"direction":[direction.x,direction.y],"queued":controller.router.request_action(kind,direction)})
func hook(id: String) -> void:
	var anchor: Node2D=room.get_node(id)
	action(&"grapple",(anchor.global_position-player.global_position-Vector2(0,-6)).normalized())
func jump() -> void: controller.router.set_jump_held(&"directional_test",true)
func release_jump() -> void: controller.router.set_jump_held(&"directional_test",false)
func on_support(id: String) -> bool:
	var index: int=room.manifest.platforms.map(func(r: Dictionary):return r.id).find(id)
	for i: int in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_normal().dot(Vector2.UP)>.7 and str((player.get_slide_collision(i).get_collider() as Node).name)=="Platform%s"%index:return true
	return false
func drive() -> void:
	if finished:return
	tick+=1;age+=1;steps_before=player.motion_steps
	if layout=="narrow":room.capture_tick=tick
	if tick>1100:failure="bounded_route_timeout/"+phase;finished=true;return
	if layout=="narrow" and not room.return_events.is_empty() and phase!="policy_recover":
		release_jump();controller.router.clear("production_environment_return_observed");set_phase("policy_recover")
	if layout!="narrow" and not danger_contacts.is_empty() and phase not in ["catch","recover_walk","recover_step","recover_entry"]:
		release_jump();controller.router.clear("danger_contact_recovery");set_phase("catch")
	if layout=="narrow" and variant in ["noH","naivejump"] and phase in ["comparison","land_crown"] and on_support("recovery"):
		release_jump();controller.router.clear("clean_miss_grounded_recovery");set_phase("recover_walk")
	match phase:
		"settle":
			if age==12:jump();set_phase("launch")
		"launch":
			if age==6:release_jump()
			if age==7:
				if variant in ["intended","noH"]:hook("side_ring");set_phase("side_wait")
				else:controller.router.set_move_axis(1);set_phase("comparison")
		"side_wait":
			if controller.traversal.state==&"free" and age>20:action(&"shoot_release",Vector2.LEFT);set_phase("recoil_out")
		"recoil_out":
			if player.recoil_burst_remaining<=0 and age>8:
				if layout=="narrow":set_phase("land_crown")
				else:hook("arch_exit_ring");set_phase("arch_wait")
		"arch_wait":
			if controller.traversal.state==&"free" and age>20:
				hook("crown_ring");set_phase("crown_wait")
		"crown_wait":
			if controller.traversal.state==&"free" and age>20:set_phase("land_crown")
		"land_crown":
			controller.router.set_move_axis(clampf(((355 if layout=="narrow" else 550)-player.position.x)/20,-1,1))
			if on_support("crown"):stable+=1
			else:stable=0
			if stable>=12:
				reached=true
				if layout=="narrow":controller.router.set_move_axis(1);set_phase("bank_return")
				else:controller.router.set_move_axis(-1);set_phase("return_drop")
		"bank_return":
			controller.router.set_move_axis(1 if player.position.x<600 else 0)
			if on_support("recovery"):controller.router.set_move_axis(0);set_phase("recover_walk")
		"policy_recover":
			controller.router.set_move_axis(0)
			if on_support("entry"):stable+=1
			else:stable=0
			if stable>=12:recovered=true;returned=reached if layout=="narrow" else returned;finished=true
		"return_drop":
			controller.router.set_move_axis(-1 if player.position.x>390 else 0)
			if player.position.y>-70:controller.router.set_move_axis(0);hook("return_catch_ring");set_phase("return_catch")
		"return_catch":
			if controller.traversal.state==&"free" and age>12:hook("side_ring");set_phase("return_hook")
		"return_hook":
			if controller.traversal.state==&"free" and age>20:action(&"shoot_release",Vector2.RIGHT);set_phase("return_land")
		"return_land":
			controller.router.set_move_axis(-1 if player.position.x>30 else 0)
			if on_support("entry"):stable+=1
			if stable>=12:returned=true;finished=true
		"comparison":
			controller.router.set_move_axis(1)
			if variant=="onlyR" and not shot_sent and age==9:
				action(&"shoot_release",Vector2.LEFT);shot_sent=true
			if variant=="onlyR" and age==25:action(&"shoot_release",Vector2(-.8,.6).normalized())
		"catch":
			controller.router.set_move_axis(0)
			if on_support("recovery"):set_phase("recover_walk")
		"recover_walk":
			controller.router.set_move_axis(clampf((-275-player.position.x)/12,-1,1))
			if absf(player.position.x+275)<4:controller.router.set_move_axis(0);jump();set_phase("recover_step")
		"recover_step":
			if age==12:release_jump()
			if on_support("recovery_step") and age>20:stable+=1
			if stable>=6:jump();set_phase("recover_entry")
		"recover_entry":
			controller.router.set_move_axis(1 if player.position.x < -180 else 0)
			if age==12:release_jump()
			if on_support("entry"):stable+=1
			if stable>=12:recovered=true;returned=reached if layout=="narrow" else returned;finished=true
func observe() -> void:
	if finished:return
	var body:=Rect2(player.position-Vector2(12,18),Vector2(24,36))
	for r: Array in room.manifest.dangers:
		if body.intersects(Rect2(r[0],r[1],r[2],r[3])):
			danger_contacts.append({"tick":tick,"body":[body.position.x,body.position.y,24,36],"danger":r.duplicate(),"position":[player.position.x,player.position.y]})
	frames.append({"tick":tick,"phase":phase,"position":[player.position.x,player.position.y],"velocity":[player.velocity.x,player.velocity.y],"grounded":player.is_on_floor(),"hook_state":String(controller.traversal.state),"hook_used":controller.traversal.hook_used,"shots":controller.action_resources.shot_charges,"energy":controller.actor_resources.stamina.current,"motor_steps":player.motion_steps-steps_before,"crown_support":on_support("crown"),"entry_support":on_support("entry")})
	if layout=="narrow":
		frames[-1]["health"]=controller.actor_resources.health.current
		frames[-1]["actor_epoch"]=room.lifetime.actor_epoch
func action_changed(state: StringName) -> void:
	events.append({"kind":String(state),"tick":tick,"position":[player.position.x,player.position.y],"target":str(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else ""})
func shot_fired(direction: Vector2, serial: int) -> void: events.append({"kind":"shot_fired","tick":tick,"direction":[direction.x,direction.y],"serial":serial})
func jumped() -> void: events.append({"kind":"jumped","tick":tick})
