class_name PlainsRegionGenerator
extends RefCounted
## Topology is committed before terrain/content. No player tuning changes.
const VERSION := "plains-region-v2"
const RNG_VERSION := "plains-region-v1"
const FAMILIES := ["woven_layers", "linked_rings", "crossroads"]
const DX := 1400.0
const DY := 700.0
const HALF := 200.0
const ATTEMPTS := 4

func generate(seed_value: String, tuning: PlayerTuning, sample := false, force_family := "", difficulty := "advanced") -> Dictionary:
	if difficulty not in ["intro","advanced"] or seed_value.is_empty() or tuning.max_jumps < 1 or tuning.max_air_shots < 1:
		return {"ok": false, "error": "Plains requires the existing base jump and recoil shot"}
	for attempt: int in ATTEMPTS:
		var m := _candidate(seed_value, sample, force_family, attempt,difficulty)
		if validate(m, tuning): return _result(m)
	return verified_fallback(seed_value,tuning,difficulty)

func verified_fallback(seed_value: String,tuning: PlayerTuning,difficulty := "advanced") -> Dictionary:
	var fallback := _candidate("region-woven_layers", false, "woven_layers", 0,difficulty)
	fallback.seed = seed_value
	fallback.fallback_id = "verified_exploration_region"
	fallback.manifest_hash = _hash(fallback)
	return _result(fallback) if validate(fallback, tuning) else {"ok": false, "error": "Region fallback failed validation"}

func _candidate(seed_value: String, sample: bool, forced: String, attempt: int,difficulty := "advanced") -> Dictionary:
	var topology := RunRandomStream.new(seed_value, "region_topology", str(attempt), RNG_VERSION)
	var content := RunRandomStream.new(seed_value, "region_content", str(attempt), RNG_VERSION)
	var reward := RunRandomStream.new(seed_value, "region_reward", str(attempt), RNG_VERSION)
	var drawn_family: String=FAMILIES[topology.next_int(3)]
	var family: String = forced if forced in FAMILIES else drawn_family
	var cols := 3 if sample else 5 + topology.next_int(2)
	if difficulty=="intro" and not sample: cols=5
	var prep_row := 1 if sample else topology.next_int(3)
	var m := {"version": VERSION, "difficulty":difficulty, "player_tuning_hash":FileAccess.get_sha256("res://config/player_tuning.json"), "seed": seed_value, "region": "plains", "layout_id": "connected_region", "family": family, "attempt": attempt, "fallback_id": "", "sample": sample, "areas": [], "connections": [], "nodes": [], "rewards": [], "pickups": [], "enemies": [], "terminal_exits": [], "budget": {"ordinary_coins": 24, "medium": 2, "high": 1, "region_top": 1, "finite_hearts": 3}, "streams": {"topology": "region_topology", "content": "region_content", "reward": "region_reward", "phases": "region_phases", "generation_seed": seed_value,"derivation_version":RNG_VERSION}}
	for row: int in 3:
		for col: int in cols:
			var id := "area_%s_%s" % [col, row]
			var label: String = ["HIGH WIND", "GRASS SLOPE", "REPAIR TUNNEL"][row]
			if col % 3 == 1: label = ["BELL TOWER", "WINDMILL", "CREEK BED"][row]
			if col % 3 == 2: label = ["BELL WOODS", "CREEK CROSSING", "UNDERWORKS"][row]
			m.areas.append({"id": id, "position": [col * DX, (row - 1) * DY], "label": label, "row": row, "col": col, "role": "junction", "ports": []})
	# Start with planar grid, prune according to genuinely different graph policies.
	var candidates: Array = []
	for row: int in 3:
		for col: int in cols - 1:
			candidates.append(["area_%s_%s" % [col, row], "area_%s_%s" % [col + 1, row], "horizontal", col, row])
	for row: int in 2:
		for col: int in cols:
			candidates.append(["area_%s_%s" % [col, row + 1], "area_%s_%s" % [col, row], "stairs", col, row])
	for c: Array in candidates:
		var keep := true
		if family == "woven_layers":
			keep = c[2] == "horizontal" or (int(c[3]) + int(c[4])) % 2 == 0 or int(c[3]) == cols - 1
		elif family == "linked_rings":
			keep = c[2] == "stairs" or int(c[4]) != 0 or int(c[3]) % 2 == 0
		else:
			keep = c[2] == "stairs" or int(c[4]) != 1 or int(c[3]) % 2 == 0
		if keep or sample: _edge(m, c[0], c[1], c[2])
	# Seed changes traversal, not only content. Remove non-bridge edges while
	# retaining three independent cycles and two incoming prep routes.
	for unused: int in 4 if not sample else 0:
		var at := topology.next_int(m.connections.size())
		var candidate: Dictionary = m.connections[at]
		m.connections.remove_at(at)
		if not _connected(m) or _cycles(m) < (3 if family == "woven_layers" else 5) or _degree(m, "area_%s_%s" % [cols-1,prep_row]) < 2:
			m.connections.insert(at, candidate)
	if sample:
		_edge(m, "area_0_1", "area_1_0", "diagonal", "open", false)
	# Two genuine extra vertical shortcuts; locked from their upper side.
	var shortcuts := 0
	for c: Array in candidates:
		if c[2] != "stairs" or _has_edge(m, c[0], c[1]): continue
		_edge(m, c[0], c[1], "stairs", "backside")
		shortcuts += 1
		if shortcuts == 2: break
	if shortcuts < 2:
		# Convert redundant stair connections into locked shortcuts, never a bridge.
		for e: Dictionary in m.connections:
			if shortcuts == 2: break
			if e.kind != "stairs" or e.condition != "open" or (sample and e.b == "area_1_0") or "area_%s_%s" % [cols-1,prep_row] in [e.a,e.b]: continue
			e.condition = "backside"
			if not _connected(m) or _cycles(m) < 3: e.condition = "open"
			else: shortcuts += 1
	m.prep_id = "area_%s_%s" % [cols-1,prep_row]
	m.merchant_id = "area_%s_1" % (1 + content.next_int(maxi(1, cols - 2)))
	_area(m, m.prep_id).role = "prep"
	_area(m, m.prep_id).label = "WINDKEEPER APPROACH"
	_area(m, m.merchant_id).role = "merchant"
	_area(m, m.merchant_id).label = "CAMP / MERCHANT"
	# Multipoint platforms and real ascending/descending stair shafts.
	for a: Dictionary in m.areas:
		var drop: bool = m.connections.any(func(e: Dictionary) -> bool: return e.kind == "stairs" and e.b == a.id)
		var d := _floor_definition("region_junction", Rect2(-HALF, 18, HALF * 2, 32), drop)
		_add_inline(m, a.id, _point(a.position), d)
	for e: Dictionary in m.connections:
		_fill_edge(m, e, content)
	# Compact tutorial is a single world prefix, not a separately loaded level.
	var first := _area(m, "area_0_1")
	var tutorial_start := Vector2(-1870, 0)
	m.spawn = [tutorial_start.x + 20, tutorial_start.y]
	m.areas.append({"id": "tutorial_jump", "position": m.spawn, "label": "HOLD JUMP / LAND / AIM BACK TO RECOIL", "role": "tutorial", "ports": []})
	m.areas.append({"id": "tutorial_bell", "position": [-660, 0], "label": "FIRST ENEMY / SHOOT THE BELL", "role": "tutorial", "ports": []})
	_edge(m, "tutorial_jump", "tutorial_bell", "tutorial")
	_edge(m, "tutorial_bell", first.id, "tutorial")
	_add_existing(m, "tutorial_gap", "plains_meadow_gap", tutorial_start)
	_add_existing(m, "tutorial_recoil", "plains_recoil_span", tutorial_start + Vector2(470, 0))
	_add_existing(m, "tutorial_bell_module", "plains_windchime_lesson", Vector2(-600, 0))
	_add_inline(m, "tutorial_join", Vector2(-120, 0), _floor_definition("region_join", Rect2(0,18,100,32)))
	# Safe catch below recoil lesson, with basic stair return; no free refill.
	var catch := _floor_definition("region_tutorial_recovery", Rect2(0, 138, 310, 24))
	catch.world_bounds.size.x = 420
	catch.platforms.append(Rect2(275, 78, 90, 18))
	_add_inline(m, "tutorial_recovery", Vector2(-1100, 0), catch)
	var prep := _point(_area(m, m.prep_id).position)
	var arena_offset := prep + Vector2(HALF, -582)
	_add_existing(m, "windkeeper_arena", "plains_boss_arena", prep + Vector2(HALF, 0))
	m.boss_arena = [arena_offset.x + 100, arena_offset.y + 250, 920, 350]
	m.areas.append({"id": "windkeeper", "position": [prep.x + 760, prep.y], "label": "WINDKEEPER / THREE PHASES", "role": "boss", "ports": []})
	_edge(m, m.prep_id, "windkeeper", "boss")
	m.prep_position = [prep.x, prep.y]
	m.merchant_position = _area(m, m.merchant_id).position.duplicate()
	# Optional difficulty loops have a hard ascending arm, one-way drop escape,
	# and a different return junction; never an easy reverse entrance to a chest.
	if not sample:
		_deep_loop(m, 1, "high", content)
		_deep_loop(m, cols - 2, "region_top", content)
	for a: Dictionary in m.areas:
		for e: Dictionary in m.connections:
			if e.a != a.id and e.b != a.id: continue
			var other := _area(m, e.b if e.a == a.id else e.a)
			var direction := (_point(other.position) - _point(a.position)).normalized()
			a.ports.append({"connection": e.id, "position": a.position.duplicate(), "direction": [direction.x, direction.y], "actions": _connection_actions(m,e), "condition": e.condition, "safe_landing": a.position.duplicate(), "outgoing": e.bidirectional or e.a == a.id})
	# Fixed total reward budget, independent of map size; position/risk determines tier.
	for i: int in 2:
		var area_id := "area_%s_%s" % [1 + reward.next_int(cols - 1), 0 if i == 0 else 2]
		var p := _point(_area(m, area_id).position)
		m.rewards.append({"id": "plains/chest/medium_%s" % i, "area": area_id, "tier": "medium", "position": [p.x - 100, p.y], "coins": 8, "items": ["damage_blue", "health_blue"], "risk": {"depth": 2, "platforming": 1, "timing": 1, "pressure": 1, "return": 1}})
	var ordinary: Array = m.areas.filter(func(a: Dictionary) -> bool: return a.role == "junction" or a.role == "prep")
	for i: int in 12:
		var p := _point(ordinary[i % ordinary.size()].position)
		m.pickups.append({"id": "plains/coin/%s" % i, "kind": "coin", "amount": 2, "position": [p.x + 70, p.y - 10]})
	for i: int in 3:
		var a: Dictionary = _area(m,m.merchant_id) if i==0 else ordinary[content.next_int(ordinary.size())]
		var p := _point(a.position)
		m.pickups.append({"id": "plains/supply/%s" % i, "kind": "heart", "amount": 1, "position": [p.x - 60, p.y]})
	m.pickups.append({"id": "plains/note/tutorial", "kind": "note", "amount": 1, "position": [-180, -30]})
	for a: Dictionary in ordinary:
		if a.id in ["area_0_1", m.prep_id, m.merchant_id] or content.next_int(5 if difficulty=="intro" else 3) != 0: continue
		var p := _point(a.position) + Vector2(135, 0)
		m.enemies.append({"id": "plains/enemy/" + a.id, "position": [p.x, p.y], "aerial": false, "patrol_radius": 0, "behavior_id": "sentry", "area": a.id})
	m.enemies.push_front({"id": "plains/enemy/tutorial", "position": [-655, 0], "aerial": false, "patrol_radius": 35, "behavior_id": "charger", "area": "tutorial_bell"})
	m.enemy_drops={}
	var drops:=EnemyDropService.new()
	drops.configure(seed_value,"plains_region")
	var left: Dictionary={"coin":12,"note":3,"heart":2}
	var sorted_enemies: Array=m.enemies.duplicate(true)
	sorted_enemies.sort_custom(func(a: Dictionary,b: Dictionary): return str(a.id)<str(b.id))
	for e: Dictionary in sorted_enemies:
		var drop:=drops.settle(StringName(e.id))
		if drop.kind!="none":
			drop.amount=mini(int(drop.amount),int(left[drop.kind]))
			left[drop.kind]-=int(drop.amount)
			if drop.amount==0: drop.kind="none"
		m.enemy_drops[e.id]=drop
	m.ground_supports=[]
	for a: Dictionary in m.areas:
		if a.get("row",-1)==2:
			m.ground_supports.append([a.position[0]-200, a.position[1]+50,400,192])
	m.world_bounds = [-1950, -2200, prep.x + 3350, 3500]
	m.shot_latch_plan = PlainsShotLatchPlanner.recorded_plan(m)
	m.stream_positions={"topology":topology.position(),"content":content.position(),"reward":reward.position()}
	m.manifest_hash = _hash(m)
	return m

func _deep_loop(m: Dictionary, col: int, tier: String, rng: RunRandomStream) -> void:
	var base := _point(_area(m, "area_%s_0" % col).position)
	var id := "deep_" + tier
	# Existing two-level moving ferry then precise recoil rise, fully in upper air.
	var ferry_id := "plains_ferry_gears" if tier == "region_top" and m.difficulty=="advanced" else "plains_ferry_two"
	var entry_steps := _floor_definition("region_deep_entry",Rect2(-190,18,80,24),true)
	entry_steps.world_bounds=Rect2(-320,-380,520,450)
	for i: int in 3:
		var x: float=[90.0,-90.0,-230.0][i]
		entry_steps.platforms.append(Rect2(x-70,-82-i*100,140,18))
		entry_steps.one_way_platform_indices.append(entry_steps.platforms.size()-1)
	_add_inline(m,id+"_entry",base,entry_steps)
	var start := base + Vector2(-150, -400)
	_add_existing(m, id + "_ferry", ferry_id, start)
	var ferry_end := start + Vector2(960, -552)
	_add_existing(m, id + "_recoil", "plains_recoil_step", ferry_end + Vector2(20, 0))
	var landing := ferry_end + Vector2(500, -190)
	_add_inline(m, id + "_landing", landing, _floor_definition("region_drop_exit", Rect2(0,18,180,24), true))
	var reward_position := landing + Vector2(70, 0)
	m.areas.append({"id": id, "position": [reward_position.x, reward_position.y], "label": "DEEP TRIAL / " + tier.to_upper(), "role": "challenge_reward", "ports": []})
	_edge(m, "area_%s_0" % col, id, "challenge", "open", false)
	_edge(m, id, "area_%s_0" % (col + 1), "drop", "open", false)
	m.rewards.append({"id": "plains/chest/" + tier, "area": id, "tier": tier, "position": [reward_position.x, reward_position.y], "coins": 18 if tier == "high" else 30, "items": ["region_damage_purple", "region_health_purple"] if tier == "high" else ["region_damage_gold", "region_health_gold"], "risk": {"depth": 3, "platforming": 3, "timing": 3, "pressure": 0, "resource": 2, "return": 2}, "variant": rng.next_int(2)})

func _fill_edge(m: Dictionary, e: Dictionary, rng: RunRandomStream) -> void:
	var a := _point(_area(m, e.a).position)
	var b := _point(_area(m, e.b).position)
	if e.kind == "diagonal":
		_add_existing(m, e.id + "_ferry", "plains_ferry_two", a + Vector2(200,0))
		var d := _floor_definition("region_diagonal_join",Rect2(0,18,180,24),true)
		d.world_bounds = Rect2(-20,-210,300,270)
		d.platforms.append(Rect2(80,-56,100,18))
		d.one_way_platform_indices.append(1)
		_add_inline(m,e.id+"_join",a+Vector2(1180,-552),d)
		e.path = [[a.x,a.y],[b.x,b.y]]
		return
	if e.kind == "stairs":
		var d := _floor_definition("region_stairs", Rect2(-200,18,80,24), true)
		d.world_bounds = Rect2(-210,-730,420,790)
		for i: int in 6:
			d.platforms.append(Rect2(-160 if i % 2 == 0 else 20, -82 - i * 100, 140, 18))
			d.one_way_platform_indices.append(d.platforms.size()-1)
		_add_inline(m, e.id, a, d)
		e.path = [[a.x,a.y]]
		for i: int in 6: e.path.append([a.x + (-90 if i % 2 == 0 else 90), a.y - 100 * (i + 1)])
		e.path.append([b.x,b.y])
		if e.condition == "backside":
			e.gate = [a.x - 205, b.y + 45, 410, 24]
			e.control = [b.x, b.y]
		return
	# Horizontal edges combine phrases in a bounded lane with both-way landings.
	var choices := [[], ["plains_gear_glade"], ["plains_windchime_timed"], ["plains_windchime_sequence"], ["plains_recoil_span"], ["plains_windchime_timed", "plains_gear_glade"]]
	var ids: Array = choices[rng.next_int(choices.size())] if a.y != 0 else choices[rng.next_int(4)]
	if m.difficulty=="intro": ids=[[],["plains_gear_glade"],["plains_windchime_timed"]][rng.next_int(3)]
	if m.sample and e.a == "area_0_1": ids = []
	var x := a.x + HALF
	e.modules = []
	for id: String in ids:
		var d := RandomStageGenerator.new().definition_for(id, false, false)
		_add_existing(m, e.id + "_%s" % e.modules.size(), id, Vector2(x, a.y))
		e.modules.append(m.nodes.size()-1)
		x += d.world_bounds.size.x
	if x < b.x - HALF:
		_add_inline(m, e.id + "_join", Vector2(x, a.y), _floor_definition("region_connection", Rect2(0,18,b.x-HALF-x,32)))
	e.path = [[a.x,a.y],[b.x,b.y]]

func _connection_actions(m: Dictionary,e: Dictionary) -> Dictionary:
	var actions: Dictionary={"jumps":0 if e.kind=="drop" else 1,"air_shots":1 if e.kind=="challenge" or (e.kind=="tutorial" and e.a=="tutorial_jump") else 0,"shoot_mechanism":e.kind=="tutorial" and e.a=="tutorial_bell","requires_burst":e.kind=="challenge" or (e.kind=="tutorial" and e.a=="tutorial_jump")}
	for index: int in e.get("modules",[]):
		var d:=definition(m.nodes[index])
		actions.air_shots=maxi(int(actions.air_shots),d.min_air_shots)
		actions.requires_burst=bool(actions.requires_burst) or d.requires_burst
		actions.shoot_mechanism=bool(actions.shoot_mechanism) or "windchime" in str(d.module_id)
	return actions

func _floor_definition(id: String, slab: Rect2, one_way := false) -> PlatformingModuleDefinition:
	var d := PlatformingModuleDefinition.new()
	d.module_id = StringName(id)
	d.world_bounds = Rect2(slab.position.x - 20,-160,slab.size.x + 40,slab.end.y+180)
	d.platforms.append(slab)
	if one_way: d.one_way_platform_indices.append(0)
	d.anchors.assign([Vector2(slab.position.x+20,slab.position.y-18), Vector2(slab.end.x-20,slab.position.y-18)])
	d.entry_port = _port("entry", d.anchors[0])
	d.exit_port = _port("exit", d.anchors[1])
	return d

func _port(id: String, p: Vector2) -> PlatformingModulePort:
	var port := PlatformingModulePort.new()
	port.port_id = StringName(id)
	port.position = p
	return port

func _add_existing(m: Dictionary, id: String, module_id: String, entry: Vector2) -> void:
	var d := RandomStageGenerator.new().definition_for(module_id, false, false)
	var phase_stream := RunRandomStream.new(str(m.seed), "region_phases", id, RNG_VERSION)
	var phases: Array = []
	for saw: ModuleSawDefinition in d.saws: phases.append({"id":str(saw.source_id),"phase":float(phase_stream.next_int(4))/4.0})
	for ferry: ModuleMovingPlatformDefinition in d.ferries: phases.append({"id":str(ferry.platform_id),"phase":float(phase_stream.next_int(4))/4.0})
	var offset := entry - Vector2(0, d.entry_port.position.y)
	m.nodes.append({"id": id, "module_id": module_id, "offset": [offset.x,offset.y], "mirrored": false, "reverse_traversal": false, "initial_phases": phases, "definition_version":d.definition_version,"definition_hash":JSON.stringify(_definition_data(d),"",true).sha256_text()})

func _add_inline(m: Dictionary, id: String, p: Vector2, d: PlatformingModuleDefinition) -> void:
	var slabs: Array = []
	for rect: Rect2 in d.platforms: slabs.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	m.nodes.append({"id": id, "module_id": str(d.module_id), "offset": [p.x,p.y], "mirrored": false, "reverse_traversal": false, "initial_phases": [], "geometry": {"bounds": [d.world_bounds.position.x,d.world_bounds.position.y,d.world_bounds.size.x,d.world_bounds.size.y], "platforms": slabs, "one_way": d.one_way_platform_indices, "junction": str(d.module_id) == "region_junction"}})

static func definition(node: Dictionary) -> PlatformingModuleDefinition:
	if not node.has("geometry"):
		var authored := RandomStageGenerator.new().definition_for(str(node.module_id),false,false).duplicate(true) as PlatformingModuleDefinition
		for phase: Dictionary in node.initial_phases:
			for saw: ModuleSawDefinition in authored.saws:
				if str(saw.source_id)==phase.id: saw.initial_phase=float(phase.phase)
			for ferry: ModuleMovingPlatformDefinition in authored.ferries:
				if str(ferry.platform_id)==phase.id: ferry.initial_phase=float(phase.phase)
		return authored
	var d := PlatformingModuleDefinition.new()
	d.module_id = StringName(node.module_id)
	var g: Dictionary = node.geometry
	d.world_bounds = Rect2(g.bounds[0],g.bounds[1],g.bounds[2],g.bounds[3])
	for r: Array in g.platforms: d.platforms.append(Rect2(r[0],r[1],r[2],r[3]))
	d.one_way_platform_indices.assign(g.one_way)
	var floor_rect := d.platforms[0]
	d.anchors.assign([Vector2(floor_rect.position.x+20,floor_rect.position.y-18),Vector2(floor_rect.end.x-20,floor_rect.position.y-18)])
	var gen := PlainsRegionGenerator.new()
	d.entry_port = gen._port("entry",d.anchors[0])
	d.exit_port = gen._port("exit",d.anchors[1])
	if g.get("junction",false):
		d.entry_ports.assign([d.entry_port,gen._port("arrival_up",Vector2(-70,0)),gen._port("arrival_down",Vector2(70,0))])
		d.exit_ports.assign([d.exit_port,gen._port("depart_up",Vector2(-40,0)),gen._port("depart_down",Vector2(40,0))])
		d.entry_ports[1].direction = Vector2.DOWN
		d.entry_ports[2].direction = Vector2.UP
		d.exit_ports[1].direction = Vector2.UP
		d.exit_ports[2].direction = Vector2.DOWN
	return d

func _edge(m: Dictionary, a: String, b: String, kind: String, condition := "open", bidirectional := true) -> void:
	m.connections.append({"id": "plains/passage/%s/%s" % [a,b], "a": a, "b": b, "kind": kind, "condition": condition, "bidirectional": bidirectional})

func _area(m: Dictionary, id: String) -> Dictionary:
	for a: Dictionary in m.areas:
		if a.id == id: return a
	return {}

func _has_edge(m: Dictionary, a: String, b: String) -> bool:
	return m.connections.any(func(e: Dictionary) -> bool: return (e.a == a and e.b == b) or (e.a == b and e.b == a))

func _degree(m: Dictionary, id: String) -> int:
	return m.connections.filter(func(e: Dictionary) -> bool: return e.condition == "open" and (e.a == id or e.b == id)).size()

func _connected(m: Dictionary) -> bool:
	if m.areas.is_empty(): return false
	var seen := {str(m.areas[0].id): true}
	for unused: int in m.areas.size():
		for e: Dictionary in m.connections:
			if e.condition != "open": continue
			if seen.has(e.a): seen[e.b] = true
			if e.bidirectional and seen.has(e.b): seen[e.a] = true
	return seen.size() == m.areas.size()

func _cycles(m: Dictionary) -> int:
	return m.connections.filter(func(e: Dictionary) -> bool: return e.condition == "open").size() - m.areas.size() + 1

func _point(p: Array) -> Vector2: return Vector2(p[0],p[1])

func _hash(m: Dictionary) -> String:
	return RandomStageGenerator.new()._manifest_hash(m)

func validate(m: Dictionary, tuning: PlayerTuning) -> bool:
	if m.get("version") != VERSION or m.get("manifest_hash") != _hash(m) or not _connected(m) or _cycles(m) < 3: return false
	if m.areas.size() < 12 or m.areas.size() > 24 or _degree(m, m.prep_id) < 2: return false
	if m.connections.filter(func(e: Dictionary) -> bool: return e.condition == "backside").size() < 2: return false
	if m.areas.filter(func(a: Dictionary) -> bool: return _degree(m,a.id) >= 3).size() < 3: return false
	var ids := {}
	for n: Dictionary in m.nodes:
		if ids.has(n.id): return false
		ids[n.id] = true
		var d := definition(n)
		if not d.supports(tuning): return false
	if not PlainsShotLatchPlanner.validate(m): return false
	# Rehashed removals, fake connections/rewards and changed geometry cannot
	# pass replay validation. Generation is bounded and each namespace is separate.
	var expected := _candidate("region-woven_layers" if m.fallback_id != "" else str(m.seed),bool(m.get("sample",false)),str(m.family),int(m.attempt),str(m.get("difficulty","advanced")))
	if m.fallback_id != "":
		expected.seed = m.seed
		expected.fallback_id = m.fallback_id
	return _hash(expected) == _hash(m)

func _result(m: Dictionary) -> Dictionary:
	var arena: Array = m.boss_arena
	var points: Array[Vector2] = []
	for a: Dictionary in m.areas: points.append(_point(a.position))
	return {"ok": true, "manifest": m, "placement_points": points, "boss_arena": Rect2(arena[0],arena[1],arena[2],arena[3]), "stage_generator_version": VERSION, "encounter_plan": {"version": VERSION, "enemies": m.enemies}, "shot_latch_plan": m.shot_latch_plan}

# Hash loaded physics data, not raw .tres bytes: exports remap .tres to binary
# resources, while a fixed seed must remain portable between native and Web.
func _definition_data(value: Variant) -> Variant:
	if value is Resource:
		var fields: Dictionary={}
		for property: Dictionary in value.get_property_list():
			if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage)&PROPERTY_USAGE_STORAGE:
				fields[property.name]=_definition_data(value.get(property.name))
		return fields
	if value is Vector2: return [float(value.x),float(value.y)]
	if value is Rect2: return [float(value.position.x),float(value.position.y),float(value.size.x),float(value.size.y)]
	if value is Array or value is PackedInt32Array or value is PackedFloat32Array or value is PackedFloat64Array:
		var result: Array=[]
		for child: Variant in value: result.append(_definition_data(child))
		return result
	if value is int or value is float: return float(value)
	if value is StringName: return str(value)
	return value
