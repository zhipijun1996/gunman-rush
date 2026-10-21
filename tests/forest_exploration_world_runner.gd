extends SceneTree
## Deterministic world/consumer contracts only. This never signs Motor traversal.
const GENERATOR := preload("res://scripts/generation/thorn_forest_region_v2_v16.gd")
const WORLD := preload("res://scripts/generation/forest_exploration_world.gd")
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool,label: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var bridge := {"platforms":[{"id":"left_bank","rect":[0.0,0.0,112.0,40.0],"one_way":false},{"id":"right_bank","rect":[208.0,0.0,256.0,48.0],"one_way":false}]}
	WORLD._receiving_bough(bridge,"gap_root",Vector2(160.0,-18.0))
	check(rect(bridge.platforms[-1].rect) == Rect2(112.0,0.0,96.0,16.0),"native11 connector counterexample: new one-way fills the 96wu gap without overlapping either solid bank")
	var seam := {"platforms":[{"id":"observation","rect":[4956.0,1100.0,336.0,48.0],"one_way":false},{"id":"exit","rect":[5292.0,1100.0,160.0,48.0],"one_way":false}]}
	check(WORLD._solid_floor_point(seam,Vector2(5288.0,1082.0)) == Vector2(5280.0,1082.0),"native13 solid-seam counterexample: shift generated waypoint eight wu onto a complete real bank, never overlay both banks with a one-way")
	var descent := {"platforms":[{"id":"upper","rect":[0.0,0.0,128.0,16.0],"one_way":true},{"id":"actual_middle","rect":[0.0,64.0,128.0,16.0],"one_way":true},{"id":"lower","rect":[0.0,192.0,128.0,48.0],"one_way":false}],"connections":[]}
	WORLD._corridor_edge(descent,"actual_receivers",{"area":"up","point":[64.0,-18.0],"support":"upper"},{"area":"down","point":[64.0,174.0],"support":"lower"},[Vector2(64.0,-18.0),Vector2(64.0,174.0)])
	check(descent.connections[0].steps.size() == 2 and descent.connections[0].steps[0].support_id == "actual_middle" and descent.connections[0].steps[1].from_support_id == "actual_middle","native12 L counterexample: intermediate one-way is an actual drop waypoint, not an ignored floor")
	var tuning := PlayerTuning.load_default()
	var generator := GENERATOR.new()
	var signatures: Dictionary = {}
	var consumed_easy: Dictionary = {}
	var manifests: Array = []
	for root: int in 4:
		for map_index: int in [1,2]:
			var seed_value := "forest-feedback-expedition-%02d" % root
			var result := generator.generate(seed_value,tuning,map_index,{"grapple":true,"abilities":["grapple"]})
			check(result.get("ok",false),"real new producer accepts S2-H map%s seed%s" % [map_index,root])
			if not result.get("ok",false): continue
			var m: Dictionary = result.manifest
			manifests.append(m)
			check(generator.validate(m,tuning),"canonical new layout validates")
			check(m == generator.generate(seed_value,tuning,map_index,{"grapple":true}).manifest,"same seed rebuilds all geometry, rewards, ecology and routes")
			check(m.layout_version == "forest-branching-expedition-v16" and m.exploration_contract.native_verified == false,"new layout is versioned and does not claim native proof")
			check(m.exploration_contract.bible_sha256 == WORLD.BIBLE_SHA,"new route design retains selected Bible identity")
			_check_world_bodies(m)
			var main := route(m,"fast")
			check(not main.is_empty() and main[0].a == "arrival" and main[-1].b == "gate_ready","ordinary main route reaches the actual Boss observation gate")
			var main_hard := false
			var maximum_rise := 0.0
			for edge: Dictionary in main:
				if edge.kind == "airborne_chain": main_hard = true
				for step: Dictionary in edge.get("steps",[]):
					if step.has("takeoff") and step.has("landing"): maximum_rise = maxf(maximum_rise,float(step.takeoff[1])-float(step.landing[1]))
			check(not main_hard,"long H/R chains are optional and absent from main")
			check(maximum_rise <= 64.01,"ordinary route never asks for a >64wu rising step")
			check(float(m.boss_approach_origin[0])-float(m.spawn[0]) >= 9000.0,"Boss follows a multi-district journey rather than a nearby route marker")
			check(m.geometry_instances.size() == (16 if map_index == 1 else 17),"same-body choices remove duplicate instances; map1 consumes L, map2 consumes two real Z/7 folds")
			var represented: Dictionary = {}
			var local_easy: Dictionary = {}
			for instance: Dictionary in m.geometry_instances:
				represented[str(instance.module_id)] = true
				if str(instance.difficulty) == "easy":
					local_easy[str(instance.module_id)] = true
					consumed_easy[str(instance.module_id)] = true
			check(local_easy.size() >= 3,"a map consumes several actual easy action families")
			check(not represented.has("low_root_tunnel"),"the rejected low-ceiling family stays out of the current expedition pool")
			var choice_instance := instance_by_id(m,"district_1_main_b")
			check(str(choice_instance.module_id) == ("backlook_fruit_cache" if map_index == 1 else "borrow_pod_crossing"),"each map really consumes its different same-body choice golden")
			check(instance_by_id(m,"district_1_explore").is_empty(),"the choice reuses the ordinary module instead of stacking a duplicate upper module")
			var choice_cache := reward(m,"district_1_explore_cache")
			check(int(choice_cache.coins) == int(choice_instance.local_geometry.risk_reward.coins),"actual choice cache consumes the authored risk reward amount")
			check(point(choice_cache.position) == point(choice_instance.local_geometry.reward_position)+point(choice_instance.translation),"reward stays on the authored upper support, not the public exit")
			for district: int in 4:
				var loop: Dictionary = m.macro_loops["district_%s" % district]
				var direct := edges(m,loop.ordinary)
				var alternate := edges(m,loop.exploration)
				check(direct[0].a == alternate[0].a and direct[-1].b == alternate[-1].b and loop.ordinary != loop.exploration,"real two-route fork reunites at each district's actual known support")
				var cache: Dictionary = reward(m,"district_%s_explore_cache" % district)
				check(not cache.is_empty() and str(cache.area) != str(loop.rejoin),"medium cache is on an exploration island, never on the public rejoin")
				var high: Dictionary = reward(m,"district_%s_master_cache" % district)
				if map_index == 2 and district == 2:
					check(high.is_empty(),"unique deep-root Reader reward does not collide with a second chest interaction")
				else:
					check(not high.is_empty() and int(high.coins)>int(cache.coins),"hard branch offers materially richer real reward candidates")
					var return_edge := edge_by_id(m,"district_%s_master_other_exit" % district)
					check(return_edge.get("claim_before_edge",false) and return_edge.claim_id == high.id,"hard receiver is actually claimed before its other return")
				var hard_return := edge_by_id(m,"district_%s_master_other_exit" % district)
				check(hard_return.kind == "ordinary_sequence" and hard_return.get("no_return_bridge_inside_challenge",false) and not hard_return.steps.is_empty() and hard_return.steps[-1].kind == "drop_through","hard return descends outside its action cavity instead of bridging the challenge")
				var hard_instance: Dictionary = instance_by_id(m,"district_%s_master" % district)
				var bounds := rect(hard_instance.local_geometry.world_bounds)
				bounds.position += point(hard_instance.translation)
				if not hard_return.steps.is_empty():
					var drop_x := float(hard_return.steps[-1].landing[0])
					check(drop_x < bounds.position.x-12.0 or drop_x > bounds.end.x+12.0,"hard return catch lies outside the complete instance, including side recovery ladders")
				var enter := edge_by_id(m,"district_%s_master_cross" % district)
				check(enter.kind == "airborne_chain" and not enter.action_program.is_empty(),"high branch keeps an actual airborne action contract")
				if not enter.post_landing_steps.is_empty():
					check(enter.landing == enter.post_landing_steps[0].get("takeoff",enter.post_landing_steps[0].landing),"air receiver and following ordinary steps share the same actual point")
			var tutorial := anchor(m,"entry_observation_fruit")
			check(tutorial.get("hang_enabled",false) and point(tutorial.position).distance_to(point(m.spawn)) < 231.0,"first supported tutorial fruit is reachable and permits fixed-anchor observation")
			for find: Dictionary in m.forest_discoveries:
				check(not support(m,str(find.support_id)).is_empty(),"Reader rests on an actual declared support")
				for chest: Dictionary in m.rewards:
					check(point(find.position).distance_to(point(chest.position)) > 180.0,"Reader and chest interaction radii do not overlap")
			if map_index == 1:
				check(not m.routes.has("crown_return_loop"),"first-map topology does not copy the crown cross-tree loop")
				check(represented.has("thorn_l_root_turn") and m.l_hollow.entry_kind == "side_descent","actual L geometry is an optional downward side hollow")
				var l_piece := instance_by_id(m,"district_2_l_side")
				var l_cache := reward(m,"district_2_explore_cache")
				var l_position := point(l_piece.local_geometry.reward_position)+point(l_piece.translation)
				check(point(l_cache.position) == l_position and str(l_cache.area) == str(m.l_hollow.reward_area),"native11 counterexample: L cache overwrites the old upper-normal reward position and area")
				check(str(l_cache.support_id) == str(l_piece.platform_id_map[l_piece.local_geometry.reward_support_id]),"L real reward transaction uses its actual receiving root")
				check(Array(m.macro_loops.district_2.exploration) == Array(m.routes.explore_2_out)+Array(m.routes.explore_2_return),"L macro exploration overrides the former upper route instead of keeping stale merge keys")
				check(m.macro_loops.district_1.actual_reward_return == "district_1_main_b_in","backlook reward really returns to its own entry before lower onward")
				var l_descent := edge_by_id(m,"l_hollow_descent")
				check(l_descent.steps[0].kind == "walk" and l_descent.steps[1].kind == "drop_through","native13 L trap: walk down onto the real receiver before one Down input; no 30wu stacked drop exceptions")
			else:
				check(m.borrow_pod_camp.support_id == "district_1_main_b__observation_root" and support(m,"hub_2__wide_root").is_empty(),"camp uses the actual pod observing root without a duplicated solid")
				check(m.borrow_pod_camp.return_route == "borrow_pod_to_camp","pod reward has a real descending return onto camp")
				var pod_bounds := rect(choice_instance.local_geometry.world_bounds)
				pod_bounds.position += point(choice_instance.translation)
				var climb := edge_by_id(m,"district_1_master_climb")
				for step: Dictionary in climb.steps:
					if step.kind != "jump_rise": continue
					check(float(step.landing[0]) < pod_bounds.position.x-12.0 or float(step.landing[0]) > pod_bounds.end.x+12.0 or float(step.landing[1])+18.0 < pod_bounds.position.y,"native12 fixed hang jump cannot be intercepted by a master staircase inside the live canopy")
				check(represented.has("thorn_z_root_switchback") and represented.has("thorn_7_root_fold"),"map2 really consumes the different Z and 7 thorn roots, not only their catalogue rows")
				var z_piece := instance_by_id(m,"district_2_z_side")
				var z_cache := reward(m,"district_2_explore_cache")
				check(point(z_cache.position) == point(z_piece.local_geometry.reward_position)+point(z_piece.translation) and str(z_cache.support_id) == str(z_piece.platform_id_map.middle_root),"Z middle-left reward is not awarded at its legal cheaper lower-right exit")
				var seven_piece := instance_by_id(m,"district_3_7_side")
				var seven_cache := reward(m,"crown_7_cache")
				check(point(seven_cache.position) == point(seven_piece.local_geometry.reward_position)+point(seven_piece.translation) and str(seven_cache.area) != "district_3_7_side_out","7 far-side reward is separate from the legal near-side lower-left output")
				var crown := route(m,"crown_return_loop")
				check(crown[0].a == m.crown_folds.outer_reward and crown[-1].b == m.camp_area,"second-map outer fold returns onto a known Z recovery root and the real pod camp")
				check(m.forest_shortcuts.size() == 1 and m.forest_shortcuts[0].unlock_reward_id == "crown_7_cache","the real reward-shortcut consumer receives an actual claim id and gate rectangle")
				check(edge_by_id(m,"seven_claimed_west_gate").condition == "opened:crown_fold_return" and route(m,"crown_7_long_return")[0].a == m.crown_folds.outer_reward,"claimed short gate and ungated authored long return are distinct physical routes")
				check(edge_by_id(m,"seven_claimed_west_gate_back").condition == "opened:crown_fold_return","reverse shortcut edge cannot pretend the real closed gate is open")
				check(float(m.forest_shortcuts[0].rect[1]) == float(seven_piece.translation[1])+64.0 and float(m.forest_shortcuts[0].rect[3]) == 224.0,"native14 gate counterexample: lower door attaches to the solid bridge underside and leaves the formal upper entrance open")
				check(float(m.crown_folds.recovery_window[2]) == 64.0,"solid doorframe preserves the raw final recovery jump through the entrance window")
				var frame := rect(m.forest_shortcuts[0].rect)
				var roof_exists := false
				for root_row: Dictionary in m.platforms:
					var root_rect := rect(root_row.rect)
					if not bool(root_row.one_way) and root_rect.position.x<=frame.position.x and root_rect.end.x>=frame.end.x and is_equal_approx(root_rect.end.y,frame.position.y): roof_exists = true
				check(roof_exists,"higher recovery jump cannot go over the door through an imaginary one-way ceiling")
				check(z_cache.resources == [{"kind":"coin","amount":4},{"kind":"note","amount":1}] and seven_cache.resources == z_cache.resources,"real Z/7 cache candidates match the existing App coin-or-one-note transaction")
			var changed := m.duplicate(true)
			changed.platforms[0].rect[2] += 1.0
			check(not generator.validate(changed,tuning),"geometry mutation cannot borrow the previous manifest hash")
			changed = m.duplicate(true)
			changed.connections.erase(edge_by_id(changed,"district_0_explore_enter"))
			changed.manifest_hash = GENERATOR._hash(changed)
			check(not generator.validate(changed,tuning),"rehashing a missing real branch does not restore canonical admission")
			signatures[JSON.stringify(m.choices)] = true
	for id: String in WORLD.EASY: check(consumed_easy.has(id),"the sampled worlds really consume each registered easy pool member")
	check(signatures.size() > 2,"seeds change real module allocations and branch heights, beyond names/hash alone")
	check(not generator.generate("no-H",tuning,1,{}).get("ok",false),"no-H generation is refused")
	check(not generator.generate("too-many",tuning,1,{"grapple":true,"abilities":["grapple","double_jump"]}).get("ok",false),"ungranted extra capability cannot silently enter S2")
	var actual_ledger: Array[StringName] = [&"grapple"]
	check(generator.generate("typed-ledger",tuning,1,{"grapple":true,"abilities":actual_ledger}).get("ok",false),"actual typed StringName ability ledger reaches the independent producer")
	for bad: Variant in [["grapple","grapple"],[&"grapple",&"unknown"],[1],"grapple",[],[true]]:
		check(not generator.generate("invalid-ledger",tuning,1,{"grapple":true,"abilities":bad}).get("ok",false),"duplicate, unknown and malformed ledgers stay rejected")
	print("FOREST EXPLORATION WORLD: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)

func route(m: Dictionary,name: String) -> Array:
	return edges(m,m.routes[name])

func edges(m: Dictionary,ids: Array) -> Array:
	var result: Array = []
	for id: String in ids: result.append(edge_by_id(m,id))
	return result

func edge_by_id(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.connections:
		if str(row.id) == id: return row
	return {}

func instance_by_id(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.geometry_instances:
		if str(row.id) == id: return row
	return {}

func reward(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.rewards:
		if str(row.id) == id: return row
	return {}

func anchor(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.hook_anchors:
		if str(row.id) == id: return row
	return {}

func support(m: Dictionary,id: String) -> Dictionary:
	for row: Dictionary in m.platforms:
		if str(row.id) == id: return row
	return {}

func point(row: Array) -> Vector2:
	return Vector2(float(row[0]),float(row[1]))

func rect(row: Array) -> Rect2:
	return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))

func _check_world_bodies(m: Dictionary) -> void:
	# Full-world contacts, unlike local module checks, see the next layer's
	# recovery floor, neighbouring walls and later district placements.
	# Respawn's real shape query includes one-way bodies, even though jumping
	# may pass upward through them. Preserve the round06 overhead counterexample.
	for area: Dictionary in m.areas:
		if str(area.id) != "arrival" and not str(area.id).begins_with("hub_"): continue
		var resting_body := Rect2(point(area.position)-Vector2(12,18),Vector2(24,36))
		for blocker: Dictionary in m.platforms:
			check(not resting_body.intersects(rect(blocker.rect).grow(-0.01)),"resting_body_including_oneway/%s/%s" % [str(area.id),str(blocker.id)])
	for edge: Dictionary in m.connections:
		if str(edge.kind) != "ordinary_sequence": continue
		var previous := point(edge.path[0])
		for index: int in edge.steps.size():
			var step: Dictionary = edge.steps[index]
			if not step.has("landing"): continue
			var landing := point(step.landing)
			var takeoff := point(step.get("takeoff",[previous.x,previous.y]))
			for marker: Vector2 in [takeoff,landing]:
				var body := Rect2(marker-Vector2(12,18),Vector2(24,36))
				for blocker: Dictionary in m.platforms:
					if bool(blocker.one_way): continue
					check(not body.intersects(rect(blocker.rect).grow(-0.01)),"world_body/%s/step%s/%s" % [str(edge.id),index,str(blocker.id)])
			if str(step.kind) == "walk" and is_equal_approx(takeoff.y,landing.y):
				var sweep := Rect2(Vector2(minf(takeoff.x,landing.x)-12.0,takeoff.y-18.0),Vector2(absf(takeoff.x-landing.x)+24.0,36.0))
				for blocker: Dictionary in m.platforms:
					if bool(blocker.one_way): continue
					check(not sweep.intersects(rect(blocker.rect).grow(-0.01)),"world_walk/%s/step%s/%s" % [str(edge.id),index,str(blocker.id)])
			if str(step.kind) == "drop_through" and step.has("path"):
				var path: Array = step.path
				for part: int in range(1,path.size()):
					var a := point(path[part-1])
					var b := point(path[part])
					# Axis-aligned input corridors only; a jump's chord is not its
					# real parabola and must not be used as a false collision test.
					if not is_equal_approx(a.x,b.x) and not is_equal_approx(a.y,b.y): continue
					var sweep := Rect2(Vector2(minf(a.x,b.x)-12.0,minf(a.y,b.y)-18.0),Vector2(absf(a.x-b.x)+24.0,absf(a.y-b.y)+36.0))
					for blocker: Dictionary in m.platforms:
						if bool(blocker.one_way) or str(blocker.id) == str(step.get("support_id","")) or str(blocker.id) == str(step.get("from_support_id","")): continue
						check(not sweep.intersects(rect(blocker.rect).grow(-0.01)),"world_drop/%s/step%s/part%s/%s" % [str(edge.id),index,part,str(blocker.id)])
			previous = landing
