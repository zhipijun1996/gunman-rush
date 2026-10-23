class_name PlainsRegionGenerator
extends RefCounted
## Topology is committed before terrain/content. No player tuning changes.
const VERSION := "plains-region-v10"
const RNG_VERSION := "plains-region-v4"
const FAMILIES := ["woven_layers", "linked_rings", "crossroads"]
const SAMPLE_DX := 1400.0 # Frozen small regression fixture only.
const SAMPLE_DY := 700.0 # Formal macros use measured phrase intervals and terrace rises.
const HALF := 200.0
const ATTEMPTS := 4
const PRE_FOCUS_15_TUNING_HASH := "e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
# A run pins content mode; legacy generation remains byte-identical.
var joint_recoil_profile := false # Explicit one-challenge semantic experiment; normal maps unchanged.
var regional_art_profile := "" # Candidate-only; empty preserves the exact formal map.
var art_language_profile := "" # Explicit pre-embedding language; no change to default/old joint records.
var root_bell_mode := "legacy_v10" # Preserve the old generator API; DemoApp explicitly pins admitted content.

func generate(seed_value: String, tuning: PlayerTuning, sample := false, force_family := "", difficulty := "advanced") -> Dictionary:
	return _generate_with_fingerprint(seed_value,tuning,sample,force_family,difficulty,FileAccess.get_sha256("res://config/player_tuning.json"))

# Only this immutable historical profile is replayable. The caller still uses
# current runtime tuning; this fingerprint identifies saved generation bytes.
func generate_before_focus_15(seed_value: String, tuning: PlayerTuning, sample := false, force_family := "", difficulty := "advanced") -> Dictionary:
	return _generate_with_fingerprint(seed_value,tuning,sample,force_family,difficulty,PRE_FOCUS_15_TUNING_HASH)

func _generate_with_fingerprint(seed_value: String,tuning: PlayerTuning,sample: bool,force_family: String,difficulty: String,tuning_hash: String) -> Dictionary:
	if regional_art_profile not in ["","continuous_plains_v1"]: return {"ok":false,"error":"Unknown regional art profile"}
	if art_language_profile not in ["","bounded_plains_v1"] or (art_language_profile!="" and (sample or joint_recoil_profile or regional_art_profile!="continuous_plains_v1")):
		return {"ok":false,"error":"Art-language candidate requires a full region and cannot inherit the rejected joint representation"}
	if difficulty not in ["intro","advanced"] or seed_value.is_empty() or tuning.max_jumps < 1 or tuning.max_air_shots < 1:
		return {"ok": false, "error": "Plains requires the existing base jump and recoil shot"}
	for attempt: int in ATTEMPTS:
		var m := _candidate(seed_value, sample, force_family, attempt,difficulty,tuning_hash)
		if validate(m, tuning): return _result(m)
	return _verified_fallback_with_fingerprint(seed_value,tuning,difficulty,tuning_hash)

func verified_fallback(seed_value: String,tuning: PlayerTuning,difficulty := "advanced") -> Dictionary:
	return _verified_fallback_with_fingerprint(seed_value,tuning,difficulty,FileAccess.get_sha256("res://config/player_tuning.json"))

func _verified_fallback_with_fingerprint(seed_value: String,tuning: PlayerTuning,difficulty: String,tuning_hash: String) -> Dictionary:
	if regional_art_profile != "" or joint_recoil_profile or art_language_profile!="": return {"ok":false,"error":"Regional art profile has no separately verified fallback"}
	var fallback := _candidate("region-woven_layers", false, "woven_layers", 0,difficulty,tuning_hash)
	fallback.seed = seed_value
	fallback.fallback_id = "verified_exploration_region"
	fallback.manifest_hash = _hash(fallback)
	return _result(fallback) if validate(fallback, tuning) else {"ok": false, "error": "Region fallback failed validation"}

func _candidate(seed_value: String, sample: bool, forced: String, attempt: int,difficulty := "advanced",tuning_hash := "") -> Dictionary:
	if art_language_profile not in ["","bounded_plains_v1"] or (art_language_profile!="" and (sample or joint_recoil_profile or regional_art_profile!="continuous_plains_v1")):
		return {"art_language_error":"Invalid or conflicting pre-embedding art profile"}
	var topology := RunRandomStream.new(seed_value, "region_topology", str(attempt), RNG_VERSION)
	var content := RunRandomStream.new(seed_value, "region_content", str(attempt), RNG_VERSION)
	var reward := RunRandomStream.new(seed_value, "region_reward", str(attempt), RNG_VERSION)
	var drawn_family: String=FAMILIES[topology.next_int(3)]
	var family: String = forced if forced in FAMILIES else drawn_family
	var cols := 3 if sample else 5 + topology.next_int(2)
	if difficulty=="intro" and not sample: cols=5
	var prep_row := 1 if sample else topology.next_int(3)
	var m := {"version": PlainsRootBellEncounterV3.CONTENT_VERSION if root_bell_mode == "v3" else PlainsRootBellEncounterV2.CONTENT_VERSION if root_bell_mode == "v2" else VERSION, "difficulty":difficulty, "player_tuning_hash":FileAccess.get_sha256("res://config/player_tuning.json") if tuning_hash.is_empty() else tuning_hash, "seed": seed_value, "region": "plains", "layout_id": "connected_region", "family": family, "attempt": attempt, "fallback_id": "", "sample": sample, "areas": [], "connections": [], "nodes": [], "rewards": [], "pickups": [], "enemies": [], "terminal_exits": [], "budget": {"ordinary_coins": 24, "medium": 2, "high": 1, "region_top": 1, "finite_hearts": 3,"cache_coin_limit":122,"cache_heart_limit":11,"cache_note_limit":8}, "streams": {"topology": "region_topology", "content": "region_content", "reward": "region_reward", "phases": "region_phases", "generation_seed": seed_value,"derivation_version":RNG_VERSION}}
	if joint_recoil_profile: m.joint_recoil_profile=true
	if art_language_profile!="":
		m.art_language_profile=art_language_profile
		m.art_language_catalog_sha256=FileAccess.get_sha256(PlainsArtLanguage.CATALOG)
		m.streams.art_language="region_art_language"
	if regional_art_profile != "":
		m.regional_art_profile=regional_art_profile
		m.art_layout={"minimum_column_span":1400.0,"quiet_arrival_width":180.0,"maximum_phrase_width":2200.0,"support_depth_policy":"original_collision_supports_and_preserved_lower_route_voids"}
	var footprint: Dictionary={"cells":[],"recipe":"fixed_sample"}
	if sample:
		for row: int in 3:
			for col: int in cols: footprint.cells.append([col,row])
	else: footprint=PlainsExplorationTopology.make(topology,family,15 if difficulty=="intro" else (15 if topology.next_int(2)==0 else 18))
	m.topology=footprint
	if not sample:
		m.topology.semantic_routes=PlainsExplorationTopology.route_specs()
		m.route_intents={"convergence":"area_2_1","main_recovery":"area_1_1","meaning":"short shot-recoil/headroom path, upper sightline discovery, and creek phase detour deliberately rejoin known camp"}
		for route_id: String in m.topology.semantic_routes:
			m.route_intents[route_id]=m.topology.semantic_routes[route_id].areas.duplicate()
	cols=0
	for cell: Array in footprint.cells:
		var col: int=cell[0];var row: int=cell[1]
		cols=maxi(cols,col+1)
		var label: String=["BELL WOODS","GRASS COURT","CREEK VAULT","REPAIR WELL","OLD CLOCK PIT"][row]
		m.areas.append({"id":"area_%s_%s" % [col,row],"position":[col*SAMPLE_DX,(row-1)*SAMPLE_DY] if sample else [0.0,0.0],"label":label,"row":row,"col":col,"role":"junction","ports":[]})
	var candidates: Array=[]
	for a: Dictionary in m.areas:
		var col: int=a.col;var row: int=a.row
		var right: String="area_%s_%s" % [col+1,row]
		var up: String="area_%s_%s" % [col,row-1]
		if not _area(m,right).is_empty(): candidates.append([a.id,right,"horizontal",col,row])
		if not _area(m,up).is_empty(): candidates.append([a.id,up,"stairs",col,row-1])
	for c: Array in candidates: _edge(m,c[0],c[1],c[2])
	var prep_candidates: Array=m.areas.filter(func(a: Dictionary): return a.col>=cols-2 and _area(m,"area_%s_%s" % [int(a.col)+1,int(a.row)]).is_empty() and _degree(m,a.id)>=2)
	if prep_candidates.is_empty(): prep_candidates=m.areas.filter(func(a: Dictionary): return a.col==cols-2 and _degree(m,a.id)>=2)
	var chosen_prep: Dictionary=prep_candidates[topology.next_int(prep_candidates.size())]
	prep_row=int(chosen_prep.row)
	m.prep_id=str(chosen_prep.id)
	# Cut galleries at different columns. No uninterrupted parallel highways.
	if not sample:
		for row: int in 5:
			var horizontal: Array=m.connections.filter(func(e: Dictionary): return e.kind=="horizontal" and int(_area(m,e.a).row)==row and not _semantic_edge(m,str(e.a),str(e.b)))
			if horizontal.is_empty(): continue
			var cut: Dictionary=horizontal[topology.next_int(horizontal.size())]
			var at: int=m.connections.find(cut);m.connections.remove_at(at)
			if not _connected(m) or _cycles(m)<5 or _degree(m,m.prep_id)<2: m.connections.insert(at,cut)
	# Seed changes traversal, not only content. Remove non-bridge edges while
	# retaining three independent cycles and two incoming prep routes.
	for unused: int in 4 if not sample else 0:
		var removable: Array=m.connections.filter(func(e: Dictionary): return e.kind=="horizontal" and not _semantic_edge(m,str(e.a),str(e.b)))
		if removable.is_empty(): break
		var candidate: Dictionary=removable[topology.next_int(removable.size())]
		var at: int=m.connections.find(candidate)
		m.connections.remove_at(at)
		if not _connected(m) or _cycles(m) < 5 or _degree(m,m.prep_id) < 2:
			m.connections.insert(at, candidate)
	if sample:
		_edge(m, "area_0_1", "area_1_0", "diagonal", "open", false)
	# Keep the authored outer creek arm a circuit rather than a 700-unit
	# descent whose only exit repeats the same shaft. No new reward budget.
	if not sample and not _area(m,"area_4_3").is_empty() and not _area(m,"area_3_3").is_empty() and m.prep_id != "area_4_3" and _degree(m,"area_4_3") == 1:
		_edge(m,"area_3_3","area_4_3","horizontal")
		m.connections[-1].outer_return = true
		m.topology.outer_return = {"areas":["area_3_3","area_4_3","area_4_2"],"purpose":"water_crossing_returns_by_forward_shaft_instead_of_repeating_entry"}
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
			# Reserve the authored upper discovery→known fork descent in well rings.
			if not sample and family=="linked_rings" and e.a=="area_1_1" and e.b=="area_1_0": continue
			if _semantic_edge(m,str(e.a),str(e.b)) or e.kind != "stairs" or e.condition != "open" or (sample and e.b == "area_1_0") or m.prep_id in [e.a,e.b]: continue
			e.condition = "backside"
			if not _connected(m) or _cycles(m) < 3: e.condition = "open"
			else: shortcuts += 1
	# Well-rings deliberately use one-way descent arms and separate climb returns.
	# Courtyard weave retains bidirectional crossings; hub satellites use lifts.
	if not sample and family=="linked_rings":
		var converted:=0
		for e: Dictionary in m.connections:
			if converted==2: break
			if _semantic_edge(m,str(e.a),str(e.b)) or e.kind!="stairs" or e.condition!="open" or m.prep_id in [e.a,e.b]: continue
			var lower: String=e.a;var upper: String=e.b;e.a=upper;e.b=lower;e.kind="drop";e.bidirectional=false
			if not _connected(m): e.a=lower;e.b=upper;e.kind="stairs";e.bidirectional=true
			else: converted+=1
	var camps: Array=m.areas.filter(func(a: Dictionary): return a.id not in ["area_0_1",m.prep_id] and a.row==1 and a.col in [1,2])
	content.next_int(camps.size()) # Preserve named content stream consumption, placement is authored.
	m.merchant_id="area_2_1"
	_area(m, m.prep_id).role = "prep"
	_area(m, m.prep_id).label = "WINDKEEPER APPROACH"
	_area(m, m.merchant_id).role = "merchant"
	_area(m, m.merchant_id).label = "CAMP / MERCHANT"
	# Authored identities are consumers of topology: terrain/recipes/ecology and
	# the scene compositor share this field. Merchant is a protected convergence.
	for a: Dictionary in m.areas:
		if sample: content.next_int(5) # Exact legacy fixture random stream alignment.
		a.identity="repair_gallery" if a.id==m.merchant_id else "clock_court" if a.row==0 else "creek_well" if a.row>=2 else "windmill_plateau"
		a.landmark={"repair_gallery":"ivy","clock_court":"ruin_arch","creek_well":"stones","windmill_plateau":"windmill"}[a.identity]
		a.label={"repair_gallery":"REPAIR GALLERY","clock_court":"BROKEN CLOCK COURT","creek_well":"CREEK RETURN","windmill_plateau":"WINDMILL MEADOW"}[a.identity] if a.role=="junction" else a.label
		a.spatial_intent="observe_routes_and_recover" if a.id==m.merchant_id else "look_across_water" if a.identity=="creek_well" else "frame_clock_sightline" if a.identity=="clock_court" else "open_meadow_landing"
	if not sample:
		# Plan phrases before allocating world space. Each interval is sized from
		# its actual authored modules; no single rectangular grid spacing.
		var spans: Array=[0.0,0.0,0.0,0.0]
		m.recipe_history=[]
		for e: Dictionary in m.connections:
			if e.kind!="horizontal": continue
			var area: Dictionary=_area(m,e.a)
			e.purpose="outer_return" if e.get("outer_return",false) else "creek_discovery" if e.a=="area_1_2" and e.b=="area_2_2" else "first_short_chain" if e.a=="area_0_1" else "rejoin_repair_camp" if e.b==m.merchant_id else "explore_creek_return" if area.identity=="creek_well" else "learn_clock_sightline" if area.identity=="clock_court" else "meadow_crossing"
			e.design_recipe=PlainsRouteRecipes.choose(content,m.recipe_history,difficulty=="intro",e.purpose,str(area.identity))
			if art_language_profile!="":
				e.art_language=PlainsArtLanguage.plan_recipe(e.design_recipe,str(area.identity),str(e.id))
				if not e.art_language.ok:
					m.art_language_error=e.art_language.error
					return m
			if joint_recoil_profile:
				# A world construction sentence exists BEFORE any Definition or
				# column/span embedding is allocated. Unimplemented sentences are
				# explicitly counted, never reported as converted environment.
				e.environment_program=PlainsJointRecoilPlan.program_for_recipe(e.design_recipe,str(area.identity),str(e.id),seed_value)
		if joint_recoil_profile:PlainsJointRecoilPlan.bind_vertical_programs(m)
		# This intent exists while every formal area position is still unassigned
		# and before module instances/Definition projections enter the Manifest.
		if art_language_profile!="":
			m.art_language_intent=PlainsArtLanguage.plan_world_intent(m)
			if not m.art_language_intent.ok:
				m.art_language_error=m.art_language_intent.error
				return m
		for e: Dictionary in m.connections:
			if e.kind!="horizontal":continue
			var area: Dictionary=_area(m,e.a)
			var width:=0.0
			for module_id: String in e.design_recipe.modules:
				if joint_recoil_profile and e.get("environment_program",{}).get("implemented",false) and module_id==e.environment_program.get("module_id",""):
					width+=float(e.environment_program.module_width)
				else:width+=RandomStageGenerator.new().definition_for(module_id,false,false).world_bounds.size.x
			var quiet_width:=180.0 if regional_art_profile!="" else 0.0
			if art_language_profile!="":
				width=maxf(width,float(e.art_language.minimum_expression_width))
				quiet_width=float(e.art_language.quiet_arrival_width)
			if regional_art_profile!="": e.art_clearance={"quiet_arrival_width":quiet_width,"purpose":"land_read_next_route_before_reentering_pressure","source":"continuous_plains_v1"}
			spans[int(area.col)]=maxf(float(spans[int(area.col)]),width+HALF*2.0+80.0+quiet_width)
		var xs: Array=[0.0]
		for col: int in spans.size():
			var minimum:=1400.0 if regional_art_profile!="" else 1080.0
			if art_language_profile!="":minimum=float(m.art_language_intent.get("minimum_column_spans",{}).get(str(col),m.art_language_intent.minimum_column_span))
			xs.append(float(xs[-1])+maxf(minimum,float(spans[col])))
		for a: Dictionary in m.areas: a.position=[xs[int(a.col)],footprint.terrace_heights[int(a.row)]]
		m.topology.column_positions=xs
		m.topology.embedding="phrase_clearance_and_authored_terraces"
		if art_language_profile!="":
			m.art_language_world=PlainsArtLanguage.resolve_world(m.art_language_intent,m)
			if not m.art_language_world.ok:
				m.art_language_error=m.art_language_world.error
				return m
			m.topology.embedding="operation_and_art_family_clearance_before_module_projection"
	# Multipoint platforms and real ascending/descending stair shafts.
	for a: Dictionary in m.areas:
		var drop: bool = m.connections.any(func(e: Dictionary) -> bool: return (e.kind=="stairs" and e.b==a.id) or (e.kind=="drop" and e.a==a.id))
		var recovery_half:=320.0 if not sample and a.id in ["area_1_1","area_3_1"] else HALF
		var d := _floor_definition("region_junction",Rect2(-recovery_half,18,recovery_half*2,32),drop)
		_add_inline(m, a.id, _point(a.position), d)
	for e: Dictionary in m.connections:
		_fill_edge(m, e, content)
	# A real side-island in the optional creek, not another cache on the direct route.
	if not sample:
		for e: Dictionary in m.connections:
			if e.get("purpose","")!="creek_discovery":continue
			var ferry_node: Dictionary=m.nodes[int(e.modules[0])]
			var bank:=_floor_definition("creek_cache_bank",Rect2(350,210,140,18),true)
			bank.world_bounds=Rect2(350,100,140,160)
			_add_inline(m,"creek_cache_bank",_point(ferry_node.offset),bank)
			m.creek_discovery={"module":ferry_node.id,"bank":"creek_cache_bank","entry_area":e.a,"exit_area":e.b,"camp":"area_2_1","reward_id":"plains/chest/medium_1","safe_observation":"entry dock; island; receiving dock","return":"receiving dock -> area_2_2 -> protected climb -> known camp","hint_from":"area_1_1"}
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
		for route: Dictionary in footprint.challenge_routes:
			_deep_loop(m,str(route.entry),str(route["return"]),str(route.tier),content)
	for a: Dictionary in m.areas:
		for e: Dictionary in m.connections:
			if e.a != a.id and e.b != a.id: continue
			var other := _area(m, e.b if e.a == a.id else e.a)
			var direction := (_point(other.position) - _point(a.position)).normalized()
			a.ports.append({"connection": e.id, "position": a.position.duplicate(), "direction": [direction.x, direction.y], "actions": _connection_actions(m,e), "condition": e.condition, "safe_landing": a.position.duplicate(), "outgoing": e.bidirectional or e.a == a.id})
	# Fixed total reward budget, independent of map size; position/risk determines tier.
	for i: int in 2:
		var preferred: Array=["area_1_1"] if i==0 else ["area_2_2"] if not sample else ["area_1_0","area_2_2"]
		var eligible: Array=m.areas.filter(func(a: Dictionary): return a.role=="junction" and a.id in preferred and not m.rewards.any(func(c: Dictionary): return c.area==a.id))
		if eligible.is_empty(): eligible=m.areas.filter(func(a: Dictionary): return a.role=="junction" and a.id!="area_0_1" and not m.rewards.any(func(c: Dictionary): return c.area==a.id))
		var area_id: String=eligible[reward.next_int(eligible.size())].id
		var p := _point(_area(m, area_id).position)
		if i==1 and m.has("creek_discovery"):
			var ferry_node: Dictionary=m.nodes.filter(func(n:Dictionary):return n.id==m.creek_discovery.module)[0]
			p=_point(ferry_node.offset)+Vector2(520,192)
		m.rewards.append({"id": "plains/chest/medium_%s" % i, "area": area_id, "tier": "medium", "position": [p.x - 100, p.y], "coins": 8, "items": ["damage_blue", "health_blue"], "risk": {"depth": 2, "platforming": 1, "timing": 1, "pressure": 1, "return": 1}})
	if m.has("creek_discovery"):
		for cache: Dictionary in m.rewards:
			if cache.id==m.creek_discovery.reward_id:cache.approach=m.creek_discovery.duplicate(true)
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
			# First creek demonstration teaches one diver; fan remains on later ordinary ferries.
			if m.has("creek_discovery") and n.id==m.creek_discovery.module and wanted_pattern!="ferry_air_intercept":continue
			if not sample and str(n.id).begins_with("plains/passage/area_0_1/area_1_1"):continue
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
				# Low arches reserve headroom. A recessed wheel must not silently move an aerial guard below the old ceiling filter.
				if d.module_id==&"plains_low_arch":continue
				# Aerial pressure at the approach, not an unavoidable stack over the saw.
				local=d.saws[0].envelope().get_center()+Vector2(85,-105)
				pattern="gear_landing_intercept";mechanism=str(d.saws[0].source_id)
			elif "windchime" in str(n.module_id):
				local=d.exit_port.position+Vector2(-90,-105)
				pattern="bell_window_intercept";mechanism="shot_latch"
			else: continue
			if m.has("creek_discovery") and n.id==m.creek_discovery.module:local=Vector2(260,165) # visible intercept beside launch; never patrol the island/only receiver
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
		if m.enemies.size()>=enemy_limit-1 or a.id in ["area_0_1","area_1_1","area_1_2","area_2_2", m.prep_id, m.merchant_id] or content.next_int(4 if difficulty=="intro" else 6) == 0: continue
		var behavior: String=["charger","sentry","diver","hopper"][content.next_int(4)]
		var aerial: bool=behavior=="diver"
		var p := _point(a.position) + (Vector2(70,-110) if aerial else Vector2(130,0))
		# The approach and known upper return bank share an observation/recoil
		# role. Reserve the right-hand receiver/retreat band from generic bodies.
		if _trial_observation_bank(m,a):p=_point(a.position)+(Vector2(-130,-65) if aerial else Vector2(-130,0))
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
	if root_bell_mode == "v3":
		m.root_bell_admission = PlainsRootBellEncounterV3.apply(m,definition)
	elif root_bell_mode == "v2":
		m.root_bell_admission = PlainsRootBellEncounterV2.apply(m,definition)
	elif PlainsRootBellPlacement.PRODUCTION_ADMITTED:
		m.root_bell_admission = PlainsRootBellPlacement.apply(m)
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
	var geometry_bounds:=Rect2(_point(m.spawn),Vector2.ONE)
	for node: Dictionary in m.nodes:
		var d:=definition(node)
		geometry_bounds=geometry_bounds.merge(Rect2(_point(node.offset)+d.world_bounds.position,d.world_bounds.size))
	geometry_bounds=geometry_bounds.grow(320.0)
	m.world_bounds = [geometry_bounds.position.x,geometry_bounds.position.y,geometry_bounds.size.x,geometry_bounds.size.y]
	if not sample:
		m.ground_supports = _regional_landmass_supports(m) if regional_art_profile=="continuous_plains_v1" and not joint_recoil_profile and art_language_profile=="" else PlainsGroundSupports.region_plan(m)
		if regional_art_profile=="continuous_plains_v1": m.art_layout.landmass_method="landform_first_joint_with_explicit_legacy_remainder" if joint_recoil_profile else "world_base_mass_minus_actual_lower_route_voids_v2"
		if art_language_profile!="":m.art_layout.landmass_method="finite_rear_landforms_with_formal_shallow_supports_front_family_pending"
	if joint_recoil_profile:
		var programs:=0
		for edge: Dictionary in m.connections:
			if edge.has("environment_program"):programs+=1
		m.environment_coverage={"programmed_horizontal_edges":programs,"converted_challenges":0,"total_nodes":m.nodes.size(),"legacy_remainder":true,"whole_region_landform_first":false,"support_baseline":"formal_shallow_supports","physics_scope":"whole_region_support_baseline_plus_owned_landform","unconverted_nodes":m.nodes.map(func(n:Dictionary)->String:return str(n.id))}
	if joint_recoil_profile and m.has("joint_recoil_target"):
		var joint_node: Dictionary=m.nodes.filter(func(n:Dictionary)->bool:return n.id==m.joint_recoil_target)[0]
		var context:=PlainsJointRecoilPlan.context_for_region(m,joint_node)
		if context.ok:
			joint_node.joint_recoil=PlainsJointRecoilPlan.build_local(context.context)
			m.environment_coverage.converted_challenges=2
			m.environment_coverage.unconverted_nodes.erase(str(joint_node.id))
			m.environment_coverage.owned_node_ids=[]
			for owned: Dictionary in context.context.owned_slabs:
				m.environment_coverage.unconverted_nodes.erase(str(owned.node_id))
				if str(owned.node_id) not in m.environment_coverage.owned_node_ids:m.environment_coverage.owned_node_ids.append(str(owned.node_id))
			var joint:=PlainsJointRecoilPlan.instantiate(joint_node)
			m.ground_supports=PlainsJointRecoilPlan.clip_supports(m.ground_supports,joint.cutout_rects)
		else: m.joint_recoil_error=context.error
	m.shot_latch_plan = PlainsShotLatchPlanner.recorded_plan(m)
	m.stream_positions={"topology":topology.position(),"content":content.position(),"reward":reward.position()}
	var shop_rng:=RunRandomStream.new(seed_value,"region_shop",str(attempt),RNG_VERSION)
	var shop_pool: Array=["damage_blue","health_blue","efficient_grip","stability_blue","braided_cord","quick_hammer","brake_boots"]
	m.shop={"item":shop_pool[shop_rng.next_int(shop_pool.size())],"price":5,"stock":1}
	m.streams.shop="region_shop"
	m.streams.items="region_items"
	m.item_version="plains-items-v2"
	m.shot_energy_version="time-energy-v2"
	if art_language_profile!="":
		var planned: Array=[]
		var unresolved: Array=[]
		for node: Dictionary in m.nodes:
			if node.has("art_expression"):planned.append(str(node.id))
			else:unresolved.append(str(node.id))
		m.art_language_coverage={"planned_node_ids":planned,"unresolved_inline_or_tutorial_node_ids":unresolved,"whole_region_front_art_ready":false,"scope":"horizontal_recipe_modules_and_registered_junction_connection; remaining_vertical_tutorial_reward_boss_are_explicit_remainder"}
	m.manifest_hash = _hash(m)
	return m

# Candidate-only second production method. The formal empty-profile path above
# continues to use its original shallow supports byte for byte.
func _regional_landmass_supports(m: Dictionary) -> Array:
	var sources: Array = []
	var obstacles: Array[Rect2] = []
	var definitions: Array = []
	var protected_air: Array = []
	var base := float(m.world_bounds[1])+float(m.world_bounds[3])+PlainsGroundSupports.EXTRA_DEPTH
	for node: Dictionary in m.nodes:
		var d := definition(node)
		var offset := _point(node.offset)
		definitions.append({"id":node.id,"definition":d,"offset":offset})
		# A newly continuous underground must not become a rescue floor below
		# an original jump gap or a shaft. Retain those fall columns to the
		# original region kill boundary, independently of successful route tests.
		var coverage: Array = []
		for index: int in d.platforms.size():
			if index in d.one_way_platform_indices: continue
			coverage.append([offset.x+d.platforms[index].position.x,offset.x+d.platforms[index].end.x])
		coverage.sort_custom(func(a: Array,b: Array)->bool:return float(a[0])<float(b[0]))
		var cursor:=offset.x+minf(d.entry_port.position.x,d.exit_port.position.x)
		var finish:=offset.x+maxf(d.entry_port.position.x,d.exit_port.position.x)
		for span: Array in coverage:
			if float(span[0])>cursor+8.0:
				var gap:=Rect2(cursor,offset.y+d.world_bounds.position.y,float(span[0])-cursor,base-(offset.y+d.world_bounds.position.y))
				protected_air.append({"owner":node.id,"kind":"original_gap_or_shaft_fall_column","standing_y":offset.y+maxf(d.entry_port.position.y,d.exit_port.position.y)+18.0,"rect":[gap.position.x,gap.position.y,gap.size.x,gap.size.y]})
			cursor=maxf(cursor,float(span[1]))
		if finish>cursor+8.0:
			var gap:=Rect2(cursor,offset.y+d.world_bounds.position.y,finish-cursor,base-(offset.y+d.world_bounds.position.y))
			protected_air.append({"owner":node.id,"kind":"original_gap_or_shaft_fall_column","standing_y":offset.y+maxf(d.entry_port.position.y,d.exit_port.position.y)+18.0,"rect":[gap.position.x,gap.position.y,gap.size.x,gap.size.y]})
		for slab: Rect2 in d.platforms: obstacles.append(Rect2(offset+slab.position,slab.size))
		for danger: Rect2 in d.danger_bounds: obstacles.append(Rect2(offset+danger.position,danger.size).grow(28.0))
		for ferry: ModuleMovingPlatformDefinition in d.ferries:
			var envelope:=ferry.envelope()
			obstacles.append(Rect2(offset+envelope.position,envelope.size).grow(28.0))
		for saw: ModuleSawDefinition in d.saws:
			var envelope:=saw.envelope()
			obstacles.append(Rect2(offset+envelope.position,envelope.size).grow(28.0))
		if str(node.module_id).begins_with("region_deep") or str(node.module_id).begins_with("region_drop"): continue
		for index: int in d.platforms.size():
			var slab:=d.platforms[index]
			# One-way ledges retain actual drop semantics; vertical walls and
			# narrow suspended stepping stones cannot seed an earth column.
			if index in d.one_way_platform_indices or slab.size.x<160.0 or slab.size.y<24.0: continue
			var start:=offset+Vector2(slab.position.x,slab.end.y)
			if start.y>=base: continue
			sources.append({"id":node.id,"rect":Rect2(start,Vector2(slab.size.x,base-start.y))})
	# A fall column ends only at an already existing complete SOLID receiving
	# floor, never at invented earth or a droppable one-way stepping stone.
	for space: Dictionary in protected_air:
		var raw: Array=space.rect
		var gap:=Rect2(raw[0],raw[1],raw[2],raw[3])
		var stop:=base
		for entry: Dictionary in definitions:
			var d: PlatformingModuleDefinition=entry.definition
			var offset: Vector2=entry.offset
			for index: int in d.platforms.size():
				if index in d.one_way_platform_indices: continue
				var floor:=Rect2(offset+d.platforms[index].position,d.platforms[index].size)
				if floor.position.y>float(space.standing_y)+2.0 and floor.position.x<=gap.position.x and floor.end.x>=gap.end.x:
					stop=minf(stop,floor.position.y)
		gap.size.y=maxf(0.0,stop-gap.position.y)
		space.rect=[gap.position.x,gap.position.y,gap.size.x,gap.size.y]
		obstacles.append(gap)
	# Explicit reward evacuation paths are as authoritative as authored modules.
	for edge: Dictionary in m.connections:
		var path: Array=edge.get("return_polyline",[])
		for index: int in maxi(0,path.size()-1):
			var a:=_point(path[index]);var b:=_point(path[index+1])
			obstacles.append(Rect2(a.min(b)-Vector2(58.0,48.0),(a-b).abs()+Vector2(116.0,96.0)))
	var result: Array[Rect2] = []
	for source: Dictionary in sources:
		var column: Rect2=source.rect
		var protected: Array[Rect2]=obstacles.duplicate()
		for entry: Dictionary in definitions:
			var d: PlatformingModuleDefinition=entry.definition
			var offset: Vector2=entry.offset
			# Preserve the complete lower room, including presently empty jump
			# and recoil air, not just its platform rectangles. Full shafts and
			# ferry wells remain void. Same-level solid neighbours may unify.
			if entry.id!=source.id and PlainsGroundSupports._has_lower_route(d,offset,column.position.y):
				protected.append(Rect2(offset+d.world_bounds.position,d.world_bounds.size).grow(24.0))
		var pieces: Array[Rect2]=[column]
		for obstacle: Rect2 in protected:
			var next: Array[Rect2]=[]
			for piece: Rect2 in pieces: next.append_array(_regional_rect_difference(piece,obstacle))
			pieces=next
			if pieces.size()>1400:
				m.art_layout.landmass_budget_failed=true
				return []
			if pieces.is_empty(): break
		result.append_array(pieces)
	m.art_layout.protected_airspaces=protected_air
	var unique: Array[Rect2]=[]
	var seen: Dictionary={}
	for support: Rect2 in result:
		var key:=str(support)
		if not seen.has(key): unique.append(support);seen[key]=true
	var values: Array=[]
	for support: Rect2 in PlainsGroundSupports._merge_columns(unique): values.append([support.position.x,support.position.y,support.size.x,support.size.y])
	return values

static func _regional_rect_difference(source: Rect2, obstacle: Rect2) -> Array[Rect2]:
	if not source.intersects(obstacle): return [source]
	var cut:=source.intersection(obstacle)
	var result: Array[Rect2]=[]
	# Four disjoint pieces preserve earth BELOW a carved room as well as
	# either side; the old horizontal-only split discarded that whole column.
	var pieces: Array[Rect2]=[
		Rect2(source.position,Vector2(cut.position.x-source.position.x,source.size.y)),
		Rect2(Vector2(cut.end.x,source.position.y),Vector2(source.end.x-cut.end.x,source.size.y)),
		Rect2(Vector2(cut.position.x,source.position.y),Vector2(cut.size.x,cut.position.y-source.position.y)),
		Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,source.end.y-cut.end.y))]
	for piece: Rect2 in pieces:
		if piece.size.x>=12.0 and piece.size.y>=12.0: result.append(piece)
	return result

func _trial_observation_bank(m:Dictionary,a:Dictionary) -> bool:
	for edge:Dictionary in m.connections:
		if edge.kind=="challenge" and edge.a==a.id:return true
		if edge.kind!="drop" or not edge.has("return_polyline"):continue
		# Real generated evacuation points, not fixed column/Seed coordinates.
		for point:Array in edge.return_polyline.slice(1):
			if _point(point).distance_to(_point(a.position))<1.0:return true
	return false

func _deep_loop(m: Dictionary, entry_id: String, return_id: String, tier: String, rng: RunRandomStream) -> void:
	var base := _point(_area(m,entry_id).position)
	var id := "deep_" + tier
	# Existing two-level moving ferry then precise recoil rise, fully in upper air.
	var variant:=rng.next_int(3)
	var recipe_ids: Array
	if tier=="high":
		recipe_ids=["plains_recoil_step","plains_remote_sequence"] if variant==0 else ["plains_ferry_two","plains_recoil_step"] if variant==1 else ["plains_windchime_timed","plains_recoil_double"]
	else:
		recipe_ids=["plains_ferry_gears" if m.difficulty=="advanced" else "plains_ferry_two","plains_recoil_double"] if variant==0 else ["plains_recoil_double","plains_windchime_sequence" if m.difficulty=="advanced" else "plains_windchime_timed"] if variant==1 else ["plains_windchime_sequence" if m.difficulty=="advanced" else "plains_windchime_timed","plains_recoil_double"]
	var selected_reason := "authored_variant"
	if tier=="high" and m.difficulty=="advanced" and variant==0:
		recipe_ids=["plains_recoil_step","plains_windchime_rush"]
		selected_reason="main_taught_double_sightline_high_combines_recoil_rise_and_deadline"
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
	var return_point:=_point(_area(m,return_id).position)
	# A wider optional ferry chain may legitimately rejoin the farther Boss-side
	# meadow. Choose a real authored recovery anchor near its physical exit.
	if tier=="region_top" and landing.x>return_point.x+100.0:
		return_id="area_4_1"
		return_point=_point(_area(m,return_id).position)
	var landing_width:=maxf(180,return_point.x+80-landing.x)
	_add_inline(m,id+"_landing",landing,_floor_definition("region_drop_exit",Rect2(0,18,landing_width,24),true))
	var reward_position:=Vector2(maxf(landing.x+35,return_point.x),landing.y)
	m.areas.append({"id": id, "position": [reward_position.x, reward_position.y], "label": "DEEP TRIAL / " + tier.to_upper(), "role": "challenge_reward", "ports": []})
	_edge(m,entry_id,id,"challenge","open",false)
	_edge(m, id, return_id, "drop", "open", false)
	var drop_edge: Dictionary=m.connections[-1]
	drop_edge.escape_x=reward_position.x
	var clear_y: float=landing.y
	for node_id: String in trial_modules:
		var node: Dictionary=m.nodes.filter(func(n: Dictionary): return n.id==node_id)[0]
		var d:=definition(node)
		for danger: Rect2 in d.danger_bounds: clear_y=maxf(clear_y,float(node.offset[1])+danger.end.y+24)
		for saw: ModuleSawDefinition in d.saws: clear_y=maxf(clear_y,float(node.offset[1])+saw.envelope().end.y+24)
	drop_edge.clear_y=maxf(clear_y,return_point.y-18.0)
	drop_edge.return_intent="drop_to_known_upper_bank_open_real_return_control_then_descend_to_recovery"
	drop_edge.return_polyline=[[reward_position.x,reward_position.y],[return_point.x,base.y],[return_point.x,return_point.y]]
	m.rewards.append({"id": "plains/chest/" + tier, "area": id, "tier": tier, "position": [reward_position.x, reward_position.y], "coins": 18 if tier == "high" else 30, "items": ["region_damage_purple", "region_health_purple"] if tier == "high" else ["region_damage_gold", "region_health_gold"], "risk": {"depth": 3, "platforming": 3, "timing": 3, "pressure": 0, "resource": 2, "return": 2}, "variant":variant,"rolled_variant":variant,"selected_reason":selected_reason,"challenge_modules":trial_modules,"action_signature":str(recipe_ids[0]).trim_prefix("plains_")+">"+str(recipe_ids[1]).trim_prefix("plains_")})

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
		var rise:=a.y-b.y
		d.world_bounds = Rect2(-220,-rise-50,440,rise+140)
		e.path = [[a.x,a.y]]
		if recipe=="lift":
			d.platforms[0]=Rect2(-200,18,100,24)
			var carrier:=ModuleMovingPlatformDefinition.new();carrier.platform_id=&"well_lift";carrier.start=Vector2(110,-70);carrier.finish=Vector2(110,-rise+130);carrier.size=Vector2(120,24);carrier.travel_duration=3.8;carrier.dwell_duration=1.5
			d.ferries.append(carrier)
			e.actions="wait_lift>jump_board>ride>jump_upper_bank"
		elif recipe=="recoil_shaft":
			for i: int in maxi(1,floori((rise-100.0)/190.0)):
				var x: float=90.0 if i%2==0 else -90.0
				var height:=minf(190.0*(i+1),rise-100.0)
				d.platforms.append(Rect2(x-70,18-height,140,18));d.one_way_platform_indices.append(d.platforms.size()-1)
				e.path.append([a.x+x,a.y-height])
			e.actions="jump>aim_down>recoil_rise>land_recover>repeat"
		else:
			for i: int in maxi(1,floori((rise-100.0)/100.0)):
				var height:=minf(100.0*(i+1),rise-80.0)
				d.platforms.append(Rect2(-160 if i % 2 == 0 else 20,18-height,140,18));d.one_way_platform_indices.append(d.platforms.size()-1)
				e.path.append([a.x + (-90 if i % 2 == 0 else 90), a.y-height])
			e.actions="hold_jump>alternate_landing>look_up"
		if e.condition=="backside":
			d.world_bounds=Rect2(-250,-rise-50,500,rise+140)
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
	var recipe: Dictionary=e.get("design_recipe",{})
	if recipe.is_empty(): recipe=PlainsRouteRecipes.choose(rng,m.recipe_history,m.difficulty=="intro","legacy_sample" if m.sample else "")
	var ids: Array=recipe.modules
	e.recipe=recipe.id;e.action_signature=recipe.actions;e.pressure=recipe.pressure;e.decision=recipe.decision
	if m.sample and e.a == "area_0_1": ids = []
	var x := a.x + HALF
	e.modules = []
	for id: String in ids:
		var program: Dictionary=e.get("environment_program",{}) if joint_recoil_profile and e.get("environment_program",{}).get("implemented",false) and id==e.environment_program.get("module_id","") and (e.id==m.get("environment_target_edge","") or e.environment_program.has("parent_program_id")) else {}
		var d := PlainsJointRecoilPlan.definition_from_program(program) if not program.is_empty() else RandomStageGenerator.new().definition_for(id, false, false)
		_add_existing(m, e.id + "_%s" % e.modules.size(), id, Vector2(x, a.y),program)
		if art_language_profile!="":
			# Preserve the exact locally authored action geometry, while binding
			# its visual specification selected before any world coordinates.
			var expression: Dictionary=e.art_language.modules[e.modules.size()].duplicate(true)
			expression.source_edge_id=e.id
			expression.source_order=e.art_language.source_order
			m.nodes[-1].art_expression=expression
		e.modules.append(m.nodes.size()-1)
		x += d.world_bounds.size.x
	if x < b.x - HALF:
		var remaining := b.x - HALF - x
		var overlap := 0.0
		# This overlap only repairs the certified bridge/arch join into the solid arch floor only; preserve the receiving one-way floor.
		if remaining == 20.0 and recipe.id == "thorn_gap" and ids == ["plains_thorn_bridge", "plains_low_arch"] and a.y == b.y:
			var arch := definition(m.nodes[int(e.modules[-1])])
			var receiving_nodes: Array = m.nodes.filter(func(n: Dictionary): return n.id == e.b)
			if receiving_nodes.size() == 1:
				var receiving := definition(receiving_nodes[0])
				var arch_floor := arch.platforms[0]
				var receiving_floor := receiving.platforms[0]
				if not arch.one_way_platform_indices.has(0) and arch_floor == Rect2(0,300,640,32) and receiving_floor == Rect2(-HALF,18,HALF*2,32):
					overlap = 20.0
		var join := _floor_definition("region_connection", Rect2(-overlap,18,remaining + overlap,32))
		if overlap > 0.0:
			join.anchors.assign([Vector2(-4,0), Vector2(4,0)])
			join.entry_port = _port("entry", join.anchors[0])
			join.exit_port = _port("exit", join.anchors[1])
		# Bind art expression to the final source geometry, including the old
		# certified 20px overlap correction; never mutate it after binding.
		_add_inline(m, e.id + "_join", Vector2(x, a.y), join,{"standing_margin":16.0} if overlap>0.0 else {})
	e.path = [[a.x,a.y],[b.x,b.y]]

func _connection_actions(m: Dictionary,e: Dictionary) -> Dictionary:
	var actions: Dictionary={"jumps":0 if e.kind=="drop" else 1,"air_shots":1 if e.kind=="challenge" or (e.kind=="tutorial" and e.a=="tutorial_jump") else 0,"shoot_mechanism":e.kind=="tutorial" and e.a=="tutorial_bell","requires_burst":e.kind=="challenge" or (e.kind=="tutorial" and e.a=="tutorial_jump")}
	if e.get("shaft_recipe","")=="recoil_shaft": actions.air_shots=1;actions.requires_burst=true
	for index: int in e.get("modules",[]):
		var d:=definition(m.nodes[index])
		actions.air_shots=maxi(int(actions.air_shots),d.min_air_shots)
		actions.requires_burst=bool(actions.requires_burst) or d.requires_burst
		actions.shoot_mechanism=bool(actions.shoot_mechanism) or "windchime" in str(d.module_id) or d.module_id in [&"plains_bell_ferry_control",&"plains_remote_sequence"]
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

func _add_existing(m: Dictionary, id: String, module_id: String, entry: Vector2, environment_program: Dictionary = {}) -> void:
	var d := PlainsJointRecoilPlan.definition_from_program(environment_program) if not environment_program.is_empty() else RandomStageGenerator.new().definition_for(module_id, false, false)
	var phase_stream := RunRandomStream.new(str(m.seed), "region_phases", id, RNG_VERSION)
	var phases: Array = []
	for saw: ModuleSawDefinition in d.saws: phases.append({"id":str(saw.source_id),"phase":float(phase_stream.next_int(4))/4.0})
	for ferry: ModuleMovingPlatformDefinition in d.ferries: phases.append({"id":str(ferry.platform_id),"phase":float(phase_stream.next_int(4))/4.0})
	var offset := entry - Vector2(0, d.entry_port.position.y)
	var node := {"id": id, "module_id": module_id, "offset": [offset.x,offset.y], "mirrored": false, "reverse_traversal": false, "initial_phases": phases, "definition_version":d.definition_version,"definition_hash":JSON.stringify(_definition_data(d),"",true).sha256_text()}
	if not environment_program.is_empty():node.environment_program=environment_program.duplicate(true)
	if joint_recoil_profile and module_id==PlainsJointRecoilPlan.MODULE_ID and not environment_program.is_empty() and not id.begins_with("tutorial") and not m.has("joint_recoil_target"):
		m.joint_recoil_target=id
	m.nodes.append(node)

func _add_inline(m: Dictionary, id: String, p: Vector2, d: PlatformingModuleDefinition, geometry_overrides: Dictionary = {}) -> void:
	var slabs: Array = []
	for rect: Rect2 in d.platforms: slabs.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
	var carriers: Array=[]
	for f: ModuleMovingPlatformDefinition in d.ferries: carriers.append({"id":str(f.platform_id),"start":[f.start.x,f.start.y],"finish":[f.finish.x,f.finish.y],"size":[f.size.x,f.size.y],"travel":f.travel_duration,"dwell":f.dwell_duration,"phase":f.initial_phase})
	var node := {"id": id, "module_id": str(d.module_id), "offset": [p.x,p.y], "mirrored": false, "reverse_traversal": false, "initial_phases": [], "geometry": {"bounds": [d.world_bounds.position.x,d.world_bounds.position.y,d.world_bounds.size.x,d.world_bounds.size.y], "platforms": slabs, "one_way": d.one_way_platform_indices, "ferries":carriers, "junction": str(d.module_id) == "region_junction"}}
	node.geometry.merge(geometry_overrides,true)
	if art_language_profile!="" and str(d.module_id) in ["region_junction","region_connection"]:
		var expression := PlainsArtLanguage.plan_generated(node)
		if expression.get("ok",false):node.art_expression=expression
		else:m.art_language_error=expression.get("error","Generated connection has no legal finite painting assembly")
	m.nodes.append(node)

static func definition(node: Dictionary) -> PlatformingModuleDefinition:
	if not node.has("geometry"):
		var authored := PlainsJointRecoilPlan.definition_from_program(node.environment_program) if node.has("environment_program") else PlainsJointRecoilPlan.definition_from_spec(node.joint_recoil.semantic_source) if node.has("joint_recoil") else RandomStageGenerator.new().definition_for(str(node.module_id),false,false).duplicate(true) as PlatformingModuleDefinition
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
	var standing_margin := float(g.get("standing_margin", 20.0))
	d.anchors.assign([Vector2(floor_rect.position.x+standing_margin,floor_rect.position.y-18),Vector2(floor_rect.end.x-standing_margin,floor_rect.position.y-18)])
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

func _semantic_edge(m: Dictionary,a: String,b: String) -> bool:
	if m.get("sample",false): return false
	for spec: Dictionary in m.topology.semantic_routes.values():
		var path: Array=spec.areas
		for i: int in range(path.size()-1):
			if (path[i]==a and path[i+1]==b) or (path[i]==b and path[i+1]==a): return true
	return false

func semantic_route_errors(m: Dictionary) -> Array[String]:
	var errors: Array[String]=[]
	if m.get("sample",false): return errors
	var required: Dictionary=PlainsExplorationTopology.route_specs()
	var declared: Variant=m.get("route_intents",{})
	var topology_routes: Variant=m.get("topology",{}).get("semantic_routes",{})
	if not declared is Dictionary or not topology_routes is Dictionary:
		errors.append("missing semantic route contracts");return errors
	for route_id: String in required:
		var path: Array=required[route_id].areas
		if declared.get(route_id,[])!=path or topology_routes.get(route_id,{})!=required[route_id]:
			errors.append(route_id+": declaration differs from authored split/rejoin contract")
		for i: int in range(path.size()-1):
			var source: String=path[i];var target: String=path[i+1]
			if _area(m,source).is_empty() or _area(m,target).is_empty():
				errors.append(route_id+": actual route area missing");continue
			var usable:=false
			for edge: Dictionary in m.get("connections",[]):
				var forward: bool=edge.get("a","")==source and edge.get("b","")==target
				var reverse: bool=edge.get("b","")==source and edge.get("a","")==target and bool(edge.get("bidirectional",false))
				if not forward and not reverse: continue
				# These are first-visit choices, so no speculative upper-side unlock.
				if edge.get("condition","")!="open": continue
				var future:=false
				for ability: String in edge.get("required_capabilities",[]):
					if ability not in ["base_jump","base_recoil","shoot_mechanism"]: future=true
				if future: continue
				usable=true;break
			if not usable: errors.append(route_id+": unavailable directed initial step "+source+" -> "+target)
	if declared.get("convergence","")!="area_2_1" or m.get("merchant_id","")!="area_2_1": errors.append("known camp convergence mismatch")
	return errors

func validate(m: Dictionary, tuning: PlayerTuning) -> bool:
	if m.get("player_tuning_hash") not in [FileAccess.get_sha256("res://config/player_tuning.json"),PRE_FOCUS_15_TUNING_HASH]: return false
	if m.get("regional_art_profile","") not in ["","continuous_plains_v1"]: return false
	if m.get("art_language_profile","") not in ["","bounded_plains_v1"] or m.has("art_language_error"):return false
	if m.get("art_language_profile","")!="" and (m.get("sample",false) or m.get("joint_recoil_profile",false)):return false
	if m.get("version") not in [VERSION, PlainsRootBellEncounterV2.CONTENT_VERSION, PlainsRootBellEncounterV3.CONTENT_VERSION] or m.get("manifest_hash") != _hash(m) or not _connected(m) or _cycles(m) < 3 or not semantic_route_errors(m).is_empty(): return false
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
	var previous_mode := root_bell_mode
	var previous_art_profile := regional_art_profile
	var previous_joint_profile := joint_recoil_profile
	var previous_language_profile := art_language_profile
	joint_recoil_profile = bool(m.get("joint_recoil_profile",false))
	art_language_profile = str(m.get("art_language_profile",""))
	regional_art_profile = str(m.get("regional_art_profile",""))
	root_bell_mode = "v3" if m.version == PlainsRootBellEncounterV3.CONTENT_VERSION else "v2" if m.version == PlainsRootBellEncounterV2.CONTENT_VERSION else "legacy_v10"
	var expected := _candidate("region-woven_layers" if m.fallback_id != "" else str(m.seed),bool(m.get("sample",false)),str(m.family),int(m.attempt),str(m.get("difficulty","advanced")),str(m.player_tuning_hash))
	root_bell_mode = previous_mode
	regional_art_profile = previous_art_profile
	joint_recoil_profile = previous_joint_profile
	art_language_profile = previous_language_profile
	if m.fallback_id != "":
		expected.seed = m.seed
		expected.fallback_id = m.fallback_id
	return _hash(expected) == _hash(m)

func _result(m: Dictionary) -> Dictionary:
	var arena: Array = m.boss_arena
	var points: Array[Vector2] = []
	for a: Dictionary in m.areas: points.append(_point(a.position))
	return {"ok": true, "manifest": m, "placement_points": points, "boss_arena": Rect2(arena[0],arena[1],arena[2],arena[3]), "stage_generator_version": m.version, "encounter_plan": {"version": m.version, "enemies": m.enemies}, "shot_latch_plan": m.shot_latch_plan}

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
