class_name PlainsRegionGenerator
extends RefCounted
## Topology is committed before terrain/content. No player tuning changes.
const VERSION := "plains-region-v7"
const RNG_VERSION := "plains-region-v3"
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
	var m := {"version": VERSION, "difficulty":difficulty, "player_tuning_hash":FileAccess.get_sha256("res://config/player_tuning.json"), "seed": seed_value, "region": "plains", "layout_id": "connected_region", "family": family, "attempt": attempt, "fallback_id": "", "sample": sample, "areas": [], "connections": [], "nodes": [], "rewards": [], "pickups": [], "enemies": [], "terminal_exits": [], "budget": {"ordinary_coins": 24, "medium": 2, "high": 1, "region_top": 1, "finite_hearts": 3,"cache_coin_limit":122,"cache_heart_limit":11,"cache_note_limit":8}, "streams": {"topology": "region_topology", "content": "region_content", "reward": "region_reward", "phases": "region_phases", "generation_seed": seed_value,"derivation_version":RNG_VERSION}}
	var footprint: Dictionary={"cells":[],"recipe":"fixed_sample"}
	if sample:
		for row: int in 3:
			for col: int in cols: footprint.cells.append([col,row])
	else: footprint=PlainsExplorationTopology.make(topology,family,15 if difficulty=="intro" else (15 if topology.next_int(2)==0 else 18))
	m.topology=footprint
	cols=0
	for cell: Array in footprint.cells:
		var col: int=cell[0];var row: int=cell[1]
		cols=maxi(cols,col+1)
		var label: String=["BELL WOODS","GRASS COURT","CREEK VAULT","REPAIR WELL","OLD CLOCK PIT"][row]
		m.areas.append({"id":"area_%s_%s" % [col,row],"position":[col*DX,(row-1)*DY],"label":label,"row":row,"col":col,"role":"junction","ports":[]})
	var candidates: Array=[]
	for a: Dictionary in m.areas:
		var col: int=a.col;var row: int=a.row
		var right: String="area_%s_%s" % [col+1,row]
		var up: String="area_%s_%s" % [col,row-1]
		if not _area(m,right).is_empty(): candidates.append([a.id,right,"horizontal",col,row])
		if not _area(m,up).is_empty(): candidates.append([a.id,up,"stairs",col,row-1])
	for c: Array in candidates: _edge(m,c[0],c[1],c[2])
	var prep_candidates: Array=m.areas.filter(func(a: Dictionary): return a.col==cols-1 and _degree(m,a.id)>=2)
	if prep_candidates.is_empty(): prep_candidates=m.areas.filter(func(a: Dictionary): return a.col==cols-2 and _degree(m,a.id)>=2)
	var chosen_prep: Dictionary=prep_candidates[topology.next_int(prep_candidates.size())]
	prep_row=int(chosen_prep.row)
	m.prep_id=str(chosen_prep.id)
	# Cut galleries at different columns. No uninterrupted parallel highways.
	if not sample:
		for row: int in 5:
			var horizontal: Array=m.connections.filter(func(e: Dictionary): return e.kind=="horizontal" and int(_area(m,e.a).row)==row)
			if horizontal.size()<2: continue
			var cut: Dictionary=horizontal[topology.next_int(horizontal.size())]
			var at: int=m.connections.find(cut);m.connections.remove_at(at)
			if not _connected(m) or _cycles(m)<5 or _degree(m,m.prep_id)<2: m.connections.insert(at,cut)
	# Seed changes traversal, not only content. Remove non-bridge edges while
	# retaining three independent cycles and two incoming prep routes.
	for unused: int in 4 if not sample else 0:
		var removable: Array=m.connections.filter(func(e: Dictionary): return e.kind=="horizontal")
		if removable.is_empty(): break
		var candidate: Dictionary=removable[topology.next_int(removable.size())]
		var at: int=m.connections.find(candidate)
		m.connections.remove_at(at)
		if not _connected(m) or _cycles(m) < 5 or _degree(m,m.prep_id) < 2:
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
			if e.kind != "stairs" or e.condition != "open" or (sample and e.b == "area_1_0") or m.prep_id in [e.a,e.b]: continue
			e.condition = "backside"
			if not _connected(m) or _cycles(m) < 3: e.condition = "open"
			else: shortcuts += 1
	# Well-rings deliberately use one-way descent arms and separate climb returns.
	# Courtyard weave retains bidirectional crossings; hub satellites use lifts.
	if not sample and family=="linked_rings":
		var converted:=0
		for e: Dictionary in m.connections:
			if converted==2: break
			if e.kind!="stairs" or e.condition!="open" or m.prep_id in [e.a,e.b]: continue
			var lower: String=e.a;var upper: String=e.b;e.a=upper;e.b=lower;e.kind="drop";e.bidirectional=false
			if not _connected(m): e.a=lower;e.b=upper;e.kind="stairs";e.bidirectional=true
			else: converted+=1
	var camps: Array=m.areas.filter(func(a: Dictionary): return a.id not in ["area_0_1",m.prep_id])
	m.merchant_id=str(camps[content.next_int(camps.size())].id)
	_area(m, m.prep_id).role = "prep"
	_area(m, m.prep_id).label = "WINDKEEPER APPROACH"
	_area(m, m.merchant_id).role = "merchant"
	_area(m, m.merchant_id).label = "CAMP / MERCHANT"
	# Multipoint platforms and real ascending/descending stair shafts.
	for a: Dictionary in m.areas:
		var drop: bool = m.connections.any(func(e: Dictionary) -> bool: return (e.kind=="stairs" and e.b==a.id) or (e.kind=="drop" and e.a==a.id))
		var d := _floor_definition("region_junction", Rect2(-HALF, 18, HALF * 2, 32), drop)
		_add_inline(m, a.id, _point(a.position), d)
	for a: Dictionary in m.areas:
		var landmark: String=["windmill","ruin_arch","windchime","stones","ivy"][content.next_int(5)]
		a.landmark=landmark
		a.label={"windmill":"WINDMILL YARD","ruin_arch":"ABANDONED CLOCK COURT","windchime":"BELL GROVE","stones":"CREEK STONES","ivy":"REPAIR GALLERY"}[landmark] if a.role=="junction" else a.label
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
	_add_existing(m, "windkeeper_arena", "plains_bellstrider_arena" if difficulty=="intro" else "plains_boss_arena", prep + Vector2(HALF, 0))
	m.boss_arena = [arena_offset.x + 100, arena_offset.y + 250, 920, 350]
	m.areas.append({"id": "windkeeper", "position": [prep.x + 760, prep.y], "label": "WINDKEEPER / THREE PHASES", "role": "boss", "ports": []})
	_edge(m, m.prep_id, "windkeeper", "boss")
	m.prep_position = [prep.x, prep.y]
	m.merchant_position = _area(m, m.merchant_id).position.duplicate()
	# Optional difficulty loops have a hard ascending arm, one-way drop escape,
	# and a different return junction; never an easy reverse entrance to a chest.
	if not sample:
		_deep_loop(m, 0, "high", content)
		_deep_loop(m, 2, "region_top", content)
	for a: Dictionary in m.areas:
		for e: Dictionary in m.connections:
			if e.a != a.id and e.b != a.id: continue
			var other := _area(m, e.b if e.a == a.id else e.a)
			var direction := (_point(other.position) - _point(a.position)).normalized()
			a.ports.append({"connection": e.id, "position": a.position.duplicate(), "direction": [direction.x, direction.y], "actions": _connection_actions(m,e), "condition": e.condition, "safe_landing": a.position.duplicate(), "outgoing": e.bidirectional or e.a == a.id})
	# Fixed total reward budget, independent of map size; position/risk determines tier.
	for i: int in 2:
		var eligible: Array=m.areas.filter(func(a: Dictionary): return a.role=="junction" and a.id!="area_0_1" and not m.rewards.any(func(c: Dictionary): return c.area==a.id))
		var area_id: String=eligible[reward.next_int(eligible.size())].id
		var p := _point(_area(m, area_id).position)
		m.rewards.append({"id": "plains/chest/medium_%s" % i, "area": area_id, "tier": "medium", "position": [p.x - 100, p.y], "coins": 8, "items": ["damage_blue", "health_blue"], "risk": {"depth": 2, "platforming": 1, "timing": 1, "pressure": 1, "return": 1}})
	var enemy_limit: int=26 if difficulty=="intro" else 36
	m.pressure={"version":"plains-pressure-v2","enemy_limit":enemy_limit,"simultaneous_attacks":1 if difficulty=="intro" else 2}
	var ordinary: Array = m.areas.filter(func(a: Dictionary) -> bool: return a.role == "junction" or a.role == "prep")
	for i: int in 12:
		var p := _point(ordinary[i % ordinary.size()].position)
		m.pickups.append({"id": "plains/coin/%s" % i, "kind": "coin", "amount": 2, "position": [p.x + 70, p.y - 10]})
	for i: int in 3:
		var a: Dictionary = _area(m,m.merchant_id) if i==0 else ordinary[content.next_int(ordinary.size())]
		var p := _point(a.position)
		m.pickups.append({"id": "plains/supply/%s" % i, "kind": "heart", "amount": 1, "position": [p.x - 60, p.y]})
	m.pickups.append({"id": "plains/note/tutorial", "kind": "note", "amount": 1, "position": [-180, -30]})
	# Reserve encounter budget for authored movement windows before junction guards.
	# Each placement records its real module, mechanism and safe escape; no key gates.
	for wanted_pattern: String in ["ferry_air_intercept","bell_window_intercept","gear_landing_intercept","ferry_fan_crossfire"]:
		var per_pattern:=0
		for n: Dictionary in m.nodes:
			if per_pattern >= (2 if difficulty=="intro" else 3): break
			if n.has("geometry") or str(n.id).begins_with("tutorial") or n.id=="windkeeper_arena": continue
			var d:=definition(n)
			var local:=Vector2.ZERO
			var pattern:=""
			var behavior:="diver"
			var mechanism:=""
			if not d.ferries.is_empty():
				var ferry: ModuleMovingPlatformDefinition=d.ferries[0]
				local=(ferry.start+ferry.finish)*.5+Vector2(-120,-165) if wanted_pattern=="ferry_fan_crossfire" else (ferry.start+ferry.finish)*.5+Vector2(0,-115)
				behavior="fan_sentry" if wanted_pattern=="ferry_fan_crossfire" else "diver"
				pattern="ferry_fan_crossfire" if wanted_pattern=="ferry_fan_crossfire" else "ferry_air_intercept";mechanism=str(ferry.platform_id)
			elif not d.saws.is_empty():
				# Aerial pressure at the approach, not an unavoidable stack over the saw.
				local=d.saws[0].envelope().get_center()+Vector2(85,-105)
				pattern="gear_landing_intercept";mechanism=str(d.saws[0].source_id)
			elif "windchime" in str(n.module_id):
				local=d.exit_port.position+Vector2(-90,-105)
				pattern="bell_window_intercept";mechanism="shot_latch"
			else: continue
			if pattern!=wanted_pattern: continue
			var blocked:=false
			var patrol_box:=Rect2(local-Vector2(55,25),Vector2(110,50))
			if not d.world_bounds.encloses(patrol_box): continue
			for slab: Rect2 in d.platforms:
				if slab.intersects(patrol_box): blocked=true
			for saw: ModuleSawDefinition in d.saws:
				if saw.envelope().grow(20).intersects(patrol_box): blocked=true
			if blocked: continue
			var p:=local+Vector2(n.offset[0],n.offset[1])
			m.enemies.append({"id":"plains/enemy/window/"+n.id+"/"+pattern,"position":[p.x,p.y],"aerial":true,"patrol_radius":35,"behavior_id":behavior,"area":n.id,"pattern":pattern,"mechanism":mechanism,"dive_depth":115.0,"escape":"wait_telegraph_then_cross_or_take_other_connection"})
			per_pattern+=1
	# Landing-pressure encounter: green cells remain usable without killing the guard.
	for n:Dictionary in m.nodes:
		if n.module_id!="plains_thorn_cells" or m.enemies.size()>=enemy_limit-1:continue
		var pos:=Vector2(n.offset[0]+460,n.offset[1]+282)
		m.enemies.append({"id":"plains/enemy/landing/"+n.id,"position":[pos.x,pos.y],"aerial":false,"patrol_radius":35,"behavior_id":"hopper","area":n.id,"pattern":"safe_cell_ambush","escape":"choose_another_green_cell_or_wait_for_locked_lunge"})
	# Put pressure inside long connections too, away from junction/spawn anchors.
	for n: Dictionary in m.nodes:
		if m.enemies.size()>=enemy_limit-1 or n.module_id!="region_connection" or not n.has("geometry"): continue
		var floor_data: Array=n.geometry.platforms[0]
		if float(floor_data[2])<420: continue
		var p:=Vector2(n.offset[0]+floor_data[0]+floor_data[2]*0.5,n.offset[1]+floor_data[1]-18)
		var behavior: String="sentry" if content.next_int(2)==0 else "charger"
		m.enemies.append({"id":"plains/enemy/lane/"+n.id,"position":[p.x,p.y],"aerial":false,"patrol_radius":35 if behavior=="charger" else 0,"behavior_id":behavior,"area":n.id})
	for a: Dictionary in ordinary:
		if m.enemies.size()>=enemy_limit-1 or a.id in ["area_0_1", m.prep_id, m.merchant_id] or content.next_int(4 if difficulty=="intro" else 6) == 0: continue
		var behavior: String=["charger","sentry","diver","hopper"][content.next_int(4)]
		var aerial: bool=behavior=="diver"
		var p := _point(a.position) + (Vector2(70,-110) if aerial else Vector2(130,0))
		m.enemies.append({"id": "plains/enemy/" + a.id, "position": [p.x, p.y], "aerial": aerial, "patrol_radius": 40 if aerial else 35 if behavior=="hopper" else 25 if behavior=="charger" else 0, "behavior_id": behavior, "area": a.id})
	m.enemies.push_front({"id": "plains/enemy/tutorial", "position": [-655, 0], "aerial": false, "patrol_radius": 35, "behavior_id": "charger", "area": "tutorial_bell"})
	for reward_data: Dictionary in m.rewards:
		var pool: Array=["damage_blue","health_blue","efficient_grip","stability_blue","braided_cord","quick_hammer","brake_boots"] if reward_data.tier=="medium" else ["region_damage_purple","region_health_purple","echo_magazine","shot_purple","region_recoil_purple","cooling_fin","field_medic"] if reward_data.tier=="high" else ["region_damage_gold","region_health_gold","echo_gold"]
		var items_rng:=RunRandomStream.new(seed_value,"region_items",str(reward_data.id),"plains-items-v2")
		reward_data.reward_mode="item_resource" if reward_data.tier!="medium" else ("resources" if items_rng.next_int(3)==0 else "item_resource")
		reward_data.resources=[]
		var value: int=16 if reward_data.tier=="medium" else 36 if reward_data.tier=="high" else 54
		reward_data.resources.append({"kind":"coin","amount":value})
		var kind: String="heart" if items_rng.next_int(2)==0 else "note"
		reward_data.resources.append({"kind":kind,"amount":(2 if reward_data.tier=="medium" else 3 if reward_data.tier=="high" else 4) if kind=="heart" else 1 if reward_data.tier=="medium" else 2 if reward_data.tier=="high" else 4})
		if reward_data.reward_mode=="item_resource" and items_rng.next_int(2)==1: reward_data.resources.reverse()
		reward_data.items=[]
		for unused: int in 2:
			var chosen:=items_rng.next_int(pool.size())
			reward_data.items.append(pool[chosen]);pool.remove_at(chosen)
		var pressure_count: int=m.enemies.filter(func(e: Dictionary): return e.has("pattern") and str(e.area).begins_with(str(reward_data.area)+"_")).size()
		if pressure_count>0: reward_data.risk.pressure=mini(3,pressure_count)
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
		if a.get("row",-1)==int(footprint.get("grid_height",3))-1:
			m.ground_supports.append([a.position[0]-200, a.position[1]+50,400,192])
	m.world_bounds = [-1950, -2200, cols*DX + 3350, 6000]
	m.shot_latch_plan = PlainsShotLatchPlanner.recorded_plan(m)
	m.stream_positions={"topology":topology.position(),"content":content.position(),"reward":reward.position()}
	var shop_rng:=RunRandomStream.new(seed_value,"region_shop",str(attempt),RNG_VERSION)
	var shop_pool: Array=["damage_blue","health_blue","efficient_grip","stability_blue","braided_cord","quick_hammer","brake_boots"]
	m.shop={"item":shop_pool[shop_rng.next_int(shop_pool.size())],"price":5,"stock":1}
	m.streams.shop="region_shop"
	m.streams.items="region_items"
	m.item_version="plains-items-v2"
	m.shot_energy_version="plains-shot-energy-v1"
	m.manifest_hash = _hash(m)
	return m

func _deep_loop(m: Dictionary, col: int, tier: String, rng: RunRandomStream) -> void:
	var base := _point(_area(m, "area_%s_0" % col).position)
	var id := "deep_" + tier
	# Existing two-level moving ferry then precise recoil rise, fully in upper air.
	var variant:=rng.next_int(3)
	var recipe_ids: Array=["plains_ferry_gears" if tier=="region_top" and m.difficulty=="advanced" else "plains_ferry_two","plains_recoil_double" if tier=="region_top" else "plains_recoil_step"] if variant==0 else ["plains_recoil_double","plains_windchime_rush" if tier=="region_top" else "plains_windchime_timed"] if variant==1 else ["plains_windchime_rush" if tier=="region_top" else "plains_windchime_timed" if m.difficulty=="intro" else "plains_windchime_sequence","plains_recoil_double"]
	var entry_steps := _floor_definition("region_deep_entry",Rect2(-190,18,80,24),true)
	entry_steps.world_bounds=Rect2(-320,-380,520,450)
	for i: int in 3:
		var x: float=[90.0,-90.0,-230.0][i]
		entry_steps.platforms.append(Rect2(x-70,-82-i*100,140,18));entry_steps.one_way_platform_indices.append(entry_steps.platforms.size()-1)
	_add_inline(m,id+"_entry",base,entry_steps)
	var cursor:=base+Vector2(-150,-400)
	var trial_modules: Array=[]
	for index: int in recipe_ids.size():
		var module_id: String=recipe_ids[index]
		var node_id: String=id+("_ferry" if index==0 else "_recoil")
		_add_existing(m,node_id,module_id,cursor)
		trial_modules.append(node_id)
		var d:=RandomStageGenerator.new().definition_for(module_id)
		cursor+=d.exit_port.position-d.entry_port.position+Vector2(20,0)
	var landing:=cursor+Vector2(20,0)
	var landing_width:=maxf(180,base.x+DX+80-landing.x)
	_add_inline(m,id+"_landing",landing,_floor_definition("region_drop_exit",Rect2(0,18,landing_width,24),true))
	var reward_position:=landing+Vector2(35,0)
	m.areas.append({"id": id, "position": [reward_position.x, reward_position.y], "label": "DEEP TRIAL / " + tier.to_upper(), "role": "challenge_reward", "ports": []})
	_edge(m, "area_%s_0" % col, id, "challenge", "open", false)
	_edge(m, id, "area_%s_0" % (col + 1), "drop", "open", false)
	var drop_edge: Dictionary=m.connections[-1]
	drop_edge.escape_x=reward_position.x
	var clear_y: float=landing.y
	for node_id: String in trial_modules:
		var node: Dictionary=m.nodes.filter(func(n: Dictionary): return n.id==node_id)[0]
		var d:=definition(node)
		for danger: Rect2 in d.danger_bounds: clear_y=maxf(clear_y,float(node.offset[1])+danger.end.y+24)
		for saw: ModuleSawDefinition in d.saws: clear_y=maxf(clear_y,float(node.offset[1])+saw.envelope().end.y+24)
	drop_edge.clear_y=clear_y
	m.rewards.append({"id": "plains/chest/" + tier, "area": id, "tier": tier, "position": [reward_position.x, reward_position.y], "coins": 18 if tier == "high" else 30, "items": ["region_damage_purple", "region_health_purple"] if tier == "high" else ["region_damage_gold", "region_health_gold"], "risk": {"depth": 3, "platforming": 3, "timing": 3, "pressure": 0, "resource": 2, "return": 2}, "variant":variant,"challenge_modules":trial_modules,"action_signature":str(recipe_ids[0]).trim_prefix("plains_")+">"+str(recipe_ids[1]).trim_prefix("plains_")})

func _fill_edge(m: Dictionary, e: Dictionary, rng: RunRandomStream) -> void:
	var a := _point(_area(m, e.a).position)
	var b := _point(_area(m, e.b).position)
	if e.kind=="drop":
		e.path=[[a.x,a.y],[b.x,b.y]];e.actions="inspect_return>drop_through>land";e.return_hint="climb_neighbouring_well"
		return
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
		var choices: Array=["lift","lift","switchback","recoil_shaft"] if m.family=="crossroads" else ["switchback","recoil_shaft","switchback","lift"] if m.family=="woven_layers" else ["recoil_shaft","lift","recoil_shaft","switchback"]
		var recipe: String=choices[rng.next_int(choices.size())] if not m.sample else "switchback"
		e.shaft_recipe=recipe
		var d := _floor_definition("region_stairs", Rect2(-200,18,80,24), true)
		d.world_bounds = Rect2(-220,-750,440,840)
		e.path = [[a.x,a.y]]
		if recipe=="lift":
			d.platforms[0]=Rect2(-200,18,100,24)
			var carrier:=ModuleMovingPlatformDefinition.new();carrier.platform_id=&"well_lift";carrier.start=Vector2(110,-70);carrier.finish=Vector2(110,-570);carrier.size=Vector2(120,24);carrier.travel_duration=3.8;carrier.dwell_duration=1.5
			d.ferries.append(carrier)
			e.actions="wait_lift>jump_board>ride>jump_upper_bank"
		elif recipe=="recoil_shaft":
			for i: int in 3:
				var x: float=90.0 if i%2==0 else -90.0
				d.platforms.append(Rect2(x-70,-172-i*190,140,18));d.one_way_platform_indices.append(d.platforms.size()-1)
				e.path.append([a.x+x,a.y-190*(i+1)])
			e.actions="jump>aim_down>recoil_rise>land_recover>repeat"
		else:
			for i: int in 6:
				d.platforms.append(Rect2(-160 if i % 2 == 0 else 20, -82 - i * 100, 140, 18));d.one_way_platform_indices.append(d.platforms.size()-1)
				e.path.append([a.x + (-90 if i % 2 == 0 else 90), a.y - 100 * (i + 1)])
			e.actions="hold_jump>alternate_landing>look_up"
		if e.condition=="backside":
			d.world_bounds=Rect2(-250,-750,500,840)
			d.platforms.append(Rect2(-229,b.y-a.y+45,24,a.y-b.y-81))
			d.platforms.append(Rect2(205,b.y-a.y+45,24,a.y-b.y-81))
		_add_inline(m, e.id, a, d)
		e.path.append([b.x,b.y])
		if e.condition == "backside":
			e.gate = [a.x - 205, b.y + 45, 410, 24]
			e.control = [b.x, b.y]
		return
	# Horizontal edges combine phrases in a bounded lane with both-way landings.
	if not m.has("recipe_history"): m.recipe_history=[]
	var recipe:=PlainsRouteRecipes.choose(rng,m.recipe_history,m.difficulty=="intro")
	var ids: Array=recipe.modules
	e.recipe=recipe.id;e.action_signature=recipe.actions;e.pressure=recipe.pressure;e.decision=recipe.decision
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
	if e.get("shaft_recipe","")=="recoil_shaft": actions.air_shots=1;actions.requires_burst=true
	for index: int in e.get("modules",[]):
		var d:=definition(m.nodes[index])
		actions.air_shots=maxi(int(actions.air_shots),d.min_air_shots)
		actions.requires_burst=bool(actions.requires_burst) or d.requires_burst
		actions.shoot_mechanism=bool(actions.shoot_mechanism) or "windchime" in str(d.module_id) or d.module_id==&"plains_bell_ferry_control"
		if d.module_id==&"plains_remote_bell":actions.optional_remote_shot=true
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
	var carriers: Array=[]
	for f: ModuleMovingPlatformDefinition in d.ferries: carriers.append({"id":str(f.platform_id),"start":[f.start.x,f.start.y],"finish":[f.finish.x,f.finish.y],"size":[f.size.x,f.size.y],"travel":f.travel_duration,"dwell":f.dwell_duration,"phase":f.initial_phase})
	m.nodes.append({"id": id, "module_id": str(d.module_id), "offset": [p.x,p.y], "mirrored": false, "reverse_traversal": false, "initial_phases": [], "geometry": {"bounds": [d.world_bounds.position.x,d.world_bounds.position.y,d.world_bounds.size.x,d.world_bounds.size.y], "platforms": slabs, "one_way": d.one_way_platform_indices, "ferries":carriers, "junction": str(d.module_id) == "region_junction"}})

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
	for data: Dictionary in g.get("ferries",[]):
		var f:=ModuleMovingPlatformDefinition.new();f.platform_id=StringName(data.id);f.start=Vector2(data.start[0],data.start[1]);f.finish=Vector2(data.finish[0],data.finish[1]);f.size=Vector2(data.size[0],data.size[1]);f.travel_duration=data.travel;f.dwell_duration=data.dwell;f.initial_phase=data.phase;d.ferries.append(f)
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
	return m.connections.filter(func(e: Dictionary) -> bool: return e.condition == "open" and (e.a==id or (e.bidirectional and e.b==id))).size()

func _connected(m: Dictionary) -> bool:
	if m.areas.is_empty(): return false
	# Both forward and reverse flood: every reachable chamber also has an exit.
	for reverse: bool in [false,true]:
		var seen := {str(m.areas[0].id): true}
		for unused: int in m.areas.size():
			for e: Dictionary in m.connections:
				if e.condition != "open": continue
				var source: String=e.b if reverse else e.a
				var target: String=e.a if reverse else e.b
				if seen.has(source): seen[target]=true
				if e.bidirectional and seen.has(target): seen[source]=true
		if seen.size()!=m.areas.size(): return false
	return true

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
