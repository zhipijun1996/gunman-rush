extends "res://tests/forest_hollow_trunk_runner.gd"
## New input strategy; unchanged base observer, actual Player, Policy and teardown.
var shared_geometry := false
var cavity_geometry := false
var cavity_elbow := false
var cavity_cell := 0
var cavity_shots := 0
var cast_offset := 0
var recoil_offset := 0
var cavity_free_ticks := 0
var standing_hook := false
var launch_offset := 0
func _initialize() -> void:
	shared_geometry="--shared" in OS.get_cmdline_user_args()
	cavity_elbow="--cavity-elbow" in OS.get_cmdline_user_args()
	cavity_geometry="--cavity" in OS.get_cmdline_user_args() or cavity_elbow
	standing_hook="--standing-hook" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cast-offset="):cast_offset=int(arg.trim_prefix("--cast-offset="))
		if arg.begins_with("--recoil-offset="):recoil_offset=int(arg.trim_prefix("--recoil-offset="))
		if arg.begins_with("--launch-offset="):launch_offset=int(arg.trim_prefix("--launch-offset="))
	super._initialize()
func create_room() -> Node2D:
	var candidate=super.create_room()
	candidate.geometry_override=ForestHollowUpperCandidate.build_cavity() if cavity_geometry else (ForestHollowUpperCandidate.build_shared_upper() if shared_geometry else ForestHollowUpperCandidate.build())
	if cavity_elbow:candidate.geometry_override=ForestHollowTrunkGeometry.build_cavity_elbow()
	if cavity_geometry:candidate.geometry_override["input_offsets"]={"cast_ticks":cast_offset,"recoil_ticks":recoil_offset,"standing_hook":standing_hook,"launch_offset":launch_offset}
	return candidate
func action(kind: StringName,direction: Vector2) -> void:
	super.action(kind,direction)
	if cavity_elbow:
		requests[-1]["body_before"]=xy(player.position)
		requests[-1]["velocity_before"]=xy(player.velocity)
		requests[-1]["grounded_before"]=player.is_on_floor()
		requests[-1]["hook_origin_before"]=xy(player.position+Vector2(0,-6))
		requests[-1]["cell"]=cavity_cell
func observe() -> void:
	super.observe()
	if not cavity_elbow or frames.is_empty() or int(frames[-1].tick)!=tick:return
	var contacts: Array=[]
	for index: int in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider: Object=hit.get_collider()
		contacts.append({"collider":String((collider as Node).name) if collider is Node else collider.get_class(),"normal":xy(hit.get_normal()),"point":xy(hit.get_position()),"travel":xy(hit.get_travel()),"remainder":xy(hit.get_remainder())})
	frames[-1]["motor_contacts"]=contacts
	frames[-1]["normal_velocity"]=xy(player.normal_velocity)
	frames[-1]["recoil_remaining"]=player.recoil_burst_remaining
	frames[-1]["apex_remaining"]=player.weapon_apex_remaining
	frames[-1]["cell"]=cavity_cell
func drive() -> void:
	if finished:return
	if cavity_geometry:
		drive_cavity()
		return
	tick+=1;age+=1;steps_before=player.motion_steps;room.tick=tick
	if tick>1600 or age>300:
		failure="bounded_upper_route/"+phase;finished=true;return
	if player.position.y>(490 if shared_geometry else 270) or player.position.x < -340 or player.position.x>810:
		failure="left_upper_candidate_bounds/"+phase;finished=true;return
	match phase:
		"settle":
			move_to(108)
			if absf(player.position.x-108)<2 and support("belly_entry"):stable+=1
			else:stable=0
			if stable>=12:
				controller.router.set_move_axis(0);jump(true);enter("upper_launch")
		"upper_launch":
			if variant=="noH_bay":controller.router.set_move_axis(1)
			if age==6 and variant!="noH_bay":jump(false)
			if age==7:
				if variant=="H0R":hook("upper_window_ring");enter("upper_pull")
				elif variant=="wrongH":action(&"grapple",Vector2.UP);enter("upper_cross")
				else:
					if variant in ["noH_oneR","noH_twoR"]:action(&"shoot_release",Vector2.LEFT)
					enter("upper_cross")
		"upper_pull":
			controller.router.set_move_axis(0)
			if controller.traversal.state==&"free" and age>20:enter("upper_cross")
		"upper_cross":
			move_to(380)
			if variant=="noH_bay" and age==20:jump(false)
			if variant=="noH_twoR" and age==16 and not support("outer_crown"):action(&"shoot_release",Vector2.LEFT)
			if support("outer_crown"):stable+=1
			else:stable=0
			if stable>=12:
				reached=true;return_start_tick=tick;enter("shared_depart" if shared_geometry else "crown_return")
			elif shared_geometry and support("trunk_between_windows"):
				jump(false);recovered=true;enter("shared_bay_align")
			elif shared_geometry and support("outer_root"):
				jump(false);recovered=true;enter("shared_outer_align")
			elif shared_geometry and support("trunk_below_window"):
				jump(false);recovered=true;enter("shared_base_align")
			elif shared_geometry and support("outer_recovery_step"):
				jump(false);recovered=true;enter("shared_step_align")
			elif shared_geometry and support("outer_sump"):
				jump(false);recovered=true;enter("shared_sump_align")
			elif support("inner_root"):
				jump(false);recovered=true;enter("shared_inner_align" if shared_geometry else "lower_loop_align")
		"shared_bay_align":
			if variant=="noH_bay":
				# Strong legal alternative: re-jump from the first actual landing,
				# not an artificial stop/walk-to-centre imposed to favour H.
				controller.router.set_move_axis(1)
				if support("trunk_between_windows"):jump(true);enter("shared_bay_crown")
			else:
				move_to(270)
				if absf(player.position.x-270)<2 and support("trunk_between_windows"):stable+=1
				else:stable=0
				if stable>=12 and controller.traversal.state==&"free":jump(true);enter("shared_bay_crown")
		"shared_bay_crown":
			move_to(380)
			if player.position.y+18< -26 and player.position.x-12>=300:jump(false)
			if support("outer_crown"):stable+=1
			else:stable=0
			if stable>=12:reached=true;return_start_tick=tick;enter("shared_depart")
		"shared_inner_align":
			move_to(160)
			if absf(player.position.x-160)<2 and support("inner_root"):jump(true);enter("shared_inner_bay")
		"shared_inner_bay":
			move_to(270)
			if player.position.y+18<98 and player.position.x-12>=210:jump(false)
			if support("trunk_between_windows"):stable+=1
			else:stable=0
			if stable>=12:enter("shared_bay_align")
		"shared_sump_align":
			move_to(370)
			if absf(player.position.x-370)<2 and support("outer_sump"):jump(true);enter("shared_sump_base")
		"shared_sump_base":
			move_to(300)
			if player.position.y+18<418 and player.position.x+12<=330:jump(false)
			if support("trunk_below_window"):stable+=1
			else:stable=0
			if stable>=12:enter("shared_base_align")
		"shared_base_align":
			move_to(300)
			if absf(player.position.x-300)<2 and support("trunk_below_window"):stable+=1
			else:stable=0
			if stable>=12:controller.router.set_move_axis(0);jump(true);enter("shared_base_step")
		"shared_base_step":
			move_to(300)
			if player.position.y+18<348:jump(false)
			if support("outer_recovery_step"):stable+=1
			else:stable=0
			if stable>=12:enter("shared_step_align")
		"shared_step_align":
			move_to(300)
			if absf(player.position.x-300)<2 and support("outer_recovery_step"):stable+=1
			else:stable=0
			if stable>=12:controller.router.set_move_axis(0);jump(true);enter("shared_step_root")
		"shared_step_root":
			move_to(380)
			if player.position.y+18<298 and player.position.x-12>=350:jump(false)
			if support("outer_root"):stable+=1
			else:stable=0
			if stable>=12:enter("shared_outer_align")
		"shared_outer_align":
			move_to(670)
			if absf(player.position.x-670)<2 and support("outer_root"):jump(true);enter("shared_outer_base")
		"shared_outer_base":
			if player.position.y+18<216:jump(false)
			if support("outer_loop_base"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("lower_loop_first")
		"shared_depart":
			move_to(343)
			if absf(player.position.x-343)<.15 and absf(player.velocity.x)<1 and support("outer_crown"):stable+=1
			else:stable=0
			if stable>=12:
				controller.router.set_move_axis(0);action(&"drop_through",Vector2.ZERO);enter("shared_descent")
		"shared_descent":
			controller.router.set_move_axis(0)
			if player.position.y>=158:
				if variant.begins_with("noH"):action(&"shoot_release",Vector2.RIGHT);enter("shared_inner_land")
				else:hook("lower_window_ring");enter("shared_hook_wait")
		"shared_hook_wait":
			controller.router.set_move_axis(0)
			if controller.traversal.state==&"free" and age>20:enter("shared_inner_land")
		"shared_inner_land":
			move_to(120)
			if support("inner_root"):stable+=1
			else:stable=0
			if stable>=12:lower_entered=true;enter("return_floor")
			elif support("outer_root") or support("outer_sump") or support("trunk_below_window"):
				failure="shared_lower_seam_missed_D";finished=true
		"lower_loop_align":
			move_to(720)
			if absf(player.position.x-720)<2 and support("inner_root"):
				controller.router.set_move_axis(0);jump(true);enter("lower_loop_first")
		"lower_loop_first":
			if player.position.y+18<116:jump(false)
			if support("outer_low_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("lower_loop_second")
		"lower_loop_second":
			if player.position.y+18<16:jump(false)
			if support("outer_high_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("lower_loop_crown")
		"lower_loop_crown":
			move_to(550)
			if player.position.y+18< -26 and player.position.x+12<=600:jump(false)
			if support("outer_crown"):stable+=1
			else:stable=0
			if stable>=12:reached=true;return_start_tick=tick;enter("shared_depart" if shared_geometry else "crown_return")
		"crown_return":
			move_to(380)
			if absf(player.position.x-380)<2 and support("outer_crown"):
				action(&"drop_through",Vector2.ZERO);enter("return_floor")
		"return_floor":
			move_to(-275)
			if absf(player.position.x+275)<2 and support("inner_root"):
				controller.router.set_move_axis(0);jump(true);enter("return_left_step")
		"return_left_step":
			if player.position.y+18<116:jump(false)
			if support("inner_recovery_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("return_entry")
		"return_entry":
			move_to(-180)
			if player.position.y+18<16:jump(false)
			if support("belly_entry"):stable+=1
			else:stable=0
			if stable>=12:returned=true;finished=true

func drive_cavity() -> void:
	tick+=1;age+=1;steps_before=player.motion_steps;room.tick=tick
	if tick>1600 or age>300:failure="bounded_cavity/"+phase;finished=true;return
	if player.position.y>490 or player.position.x < -510 or player.position.x>710:failure="cavity_visible_bounds/"+phase;finished=true;return
	if not room.return_events.is_empty() and phase not in ["cavity_recover","cavity_recover_stable"]:
		jump(false);controller.router.set_move_axis(0);recovered=true;enter("cavity_recover")
	match phase:
		"settle":
			move_to(-245+launch_offset)
			if absf(player.position.x-(-245+launch_offset))<.15 and absf(player.velocity.x)<1 and support("cavity_observe"):stable+=1
			else:stable=0
			if stable>=12:
				if variant=="noH_cavity_outer":enter("cavity_outer_align")
				elif standing_hook:
					controller.router.set_move_axis(0);hook("cavity_ring_a");cavity_free_ticks=0;enter("cavity_pull")
				else:jump(true);enter("cavity_launch")
		"cavity_launch":
			if age==6:jump(false)
			if age==7+cast_offset:
				jump(false)
				if variant in ["cavity_HR","cavity_wrongR","elbow_HR","elbow_H0R"]:hook("cavity_ring_a" if cavity_cell==0 else "cavity_ring_b");cavity_free_ticks=0;enter("cavity_pull")
				else:action(&"shoot_release",Vector2.LEFT);cavity_shots=1;enter("cavity_cross")
		"cavity_pull":
			controller.router.set_move_axis(0)
			if cavity_elbow and cavity_cell==1 and controller.traversal.state in [&"hook_miss",&"hook_retract"]:
				failure="elbow_second_hook_did_not_complete/"+String(controller.traversal.state);finished=true;return
			if controller.traversal.state==&"free" and age>20:cavity_free_ticks+=1
			else:cavity_free_ticks=0
			if cavity_free_ticks>recoil_offset:
				if cavity_elbow and cavity_cell==1:
					events.append({"kind":"elbow_kick_release","tick":tick,"position":xy(player.position),"velocity":xy(player.velocity),"hook_start":xy(controller.traversal.hook_start),"hook_tip":xy(controller.traversal.hook_tip),"apex_remaining":player.weapon_apex_remaining})
				if not (cavity_elbow and cavity_cell==1 and variant=="elbow_H0R"):
					action(&"shoot_release",Vector2.DOWN if variant=="cavity_wrongR" else Vector2.LEFT)
				enter("cavity_cross")
		"cavity_cross":
			move_to(110 if cavity_cell==0 else 430)
			if (variant=="noH_cavity_twoR" or (variant=="noH_elbow_oneR" and cavity_cell==0)) and cavity_shots==1 and age==16:
				action(&"shoot_release",Vector2.LEFT);cavity_shots=2
			var id: String="cavity_bay" if cavity_cell==0 else "cavity_exit"
			if support(id):stable+=1
			else:stable=0
			if stable>=12:
				if cavity_cell==0:
					cavity_cell=1;controller.router.set_move_axis(0)
					if cavity_elbow:enter("elbow_walkoff")
					elif standing_hook:hook("cavity_ring_b");cavity_free_ticks=0;enter("cavity_pull")
					else:jump(true);enter("cavity_launch")
				else:reached=true;return_start_tick=tick;enter("elbow_return_align" if cavity_elbow else "cavity_return_align")
		"elbow_walkoff":
			var bay := ForestDirectionalGeometry.rect(room.manifest.platforms.filter(func(row: Dictionary) -> bool: return row.id=="cavity_bay")[0].rect)
			var half := (player.get_node("CollisionShape2D") as CollisionShape2D).shape.get_rect().size*.5
			controller.router.set_move_axis(1)
			if not player.is_on_floor() and player.position.x-half.x>=bay.end.x:
				controller.router.set_move_axis(0)
				events.append({"kind":"elbow_airborne_departure","tick":tick,"position":xy(player.position),"grounded":player.is_on_floor(),"bay_rect":[bay.position.x,bay.position.y,bay.size.x,bay.size.y]})
				if variant=="noH_elbow_oneR":
					action(&"shoot_release",Vector2.LEFT);enter("cavity_cross")
				else:hook("cavity_ring_b");cavity_free_ticks=0;enter("cavity_pull")
		"elbow_return_align":
			var relay := ForestDirectionalGeometry.rect(room.manifest.platforms.filter(func(row: Dictionary) -> bool: return row.id=="elbow_return_relay")[0].rect)
			var launch_x := relay.get_center().x
			move_to(launch_x)
			if absf(player.position.x-launch_x)<2 and support("cavity_exit"):jump(true);enter("elbow_return_relay")
		"elbow_return_relay":
			var relay := ForestDirectionalGeometry.rect(room.manifest.platforms.filter(func(row: Dictionary) -> bool: return row.id=="elbow_return_relay")[0].rect)
			move_to(relay.get_center().x)
			if player.position.y+18<relay.position.y-2:jump(false)
			if support("elbow_return_relay"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_return_step")
		"cavity_outer_align":
			move_to(-335)
			if absf(player.position.x+335)<2 and support("cavity_observe"):jump(true);enter("cavity_outer_step")
		"cavity_outer_step":
			move_to(-410)
			if player.position.y+18 < -402 and player.position.x+12<=-350:jump(false)
			if support("cavity_left_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_outer_upper")
		"cavity_outer_upper":
			move_to(-285)
			if player.position.y+18 < -492 and player.position.x-12>=-360:jump(false)
			if support("cavity_left_upper"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_outer_roof")
		"cavity_outer_roof":
			move_to(-190)
			if player.position.y+18 < -522 and player.position.x-12>=-220:jump(false)
			if support("belly_roof_upper"):stable+=1
			else:stable=0
			if stable>=12:enter("cavity_outer_walk")
		"cavity_outer_walk":
			move_to(400)
			if absf(player.position.x-400)<2 and support("cavity_roof_step"):
				action(&"drop_through",Vector2.ZERO);enter("cavity_outer_drop")
		"cavity_outer_drop":
			move_to(430)
			if support("cavity_exit"):stable+=1
			else:stable=0
			if stable>=12:reached=true;return_start_tick=tick;enter("elbow_return_align" if cavity_elbow else "cavity_return_align")
		"cavity_return_align":
			move_to(570)
			if absf(player.position.x-570)<2 and support("cavity_exit"):jump(true);enter("cavity_return_step")
		"cavity_return_step":
			move_to(650)
			if player.position.y+18 < -402 and player.position.x-12>=610:jump(false)
			if support("cavity_right_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_return_upper")
		"cavity_return_upper":
			move_to(515)
			if player.position.y+18 < -492 and player.position.x+12<=570:jump(false)
			if support("cavity_right_upper"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_return_roof_step")
		"cavity_return_roof_step":
			move_to(400)
			if player.position.y+18 < -502 and player.position.x+12<=450:jump(false)
			if support("cavity_roof_step"):stable+=1
			else:stable=0
			if stable>=12:jump(true);enter("cavity_return_roof")
		"cavity_return_roof":
			move_to(300)
			if player.position.y+18 < -522 and player.position.x+12<=330:jump(false)
			if support("trunk_upper_cap"):stable+=1
			else:stable=0
			if stable>=12:enter("cavity_return_walk")
		"cavity_return_walk":
			move_to(-285)
			if support("cavity_observe"):stable+=1
			else:stable=0
			if stable>=12:controller.router.set_move_axis(0);returned=true;finished=true

			elif absf(player.position.x+285)<2 and (support("cavity_left_upper") or support("cavity_left_step")):
				action(&"drop_through",Vector2.ZERO);enter("cavity_drop_to_S")
		"cavity_drop_to_S":
			move_to(-285)
			if support("cavity_observe"):stable+=1
			else:stable=0
			if stable>=12:controller.router.set_move_axis(0);returned=true;finished=true
		"cavity_recover":
			controller.router.set_move_axis(0)
			if support("cavity_observe"):stable+=1
			else:stable=0
			if stable>=12:returned=true;finished=true
