extends SceneTree
## Real input and bodies. No mid-route position/resource/state writes.
class Driver extends Node:
	var host
	func _physics_process(_delta: float) -> void: host.drive()
class Observer extends Node:
	var host
	func _physics_process(_delta: float) -> void: host.observe()
var aircatch_geometry := false
var room: Node2D
var player: PlayerMotor
var controller: PlayerController
var variant := "deepH_zeroR"
var output := "res://build/forest_depth/hollow_trunk/native/capture.json"
var phase := "settle"
var age := 0
var tick := 0
var stable := 0
var steps_before := 0
var finished := false
var reached := false
var returned := false
var recovered := false
var retried := false
var lower_entered := false
var failure := ""
var frames: Array = []
var events: Array = []
var requests: Array = []
var initial_hp := 0.0
var air_shot_sent := false
var return_start_tick := -1
var direct_recovered := false
func _initialize() -> void:
	aircatch_geometry="--aircatch" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--variant="):variant=arg.trim_prefix("--variant=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	run.call_deferred()
func create_room() -> Node2D:
	var candidate=load("res://scripts/demo/forest_hollow_trunk_golden.gd").new()
	if aircatch_geometry:candidate.geometry_override=ForestHollowTrunkGeometry.build_aircatch()
	return candidate
func run() -> void:
	room=create_room()
	room.grant_hook=not variant.begins_with("noH")
	room.return_style="shallow_recoil" if variant=="airH_recoil" else "deep_zeroR"
	root.add_child(room)
	player=room.player;controller=room.controller
	initial_hp=controller.actor_resources.health.current
	player.get_node("KeyboardMouseAdapter").set_process_unhandled_input(false)
	controller.traversal.action_changed.connect(func(state: StringName) -> void: events.append({"kind":String(state),"tick":tick,"position":xy(player.position),"target":String(controller.traversal.hook_target.name) if is_instance_valid(controller.traversal.hook_target) else ""}))
	controller.shoot_ability.shot_fired.connect(func(direction: Vector2, serial: int) -> void: events.append({"kind":"shot_fired","tick":tick,"direction":xy(direction),"serial":serial}))
	controller.jump_ability.jumped.connect(func() -> void: events.append({"kind":"jumped","tick":tick}))
	var driver := Driver.new();driver.host=self;driver.process_physics_priority=-100;root.add_child(driver)
	var observer := Observer.new();observer.host=self;observer.process_physics_priority=2000;root.add_child(observer)
	while not finished:await process_frame
	driver.set_physics_process(false);observer.set_physics_process(false)
	controller.router.clear("hollow_capture_complete")
	var data := {"variant":variant,"scope":"new unverified hollow-trunk golden; NOT formal region","manifest":room.manifest,"frames":frames,"events":events,"requests":requests,"reached":reached,"returned":returned,"recovered":recovered,"retried":retried,"lower_entered":lower_entered,"failure":failure,"initial_hp":initial_hp,"final_hp":controller.actor_resources.health.current,"damage_events":room.damage_events,"policy_returns":room.return_events,"return_start_tick":return_start_tick,"direct_recovered":direct_recovered,"manual_motor_step":false,"midroute_injection":false,"engine":Engine.get_version_info()}
	if aircatch_geometry:data["aircatch_geometry"]=true
	data["audio_released"]=await preload("res://tests/audio_teardown.gd").drain_world(room)
	driver.free();observer.free();room.free()
	await process_frame;await process_frame
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("FOREST HOLLOW: %s terminal failure=%s reached=%s returned=%s recovered=%s ticks=%s" % [variant,failure,reached,returned,recovered,tick])
	quit(0 if failure.is_empty() and data.audio_released else 1)
func xy(v: Vector2) -> Array: return [v.x,v.y]
func enter(next: String) -> void:
	events.append({"kind":"phase","tick":tick,"position":xy(player.position),"from":phase,"to":next})
	phase=next;age=0;stable=0
func jump(value: bool) -> void: controller.router.set_jump_held(&"hollow_golden",value)
func move_to(x: float) -> void: controller.router.set_move_axis(clampf((x-player.position.x)/12.0,-1,1))
func action(kind: StringName, direction: Vector2) -> void:
	requests.append({"kind":String(kind),"tick":tick,"direction":xy(direction),"queued":controller.router.request_action(kind,direction)})
	if aircatch_geometry:
		requests[-1]["body_before"]=xy(player.position)
		requests[-1]["velocity_before"]=xy(player.velocity)
		requests[-1]["grounded_before"]=player.is_on_floor()
func hook(id: String) -> void: action(&"grapple",(room.get_node(id).global_position-player.position-Vector2(0,-6)).normalized())
func raw_contact(id: String) -> bool:
	var index: int=room.manifest.platforms.map(func(row: Dictionary): return row.id).find(id)
	for i: int in player.get_slide_collision_count():
		var hit := player.get_slide_collision(i)
		if hit.get_normal().y < -.7 and String((hit.get_collider() as Node).name)=="Platform%s" % index:return true
	return false
func support(id: String) -> bool:
	# move_and_slide records contacts encountered DURING its displacement. A
	# departing corner contact is not a full-body stable support at the END.
	if not player.is_on_floor() or not raw_contact(id): return false
	var rows: Array=room.manifest.platforms.filter(func(row: Dictionary) -> bool: return row.id==id)
	var rect := ForestDirectionalGeometry.rect(rows[0].rect)
	return absf(player.position.y+18-rect.position.y)<1 and player.position.x-12>=rect.position.x and player.position.x+12<=rect.end.x
func drive() -> void:
	if finished:return
	tick+=1;age+=1;steps_before=player.motion_steps;room.tick=tick
	if tick>1800 or age>360:
		failure="bounded_route_timeout/"+phase;finished=true;return
	if player.position.y>490 or player.position.x < -340 or player.position.x>760:
		failure="left_candidate_visible_bounds/"+phase;finished=true;return
	if phase in ["noH_cross","noH_lower"] and support("outer_sump"):
		jump(false);controller.router.set_move_axis(0);recovered=true;enter("sump_to_base")
	match phase:
		"settle":
			if age==12:jump(true);enter("launch")
		"launch":
			if age==6:jump(false)
			if age==7:
				if variant.begins_with("noH"):controller.router.set_move_axis(1);enter("noH_cross")
				elif variant=="miss_retry" and not retried:action(&"grapple",Vector2.UP);controller.router.set_move_axis(1);enter("intentional_miss")
				else:hook("upper_window_ring");enter("upper_hook")
		"upper_hook":
			if controller.traversal.state==&"free" and age>20:action(&"shoot_release",Vector2.LEFT);enter("upper_cross")
		"upper_cross", "noH_cross":
			move_to(380)
			if phase=="noH_cross":
				if age==9:action(&"shoot_release",Vector2.LEFT)
				if variant=="noH_twoR" and age==25:action(&"shoot_release",Vector2(-.8,.6).normalized())
			if support("outer_crown"):stable+=1
			else:stable=0
			if stable>=12:
				reached=true
				if variant in ["airH_recoil","deepH_zeroR","return_R","return_none"]:return_start_tick=tick;enter("air_depart")
				else:enter("outer_drop")
			elif support("inner_root") and age>45:
				if variant.begins_with("noH"):enter("inner_walk")
				else:failure="upper_window_missed_to_inner_root";finished=true
		"intentional_miss":
			move_to(120)
			if support("inner_root"):
				controller.router.set_move_axis(0);recovered=true;enter("inner_walk")
		"air_depart":
			move_to(343)
			if absf(player.position.x-343)<2 and support("outer_crown") and age>8:
				controller.router.set_move_axis(0);action(&"drop_through",Vector2.ZERO);enter("air_descent")
		"air_descent":
			# Same physical crown and departure for all controls. Shoot-only gets
			# its earliest legal body-fit crossing, not the deep H's later cast.
			if variant=="return_none" and player.position.y>=135:move_to(280)
			if player.position.y>=158:
				if variant=="return_R":
					action(&"shoot_release",Vector2.RIGHT);air_shot_sent=true;enter("air_land_inner")
				elif variant in ["airH_recoil","deepH_zeroR"]:hook("lower_window_ring");enter("air_hook_wait")
				else:
					move_to(280)
					if player.position.x<=312:
						if variant=="deepH_zeroR":hook("lower_window_ring");enter("air_hook_wait")
						else:enter("direct_fall")
		"air_hook_wait":
			controller.router.set_move_axis(0)
			if controller.traversal.state==&"free" and age>20:
				if variant=="airH_recoil":action(&"shoot_release",Vector2.RIGHT);air_shot_sent=true
				enter("air_land_inner")
		"air_land_inner":
			move_to(120)
			if support("inner_root"):stable+=1
			else:stable=0
			if stable>=(12 if aircatch_geometry else 8):lower_entered=true;enter("inner_walk")
			elif support("trunk_below_window") or support("outer_sump") or support("outer_root") or support("outer_recovery_step"):
				failure="air_return_missed_inner_reception";finished=true
		"direct_fall":
			move_to(310)
			if support("inner_root"):lower_entered=true;enter("inner_walk")
			elif support("trunk_below_window"):
				direct_recovered=true;recovered=true;controller.router.set_move_axis(0);jump(true);enter("base_step_jump")
			elif support("outer_sump"):direct_recovered=true;recovered=true;enter("sump_to_base")
			elif support("outer_recovery_step"):
				direct_recovered=true;recovered=true;controller.router.set_move_axis(0);jump(true);enter("step_outer_jump")
		"outer_drop":
			move_to(620)
			if support("outer_root"):controller.router.set_move_axis(0);enter("outer_observe")
		"outer_observe":
			move_to(370)
			if absf(player.position.x-370)<4 and support("outer_root") and age>12:
				controller.router.set_move_axis(0)
				if variant.begins_with("noH"):jump(true);enter("noH_lower")
				else:jump(true);enter("lower_launch")
		"lower_launch":
			if age==6:jump(false)
			if age==7:hook("lower_window_ring");enter("lower_hook")
		"lower_hook":
			if controller.traversal.state==&"free" and age>20:action(&"shoot_release",Vector2.RIGHT);enter("lower_cross")
		"lower_cross", "noH_lower":
			move_to(120)
			if phase=="noH_lower":
				if age==10:jump(false);action(&"shoot_release",Vector2.RIGHT)
				if variant=="noH_twoR" and age==26:action(&"shoot_release",Vector2(.8,.6).normalized())
			if support("inner_root"):stable+=1
			else:stable=0
			if stable>=8:lower_entered=true;enter("inner_walk")
			elif support("trunk_below_window") and age>60:
				failure="lower_window_miss_landed_local_base";finished=true
		"sump_to_base":
			move_to(370)
			if absf(player.position.x-370)<4 and support("outer_sump"):jump(true);enter("sump_base_jump")
		"sump_base_jump":
			move_to(300)
			if player.position.y+18<418:jump(false)
			if support("trunk_below_window") and age>10:stable+=1
			if stable>=6:controller.router.set_move_axis(0);jump(true);enter("base_step_jump")
		"base_step_jump":
			move_to(300)
			if player.position.y+18<348:jump(false)
			if support("outer_recovery_step") and age>10:stable+=1
			if stable>=6:jump(true);enter("step_outer_jump")
		"step_outer_jump":
			move_to(380)
			if player.position.y+18<298:jump(false)
			if support("outer_root") and age>10:stable+=1
			if stable>=6:
				controller.router.set_move_axis(0)
				if variant=="return_none" and direct_recovered:finished=true
				else:enter("outer_observe")
		"inner_walk":
			move_to(-275)
			if absf(player.position.x+275)<4 and support("inner_root"):
				controller.router.set_move_axis(0);jump(true);enter("inner_step")
		"inner_step":
			if player.position.y+18<116:jump(false)
			if support("inner_recovery_step") and age>10:stable+=1
			if stable>=6:jump(true);enter("back_to_belly")
		"back_to_belly":
			move_to(-180)
			if player.position.y+18<16:jump(false)
			if support("belly_entry"):stable+=1
			else:stable=0
			if stable>=12:
				if variant=="miss_retry" and not retried:
					retried=true;move_to(0);enter("retry_align")
				else:returned=true;finished=true
		"retry_align":
			move_to(0)
			if absf(player.position.x)<4 and support("belly_entry"):
				controller.router.set_move_axis(0);jump(true);enter("launch")
func observe() -> void:
	if finished:return
	var supports: Array = []
	var contacts: Array = []
	for row: Dictionary in room.manifest.platforms:
		if support(row.id):supports.append(row.id)
		if raw_contact(row.id):contacts.append(row.id)
	var probe_contacts: Array = []
	var traversal := controller.traversal
	var probe: ShapeCast2D=traversal._hook_probe
	if is_instance_valid(probe):
		for index: int in probe.get_collision_count():
			var collider: Object=probe.get_collider(index)
			probe_contacts.append({"collider":String((collider as Node).name) if collider is Node else collider.get_class(),"point":xy(probe.get_collision_point(index)),"source":xy(probe.global_position),"finish":xy(probe.to_global(probe.target_position))})
	var visibility: Dictionary = {}
	var inverse := room.get_viewport().get_canvas_transform().affine_inverse()
	var first := inverse*Vector2.ZERO
	var last := inverse*room.get_viewport().get_visible_rect().size
	var view := Rect2(first,last-first)
	for row: Dictionary in room.manifest.hook_anchors:
		var source := player.position+Vector2(0,-6)
		var query := PhysicsRayQueryParameters2D.create(source,ForestDirectionalGeometry.point(row.position),1,[player.get_rid()])
		visibility[row.id]={"on_screen":view.has_point(ForestDirectionalGeometry.point(row.position)),"terrain_clear":player.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"distance":source.distance_to(ForestDirectionalGeometry.point(row.position))}
	frames.append({"tick":tick,"phase":phase,"position":xy(player.position),"velocity":xy(player.velocity),"grounded":player.is_on_floor(),"supports":supports,"raw_floor_contacts":contacts,"hook_start":xy(traversal.hook_start),"hook_tip":xy(traversal.hook_tip),"probe_contacts":probe_contacts,"body":[player.position.x-12,player.position.y-18,24,36],"drop_remaining":player._drop_remaining,"hook_enabled":controller.traversal.hook_enabled,"hook_state":String(controller.traversal.state),"hook_used":controller.traversal.hook_used,"shots":controller.action_resources.shot_charges,"energy":controller.actor_resources.stamina.current,"health":controller.actor_resources.health.current,"motor_steps":player.motion_steps-steps_before,"visible_targets":visibility,"actual_camera_view":[view.position.x,view.position.y,view.size.x,view.size.y],"body_on_screen":view.encloses(Rect2(player.position-Vector2(12,18),Vector2(24,36)))})
	if aircatch_geometry:
		var collisions: Array=[]
		for index: int in player.get_slide_collision_count():
			var hit := player.get_slide_collision(index)
			var body: Object=hit.get_collider()
			collisions.append({"collider":String((body as Node).name) if body is Node else body.get_class(),"normal":xy(hit.get_normal()),"point":xy(hit.get_position())})
		frames[-1]["motor_contacts"]=collisions
		frames[-1]["normal_velocity"]=xy(player.normal_velocity)
		frames[-1]["recoil_remaining"]=player.recoil_burst_remaining
