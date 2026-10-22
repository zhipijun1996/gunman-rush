class_name ForestExplorationModules
extends RefCounted
## Finite, replayable exploration pieces. Geometry/action intent is not Motor admission.
## All positions are local body centres; a standing body is 18wu above its support.
const VERSION := "forest-exploration-modules-v1"
const THORN_CORRIDORS := preload("res://scripts/generation/forest_thorn_corridor_modules.gd")

static func catalogue() -> Array[Dictionary]:
	var entries: Array[Dictionary] = [
		{"id":"root_meadow","difficulty":"easy","identity":"broad horizontal roots, two short gaps and a low crest"},
		{"id":"mushroom_fork","difficulty":"easy","identity":"visible upper mushroom branch and lower safe passage rejoin"},
		{"id":"low_root_tunnel","difficulty":"easy","identity":"horizontal hollow roof with a sheltered floor gap"},
		{"id":"root_basin_return","difficulty":"easy","identity":"controlled descent into a broad basin and shallow exit terraces"},
		{"id":"side_fruit_crossing","difficulty":"normal","identity":"side fruit shortcut over lower recovery stepping roots"},
		{"id":"double_fruit_s","difficulty":"normal","identity":"two fruit directions separated by an observation perch"},
		{"id":"double_window","difficulty":"normal","identity":"two traversable windows through one trunk, lower return route"},
		{"id":"canopy_detour","difficulty":"normal","identity":"upper reward bough over an independent lower root bypass"},
		{"id":"thorn_side_passage","difficulty":"hard","identity":"horizontal H/R passage between host-covered thorn faces"},
		{"id":"backbranch_turn","difficulty":"hard","identity":"drop outside a broken branch and turn back behind the departure"},
		{"id":"crown_hook_relay","difficulty":"hard","identity":"separated airborne H/R/H crown relay with a lower catch"},
		{"id":"deep_root_switchback","difficulty":"hard","identity":"descend first, reverse direction on side fruits, ascend to a hidden lip"},
		{"id":"backlook_fruit_cache","difficulty":"normal","identity":"visible high cache rewards turning back from the side-fruit receiver; drop back to the root bypass"},
		{"id":"borrow_pod_crossing","difficulty":"normal","identity":"read a living pod's right-high swing to kick back to a high reward root, or use the longer fixed-fruit approach"},
	]
	entries.append_array(THORN_CORRIDORS.catalogue())
	return entries

static func build(id: String) -> Dictionary:
	var m: Dictionary
	match id:
		"root_meadow": m = _root_meadow()
		"mushroom_fork": m = _mushroom_fork()
		"low_root_tunnel": m = _low_root_tunnel()
		"root_basin_return": m = _root_basin_return()
		"side_fruit_crossing": m = _side_fruit_crossing()
		"double_fruit_s": m = _double_fruit_s()
		"double_window": m = _double_window()
		"canopy_detour": m = _canopy_detour()
		"thorn_side_passage": m = _thorn_side_passage()
		"backbranch_turn": m = _backbranch_turn()
		"crown_hook_relay": m = _crown_hook_relay()
		"deep_root_switchback": m = _deep_root_switchback()
		"backlook_fruit_cache": m = _backlook_fruit_cache()
		"borrow_pod_crossing": m = _borrow_pod_crossing()
		_: return THORN_CORRIDORS.build(id)
	for entry: Dictionary in catalogue():
		if entry.id == id:
			m.merge(entry)
			break
	m.version = VERSION
	m.danger_hosts = []
	m.danger_faces = []
	for surface: Dictionary in m.danger_surfaces:
		m.danger_hosts.append(surface.host_support_id)
		m.danger_faces.append(surface.face)
	m.main_route_kind = "air_chain" if m.difficulty == "hard" else "ordinary_sequence"
	m.admission = {"geometry":"candidate","motor":"unverified","visual":"unverified","production_pool":false}
	m.requires = ["grapple"]
	m.resource_contract = {"new_abilities":false,"health_override":false,"shot_refill_override":false,"physics_override":false}
	return m

static func _base(width: float, ceiling := -240.0, bottom := 220.0) -> Dictionary:
	return {"width":width,"height":bottom-ceiling,"world_bounds":[0.0,ceiling,width,bottom-ceiling],
		"spawn":[40.0,-18.0],"goal":[width-40.0,-18.0],"entry_support_id":"entry","exit_support_id":"exit",
		"platforms":[],"hook_anchors":[],"dangers":[],"danger_surfaces":[],"steps":[],"routes":{},"action_program":[],
		"risk_reward":{"optional":false,"coins":1,"notes":0,"tier":"low","return_required":true}}

static func _p(m: Dictionary, id: String, rect: Array, one_way := false) -> void:
	m.platforms.append({"id":id,"rect":rect,"one_way":one_way})

static func _fruit(m: Dictionary, id: String, position: Array, host: String, root: Array) -> void:
	m.hook_anchors.append({"id":id,"position":position,"host_support_id":host,"stem_root":root,
		"fruit_presentation":"rooted_fruit","fruit_role":"optional"})

static func _step(kind: String, from: String, to: String, takeoff: Array, landing: Array) -> Dictionary:
	return {"kind":kind,"from_support_id":from,"support_id":to,"takeoff":takeoff,"landing":landing}

static func _walk(to: String, landing: Array) -> Dictionary:
	return {"kind":"walk","support_id":to,"landing":landing}

static func _drop(from: String, to: String, takeoff: Array, landing: Array) -> Dictionary:
	var step := _step("drop_through",from,to,takeoff,landing)
	step.path = [takeoff.duplicate(),[landing[0],takeoff[1]],landing.duplicate()]
	return step

static func _reward(m: Dictionary, support: String, position: Array, coins: int, notes := 0) -> void:
	m.reward_support_id = support
	m.reward_position = position
	m.risk_reward = {"optional":m.get("difficulty", "") == "hard","coins":coins,"notes":notes,
		"tier":"high" if coins >= 6 else "medium" if coins >= 3 else "low","return_required":true}

static func _recovery(m: Dictionary, width: float) -> void:
	_p(m,"catch",[-160.0,144.0,width+160.0,40.0])
	# The ladder is OUTSIDE the solid entry's left edge. Putting it underneath
	# a solid root would ask the player to jump through that root's underside.
	_p(m,"catch_step_low",[-144.0,96.0,128.0,16.0],true)
	_p(m,"catch_step_high",[-128.0,48.0,128.0,16.0],true)
	m.world_bounds[0] = -160.0
	m.world_bounds[2] = width+160.0
	m.routes.recovery = [_walk("catch",[-80.0,126.0]),
		_step("jump_rise","catch","catch_step_low",[-80.0,126.0],[-80.0,78.0]),
		_step("jump_rise","catch_step_low","catch_step_high",[-80.0,78.0],[-64.0,30.0]),
		_step("jump_rise","catch_step_high","entry",[-32.0,30.0],[32.0,-18.0])]

static func _deep_recovery(m: Dictionary, floor_y: float) -> void:
	m.world_bounds[0] = -160.0
	m.world_bounds[2] = float(m.width)+160.0
	_p(m,"catch",[-160.0,floor_y,float(m.width)+160.0,40.0])
	var steps: Array = [_walk("catch",[-80.0,floor_y-18.0])]
	var previous := "catch"
	var previous_y := floor_y
	var index := 0
	while previous_y > 64.0:
		var y := maxf(48.0,previous_y-64.0)
		var id := "return_step_%s" % index
		_p(m,id,[-128.0,y,128.0,16.0],true)
		steps.append(_step("jump_rise",previous,id,[-80.0,previous_y-18.0],[-80.0,y-18.0]))
		previous = id
		previous_y = y
		index += 1
	steps.append(_step("jump_rise",previous,"entry",[-32.0,previous_y-18.0],[32.0,-18.0]))
	m.routes.recovery = steps

static func _root_meadow() -> Dictionary:
	var m := _base(880.0)
	_p(m,"entry",[0.0,0.0,240.0,48.0])
	_p(m,"low_crest",[312.0,-32.0,224.0,48.0])
	_p(m,"exit",[608.0,0.0,272.0,48.0])
	_recovery(m,880.0)
	m.steps = [_walk("entry",[208.0,-18.0]),
		_step("jump_gap","entry","low_crest",[208.0,-18.0],[344.0,-50.0]),
		_walk("low_crest",[504.0,-50.0]),
		_step("jump_gap","low_crest","exit",[504.0,-50.0],[640.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	_reward(m,"low_crest",[432.0,-50.0],1)
	return m

static func _mushroom_fork() -> Dictionary:
	var m := _base(960.0)
	_p(m,"entry",[0.0,0.0,240.0,40.0])
	_p(m,"mushroom_a",[304.0,-48.0,200.0,20.0],true)
	_p(m,"mushroom_b",[584.0,-48.0,200.0,20.0],true)
	_p(m,"exit",[848.0,0.0,112.0,40.0])
	_p(m,"lower_root",[208.0,48.0,672.0,40.0])
	_recovery(m,960.0)
	m.steps = [_walk("entry",[208.0,-18.0]),
		_step("jump_gap","entry","mushroom_a",[208.0,-18.0],[336.0,-66.0]),
		_walk("mushroom_a",[472.0,-66.0]),
		_step("jump_gap","mushroom_a","mushroom_b",[472.0,-66.0],[616.0,-66.0]),
		_walk("mushroom_b",[752.0,-66.0]),
		_step("jump_gap","mushroom_b","exit",[752.0,-66.0],[880.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.lower_bypass = [_drop("entry","lower_root",[224.0,-18.0],[272.0,30.0]),
		_walk("lower_root",[816.0,30.0]),_step("jump_rise","lower_root","exit",[816.0,30.0],[872.0,-18.0]),_walk("exit",m.goal)]
	_reward(m,"mushroom_b",[672.0,-66.0],2)
	return m

static func _low_root_tunnel() -> Dictionary:
	var m := _base(960.0,-220.0)
	_p(m,"entry",[0.0,0.0,400.0,40.0])
	_p(m,"exit",[496.0,0.0,464.0,40.0])
	_p(m,"tunnel_roof",[256.0,-160.0,448.0,32.0])
	_recovery(m,960.0)
	m.steps = [_walk("entry",[368.0,-18.0]),
		_step("jump_gap","entry","exit",[368.0,-18.0],[528.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.observation_voids = [[256.0,-128.0,448.0,128.0]]
	_reward(m,"exit",[624.0,-18.0],1)
	return m

static func _root_basin_return() -> Dictionary:
	var m := _base(1040.0,-200.0,260.0)
	_p(m,"entry",[0.0,0.0,224.0,32.0],true)
	_p(m,"basin",[160.0,96.0,400.0,64.0])
	_p(m,"low_exit",[496.0,48.0,224.0,32.0],true)
	_p(m,"exit",[688.0,0.0,352.0,48.0])
	# The return mushroom is a real intermediate landing, not empty air on
	# the way to the basin. Read the descent as two gentle, stable steps.
	m.steps = [_drop("entry","return_mushroom",[208.0,-18.0],[256.0,30.0]),
		_drop("return_mushroom","basin",[256.0,30.0],[320.0,78.0]),_walk("basin",[528.0,78.0]),
		_step("jump_rise","basin","low_exit",[528.0,78.0],[592.0,30.0]),
		_step("jump_rise","low_exit","exit",[656.0,30.0],[736.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	_p(m,"return_mushroom",[144.0,48.0,144.0,16.0],true)
	m.routes.returning = [_drop("exit","low_exit",[720.0,-18.0],[640.0,30.0]),
		_drop("low_exit","basin",[528.0,30.0],[480.0,78.0]),_walk("basin",[224.0,78.0]),
		_step("jump_rise","basin","return_mushroom",[224.0,78.0],[208.0,30.0]),
		_step("jump_rise","return_mushroom","entry",[192.0,30.0],[160.0,-18.0])]
	m.routes.recovery = [_walk("basin",[224.0,78.0]),
		_step("jump_rise","basin","return_mushroom",[224.0,78.0],[208.0,30.0]),
		_step("jump_rise","return_mushroom","entry",[192.0,30.0],[160.0,-18.0])]
	_reward(m,"basin",[352.0,78.0],1)
	return m

static func _side_fruit_crossing() -> Dictionary:
	var m := _base(960.0,-320.0,260.0)
	_p(m,"entry",[0.0,0.0,240.0,48.0])
	_p(m,"low_root_a",[272.0,48.0,160.0,24.0],true)
	_p(m,"receiver",[464.0,-16.0,224.0,32.0],true)
	_p(m,"exit",[752.0,0.0,208.0,48.0])
	_fruit(m,"side_fruit",[400.0,-64.0],"receiver",[464.0,-16.0])
	_recovery(m,960.0)
	m.steps = [_step("jump_gap","entry","low_root_a",[208.0,-18.0],[304.0,30.0]),
		_step("jump_rise","low_root_a","receiver",[400.0,30.0],[496.0,-34.0]),
		_walk("receiver",[656.0,-34.0]),
		_step("jump_gap","receiver","exit",[656.0,-34.0],[784.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.action_program = [{"action":"H","anchor":"side_fruit"},{"action":"R","direction":[-1.0,0.0]}]
	m.routes.returning = [_step("jump_gap","exit","receiver",[784.0,-18.0],[656.0,-34.0]),
		_drop("receiver","low_root_a",[496.0,-34.0],[400.0,30.0]),_step("jump_rise","low_root_a","entry",[304.0,30.0],[208.0,-18.0])]
	_reward(m,"receiver",[576.0,-34.0],3)
	return m

static func _double_fruit_s() -> Dictionary:
	var m := _base(1120.0,-320.0,260.0)
	_p(m,"entry",[0.0,0.0,224.0,48.0])
	_p(m,"observation",[304.0,-64.0,192.0,24.0],true)
	_p(m,"lower_cross",[576.0,0.0,192.0,40.0])
	_p(m,"exit",[848.0,0.0,272.0,48.0])
	_p(m,"upper_reward",[544.0,-144.0,192.0,24.0],true)
	_fruit(m,"fruit_west",[256.0,-96.0],"observation",[304.0,-64.0])
	_fruit(m,"fruit_east",[544.0,-80.0],"lower_cross",[576.0,0.0])
	_recovery(m,1120.0)
	m.steps = [_step("jump_gap","entry","observation",[192.0,-18.0],[336.0,-82.0]),
		_walk("observation",[464.0,-82.0]),_step("jump_gap","observation","lower_cross",[464.0,-82.0],[608.0,-18.0]),
		_walk("lower_cross",[736.0,-18.0]),_step("jump_gap","lower_cross","exit",[736.0,-18.0],[880.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.upper_reward = [
		_step("jump_gap","observation","upper_reward",[464.0,-82.0],[576.0,-162.0]),
		_walk("upper_reward",[640.0,-162.0]),
		_drop("upper_reward","lower_cross",[704.0,-162.0],[704.0,-18.0])]
	m.action_program = [{"action":"H","anchor":"fruit_west"},{"action":"H","anchor":"fruit_east"}]
	m.routes.returning = [_drop("exit","catch",[880.0,-18.0],[816.0,126.0])]+m.routes.recovery
	_reward(m,"upper_reward",[640.0,-162.0],4)
	return m

static func _double_window() -> Dictionary:
	var m := _base(1120.0,-320.0,320.0)
	_p(m,"entry",[0.0,0.0,240.0,48.0])
	_p(m,"upper_bank",[304.0,-64.0,192.0,24.0],true)
	_p(m,"trunk_upper",[496.0,-256.0,160.0,64.0])
	_p(m,"trunk_middle",[496.0,-48.0,160.0,64.0])
	_p(m,"trunk_lower",[496.0,128.0,160.0,64.0])
	_p(m,"upper_receiver",[656.0,-64.0,208.0,24.0],true)
	_p(m,"lower_bank",[208.0,64.0,656.0,20.0],true)
	_p(m,"exit",[896.0,0.0,224.0,48.0])
	_p(m,"exit_step",[816.0,64.0,160.0,20.0],true)
	_fruit(m,"upper_window_fruit",[704.0,-128.0],"upper_receiver",[704.0,-64.0])
	_fruit(m,"lower_window_fruit",[720.0,48.0],"exit_step",[816.0,64.0])
	# A catch at y144 would intersect the lower trunk (y128..192).
	# The entire standing body now passes below that trunk, not through it.
	_deep_recovery(m,240.0)
	# The upper opening has a real horizontal standable crossing, rather than
	# a fictitious edge straight through the solid middle of the tree.
	_p(m,"upper_window_floor",[496.0,-64.0,160.0,16.0],true)
	m.steps = [_step("jump_gap","entry","upper_bank",[208.0,-18.0],[336.0,-82.0]),
		_walk("upper_bank",[464.0,-82.0]),_walk("upper_window_floor",[576.0,-82.0]),
		_walk("upper_receiver",[816.0,-82.0]),_step("jump_gap","upper_receiver","exit",[832.0,-82.0],[928.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.lower_bypass = [_drop("entry","lower_bank",[224.0,-18.0],[272.0,46.0]),
		_walk("lower_bank",[816.0,46.0]),_walk("exit_step",[880.0,46.0]),
		_step("jump_rise","exit_step","exit",[880.0,46.0],[960.0,-18.0]),_walk("exit",m.goal)]
	m.action_program = [{"action":"H","anchor":"upper_window_fruit"}]
	m.observation_voids = [[496.0,-192.0,160.0,128.0],[496.0,16.0,160.0,112.0]]
	_reward(m,"upper_receiver",[768.0,-82.0],4)
	return m

static func _canopy_detour() -> Dictionary:
	var m := _base(1280.0,-400.0,280.0)
	_p(m,"entry",[0.0,0.0,240.0,48.0])
	_p(m,"lower_root",[208.0,64.0,800.0,40.0])
	_p(m,"exit_step",[944.0,0.0,160.0,24.0],true)
	_p(m,"exit",[1072.0,0.0,208.0,48.0])
	_p(m,"crown_west",[304.0,-64.0,192.0,24.0],true)
	_p(m,"crown_middle",[560.0,-128.0,224.0,24.0],true)
	_p(m,"crown_east",[848.0,-64.0,192.0,24.0],true)
	_fruit(m,"crown_side_fruit",[528.0,-176.0],"crown_middle",[560.0,-128.0])
	_recovery(m,1280.0)
	m.steps = [_drop("entry","lower_root",[224.0,-18.0],[272.0,46.0]),
		_walk("lower_root",[976.0,46.0]),_step("jump_rise","lower_root","exit_step",[976.0,46.0],[1008.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.upper_reward = [_step("jump_gap","entry","crown_west",[208.0,-18.0],[336.0,-82.0]),
		_walk("crown_west",[464.0,-82.0]),_step("jump_gap","crown_west","crown_middle",[464.0,-82.0],[592.0,-146.0]),
		_walk("crown_middle",[752.0,-146.0]),_step("jump_gap","crown_middle","crown_east",[752.0,-146.0],[880.0,-82.0]),
		_drop("crown_east","exit",[1008.0,-82.0],[1120.0,-18.0]),_walk("exit",m.goal)]
	m.action_program = [{"action":"H","anchor":"crown_side_fruit"},{"action":"R","direction":[0.0,1.0]}]
	_reward(m,"crown_middle",[672.0,-146.0],5)
	return m

static func _thorn_side_passage() -> Dictionary:
	var m := _base(960.0,-320.0,400.0)
	_p(m,"entry",[0.0,0.0,224.0,48.0])
	_p(m,"mouth_roof",[288.0,-208.0,256.0,48.0])
	_p(m,"mouth_root",[288.0,-16.0,256.0,192.0])
	_p(m,"receiver",[592.0,-48.0,176.0,48.0])
	_p(m,"exit",[816.0,0.0,144.0,48.0])
	_fruit(m,"mouth_fruit",[272.0,-88.0],"mouth_root",[288.0,-16.0])
	m.dangers = [[320.0,-160.0,192.0,16.0],[320.0,-40.0,192.0,24.0]]
	m.danger_surfaces = [{"danger_index":0,"host_support_id":"mouth_roof","face":"down"},
		{"danger_index":1,"host_support_id":"mouth_root","face":"up"}]
	_deep_recovery(m,304.0)
	m.action_program = [{"action":"H","anchor":"mouth_fruit"},{"action":"R","direction":[-1.0,0.0]}]
	m.steps = [_step("jump_gap","receiver","exit",[736.0,-66.0],[848.0,-18.0]),_walk("exit",m.goal)]
	m.routes.receiver_to_exit = m.steps.duplicate(true)
	m.observation_voids = [[288.0,-144.0,256.0,104.0]]
	_reward(m,"receiver",[672.0,-66.0],7,1)
	m.risk_reward.optional = true
	return m

static func _backbranch_turn() -> Dictionary:
	# Reuse its authored body/anchor/action coordinates exactly, only translating
	# the complete piece into this library's local reference frame.
	var raw := ForestBibleBackbranchGeometry.build()
	var delta := Vector2(-1640.0,-982.0)
	var m := _base(800.0,-182.0,458.0)
	m.spawn = _pair(_point(raw.spawn)+delta)
	m.goal = _pair(_point(raw.goal)+delta)
	m.entry_support_id = "entry"
	m.exit_support_id = "crown"
	for row: Dictionary in raw.platforms:
		var rect := _rect(row.rect)
		rect.position += delta
		_p(m,str(row.id),[rect.position.x,rect.position.y,rect.size.x,rect.size.y],bool(row.one_way))
	_fruit(m,"side_fruit",[246.0,78.0],"entry",[246.0,42.0])
	m.action_program = raw.action_program.duplicate(true)
	m.departure = raw.departure.duplicate(true)
	for i: int in m.departure.path.size(): m.departure.path[i] = _pair(_point(m.departure.path[i])+delta)
	m.departure.landing = _pair(_point(m.departure.landing)+delta)
	m.source_geometry = {"factory":"res://scripts/generation/forest_bible_backbranch_geometry.gd","version":raw.version,"translation":_pair(delta)}
	m.routes.recovery = [_walk("recovery",[540.0,320.0]),
		_step("jump_rise","recovery","recovery_step",[540.0,320.0],[540.0,220.0]),
		_step("jump_rise","recovery_step","retry_step",[540.0,220.0],[540.0,110.0]),
		_step("jump_gap","retry_step","entry",[520.0,110.0],[380.0,0.0])]
	_reward(m,"crown",m.goal.duplicate(),8,1)
	m.risk_reward.optional = true
	return m

static func _crown_hook_relay() -> Dictionary:
	var m := _base(1120.0,-420.0,300.0)
	_p(m,"entry",[0.0,0.0,224.0,48.0])
	_p(m,"branch_a",[368.0,-112.0,128.0,24.0],true)
	_p(m,"branch_b",[656.0,-192.0,144.0,24.0],true)
	_p(m,"exit",[880.0,-112.0,240.0,48.0])
	m.goal = [1080.0,-130.0]
	_fruit(m,"relay_a",[304.0,-112.0],"branch_a",[368.0,-112.0])
	_fruit(m,"relay_b",[592.0,-192.0],"branch_b",[656.0,-192.0])
	_fruit(m,"relay_c",[816.0,-224.0],"exit",[880.0,-112.0])
	_deep_recovery(m,208.0)
	m.action_program = [{"action":"H","anchor":"relay_a"},{"action":"R","direction":[-1.0,0.0]},
		{"action":"H","anchor":"relay_b"},{"action":"H","anchor":"relay_c"}]
	_reward(m,"branch_b",[736.0,-210.0],8,1)
	m.risk_reward.optional = true
	return m

static func _deep_root_switchback() -> Dictionary:
	var m := _base(1120.0,-400.0,520.0)
	_p(m,"entry",[0.0,0.0,224.0,32.0],true)
	_p(m,"basin",[160.0,352.0,800.0,64.0])
	_p(m,"east_low",[800.0,224.0,192.0,24.0],true)
	_p(m,"west_middle",[336.0,112.0,160.0,24.0],true)
	_p(m,"east_crown",[688.0,-64.0,176.0,48.0])
	_p(m,"exit",[928.0,0.0,192.0,48.0])
	_fruit(m,"lower_east",[752.0,224.0],"east_low",[800.0,224.0])
	_fruit(m,"middle_west",[528.0,96.0],"west_middle",[496.0,112.0])
	_fruit(m,"upper_east",[640.0,-96.0],"east_crown",[688.0,-64.0])
	_p(m,"return_low",[160.0,240.0,128.0,20.0],true)
	_p(m,"return_high",[112.0,128.0,128.0,20.0],true)
	m.departure = _drop("entry","basin",[208.0,-18.0],[272.0,334.0])
	m.action_start = [592.0,334.0]
	m.approach_steps = [m.departure.duplicate(true),_walk("basin",m.action_start.duplicate())]
	m.action_program = [{"action":"H","anchor":"lower_east"},{"action":"R","direction":[1.0,0.5]},
		{"action":"H","anchor":"middle_west"},{"action":"H","anchor":"upper_east"},{"action":"R","direction":[0.0,1.0]}]
	m.routes.recovery = [_walk("basin",[224.0,334.0]),
		_step("jump_rise","basin","return_low",[224.0,334.0],[224.0,222.0]),
		_step("jump_rise","return_low","return_high",[192.0,222.0],[176.0,110.0]),
		_step("jump_rise","return_high","entry",[176.0,110.0],[176.0,-18.0])]
	m.steps = [_step("jump_gap","east_crown","exit",[832.0,-82.0],[960.0,-18.0]),_walk("exit",m.goal)]
	m.routes.receiver_to_exit = m.steps.duplicate(true)
	_reward(m,"east_crown",[768.0,-82.0],10,2)
	m.risk_reward.optional = true
	return m

static func _pair(point: Vector2) -> Array:
	return [point.x,point.y]

static func _point(pair: Array) -> Vector2:
	return Vector2(float(pair[0]),float(pair[1]))

static func _rect(row: Array) -> Rect2:
	return Rect2(float(row[0]),float(row[1]),float(row[2]),float(row[3]))

static func _backlook_fruit_cache() -> Dictionary:
	var m := _base(1120.0,-320.0,260.0)
	_p(m,"entry",[0.0,0.0,256.0,48.0])
	_p(m,"lower_root",[208.0,64.0,608.0,48.0])
	_p(m,"lower_receiver",[784.0,0.0,160.0,20.0],true)
	_p(m,"exit",[928.0,0.0,192.0,48.0])
	_p(m,"upper_receiver",[336.0,-64.0,208.0,24.0],true)
	_p(m,"cache_perch",[144.0,-192.0,128.0,24.0],true)
	_fruit(m,"overlook_side_fruit",[304.0,-80.0],"upper_receiver",[336.0,-64.0])
	# lower_root ends at y112. A y144 catch gives a 36wu body only
	# 32wu beneath it; y160 leaves the complete body twelve wu clear.
	_deep_recovery(m,160.0)
	m.steps = [_drop("entry","lower_root",[240.0,-18.0],[288.0,46.0]),
		_walk("lower_root",[784.0,46.0]),
		_step("jump_rise","lower_root","lower_receiver",[784.0,46.0],[848.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	m.routes.backlook_cache = [_walk("entry",[240.0,-18.0]),
		_step("jump_gap","entry","upper_receiver",[240.0,-18.0],[352.0,-82.0]),
		_step("jump_gap","upper_receiver","cache_perch",[352.0,-82.0],[256.0,-210.0]),
		_walk("cache_perch",[208.0,-210.0])]
	m.routes.cache_return = [_drop("cache_perch","entry",[208.0,-210.0],[160.0,-18.0]),_walk("entry",m.spawn)]
	m.action_program = [{"action":"H","anchor":"overlook_side_fruit"},{"action":"R","direction":[0.0,1.0]}]
	_reward(m,"cache_perch",[208.0,-210.0],4)
	m.risk_reward.optional = true
	m.choice_contract = {"main_route":"main","reward_route":"backlook_cache","return_route":"cache_return",
		"reward_support_id":"cache_perch","reward_position":[208.0,-210.0],
		"route_ports":{"backlook_cache":{"start_support":"entry","start":[40.0,-18.0],"goal_support":"cache_perch","goal":[208.0,-210.0]},
			"cache_return":{"start_support":"cache_perch","start":[208.0,-210.0],"goal_support":"entry","goal":[40.0,-18.0]}},
		"reward_not_on_main_route":true,"reward_consumer_required":"bind the 4 actual coins to cache_perch; never move them to the common exit"}
	m.play_contract = {"observe":"read the high cache from departure, then notice the side fruit and higher receiver to the right",
		"challenge":"choose the low root bypass or gain the receiver and reverse direction for the cache",
		"recovery":"drop from the reward through its one-way branch to the original entry, then take the lower route",
		"choice":"progress right now versus spend an upward-and-backward detour for four coins",
		"cheapest_strategy":"ordinary lower route reaches exit without automatically visiting the upper cache; real jump-plus-recoil shortcuts remain valid alternatives",
		"hook_alternative":"the side fruit is a shorter way to reach the observation receiver; supported jumps and direct recoil remain available",
		"jump_screening":"entry-to-cache rises192wu, receiver-to-cache128wu; compare current full-held first-jump envelope, then verify real Motor"}
	m.ecology_slots = [
		{"id":"lower_root_patrol","behavior_id":"charger","support_id":"lower_root","position":[624.0,46.0],"patrol_radius":64.0,"optional":true,"role":"pressure the lower bypass after the safe departure; upper route can avoid it"},
		{"id":"overlook_lantern","behavior_id":"forest_lantern","support_id":"upper_receiver","position":[448.0,-144.0],"patrol_radius":48.0,"aerial":true,"optional":true,"role":"living-anchor option near the upper receiver; fixed fruit and ground bypass survive its defeat"}]
	return m

static func _borrow_pod_crossing() -> Dictionary:
	var m := _base(1280.0,-480.0,320.0)
	_p(m,"entry",[0.0,0.0,288.0,48.0])
	_p(m,"root_step_a",[560.0,96.0,160.0,20.0],true)
	_p(m,"root_step_b",[624.0,32.0,128.0,20.0],true)
	_p(m,"observation_root",[784.0,0.0,336.0,48.0])
	_p(m,"exit",[1120.0,0.0,160.0,48.0])
	_p(m,"reward_receiver",[800.0,-192.0,256.0,24.0],true)
	_p(m,"pod_host",[416.0,-400.0,448.0,64.0])
	_deep_recovery(m,160.0)
	_fruit(m,"fallback_fruit",[1088.0,-240.0],"reward_receiver",[1048.0,-184.0])
	m.hook_anchors[-1].hang_enabled = true
	m.steps = [_drop("entry","catch",[276.0,-18.0],[336.0,142.0]),
		_walk("catch",[592.0,142.0]),
		_step("jump_rise","catch","root_step_a",[592.0,142.0],[624.0,78.0]),
		_step("jump_rise","root_step_a","root_step_b",[672.0,78.0],[688.0,14.0]),
		_step("jump_gap","root_step_b","observation_root",[720.0,14.0],[816.0,-18.0]),_walk("exit",m.goal)]
	m.routes.main = m.steps.duplicate(true)
	var approach: Array = m.steps.slice(0,5).duplicate(true)
	m.routes.pod_approach = approach+[_walk("observation_root",[848.0,-18.0])]
	m.routes.fixed_fruit_approach = approach+[_walk("observation_root",[1072.0,-18.0])]
	m.routes.reward_return = [_drop("reward_receiver","observation_root",[928.0,-210.0],[944.0,-18.0]),_walk("exit",m.goal)]
	# The live target is an existing enemy, not an invented fixed GrappleAnchor
	# or a request to stand/hang on a moving body. Its exchanged movement must
	# be driven and observed by the real live-target consumer in the world.
	m.action_program = [{"action":"H","anchor":"fallback_fruit"}]
	var definition_path := "res://resources/enemies/forest_swing_pod.tres"
	var pod_definition := load(definition_path) as ForestEnemyDefinition
	var traversal := load("res://resources/player/traversal.tres") as TraversalDefinition
	var home := Vector2(640.0,-160.0)
	var radius: float = pod_definition.patrol_half_width
	var sweep := Rect2(home-Vector2(radius,pod_definition.swing_rise)-pod_definition.collision_size*0.5,
		Vector2(radius*2.0,pod_definition.swing_rise)+pod_definition.collision_size)
	m.ecology_slots = [{"id":"borrow_pod","behavior_id":"forest_swing_pod","position":_pair(home),
		"patrol_radius":radius,"tether_host_support_id":"pod_host","tether_origin":[640.0,-344.0],
		"shore_support_ids":["observation_root","reward_receiver"],"fixed_alternative_anchor_ids":["fallback_fruit"],
		"role":"Catch from the right when the pod is high on its rightward arc; auto contact kicks right/up for24wu, never a moving hang.",
		"optional":true,"ordinary_route_survives_defeat":true}]
	m.interaction_contract = {"kind":"existing_live_pod_exchange","enemy_slot":"borrow_pod",
		"behaviour_definition":definition_path,"behaviour_definition_sha256":FileAccess.get_sha256(definition_path),
		"approach_route":"pod_approach","fallback_approach_route":"fixed_fruit_approach","return_route":"reward_return",
		"observation":{"support_id":"observation_root","position":[848.0,-18.0]},
		"fixed_observation":{"support_id":"observation_root","position":[1072.0,-18.0]},
		"reward":{"support_id":"reward_receiver","position":[928.0,-210.0]},
		"route_ports":{"pod_approach":{"start_support":"entry","start":[40.0,-18.0],"goal_support":"observation_root","goal":[848.0,-18.0]},
			"fixed_fruit_approach":{"start_support":"entry","start":[40.0,-18.0],"goal_support":"observation_root","goal":[1072.0,-18.0]},
			"reward_return":{"start_support":"reward_receiver","start":[928.0,-210.0],"goal_support":"exit","goal":[1240.0,-18.0]}},
		"authored_body_sweep":[sweep.position.x,sweep.position.y,sweep.size.x,sweep.size.y],
		"contact_mode":"existing_auto_contact_away_kick","fixed_hang_only_on_fallback_fruit":true,
		"normal_kick_displacement":_pair(traversal.hook_kick*traversal.hook_launch_seconds),"target_motion_is_not_carriage":true,
		"live_high_phase":"right-hand upper arc; actual interception and landing require Motor evidence",
		"bad_phase":"middle/lower arc gives less height; decline, spend real recoil or use the fixed route",
		"defeat_alternative":"walk farther right to the independently mounted fixed fruit; ordinary main route stays open",
		"loot_policy":"real existing enemy drop settlement; no guaranteed kill coins and no health/phase override",
		"reward_consumer_required":"bind5coin/1note to reward_receiver, not the common exit",
		"native_interactions":"unverified"}
	_reward(m,"reward_receiver",[928.0,-210.0],5,1)
	m.risk_reward.optional = true
	m.play_contract = {"observe":"from a broad right-hand root, read a live pod turning naturally above the root hollow and a distinct high receiving branch",
		"challenge":"cast left into a useful high swing, then use the actual right/up contact kick and ordinary input to receive on the upper right root",
		"recovery":"missed height falls to the broad root hollow; actual side steps and the ordinary route remain usable",
		"choice":"take an already favourable live opportunity, move farther right for a fixed fruit, spend real recoil or skip the reward",
		"cheapest_strategy":"fixed fruit may be faster than waiting through a bad phase; compare actual phase-bound runs instead of asserting the live target always wins",
		"resource_consequence":"H damages a fresh2HP pod by existing1HP; a repeat H can kill it, so no repeated harmless borrowing is promised",
		"return":"drop from the high reward one-way root onto the familiar observation root, then continue east"}
	return m
