extends SceneTree
## Structural/input contract only. A pass is not real Motor or art admission.
const LIBRARY := preload("res://scripts/generation/forest_exploration_modules.gd")
const PLAYER := preload("res://game/player/player.tscn")
var assertions := 0
var failures := 0
var results: Array[Dictionary] = []
var body_size := Vector2.ZERO

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	assertions += 1
	results.append({"label":label,"passed":ok})
	if not ok:
		failures += 1
		printerr("FOREST EXPLORATION MODULE FAIL: "+label)

func _run() -> void:
	# Derive the body from the real player scene; do not quietly test a point
	# or a second hand-maintained collision size instead of the player.
	var state := PLAYER.get_state()
	for index: int in state.get_node_count():
		if state.get_node_name(index) != &"CollisionShape2D": continue
		for property: int in state.get_node_property_count(index):
			if state.get_node_property_name(index,property) == &"shape":
				var shape := state.get_node_property_value(index,property) as RectangleShape2D
				if shape != null: body_size = shape.size
	_check(body_size.x > 0.0 and body_size.y > 0.0,"static clearance uses the actual player collision shape")
	var catalogue := LIBRARY.catalogue()
	var original_ids := ["root_meadow","mushroom_fork","low_root_tunnel","root_basin_return","side_fruit_crossing","double_fruit_s","double_window","canopy_detour","thorn_side_passage","backbranch_turn","crown_hook_relay","deep_root_switchback"]
	_check(catalogue.size() >= 12 and catalogue.slice(0,12).map(func(row: Dictionary) -> String: return str(row.id)) == original_ids,"finite twelve-piece original catalogue remains an exact prefix")
	var active_ids: Array = catalogue.map(func(row: Dictionary) -> String: return str(row.id))
	_check("backlook_fruit_cache" in active_ids and "borrow_pod_crossing" in active_ids and "thorn_l_root_turn" in active_ids,"new backlook, living-pod and L-root families are concrete catalogue candidates")
	_check("sheltered_short_hops" not in active_ids and LIBRARY.build("sheltered_short_hops").is_empty(),"user-discarded low-ceiling family remains absent from catalogue and factory")
	_check(LIBRARY.build("unknown_forest_piece").is_empty(),"unknown input is refused rather than aliased to another piece")
	var counts := {"easy":0,"normal":0,"hard":0}
	var ids: Dictionary = {}
	var physical_shapes: Dictionary = {}
	var highest_easy_reward := 0
	var highest_normal_reward := 0
	var lowest_hard_reward := 100000
	for entry: Dictionary in catalogue:
		var id := str(entry.id)
		_check(not ids.has(id),"unique catalogue id / "+id)
		ids[id] = true
		var piece := LIBRARY.build(id)
		_check(not piece.is_empty(),"actual factory / "+id)
		if piece.is_empty(): continue
		if id in original_ids: counts[str(piece.difficulty)] += 1
		_check(piece.requires == ["grapple"],"S2-H only, no stronger movement grant / "+id)
		_check(piece.admission.motor == "unverified" and piece.admission.production_pool == false,"no fabricated native admission / "+id)
		var supports: Dictionary = {}
		var bounds := _rect(piece.world_bounds)
		var all_in_bounds := true
		for row: Dictionary in piece.platforms:
			_check(not supports.has(row.id),"support id is unique / "+id+"/"+str(row.id))
			var rect := _rect(row.rect)
			all_in_bounds = all_in_bounds and rect.has_area() and bounds.encloses(rect)
			supports[str(row.id)] = row
		_check(all_in_bounds,"complete collision geometry stays within its declared deployment footprint / "+id)
		_check(_standing_on(piece.spawn,str(piece.entry_support_id),supports),"entry port has its actual receiving support / "+id)
		_check(_standing_on(piece.goal,str(piece.exit_support_id),supports),"exit port has its actual receiving support / "+id)
		_check(_standing_on(piece.reward_position,str(piece.reward_support_id),supports),"reward is placed on a real support / "+id)
		_check(_body_clear(piece.spawn,supports) and _body_clear(piece.goal,supports) and _body_clear(piece.reward_position,supports),"real body fits at spawn, final receiver and reward / "+id)
		var anchor_ids: Dictionary = {}
		for anchor: Dictionary in piece.hook_anchors:
			_check(not anchor_ids.has(anchor.id),"fruit id is unique / "+id+"/"+str(anchor.id))
			anchor_ids[str(anchor.id)] = true
			var host: Dictionary = supports.get(str(anchor.host_support_id),{})
			_check(not host.is_empty() and _on_rect(_point(anchor.stem_root),_rect(host.get("rect",[0,0,0,0]))),"fruit root touches its named real host, not a nearest label / "+id+"/"+str(anchor.id))
		var step_diagnostics: Array = []
		var valid_steps := _steps(piece.steps,supports,step_diagnostics,"steps")
		for route_name: String in piece.routes:
			var valid_route := _steps(piece.routes[route_name],supports,step_diagnostics,route_name)
			valid_steps = valid_steps and valid_route
		_check(valid_steps,"ordinary movement records reference actual takeoff and receiving supports / "+id)
		results[-1].diagnostics = step_diagnostics
		if not valid_steps: printerr("FOREST EXPLORATION STEP DETAILS / "+id+": "+JSON.stringify(step_diagnostics))
		var catch_id := "catch" if supports.has("catch") else "basin" if supports.has("basin") else "recovery"
		_check(_catch_corridor_clear(catch_id,supports),"complete body can walk across its catch basin without a buried wall / "+id)
		var valid_program := true
		for action: Dictionary in piece.action_program:
			if action.action == "H": valid_program = valid_program and anchor_ids.has(str(action.get("anchor","")))
			elif action.action == "R": valid_program = valid_program and action.get("direction",[]).size() == 2 and _point(action.direction).length_squared() > 0.0
			else: valid_program = false
		_check(valid_program,"intended action program references actual fruits and finite recoil directions / "+id)
		if piece.has("choice_contract"):
			var choice: Dictionary = piece.choice_contract
			var routes_bound: bool = piece.routes.has(choice.main_route) and piece.routes.has(choice.reward_route) and piece.routes.has(choice.return_route)
			_check(routes_bound,"new branch choice binds real executable route records / "+id)
			var reward_steps: Array = piece.routes.get(choice.reward_route,[])
			var return_steps: Array = piece.routes.get(choice.return_route,[])
			_check(not reward_steps.is_empty() and reward_steps[-1].support_id == piece.reward_support_id and reward_steps[-1].landing == piece.reward_position and not return_steps.is_empty() and return_steps[-1].support_id == piece.entry_support_id and return_steps[-1].landing == piece.spawn,"reward route arrives at its actual cache and return arrives at original departure / "+id)
			var main_touches_cache := false
			for step: Dictionary in piece.steps: main_touches_cache = main_touches_cache or step.get("support_id") == piece.reward_support_id
			_check(not main_touches_cache,"ordinary progress does not automatically visit the optional high reward / "+id)
		_check(_hazards(piece,supports),"every danger contacts the named real host in the stated direction / "+id)
		# A geometry identity check prevents aliases; it does not score diversity,
		# enjoyment or claim that a change in hash makes a new player experience.
		var shape := JSON.stringify([piece.platforms,piece.hook_anchors,piece.dangers])
		_check(not physical_shapes.has(shape),"not a second id for identical physical contents / "+id)
		physical_shapes[shape] = true
		if piece.difficulty == "easy":
			highest_easy_reward = maxi(highest_easy_reward,int(piece.risk_reward.coins))
			_check(piece.dangers.is_empty() and piece.action_program.is_empty(),"easy main route has no mandatory damage or airborne H/R chain / "+id)
			_check(_gentle_main(piece,supports),"easy main route: rises <=64wu, gaps <=110wu, landing width >=96wu / "+id)
			_check(not piece.routes.get("recovery",[]).is_empty(),"easy route has a represented way to recover/retry / "+id)
		elif piece.difficulty == "normal":
			highest_normal_reward = maxi(highest_normal_reward,int(piece.risk_reward.coins))
			_check(piece.main_route_kind == "ordinary_sequence" and not piece.steps.is_empty(),"normal piece retains ordinary movement alternative / "+id)
			_check(not piece.action_program.is_empty(),"normal piece has an explicit optional H direction choice / "+id)
		else:
			lowest_hard_reward = mini(lowest_hard_reward,int(piece.risk_reward.coins))
			_check(piece.risk_reward.optional == true and piece.main_route_kind == "air_chain","hard piece is an optional challenge, never mislabeled as an easy jump sequence / "+id)
			_check(not piece.routes.get("recovery",[]).is_empty(),"hard piece includes lower recovery / "+id)
			_check(piece.action_program.size() >= 2,"hard piece describes a genuine combination rather than a difficulty label alone / "+id)
	for tier: String in counts:
		_check(counts[tier] == 4,"four concrete pieces at "+tier+" difficulty")
	_check(highest_easy_reward < highest_normal_reward and highest_normal_reward < lowest_hard_reward,"optional hard rewards exceed ordinary exploration resources")
	# Independent failure probes target real deployment invariants.
	var danger_piece := LIBRARY.build("thorn_side_passage")
	var support_map := _support_map(danger_piece)
	var bad := danger_piece.duplicate(true)
	bad.danger_surfaces[0].host_support_id = "entry"
	_check(not _hazards(bad,support_map),"reject hazard merely relabeled to a remote solid")
	bad = danger_piece.duplicate(true)
	bad.dangers[1][1] -= 40.0
	_check(not _hazards(bad,support_map),"reject floating thorn strip off its actual platform")
	bad = danger_piece.duplicate(true)
	bad.danger_surfaces[1].face = "down"
	_check(not _hazards(bad,support_map),"reject wrong danger face")
	var easy := LIBRARY.build("root_meadow")
	var easy_supports := _support_map(easy)
	bad = easy.duplicate(true)
	bad.platforms[1].rect[1] = -128.0
	_check(not _gentle_main(bad,_support_map(bad)),"reject easy label on a steep ascent")
	bad = easy.duplicate(true)
	bad.steps[1].support_id = "missing_receiver"
	_check(not _steps(bad.steps,easy_supports),"reject a route targeting a nonexistent landing")
	bad = LIBRARY.build("double_window")
	for row: Dictionary in bad.platforms:
		if row.id == "catch": row.rect[1] = 144.0
	_check(not _catch_corridor_clear("catch",_support_map(bad)),"reject original y144 catch intersecting the actual lower solid trunk")
	bad = easy.duplicate(true)
	for row: Dictionary in bad.platforms:
		if row.id == "catch_step_high": row.rect[0] = 16.0
	_check(_standing_on([80.0,30.0],"catch_step_high",_support_map(bad)) and not _body_clear([80.0,30.0],_support_map(bad)),"reject recovery step whose standing body is inside the solid entry underside")
	bad = LIBRARY.build("double_window")
	for row: Dictionary in bad.platforms:
		if row.id == "trunk_upper": row.rect[1] = -144.0
	_check(_standing_on([576.0,-82.0],"upper_window_floor",_support_map(bad)) and not _body_clear([576.0,-82.0],_support_map(bad)),"reject an apparent upper window that only a point fits through")
	bad = LIBRARY.build("mushroom_fork")
	bad.routes.lower_bypass[1].landing = [840.0,30.0]
	bad.routes.lower_bypass[2].takeoff = [840.0,30.0]
	_check(not _steps(bad.routes.lower_bypass,_support_map(bad)),"reject old mushroom low route whose centre fits but right body edge enters the solid exit")
	var mushroom := LIBRARY.build("mushroom_fork")
	var mushroom_supports := _support_map(mushroom)
	_check(mushroom.routes.lower_bypass[2].support_id == "exit" and _standing_on([872.0,-18.0],"exit",mushroom_supports) and _body_clear([872.0,-18.0],mushroom_supports),"mushroom lower branch receives its full body on the same real solid exit as the main route")
	var mushroom_receivers_clear := true
	for route_name: String in ["main","lower_bypass"]:
		for step: Dictionary in mushroom.routes[route_name]:
			if step.support_id == "exit": mushroom_receivers_clear = mushroom_receivers_clear and _receiving_support_unambiguous(step.landing,"exit",mushroom_supports)
	_check(mushroom_receivers_clear,"mushroom exit landing records have one real receiving surface, without a same-height one-way collider taking its identity")
	bad = mushroom.duplicate(true)
	var old_mushroom_receiver := {"id":"lower_receiver","rect":[816.0,0.0,144.0,20.0],"one_way":true}
	bad.platforms.append(old_mushroom_receiver)
	_check(_steps(bad.steps,_support_map(bad)) and not _receiving_support_unambiguous([880.0,-18.0],"exit",_support_map(bad)) and not _receiving_support_unambiguous([872.0,-18.0],"exit",_support_map(bad)),"reject original overlapping mushroom receiver even though point/body endpoints fit: actual one-way can intercept both routes' solid exit")
	results[-1].rejected_support = old_mushroom_receiver
	bad = LIBRARY.build("root_basin_return")
	for step: Dictionary in bad.steps:
		if step.get("from_support_id") == "low_exit" and step.support_id == "exit": step.takeoff = [680.0,30.0]
	_check(not _steps(bad.steps,_support_map(bad)),"reject old basin takeoff whose right body edge enters the upper solid shore")
	var basin := LIBRARY.build("root_basin_return")
	var basin_supports := _support_map(basin)
	_check(basin.steps[0].support_id == "return_mushroom" and basin.steps[1].from_support_id == "return_mushroom" and basin.steps[1].support_id == "basin" and _steps(basin.steps,basin_supports),"basin descent records the real intermediate mushroom and full-body supported landing before continuing lower")
	_check(_drop_path_clear(basin.steps[0],basin_supports) and _drop_path_clear(basin.steps[1],basin_supports),"both gentle basin descents have clear full-body swept corridors and no earlier receiving surface")
	_check(_steps(basin.routes.returning,basin_supports) and _steps(basin.routes.recovery,basin_supports),"split basin descent preserves actual full-body return and recovery supports")
	var old_basin_drop := {"kind":"drop_through","from_support_id":"entry","support_id":"basin","takeoff":[208.0,-18.0],"landing":[272.0,78.0],"path":[[208.0,-18.0],[272.0,-18.0],[272.0,78.0]]}
	_check(not _drop_path_clear(old_basin_drop,basin_supports),"reject original direct272 basin drop: real return mushroom intercepts the falling body before its claimed basin landing")
	results[-1].rejected_step = old_basin_drop
	bad = LIBRARY.build("double_window")
	bad.routes.lower_bypass[3].takeoff = [928.0,46.0]
	_check(not _steps(bad.routes.lower_bypass,_support_map(bad)),"reject old lower-window takeoff inside the exit wall")
	var backlook := LIBRARY.build("backlook_fruit_cache")
	var backlook_supports := _support_map(backlook)
	var envelope := MovementCapabilityEnvelope.snapshot(PlayerTuning.load_default())
	var cache_rect := _rect(backlook_supports.cache_perch.rect)
	var entry_rect := _rect(backlook_supports.entry.rect)
	var receiver_rect := _rect(backlook_supports.upper_receiver.rect)
	_check(not envelope.is_empty() and entry_rect.position.y-cache_rect.position.y > float(envelope.get("held_jump_height",INF)),"backlook entry-to-cache exceeds actual full-held ordinary first-jump height; no H requirement inferred")
	_check(not envelope.is_empty() and receiver_rect.position.y-cache_rect.position.y <= float(envelope.get("held_jump_height",-INF)),"backlook receiver screens into the first-jump height envelope; actual trajectory remains unverified")
	_check(entry_rect.position.y-(-128.0) <= float(envelope.get("held_jump_height",-INF)),"retain old128wu cache counterexample: ordinary held first jump can reach its height")
	bad = backlook.duplicate(true)
	for row: Dictionary in bad.platforms:
		if row.id == "catch": row.rect[1] = 144.0
	_check(not _catch_corridor_clear("catch",_support_map(bad)),"reject old backlook y144 catch whose body overlaps the lower-root underside by4wu")
	var pod := LIBRARY.build("borrow_pod_crossing")
	_check(_pod_exchange_contract(pod),"living-pod choice binds a real clear orbit, both shores and independently hosted fixed alternative")
	var pod_supports := _support_map(pod)
	var pod_contract: Dictionary = pod.interaction_contract
	var pod_ports: Dictionary = pod_contract.route_ports
	var live_routes_fit := true
	for route_name: String in pod_ports:
		live_routes_fit = live_routes_fit and _route_ports_fit(pod,route_name,pod_ports[route_name])
	_check(live_routes_fit,"live and fixed approaches stop at their real observation shores; only the separate return starts at reward")
	var highest_main_surface := INF
	var main_touches_reward := false
	for step: Dictionary in pod.steps:
		highest_main_surface = minf(highest_main_surface,_rect(pod_supports[str(step.support_id)].rect).position.y)
		main_touches_reward = main_touches_reward or step.support_id == pod.reward_support_id
	_check(not main_touches_reward and highest_main_surface-_rect(pod_supports[pod.reward_support_id].rect).position.y > float(envelope.get("held_jump_height",INF)),"pod reward is outside the direct ordinary first-jump height from all main-route shores; recoil alternatives remain legal")
	bad = pod.duplicate(true)
	bad.ecology_slots.clear()
	_check(_steps(bad.steps,_support_map(bad)) and _catch_corridor_clear("catch",_support_map(bad)),"removing the living pod leaves the ordinary root route and catch body corridor intact; not a Motor death proof")
	bad = pod.duplicate(true)
	bad.ecology_slots[0].tether_host_support_id = "entry"
	_check(not _pod_exchange_contract(bad),"reject a pod tether merely relabeled to a distant root")
	bad = pod.duplicate(true)
	bad.ecology_slots[0].tether_origin = [640.0,-336.0]
	_check(not _pod_exchange_contract(bad),"reject a pod tether on the half-open host underside instead of inside its real body")
	bad = pod.duplicate(true)
	bad.hook_anchors.clear()
	_check(not _pod_exchange_contract(bad),"reject a living choice whose claimed death alternative has no actual fixed fruit")
	bad = pod.duplicate(true)
	for row: Dictionary in bad.platforms:
		if row.id == "pod_host": row.rect = [528.0,-240.0,224.0,64.0]
	bad.ecology_slots[0].tether_origin = [640.0,-208.0]
	_check(not _pod_exchange_contract(bad),"reject an attached pod whose real moving body sweeps through the host")
	bad = pod.duplicate(true)
	bad.interaction_contract.route_ports.pod_approach.goal_support = pod.reward_support_id
	bad.interaction_contract.route_ports.pod_approach.goal = pod.reward_position.duplicate()
	_check(not _route_ports_fit(bad,"pod_approach",bad.interaction_contract.route_ports.pod_approach),"reject ordinary approach falsely claiming the unplayed live transfer already landed on the high reward")
	var elbow := LIBRARY.build("thorn_l_root_turn")
	var elbow_supports := _support_map(elbow)
	_check(_standing_on(elbow.goal,str(elbow.exit_support_id),elbow_supports) and elbow.goal[1] != elbow.spawn[1],"delegated L-root keeps its actual lower exit body port instead of flattening it to the entry height")
	_check(_steps(elbow.steps,elbow_supports) and _hazards(elbow,elbow_supports),"aggregated L-root ordinary movement keeps full-body receiving supports and physically attached dangers")
	var elbow_faces_fit := true
	for surface: Dictionary in elbow.danger_surfaces:
		var danger := _rect(elbow.dangers[int(surface.danger_index)])
		elbow_faces_fit = elbow_faces_fit and is_equal_approx(danger.size.y,24.0 if surface.face == "up" else 16.0)
	_check(elbow_faces_fit and not elbow.dangers.is_empty(),"L-root uses the existing up24/down16 danger faces on its real root hosts")
	var output := "res://build/region_bible_v2/forest-exploration-modules/report.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"scope":"finite module structural, full-body static corridor and risk/reward contract; airborne trajectories/Motor/visual/player/device unverified","body_shape_source":"res://game/player/player.tscn#CollisionShape2D","body_size":[body_size.x,body_size.y],"assertions":assertions,"failures":failures,"checks":results},"  "))
	file.close()
	print("FOREST EXPLORATION MODULES: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)

func _support_map(piece: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in piece.platforms: result[str(row.id)] = row
	return result

func _route_ports_fit(piece: Dictionary, route_name: String, ports: Dictionary) -> bool:
	var route: Array = piece.routes.get(route_name,[])
	var supports := _support_map(piece)
	if route.is_empty() or not _steps(route,supports): return false
	if not _standing_on(ports.get("start",[]),str(ports.get("start_support","")),supports): return false
	if not _body_clear(ports.start,supports): return false
	var first: Dictionary = route[0]
	if first.get("from_support_id",first.support_id) != ports.start_support: return false
	var last: Dictionary = route[-1]
	return last.support_id == ports.get("goal_support") and last.landing == ports.get("goal")

func _pod_exchange_contract(piece: Dictionary) -> bool:
	var definition := load("res://resources/enemies/forest_swing_pod.tres") as ForestEnemyDefinition
	if definition == null or not definition.is_valid(): return false
	var slots: Array = piece.get("ecology_slots",[])
	var contract: Dictionary = piece.get("interaction_contract",{})
	if slots.size() != 1 or contract.get("contact_mode") != "existing_auto_contact_away_kick": return false
	var slot: Dictionary = slots[0]
	if slot.get("behavior_id") != str(definition.behavior_id) or slot.get("id") != contract.get("enemy_slot"): return false
	var supports := _support_map(piece)
	var host: Dictionary = supports.get(str(slot.get("tether_host_support_id","")),{})
	if host.is_empty() or bool(host.one_way) or not _rect(host.rect).has_point(_point(slot.get("tether_origin",[]))): return false
	var radius := float(slot.get("patrol_radius",-1.0))
	var home := _point(slot.get("position",[]))
	if not home.is_finite() or not is_finite(radius) or radius <= 0.0 or radius > definition.patrol_half_width: return false
	var orbit := Rect2(home-Vector2(radius,definition.swing_rise)-definition.collision_size*0.5,Vector2(radius*2.0,definition.swing_rise)+definition.collision_size)
	if not _rect(piece.world_bounds).encloses(orbit): return false
	for row: Dictionary in piece.platforms:
		if not bool(row.one_way) and orbit.intersects(_rect(row.rect)): return false
	var shores: Array = slot.get("shore_support_ids",[])
	if shores.size() != 2: return false
	for key: String in ["observation","reward"]:
		var port: Dictionary = contract.get(key,{})
		var support := str(port.get("support_id",""))
		if support not in shores or not _standing_on(port.get("position",[]),support,supports) or not _body_clear(port.get("position",[]),supports): return false
	var alternatives: Array = slot.get("fixed_alternative_anchor_ids",[])
	if alternatives.is_empty(): return false
	for id: String in alternatives:
		var found := false
		for anchor: Dictionary in piece.hook_anchors:
			if anchor.id != id: continue
			var fruit_host: Dictionary = supports.get(str(anchor.host_support_id),{})
			found = not fruit_host.is_empty() and _on_rect(_point(anchor.stem_root),_rect(fruit_host.rect)) and bool(anchor.get("hang_enabled",false))
		if not found: return false
	return true

func _standing_on(at: Array, id: String, supports: Dictionary) -> bool:
	if not supports.has(id): return false
	var rect := _rect(supports[id].rect)
	var foot := _point(at)+Vector2(0.0,body_size.y*0.5)
	return is_equal_approx(foot.y,rect.position.y) and foot.x-body_size.x*0.5 >= rect.position.x and foot.x+body_size.x*0.5 <= rect.end.x

func _receiving_support_unambiguous(at: Array, id: String, supports: Dictionary) -> bool:
	if not _standing_on(at,id,supports): return false
	var foot := _point(at)+Vector2(0.0,body_size.y*0.5)
	for row: Dictionary in supports.values():
		if str(row.id) == id: continue
		var rect := _rect(row.rect)
		if is_equal_approx(foot.y,rect.position.y) and foot.x+body_size.x*0.5 > rect.position.x and foot.x-body_size.x*0.5 < rect.end.x: return false
	return true

func _steps(steps: Array, supports: Dictionary, diagnostics: Array = [], route_name := "") -> bool:
	for step: Dictionary in steps:
		var reason := ""
		if step.get("kind") not in ["walk","jump_gap","jump_rise","drop_through"]: reason = "unsupported_kind"
		elif not _standing_on(step.get("landing",[]),str(step.get("support_id","")),supports): reason = "landing_not_on_named_support"
		elif not _body_clear(step.get("landing",[]),supports): reason = "landing_body_inside_solid"
		elif step.has("from_support_id") and not _standing_on(step.get("takeoff",[]),str(step.from_support_id),supports): reason = "takeoff_not_on_named_support"
		elif step.has("takeoff") and not _body_clear(step.takeoff,supports): reason = "takeoff_body_inside_solid"
		if not reason.is_empty():
			diagnostics.append({"route":route_name,"reason":reason,"step":step.duplicate(true),
				"landing_body_blockers":_body_blockers(step.get("landing",[]),supports),
				"takeoff_body_blockers":_body_blockers(step.get("takeoff",[]),supports)})
			return false
	return true

func _drop_path_clear(step: Dictionary, supports: Dictionary) -> bool:
	if step.get("kind") != "drop_through" or not _steps([step],supports): return false
	var path: Array = step.get("path",[])
	if path.size() < 2 or path[0] != step.takeoff or path[-1] != step.landing: return false
	for index: int in range(1,path.size()):
		var before := _point(path[index-1])
		var after := _point(path[index])
		# Authored ordinary drop paths have horizontal departure then vertical
		# fall. This is a static corridor/first-surface test, not a Motor replay.
		if not is_equal_approx(before.x,after.x) and not is_equal_approx(before.y,after.y): return false
		var sweep := Rect2(before.min(after)-body_size*0.5,(after-before).abs()+body_size).grow(-0.001)
		for row: Dictionary in supports.values():
			var rect := _rect(row.rect)
			if not bool(row.one_way):
				if sweep.intersects(rect): return false
			elif after.y > before.y and str(row.id) != str(step.from_support_id):
				var before_foot := before.y+body_size.y*0.5
				var after_foot := after.y+body_size.y*0.5
				var overlaps_width := after.x+body_size.x*0.5 > rect.position.x and after.x-body_size.x*0.5 < rect.end.x
				if overlaps_width and rect.position.y > before_foot+0.001 and rect.position.y < after_foot-0.001: return false
	return true

func _body_clear(at: Array, supports: Dictionary) -> bool:
	if at.size() != 2 or body_size.x <= 0.0 or body_size.y <= 0.0: return false
	return _body_blockers(at,supports).is_empty()

func _body_blockers(at: Array, supports: Dictionary) -> Array[String]:
	var blockers: Array[String] = []
	if at.size() != 2: return blockers
	var body := Rect2(_point(at)-body_size*0.5,body_size).grow(-0.001)
	for row: Dictionary in supports.values():
		if not bool(row.one_way) and body.intersects(_rect(row.rect)): blockers.append(str(row.id))
	return blockers

func _catch_corridor_clear(id: String, supports: Dictionary) -> bool:
	if not supports.has(id) or body_size.x <= 0.0 or body_size.y <= 0.0: return false
	var floor_rect := _rect(supports[id].rect)
	# Exact swept AABB of a horizontal walk on this continuous catch floor.
	# This deliberately makes no assertion about airborne jump trajectories.
	var corridor := Rect2(Vector2(floor_rect.position.x,floor_rect.position.y-body_size.y),Vector2(floor_rect.size.x,body_size.y)).grow(-0.001)
	for row: Dictionary in supports.values():
		if not bool(row.one_way) and corridor.intersects(_rect(row.rect)): return false
	return true

func _gentle_main(piece: Dictionary, supports: Dictionary) -> bool:
	for step: Dictionary in piece.steps:
		if step.get("kind") not in ["jump_gap","jump_rise"]: continue
		if not supports.has(str(step.get("from_support_id",""))) or not supports.has(str(step.get("support_id",""))): return false
		var before := _rect(supports[str(step.from_support_id)].rect)
		var after := _rect(supports[str(step.support_id)].rect)
		var gap := maxf(0.0,maxf(after.position.x-before.end.x,before.position.x-after.end.x))
		if before.position.y-after.position.y > 64.0 or gap > 110.0 or after.size.x < 96.0: return false
	return true

func _hazards(piece: Dictionary, supports: Dictionary) -> bool:
	if piece.dangers.size() != piece.danger_surfaces.size(): return false
	for surface: Dictionary in piece.danger_surfaces:
		if not supports.has(str(surface.host_support_id)): return false
		var host: Dictionary = supports[str(surface.host_support_id)]
		if bool(host.one_way): return false
		var rect := _rect(host.rect)
		var danger := _rect(piece.dangers[int(surface.danger_index)])
		if danger.position.x < rect.position.x or danger.end.x > rect.end.x: return false
		if surface.face == "up":
			if not is_equal_approx(danger.end.y,rect.position.y): return false
		elif surface.face == "down":
			if not is_equal_approx(danger.position.y,rect.end.y): return false
		else: return false
	return true

func _on_rect(point: Vector2, rect: Rect2) -> bool:
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y

func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1])) if pair.size() == 2 else Vector2(INF,INF)

func _rect(row: Array) -> Rect2:
	return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))
