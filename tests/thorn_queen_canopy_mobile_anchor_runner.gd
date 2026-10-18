extends "res://tests/thorn_queen_canopy_runner.gd"
## Explicit new experiment; original full_fight and its four strategies stay intact.
var departure_tick := -1
var cast_tick := -1
var kick_tick := -1
var follow_shot_tick := -1
var target_contact_tick := -1
var arrival_tick := -1
var cast_side := 0.0
var recovered_support_ticks := 0
var experiment := "none"
var candidate_definition: ThornQueenCanopyDefinition

func _initialize() -> void:
	super._initialize()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--experiment="): experiment=arg.trim_prefix("--experiment=")

func queen_definition() -> ThornQueenCanopyDefinition:
	if experiment!="early_crown": return super.queen_definition()
	if candidate_definition==null:
		candidate_definition=super.queen_definition().duplicate(true) as ThornQueenCanopyDefinition
		candidate_definition.canopy_path_a=[Vector2(550,440),Vector2(550,110),Vector2(930,110),Vector2(426,110),Vector2(426,310),Vector2(550,310),Vector2(600,200),Vector2(740,200),Vector2(740,410)]
	return candidate_definition

func make_queen_motor() -> BossMotor:
	var motor := super.make_queen_motor()
	if experiment=="early_crown": (motor.get_node("Encounter") as ThornQueenCanopyEncounter).definition=queen_definition()
	return motor

func persist_partial() -> void:
	super.persist_partial()
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output_dir+"/partial.json"))
	report.experiment=experiment
	report.candidate_config={"scope":"opt-in golden only, not current v10 Manifest or formal save","experiment":experiment,"path_a":geometry.motion_paths[0],"base_resource":"res://resources/bosses/thorn_queen_canopy.tres","base_resource_sha256":FileAccess.get_sha256("res://resources/bosses/thorn_queen_canopy.tres"),"same_definition_instance":queen.definition==candidate_definition if experiment=="early_crown" else true}
	FileAccess.open(output_dir+"/partial.json",FileAccess.WRITE).store_string(JSON.stringify(report))

func fixture(id: String,h_enabled := true,hazard_probe := false,body_probe := false) -> void:
	await super.fixture(id,h_enabled,hazard_probe,body_probe)
	# The Policy sink owns these health commits; Damageable.damaged is not emitted
	# on that path. Pass the exact original context to its original sink once.
	var original_sink: Callable=queen.damageable.damage_sink
	queen.damageable.damage_sink=func(context: Dictionary) -> bool:
		var row := {"event":"mobile_actual_damage_context","case":current,"tick":tick+1,"id":str(context.event_id),"damage_type":str(context.get("damage_type","")),"source_actor_id":context.get("source_actor_id",0),"target_actor_id":context.get("target_actor_id",0),"session_id":context.get("session_id",0),"shot_id":context.get("shot_id",0),"fired_airborne":context.get("fired_airborne",false),"amount":context.amount}
		var accepted: bool=original_sink.call(context)
		row.submission_accepted=accepted
		events.append(row)
		return accepted

func frames(count: int) -> void:
	for i: int in count:
		await super.frames(1)
		if frames_data.is_empty() or not is_instance_valid(queen): continue
		var row: Dictionary=frames_data.back()
		var traversal := controller.traversal
		row.mobile_anchor=queen.mobile_anchor_enabled()
		row.queen_grapple_group=queen.motor.is_in_group(&"grapple_target")
		row.hook_target_id=traversal.hook_target.get_instance_id() if is_instance_valid(traversal.hook_target) else 0
		row.hook_local=[traversal.hook_local.x,traversal.hook_local.y]
		row.hook_kick_side=traversal.kick_side
		row.contact_grace=traversal._contact_remaining
		row.queen_contact_protected=traversal.protects_contact(queen.motor)
		row.band_contact_protected=[]
		for field: ThornQueenWeaveBand in queen.bands:
			if is_instance_valid(field): row.band_contact_protected.append({"id":field.get_instance_id(),"protected":traversal.protects_contact(field)})
		row.queen_velocity=[queen.motor.velocity.x,queen.motor.velocity.y]
		row.player_instance=player.get_instance_id();row.session_id=controller.session_id
		row.player_health_epoch=controller.actor_resources.health.epoch
		row.actual_air_hit_receipts=controller._air_hit_receipts.duplicate()
		row.actual_player_contacts=[]
		for index: int in player.get_slide_collision_count():
			var hit := player.get_slide_collision(index)
			var normal := hit.get_normal()
			row.actual_player_contacts.append({"normal":[normal.x,normal.y],"collider_id":hit.get_collider_id()})

func mark(label: String,extra: Dictionary={}) -> void:
	var row := {"event":label,"case":current,"tick":tick,"player":[player.position.x,player.position.y],"boss":[queen.motor.position.x,queen.motor.position.y],"boss_mode":queen.motion_mode,"boss_id":queen.motor.get_instance_id(),"player_id":player.get_instance_id(),"session_id":controller.session_id}
	row.merge(extra);events.append(row)

func shared_departure() -> bool:
	for i: int in 180:
		if queen.motion_mode=="flight": break
		await frames(1)
	if queen.motion_mode!="flight": return false
	controller.router.set_move_axis(1)
	controller.router.set_jump_held(&"mobile_anchor_golden",true)
	for i: int in 30:
		await frames(1)
		if not player.is_on_floor() and player.position.x-12>500:
			controller.router.set_jump_held(&"mobile_anchor_golden",false)
			departure_tick=tick;mark("mobile_shared_departure")
			return true
	controller.router.set_jump_held(&"mobile_anchor_golden",false)
	return false

func mobile_prefix(follow_shot := true) -> bool:
	for i: int in 30:
		var origin := player.position+Vector2(0,-6)
		var offset := queen.motor.position-origin
		var ray := PhysicsRayQueryParameters2D.create(origin,queen.motor.position,1,[player.get_rid()])
		if queen.motion_mode=="flight" and offset.length()<=controller.traversal.definition.hook_range and player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			cast_tick=tick+1;cast_side=signf(origin.x-queen.motor.position.x)
			mark("mobile_body_H_request",{"request_tick":cast_tick,"origin":[origin.x,origin.y],"aim":[offset.normalized().x,offset.normalized().y],"range":controller.traversal.definition.hook_range})
			if not controller.router.request_action(&"grapple",offset.normalized()): return false
			break
		await frames(1)
	if cast_tick<0: return false
	for i: int in 80:
		await frames(1)
		if controller.traversal.state in [&"hook_miss",&"hook_retract"]: return false
		if controller.traversal.state==&"hook_pull" and controller.traversal.hook_target==queen.motor and target_contact_tick<0:
			target_contact_tick=tick;mark("mobile_body_actual_contact")
		if controller.traversal.state==&"hook_contact_kick" and arrival_tick<0:
			arrival_tick=tick;mark("mobile_body_actual_arrival",{"surface_distance":player.position.distance_to(controller.traversal.hook_tip)})
		if controller.traversal.state==&"hook_kick":
			kick_tick=tick;mark("mobile_body_actual_kick",{"kick_side":controller.traversal.kick_side,"relative_x":player.position.x-queen.motor.position.x})
			break
	if kick_tick<0: return false
	if not follow_shot: return true
	# Shoot at the actual moving body with the existing full LOS/trajectory helper.
	# No fabricated recoil direction or two-shot ceiling is imposed.
	for i: int in 30:
		if fire_visible(false): follow_shot_tick=tick+1;mark("mobile_body_followup_request",{"request_tick":follow_shot_tick});return true
		await frames(1)
	return false

func complete_current_fight(hook_only := false) -> int:
	var stable := 0
	var holding := 0
	var recovery := -1
	var kill_tick := -1
	for i: int in 1800:
		if controller.actor_resources.health.terminal: break
		if queen.health.terminal:
			if kill_tick<0: kill_tick=tick
			if experiment=="early_crown" and hook_only and support_id().is_empty():
				# New candidate-only recovery after the original pureH edge stop:
				# ordinary movement to a wide receiving bank, no gun/teleport.
				var target_x := 850.0 if player.position.x>=650 else 450.0
				controller.router.set_move_axis(0 if absf(target_x-player.position.x)<3 else signf(target_x-player.position.x))
			else: controller.router.set_move_axis(0)
			stable=stable+1 if not support_id().is_empty() else 0
			if stable>=12: break
		else:
			if hook_only and controller.traversal.state==&"free" and (not controller.traversal.hook_used or player.is_on_floor()):
				var origin := player.position+Vector2(0,-6)
				var offset := queen.motor.position-origin
				var ray := PhysicsRayQueryParameters2D.create(origin,queen.motor.position,1,[player.get_rid()])
				if queen.mobile_anchor_enabled() and offset.length()<=controller.traversal.definition.hook_range and player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					controller.router.request_action(&"grapple",offset.normalized());mark("mobile_hook_only_recast_request")
			if recovery<0 and support_id()=="low":
				recovery=0;holding=23;controller.router.set_jump_held(&"mobile_anchor_golden",true)
			if recovery>=0:
				recovery+=1;controller.router.set_move_axis(-1 if player.position.x>475 else 0)
				if not hook_only and recovery==12 and controller.shoot_ability.cooldown_remaining<=0: controller.router.request_action(&"shoot_release",Vector2.DOWN)
				if support_id()=="S" or recovery>=100: recovery=-1
			else:
				var target_x := 850.0 if player.position.y+18<242 or player.position.x>712 else 450.0
				controller.router.set_move_axis(0 if absf(target_x-player.position.x)<3 else signf(target_x-player.position.x))
				if holding==0 and player.is_on_floor() and queen.motor.position.distance_to(player.position)<155 and absf(queen.motor.position.y-player.position.y)<115:
					controller.router.set_jump_held(&"mobile_anchor_golden",true);holding=23
				if not hook_only: fire_visible(false)
		if holding>0:
			holding-=1
			if holding==0: controller.router.set_jump_held(&"mobile_anchor_golden",false)
		await frames(1)
	controller.router.set_jump_held(&"mobile_anchor_golden",false)
	recovered_support_ticks=stable
	check(queen.health.terminal and not controller.actor_resources.health.terminal and stable>=12,"full24HP natural fight ends alive with actual support12")
	return kill_tick

func run() -> void:
	if selected=="mobile_mixed_chase":
		await run_mixed_chase_fixture()
		return
	check(selected in ["mobile_anchor","mobile_ordinary","mobile_hook_only"],"explicit independent mobile-anchor case selected")
	await fixture(selected,true)
	check(controller.traversal.definition.hook_range==231 and controller.traversal.definition.hook_stop_distance==30,"actual unchanged231 range and30 surface stop")
	check(queen.config().canopy_speed==360 and queen.health.current==24 and controller.actor_resources.health.current==5 and controller.actor_resources.stamina.current==100,"same real Boss speed and starting health/energy")
	var departure := await shared_departure()
	check(departure,"shared normal jump fully leaves S lip without moving the player")
	var prefix_ok := departure
	if prefix_ok and selected!="mobile_ordinary": prefix_ok=await mobile_prefix(selected!="mobile_hook_only")
	check(prefix_ok,"selected actual mobile-body prefix completes")
	var kill_tick := -1
	if prefix_ok: kill_tick=await complete_current_fight(selected=="mobile_hook_only")
	var own := frames_data.filter(func(f: Dictionary) -> bool: return f.case==current)
	var hits := events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="boss")
	check(own.all(func(f: Dictionary) -> bool: return Rect2(400,0,560,600).encloses(Rect2(Vector2(f.player[0],f.player[1])-Vector2(12,18),Vector2(24,36)))),"every actual whole body stays within sealed arena")
	check(hits.size()==24,"all24 actual Boss Policy commits preserved")
	check(events.any(func(e: Dictionary) -> bool: return e.get("event")=="canopy_phase_started" and e.get("phase")==2) and events.any(func(e: Dictionary) -> bool: return e.get("event")=="canopy_phase_started" and e.get("phase")==3),"real damage starts both persistent field mechanisms")
	if selected=="mobile_ordinary": check(not events.any(func(e: Dictionary) -> bool: return e.get("event")=="actual_queued_input" and e.get("action")=="grapple"),"ordinary control submits zero H and has no artificial shot-count cap")
	else:
		check(target_contact_tick>cast_tick and arrival_tick>target_contact_tick and kick_tick>arrival_tick and (follow_shot_tick>kick_tick if selected=="mobile_anchor" else follow_shot_tick<0),"actual moving-body H contact then native arrival kick and selected followup")
	if selected=="mobile_hook_only": check(not events.any(func(e: Dictionary) -> bool: return e.get("event")=="accepted_shot" or e.get("event")=="actual_queued_input" and e.get("action")=="shoot_release"),"strong pureH control has no shot input or accepted gun")
	check(own.all(func(f: Dictionary) -> bool: return f.queen_grapple_group==f.mobile_anchor and (not f.queen_grapple_group or f.boss_hp>0 and f.motion_mode!="intro")),"live-anchor group is derived from real active nonintro state")
	check(not queen.motor.is_in_group(&"grapple_target") if queen.health.terminal else true,"dead Queen removes live-anchor group")
	cases.append({"id":current,"initial_player_hp":5,"initial_boss_hp":24,"initial_energy":100,"kill_tick":kill_tick,"ticks":tick,"boss_hp":queen.health.current,"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"support12":recovered_support_ticks,"departure_tick":departure_tick,"cast_tick":cast_tick,"target_contact_tick":target_contact_tick,"arrival_tick":arrival_tick,"kick_tick":kick_tick,"follow_shot_tick":follow_shot_tick})
	persist_partial()
	await cleanup()
	var partial := FileAccess.open(output_dir+"/partial.json",FileAccess.READ)
	var report: Dictionary=JSON.parse_string(partial.get_as_text());report.assertions=assertions;report.failures=failures
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("CANOPY QUEEN GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)

# Explicit final mixed control on the original resource paths, not early_crown.
# Native kick and real projectile hits may each restore air actions; neither is
# invented as a required gate. Decisions read actual relative motion and LOS.
func complete_mixed_chase() -> int:
	var stable := 0
	var holding := 0
	var recovery := -1
	var kill_tick := -1
	var shore_response := false
	var shore_arrived := false
	var shore_support := 0
	var shore_jumped := false
	var shore_r_count := 0
	for i: int in 1800:
		if controller.actor_resources.health.terminal: break
		if queen.health.terminal:
			if kill_tick<0: kill_tick=tick
			var target_x := 850.0 if player.position.x>=650 else 450.0
			controller.router.set_move_axis(0 if not support_id().is_empty() or absf(target_x-player.position.x)<3 else signf(target_x-player.position.x))
			stable=stable+1 if not support_id().is_empty() else 0
			if stable>=12: break
		else:
			if queen.stage_phase>=3 and queen.locked_receiver_id=="S" and not shore_response:
				shore_response=true
				mark("mixed_warning_response",{"locked":queen.locked_receiver_id,"target":"right","field_age":queen.bands[1].age})
			if shore_response and not shore_arrived:
				# Same actual S-to-right warning response available to ordinary_keep.
				controller.router.set_move_axis(0 if absf(850-player.position.x)<3 else signf(850-player.position.x))
				if player.is_on_floor() and support_id()=="S" and not shore_jumped:
					controller.router.set_jump_held(&"mobile_anchor_golden",true);holding=23;shore_jumped=true
				if not player.is_on_floor() and player.position.y+18<=242 and player.position.x<772 and player.recoil_burst_remaining<=0 and controller.shoot_ability.cooldown_remaining<=0 and controller.action_resources.shot_charges>0 and controller.actor_resources.stamina.current>=20 and (shore_r_count==0 or player.position.y+18>=188):
					controller.router.request_action(&"shoot_release",Vector2.LEFT);shore_r_count+=1
					mark("mixed_shore_crossing_R",{"number":shore_r_count})
				shore_support=shore_support+1 if support_id()=="right" else 0
				if shore_support>=12: shore_arrived=true;mark("mixed_new_shore_support12")
				if player.position.x>=772: fire_visible(false)
			else:
				if recovery<0 and support_id()=="low":
					recovery=0;holding=23;controller.router.set_jump_held(&"mobile_anchor_golden",true)
				if recovery>=0:
					recovery+=1;controller.router.set_move_axis(-1 if player.position.x>475 else 0)
					if recovery==12 and controller.shoot_ability.cooldown_remaining<=0: controller.router.request_action(&"shoot_release",Vector2.DOWN)
					if support_id()=="S" or recovery>=100: recovery=-1
				else:
					var target_x := 850.0 if player.position.y+18<242 or player.position.x>712 else 450.0
					controller.router.set_move_axis(0 if absf(target_x-player.position.x)<3 else signf(target_x-player.position.x))
					if holding==0 and player.is_on_floor() and queen.motor.position.distance_to(player.position)<155 and absf(queen.motor.position.y-player.position.y)<115:
						controller.router.set_jump_held(&"mobile_anchor_golden",true);holding=23
					var origin := player.position+Vector2(0,-6)
					var offset := queen.motor.position-origin
					var radial_speed := queen.motor.velocity.dot(offset.normalized())
					var ray := PhysicsRayQueryParameters2D.create(origin,queen.motor.position,1,[player.get_rid()])
					var chase := queen.motion_mode=="flight" and radial_speed>60 and offset.length()>90 and offset.length()<=controller.traversal.definition.hook_range+24 and controller.traversal.state==&"free" and (not controller.traversal.hook_used or player.is_on_floor()) and player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
					if chase:
						var accepted := controller.router.request_action(&"grapple",offset.normalized())
						mark("mixed_chase_decision",{"radial_speed":radial_speed,"distance":offset.length(),"requested":accepted,"hook_used":controller.traversal.hook_used,"queen_velocity":[queen.motor.velocity.x,queen.motor.velocity.y]})
					elif controller.traversal.state in [&"free",&"hook_kick"]:
						if fire_visible(false): mark("mixed_counter_shot_decision",{"radial_speed":radial_speed,"distance":offset.length()})
		if holding>0:
			holding-=1
			if holding==0: controller.router.set_jump_held(&"mobile_anchor_golden",false)
		await frames(1)
	controller.router.set_jump_held(&"mobile_anchor_golden",false)
	recovered_support_ticks=stable
	check(queen.health.terminal and not controller.actor_resources.health.terminal and stable>=12,"full24HP natural fight ends alive with actual support12")
	return kill_tick

func run_mixed_chase_fixture() -> void:
	check(selected=="mobile_mixed_chase","explicit independent mobile-anchor case selected")
	await fixture(selected,true)
	check(controller.traversal.definition.hook_range==231 and controller.traversal.definition.hook_stop_distance==30,"actual unchanged231 range and30 surface stop")
	check(queen.config().canopy_speed==360 and queen.health.current==24 and controller.actor_resources.health.current==5 and controller.actor_resources.stamina.current==100,"same real Boss speed and starting health/energy")
	var departure := await shared_departure()
	check(departure,"shared normal jump fully leaves S lip without moving the player")
	var prefix_ok := departure
	if prefix_ok and selected!="mobile_ordinary": prefix_ok=await mobile_prefix(selected!="mobile_hook_only")
	check(prefix_ok,"selected actual mobile-body prefix completes")
	var kill_tick := -1
	if prefix_ok: kill_tick=await complete_mixed_chase()
	var own := frames_data.filter(func(f: Dictionary) -> bool: return f.case==current)
	var hits := events.filter(func(e: Dictionary) -> bool: return e.get("case")==current and e.get("event")=="policy_result" and e.get("target")=="boss")
	check(own.all(func(f: Dictionary) -> bool: return Rect2(400,0,560,600).encloses(Rect2(Vector2(f.player[0],f.player[1])-Vector2(12,18),Vector2(24,36)))),"every actual whole body stays within sealed arena")
	check(hits.size()==24,"all24 actual Boss Policy commits preserved")
	check(events.any(func(e: Dictionary) -> bool: return e.get("event")=="canopy_phase_started" and e.get("phase")==2) and events.any(func(e: Dictionary) -> bool: return e.get("event")=="canopy_phase_started" and e.get("phase")==3),"real damage starts both persistent field mechanisms")
	if selected=="mobile_ordinary": check(not events.any(func(e: Dictionary) -> bool: return e.get("event")=="actual_queued_input" and e.get("action")=="grapple"),"ordinary control submits zero H and has no artificial shot-count cap")
	else:
		check(target_contact_tick>cast_tick and arrival_tick>target_contact_tick and kick_tick>arrival_tick and (follow_shot_tick>kick_tick if selected=="mobile_mixed_chase" else follow_shot_tick<0),"actual moving-body H contact then native arrival kick and selected followup")
	if selected=="mobile_hook_only": check(not events.any(func(e: Dictionary) -> bool: return e.get("event")=="accepted_shot" or e.get("event")=="actual_queued_input" and e.get("action")=="shoot_release"),"strong pureH control has no shot input or accepted gun")
	check(own.all(func(f: Dictionary) -> bool: return f.queen_grapple_group==f.mobile_anchor and (not f.queen_grapple_group or f.boss_hp>0 and f.motion_mode!="intro")),"live-anchor group is derived from real active nonintro state")
	check(not queen.motor.is_in_group(&"grapple_target") if queen.health.terminal else true,"dead Queen removes live-anchor group")
	cases.append({"id":current,"initial_player_hp":5,"initial_boss_hp":24,"initial_energy":100,"kill_tick":kill_tick,"ticks":tick,"boss_hp":queen.health.current,"player_hp":controller.actor_resources.health.current,"energy":controller.actor_resources.stamina.current,"support12":recovered_support_ticks,"departure_tick":departure_tick,"cast_tick":cast_tick,"target_contact_tick":target_contact_tick,"arrival_tick":arrival_tick,"kick_tick":kick_tick,"follow_shot_tick":follow_shot_tick})
	persist_partial()
	await cleanup()
	var partial := FileAccess.open(output_dir+"/partial.json",FileAccess.READ)
	var report: Dictionary=JSON.parse_string(partial.get_as_text());report.assertions=assertions;report.failures=failures
	FileAccess.open(output_dir+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print("CANOPY QUEEN GOLDEN: %s assertions, %s failures"%[assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
