class_name ForestThornCorridorModules
extends RefCounted
## Root-hosted bends. Dictionaries are candidates, never alternate movement code.
const VERSION := "forest-thorn-corridors-v1"
const BIBLE_SHA := "a7bad8323af64a7be0577132e5d988a6e1b781d9e1ac1639d37f9d65935194e3"

static func catalogue() -> Array[Dictionary]:
	return [{"id":"thorn_l_root_turn","difficulty":"normal","identity":"descend into a broad root elbow, then choose a long jump or side-fruit recoil over the thorn-covered root"},
		{"id":"thorn_7_root_fold","difficulty":"normal","identity":"cross the upper root rightward, read the far descent, then turn inward left beneath it"},
		{"id":"thorn_z_root_switchback","difficulty":"normal","identity":"alternate right-left-right across three broad rooted levels, with opposite-facing optional fruit/recoil phrases"}]

static func build(id: String) -> Dictionary:
	var m: Dictionary
	match id:
		"thorn_l_root_turn": m=_l_root_turn()
		"thorn_7_root_fold": m=_seven_root_fold()
		"thorn_z_root_switchback": m=_z_root_switchback()
		_: return {}
	for row: Dictionary in catalogue():
		if str(row.id)==id: m.merge(row); break
	m.version = VERSION
	m.requires = ["grapple"]
	m.main_route_kind = "ordinary_sequence"
	m.admission = {"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false}
	m.resource_contract = {"new_abilities":false,"health_override":false,"shot_refill_override":false,"physics_override":false}
	m.danger_hosts = []
	m.danger_faces = []
	for surface: Dictionary in m.danger_surfaces:
		m.danger_hosts.append(surface.host_support_id)
		m.danger_faces.append(surface.face)
	return m

static func _l_root_turn() -> Dictionary:
	var m := {"width":1200.0,"height":552.0,"world_bounds":[-160.0,-192.0,1360.0,552.0],
		"spawn":[40.0,-18.0],"goal":[1160.0,142.0],"entry_support_id":"entry","exit_support_id":"exit",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],"steps":[],"routes":{},"action_program":[],
		"risk_reward":{"coins":4,"notes":0,"tier":"medium","optional":true,"return_required":true}}
	_p(m,"entry",[0.0,0.0,256.0,48.0])
	# A real vertical root and its attached bough shape the elbow. There is
	# generous body space below, rather than a low-ceiling short-hop course.
	_p(m,"upright_root",[448.0,-192.0,96.0,224.0])
	_p(m,"fruit_bough",[544.0,-64.0,160.0,32.0])
	_p(m,"elbow_root",[256.0,160.0,352.0,48.0])
	_p(m,"receiver",[672.0,160.0,224.0,48.0])
	_p(m,"exit",[976.0,160.0,224.0,64.0])
	m.hook_anchors.append({"id":"elbow_side_fruit","position":[688.0,32.0],"host_support_id":"fruit_bough","stem_root":[688.0,-32.0],"fruit_presentation":"rooted_fruit","fruit_role":"optional"})
	_hazard(m,"upright_root","down",[464.0,32.0,64.0,16.0])
	_hazard(m,"elbow_root","up",[560.0,136.0,48.0,24.0])
	_recovery(m)
	m.steps = [_walk("entry",[240.0,-18.0]),
		_drop("entry","elbow_root",[240.0,-18.0],[320.0,142.0]),
		_walk("elbow_root",[528.0,142.0]),
		_step("jump_gap","elbow_root","receiver",[528.0,142.0],[704.0,142.0]),
		_walk("receiver",[864.0,142.0]),
		_step("jump_gap","receiver","exit",[864.0,142.0],[1008.0,142.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.to_elbow = m.steps.slice(0,2)
	m.reward_outbound_step_count=4
	m.recovery_start=[-80.0,302.0]
	# This is an explicit retry/return to departure, not a shortcut or a
	# claimed fork/rejoin at a different hub.
	m.routes.returning = [_walk("receiver",[704.0,142.0]),
		_step("jump_gap","receiver","elbow_root",[704.0,142.0],[528.0,142.0]),
		_walk("elbow_root",[272.0,142.0]),
		_drop("elbow_root","catch",[272.0,142.0],[192.0,302.0])]+m.routes.recovery
	m.action_program = [{"action":"H","anchor":"elbow_side_fruit"},{"action":"R","direction":[-1.0,0.0]}]
	m.shortcut_contract = {"start_support":"elbow_root","start":[496.0,142.0],"jump_before_hook":true,
		"landing_support":"receiver","landing":[800.0,142.0],"action_program":m.action_program.duplicate(true),
		"scope":"optional human H/R route; ordinary route is the main executable steps; real Motor and timing unverified"}
	m.reward_support_id = "receiver"
	m.reward_position = [800.0,142.0]
	m.corridor_contract = {"shape":"L","bible_sha256":BIBLE_SHA,
		"main_route":"main","return_route":"returning","recovery_route":"recovery",
		"entry_floor_y":0.0,"exit_floor_y":160.0,"non_level_ports":true,
		"spine":[[240.0,-18.0],[320.0,142.0],[1160.0,142.0]],
		"safe_observation_support":"elbow_root","safe_observation":[384.0,142.0],
		"reward_role":"same challenge receiving-root reward, not an independent secret or a public-hub cache",
		"ordinary_takeoff":[528.0,142.0],"ordinary_receiver":[704.0,142.0],
		"hold_to_receiver_required_by_candidate":true,"native_verified":false}
	m.play_contract = {"observe":"look down into the broad elbow and read the thorn-covered root and receiving branch together",
		"challenge":"commit to the descent, then choose a full-held ordinary jump or jump-H/recoil across the root-tip thorns",
		"recovery":"missed jumps fall into a visible continuous root basin; return branches outside the entry body lead back to the departure",
		"choice":"ordinary jump spends no shot; the side fruit and back-facing shot offer a different approach and correction",
		"cheapest_strategy":"a well-held ordinary jump is intentionally legal; no claim that H or R is mandatory",
		"visual":"one real upright root joins the overhead fruit bough; thorns grow on its underside and the lower root's upper surface"}
	m.ecology_slots = []
	m.windows = [{"id":"root_elbow_descent","clear_rect":[256.0,-32.0,192.0,192.0]},
		{"id":"elbow_onward","clear_rect":[544.0,48.0,656.0,88.0]}]
	m.tile_contract = {"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,
		"hazards":"actual solid root surfaces: up24/down16","standalone_spike_blocks":false}
	return m

static func _p(m: Dictionary,id: String,rect: Array,one_way := false) -> void:
	m.platforms.append({"id":id,"rect":rect,"one_way":one_way})

static func _hazard(m: Dictionary,host: String,face: String,rect: Array) -> void:
	m.danger_surfaces.append({"danger_index":m.dangers.size(),"host_support_id":host,"face":face})
	m.dangers.append(rect)

static func _step(kind: String,from: String,to: String,takeoff: Array,landing: Array) -> Dictionary:
	return {"kind":kind,"from_support_id":from,"support_id":to,"takeoff":takeoff,"landing":landing}

static func _walk(to: String,landing: Array) -> Dictionary:
	return {"kind":"walk","support_id":to,"landing":landing}

static func _drop(from: String,to: String,takeoff: Array,landing: Array) -> Dictionary:
	var step := _step("drop_through",from,to,takeoff,landing)
	step.path = [takeoff.duplicate(),[landing[0],takeoff[1]],landing.duplicate()]
	return step

static func _recovery(m: Dictionary) -> void:
	_p(m,"catch",[-160.0,320.0,1360.0,40.0])
	var steps: Array = [_walk("catch",[-80.0,302.0])]
	var previous := "catch"
	var previous_y := 320.0
	for index: int in 4:
		var y := 256.0-float(index)*64.0
		var id := "return_root_%s" % index
		_p(m,id,[-128.0,y,128.0,16.0],true)
		steps.append(_step("jump_rise",previous,id,[-80.0,previous_y-18.0],[-80.0,y-18.0]))
		previous = id
		previous_y = y
	steps.append(_step("jump_rise",previous,"entry",[-32.0,46.0],[32.0,-18.0]))
	steps.append(_walk("entry",m.spawn.duplicate()))
	m.routes.recovery = steps

static func _seven_root_fold() -> Dictionary:
	var m := {"width":1280.0,"height":680.0,"world_bounds":[-160.0,-128.0,1440.0,680.0],
		"spawn":[40.0,-18.0],"goal":[40.0,270.0],"entry_support_id":"upper_root","exit_support_id":"lower_root",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],"steps":[],"routes":{},"action_program":[],
		"risk_reward":{"coins":4,"notes":0,"tier":"medium","optional":true,"return_required":true}}
	_p(m,"upper_root",[0.0,0.0,960.0,48.0])
	_p(m,"lower_root",[0.0,288.0,1152.0,48.0])
	_hazard(m,"upper_root","up",[496.0,-24.0,48.0,24.0])
	_hazard(m,"upper_root","down",[816.0,48.0,80.0,16.0])
	_hazard(m,"lower_root","up",[640.0,264.0,64.0,24.0])
	m.hook_anchors.append({"id":"inward_fruit","position":[576.0,160.0],"host_support_id":"upper_root","stem_root":[576.0,48.0],"fruit_presentation":"rooted_fruit","fruit_role":"optional"})
	_tall_recovery(m,512.0,1280.0)
	m.steps=[_walk("upper_root",[464.0,-18.0]),
		_step("jump_gap","upper_root","upper_root",[464.0,-18.0],[640.0,-18.0]),
		_walk("upper_root",[928.0,-18.0]),
		_drop("upper_root","lower_root",[928.0,-18.0],[1072.0,270.0]),
		_walk("lower_root",[752.0,270.0]),
		_step("jump_gap","lower_root","lower_root",[752.0,270.0],[576.0,270.0]),
		_walk("lower_root",m.goal)]
	m.routes.main=m.steps.duplicate(true)
	m.reward_position=[1008.0,270.0]; m.reward_support_id="lower_root"
	m.reward_outbound_step_count=4
	m.routes.reward=m.steps.slice(0,m.reward_outbound_step_count)+[_walk("lower_root",m.reward_position)]
	m.routes.returning=[_walk("lower_root",[752.0,270.0]),
		_step("jump_gap","lower_root","lower_root",[752.0,270.0],[576.0,270.0])]+_return_from_floor(m,"lower_root",288.0)
	m.branch_reward_contract={"reward_route":"reward","return_route":"returning","reward_support_id":"lower_root","reward_position":m.reward_position.duplicate(),
		"fast_bypass":"a legal west-side ordinary descent can reach the lower-left output, but the far inward fruit cache still requires a lower-thorn crossing or the full upper approach",
		"fast_bypass_native":"unverified; source-review strategy, not a completed native proof","exit_coin_override":false}
	m.action_program=[{"action":"H","anchor":"inward_fruit"},{"action":"R","direction":[1.0,0.0]}]
	m.shortcut_contract={"start_support":"lower_root","start":[752.0,270.0],"jump_before_hook":true,
		"landing_support":"lower_root","landing":[512.0,270.0],"action_program":m.action_program.duplicate(true),
		"scope":"optional jump-H / right-facing recoil inward approach; ordinary long-held jump is legal; H/R Motor unverified"}
	m.corridor_contract={"shape":"7","bible_sha256":BIBLE_SHA,"main_route":"main","return_route":"returning","recovery_route":"recovery",
		"entry_floor_y":0.0,"exit_floor_y":288.0,"non_level_ports":true,"reverse_exit":true,
		"spine":[[40.0,-18.0],[928.0,-18.0],[1072.0,270.0],[40.0,270.0]],
		"safe_observation_support":"upper_root","safe_observation":[928.0,-18.0],"vertical_root_spacing":288.0,
		"reward_role":"far-side receiving-root cache; near-side fast descent reaches the output without automatically reaching the cache","native_verified":false}
	m.play_contract={"observe":"look from the far upper root into the broad outside descent and the inward fruit below",
		"challenge":"traverse right over an exposed upper thorn patch, control the outside fall, then reverse left across the lower rooted patch",
		"recovery":"wide continuous basin and outside return boughs recover failed approaches without teleporting",
		"choice":"ordinary full-held jumps preserve ammunition; the inward fruit and right-facing recoil provide another lower approach",
		"cheapest_strategy":"near-side fast descent is legal onward progress; taking the far-side cache still traverses a thorn crossing, with ordinary or H/R options",
		"visual":"two substantial root shelves fold around a wide far-side opening; upper underside thorns stay far above the lower full-height jump"}
	m.windows=[{"id":"far_root_descent","clear_rect":[960.0,0.0,192.0,288.0]},
		{"id":"inward_root_corridor","clear_rect":[0.0,64.0,960.0,200.0]}]
	_common_material(m)
	return m

static func _z_root_switchback() -> Dictionary:
	var m := {"width":1408.0,"height":1000.0,"world_bounds":[-160.0,-128.0,1568.0,1000.0],
		"spawn":[40.0,-18.0],"goal":[1240.0,558.0],"entry_support_id":"upper_root","exit_support_id":"lower_root",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],"steps":[],"routes":{},"action_program":[],
		"risk_reward":{"coins":4,"notes":0,"tier":"medium","optional":true,"return_required":true}}
	# Alternating real solid shelves catch the normal descent at the next
	# level. The middle root extends beyond the upper root's right opening;
	# the lower root extends beyond the middle root's left opening.
	_p(m,"upper_root",[0.0,0.0,960.0,48.0])
	_p(m,"middle_root",[192.0,288.0,1088.0,48.0])
	_p(m,"lower_root",[0.0,576.0,1280.0,64.0])
	_hazard(m,"upper_root","up",[496.0,-24.0,48.0,24.0])
	_hazard(m,"upper_root","down",[816.0,48.0,80.0,16.0])
	_hazard(m,"middle_root","up",[640.0,264.0,64.0,24.0])
	_hazard(m,"middle_root","down",[384.0,336.0,80.0,16.0])
	_hazard(m,"lower_root","up",[656.0,552.0,64.0,24.0])
	m.hook_anchors.append({"id":"middle_inward_fruit","position":[576.0,160.0],"host_support_id":"upper_root","stem_root":[576.0,48.0],"fruit_presentation":"rooted_fruit","fruit_role":"optional"})
	m.hook_anchors.append({"id":"lower_outward_fruit","position":[800.0,448.0],"host_support_id":"middle_root","stem_root":[800.0,336.0],"fruit_presentation":"rooted_fruit","fruit_role":"optional"})
	_tall_recovery(m,832.0,1408.0)
	m.steps=[_walk("upper_root",[464.0,-18.0]),
		_step("jump_gap","upper_root","upper_root",[464.0,-18.0],[640.0,-18.0]),
		_walk("upper_root",[928.0,-18.0]),
		_drop("upper_root","middle_root",[928.0,-18.0],[1072.0,270.0]),
		_walk("middle_root",[752.0,270.0]),
		_step("jump_gap","middle_root","middle_root",[752.0,270.0],[576.0,270.0]),
		_walk("middle_root",[224.0,270.0]),
		_drop("middle_root","lower_root",[224.0,270.0],[128.0,558.0]),
		_walk("lower_root",[608.0,558.0]),
		_step("jump_gap","lower_root","lower_root",[608.0,558.0],[784.0,558.0]),
		_walk("lower_root",m.goal)]
	m.routes.main=m.steps.duplicate(true)
	m.reward_position=[288.0,270.0]; m.reward_support_id="middle_root"
	m.reward_outbound_step_count=7
	m.routes.reward=m.steps.slice(0,m.reward_outbound_step_count)+[_walk("middle_root",m.reward_position)]
	m.routes.returning=[_walk("middle_root",[224.0,270.0]),
		_drop("middle_root","lower_root",[224.0,270.0],[128.0,558.0])]+_return_from_floor(m,"lower_root",576.0)
	m.branch_reward_contract={"reward_route":"reward","return_route":"returning","reward_support_id":"middle_root","reward_position":m.reward_position.duplicate(),
		"fast_bypass":"from the first middle landing, an ordinary right-side walk-off and inward fall can reach the lower-right output while skipping the middle-left cache",
		"fast_bypass_native":"unverified; source-review strategy, not a completed native proof","exit_coin_override":false}
	m.action_program=[{"action":"H","anchor":"middle_inward_fruit"},{"action":"R","direction":[1.0,0.0]}]
	m.shortcut_contract={"start_support":"middle_root","start":[752.0,270.0],"jump_before_hook":true,
		"landing_support":"middle_root","landing":[512.0,270.0],"action_program":m.action_program.duplicate(true),
		"scope":"optional first inward H/R phrase, with a real middle receiving root before the next phrase; no claim of continuous mandatory air chain"}
	m.optional_phrases=[m.shortcut_contract.duplicate(true),{"start_support":"lower_root","start":[608.0,558.0],"jump_before_hook":true,
		"landing_support":"lower_root","landing":[864.0,558.0],"action_program":[{"action":"H","anchor":"lower_outward_fruit"},{"action":"R","direction":[-1.0,0.0]}],
		"scope":"optional outward H/R phrase after actual middle-root reception and left-side descent; H/R Motor unverified"}]
	m.corridor_contract={"shape":"Z","bible_sha256":BIBLE_SHA,"main_route":"main","return_route":"returning","recovery_route":"recovery",
		"entry_floor_y":0.0,"exit_floor_y":576.0,"non_level_ports":true,"vertical_root_spacing":288.0,
		"spine":[[40.0,-18.0],[928.0,-18.0],[1072.0,270.0],[224.0,270.0],[128.0,558.0],[1240.0,558.0]],
		"safe_observation_support":"middle_root","safe_observation":[1072.0,270.0],
		"ordinary_right_drop_is_caught_by":"middle_root","ordinary_left_drop_is_caught_by":"lower_root",
		"reward_role":"middle-left inner-fold cache; legal outer-right fast descent reaches the onward exit without this reward",
		"native_verified":false}
	m.play_contract={"observe":"read the right upper opening, left middle opening and opposite-facing fruits as a three-level route",
		"challenge":"rightward approach, leftward middle thorn crossing, then a left-end descent and rightward lower crossing, with real reception between turns",
		"recovery":"each normal opening lands on the next broad root; missed outer approaches have a continuous catch basin and return boughs",
		"choice":"two opposite-facing H/R phrases can change approaches, separated by actual stable root landings; ordinary long-held jumps remain legal",
		"cheapest_strategy":"ordinary outer-right descent is legal fast progress but skips the middle-left cache; the inner exploration route earns the cache without requiring an H/R password",
		"visual":"three long solid roots overlap at alternating ends, with naturally hosted upper and underside thorn strips, not a rectangular spike maze"}
	m.windows=[{"id":"right_outer_opening","clear_rect":[960.0,0.0,320.0,288.0]},
		{"id":"left_inner_opening","clear_rect":[0.0,288.0,192.0,288.0]},
		{"id":"lower_outward_run","clear_rect":[192.0,352.0,1088.0,200.0]}]
	_common_material(m)
	return m

static func _tall_recovery(m: Dictionary,floor_y: float,far_x: float) -> void:
	_p(m,"catch",[-160.0,floor_y,far_x+160.0,40.0])
	m.recovery_start=[-80.0,floor_y-18.0]
	var steps: Array=[_walk("catch",m.recovery_start.duplicate())]
	var previous := "catch"
	var previous_y := floor_y
	var index := 0
	var y := floor_y-128.0
	while y>=64.0:
		var id := "return_root_%s" % index
		_p(m,id,[-128.0,y,128.0,16.0],true)
		steps.append(_step("jump_rise",previous,id,[-80.0,previous_y-18.0],[-80.0,y-18.0]))
		previous=id; previous_y=y; index+=1; y-=128.0
	steps.append(_step("jump_rise",previous,str(m.entry_support_id),[-32.0,previous_y-18.0],[32.0,-18.0]))
	steps.append(_walk(str(m.entry_support_id),m.spawn.duplicate()))
	m.routes.recovery=steps

static func _return_from_floor(m: Dictionary,support: String,floor_y: float) -> Array:
	var steps: Array=[_walk(support,[32.0,floor_y-18.0])]
	var previous := support
	var previous_y := floor_y
	for row: Dictionary in m.platforms:
		if not str(row.id).begins_with("return_root_") or float(row.rect[1])>=previous_y: continue
		var y := float(row.rect[1])
		steps.append(_step("jump_rise",previous,str(row.id),[32.0,previous_y-18.0] if previous==support else [-80.0,previous_y-18.0],[-80.0,y-18.0]))
		previous=str(row.id);previous_y=y
	steps.append(_step("jump_rise",previous,str(m.entry_support_id),[-32.0,previous_y-18.0],[32.0,-18.0]))
	steps.append(_walk(str(m.entry_support_id),m.spawn.duplicate()))
	return steps

static func _common_material(m: Dictionary) -> void:
	m.ecology_slots=[]
	m.tile_contract={"family":"shared_underworld_with_forest_bible_material","source_tile_px":16,"world_tile_wu":32,
		"hazards":"actual solid root surfaces: up24/down16","standalone_spike_blocks":false}
