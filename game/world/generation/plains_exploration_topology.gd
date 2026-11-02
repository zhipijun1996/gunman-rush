class_name PlainsExplorationTopology
extends RefCounted
## Authored semantic footprints. Addresses are not a world-coordinate lattice.
## Each has a different belfry/creek/convergence outline before bounded route choices.
static func make(rng: RunRandomStream, family: String, count: int) -> Dictionary:
	var rows: Array
	if family=="woven_layers": rows=[[0,1,2],[0,1,2,3,4],[1,2,3,4],[2,3,4]]
	elif family=="linked_rings": rows=[[0,1,2,3],[0,1,2,3,4],[1,2,3,4],[2,3]]
	else: rows=[[0,1,2],[0,1,2,3,4],[0,1,2,3,4],[3,4]]
	if count==18:
		# Three authored outer-arm chambers: extend a return circuit, not random void filling.
		if family=="woven_layers": rows[0].append_array([3,4]);rows[3].push_front(1)
		elif family=="linked_rings": rows[0].append(4);rows[3].append_array([1,4]);rows[3].sort()
		else: rows[0].append_array([3,4]);rows[3].push_front(2)
	var cells: Array=[]
	for row: int in rows.size():
		for col: int in rows[row]: cells.append([col,row])
	var upper_rise:=510.0 if rng.next_int(2)==0 else 700.0
	var lower_rise:=510.0 if rng.next_int(2)==0 else 700.0
	var return_rise:=510.0 if rng.next_int(2)==0 else 700.0
	var heights: Array=[-upper_rise,0.0,lower_rise,lower_rise+return_rise]
	return {"cells":cells,"recipe":"courtyard_weave" if family=="woven_layers" else "offset_well_rings" if family=="linked_rings" else "hub_satellites","grid_width":5,"grid_height":4,"footprint_fallback":false,"semantic_version":"plains-authored-macros-v1","terrace_heights":heights,"challenge_routes":[{"tier":"high","entry":"area_0_0","return":"area_1_1","purpose":"upper_short_chain_to_known_recovery"},{"tier":"region_top","entry":"area_2_0","return":"area_3_1","purpose":"upper_mastery_to_forward_meadow"}],"macro_intent":"alternating_court_and_creek" if family=="woven_layers" else "descending_ring_separate_return" if family=="linked_rings" else "repair_hub_outer_satellites"}
static func route_specs() -> Dictionary:
	# Define actual split/rejoin promises BEFORE pruning or assigning locks.
	# Alternative discovery takes distinct terrain/shot-angle/water mechanics;
	# the concise teaching route always reaches the known protected camp.
	return {
		"short_technique":{"areas":["area_0_1","area_1_1","area_2_1"],"purpose":"dual_use_shot_then_short_timing_to_recovery","initial_open":true},
		"upper_discovery":{"areas":["area_0_1","area_0_0","area_1_0","area_2_0","area_2_1"],"purpose":"longer_clock_sightline_discovery_rejoins_camp","initial_open":true},
		"creek_return":{"areas":["area_1_1","area_1_2","area_2_2","area_2_1"],"purpose":"water_phase_detour_from_shortchain_rejoins_camp","initial_open":true}
	}

static func connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty(): return false
	var seen: Dictionary={cells[0]:true}
	for unused: int in cells.size():
		for c: Vector2i in cells:
			if seen.has(c): continue
			for delta: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if seen.has(c+delta): seen[c]=true;break
	return seen.size()==cells.size()
static func cycles(cells: Array[Vector2i]) -> int:
	var edges:=0
	for c: Vector2i in cells:
		if c+Vector2i.RIGHT in cells: edges+=1
		if c+Vector2i.DOWN in cells: edges+=1
	return edges-cells.size()+1

static func boss_cell(cells: Array[Vector2i]) -> bool:
	var far:=0
	for c: Vector2i in cells: far=maxi(far,c.x)
	for c: Vector2i in cells:
		if c.x!=far: continue
		var degree:=0
		for d: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if c+d in cells: degree+=1
		if degree>=2: return true
	return false
