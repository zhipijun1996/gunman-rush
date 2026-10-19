class_name ThornForestRegionV1
extends RefCounted
## Forest-owned semantic graph. Geometry, grants and encounters are recorded before assembly.
# Historical generation basis, not the current runtime movement/aim contract.
# Baseline 6c61faadd511c48a267b975550da897e701fd09f config bytes.
const GENERATION_TUNING_HASH := "e5161bb8ef1855b9eda515ab0613a4a738b47abc43b0f2dc118d2e45f71b2058"
const VERSION := "thorn-forest-region-v1"
const FAMILIES := ["embracing_trunks", "slant_canopy", "hollow_heart"]
const TRAVERSAL := preload("res://resources/player/traversal.tres")

static func seed_for(root_seed: String, map_index: int) -> String:
	return root_seed + "/thorn_forest/map_%s" % map_index

func generate(seed_value: String, tuning: PlayerTuning, map_index := 1, capability_snapshot: Dictionary = {}) -> Dictionary:
	if seed_value.is_empty() or tuning == null or map_index not in [1, 2] or not bool(capability_snapshot.get("grapple", false)):
		return {"ok":false, "error":"Forest entry requires the accepted H grant and a valid map index"}
	var m := _candidate(seed_value, map_index)
	if not validate(m, tuning): return {"ok":false, "error":"Forest layout contract failed; no unverified fallback used"}
	var points: Array[Vector2] = []
	for area: Dictionary in m.areas: points.append(Vector2(area.position[0], area.position[1]))
	return {"ok":true, "manifest":m, "stage_generator_version":VERSION,
		"boss_arena":_rect(m.boss_arena), "placement_points":points,
		"encounter_plan":{"version":VERSION, "enemies":m.enemies.duplicate(true)}, "exit_points":[]}

func _candidate(seed_value: String, map_index: int) -> Dictionary:
	var topology := RunRandomStream.new(seed_value, "forest_topology", "map_%s" % map_index, VERSION)
	var content := RunRandomStream.new(seed_value, "forest_ecology", "map_%s" % map_index, VERSION)
	var family: String = FAMILIES[topology.next_int(FAMILIES.size())]
	var mirror := topology.next_int(2) == 1
	var m := {"version":VERSION, "region":"thorn_forest", "map_index":map_index, "seed":seed_value,
		"family":family, "layout_id":"forest_canopy_loops", "fallback_id":"", "requires":["grapple"],
		"player_tuning_hash":GENERATION_TUNING_HASH,
		"traversal_hash":FileAccess.get_sha256("res://resources/player/traversal.tres"),
		"platforms":[], "hook_anchors":[], "areas":[], "connections":[], "rewards":[],
		"pickups":[], "enemies":[], "enemy_drops":{}, "dangers":[], "nodes":[{"id":"forest", "mirrored":mirror}],
		"merchant_id":"root_camp", "shop":{"item":"health_blue", "price":5, "stock":1},
		"shot_latch_plan":{"version":1, "latches":[]}, "terminal_exits":[],
		"streams":{"topology":"forest_topology", "content":"forest_ecology", "reward":"forest_rewards", "version":VERSION}}
	var start := Vector2(130, 582)
	_platform(m, "root_floor", Rect2(-250, 600, 1850, 100), false)
	_area(m, "arrival", start, "ROOT GLADE", "tutorial")
	var junction := _path(m, "learn", "arrival", "junction", start, [1, 1], 120.0)
	_area(m, "junction", junction, "FORKED BOUGHS", "junction")
	_platform(m, "junction_root", Rect2(junction.x-230, junction.y+18, 460, 36), true)
	var lower_steps: Array = [1, 1, -1]
	var upper_steps: Array = [-1, 1, 1]
	if family == "slant_canopy":
		lower_steps = [1, 1, 1, -1, -1]
		upper_steps = [-1, -1, 1, 1, 1]
	elif family == "hollow_heart":
		lower_steps = [1, -1, 1]
		upper_steps = [-1, -1, 1, 1, 1]
	# Both branch endpoints meet the same camp, but differ in turns and optional encounters.
	var rise := 120.0 if lower_steps.size() == 3 else 72.0
	var convergence := _path(m, "root_route", "junction", "camp", junction+Vector2(100,0), lower_steps, rise)
	var canopy_rise := 360.0 / float(upper_steps.size())
	var canopy_end := _path(m, "canopy_route", "junction", "camp", junction+Vector2(-100,0), upper_steps, canopy_rise)
	assert(absf(convergence.y-canopy_end.y) < 0.01 and absf(convergence.x-canopy_end.x) < 220.0)
	_area(m, "camp", convergence, "HOLLOW ROOT CAMP", "merchant")
	_platform(m, "camp_root", Rect2(convergence.x-270, convergence.y+18, 510, 20), true)
	m.merchant_position = _pair(convergence+Vector2(20, 0))
	var prize := _path(m, "cache_climb", "camp", "cache", convergence, [-1, -1, -1], 120.0)
	_area(m, "cache", prize, "THORN CROWN CACHE", "challenge_reward")
	_platform(m, "cache_root", Rect2(prize.x-95, prize.y+18, 260, 36), true)
	m.rewards.append({"id":"crown_cache", "area":"cache", "tier":"high", "position":_pair(prize), "claimed":false,
		"reward_mode":"item_resource", "items":["region_health_purple","region_damage_purple"], "coins":18,
		"resources":[{"kind":"coin","amount":18},{"kind":"note","amount":2}],
		"risk":{"depth":3,"platforming":3,"return":1}, "action_signature":"short_hook_crown_and_descent"})
	# One-way controlled descent is a real physical return, never an alive-enemy dependency.
	m.connections.append({"id":"cache_return", "a":"cache", "b":"camp", "kind":"descent", "condition":"open", "path":[_pair(prize),_pair(convergence)], "steps":[]})
	m.connections.append({"id":"camp_return", "a":"camp", "b":"junction", "kind":"descent", "condition":"open", "path":[_pair(convergence),_pair(junction)], "steps":[]})
	var prep_directions: Array = [1, 1] if map_index == 1 else [1, 1, -1, 1]
	var prep := _path(m, "crown_approach", "camp", "prep", convergence, prep_directions, 120.0)
	_area(m, "prep", prep, "GUARDIAN APPROACH" if map_index == 1 else "QUEEN'S CROWN", "prep")
	var arena := Rect2(prep.x+20, prep.y-490, 1100, 508)
	_platform(m, "arena_floor", Rect2(arena.position.x, arena.end.y, arena.size.x, 100), false)
	for side: int in [-1, 1]:
		var x := arena.get_center().x+side*330
		_platform(m, "arena_branch_%s" % side, Rect2(x-115, arena.end.y-110, 230, 20), true)
		m.hook_anchors.append({"id":"arena_ring_%s" % side, "position":[x+side*20,arena.end.y-145]})
		m.hook_anchors.append({"id":"arena_inner_ring_%s" % side, "position":[arena.get_center().x+side*150,arena.end.y-150]})
	_area(m, "boss", Vector2(arena.get_center().x, arena.end.y-18), "BRAMBLE WARDEN" if map_index == 1 else "THORN QUEEN", "boss")
	m.connections.append({"id":"arena_entry", "a":"prep", "b":"boss", "kind":"walk", "condition":"open", "path":[_pair(prep),m.areas[-1].position.duplicate()], "steps":[]})
	m.boss_arena = [arena.position.x,arena.position.y,arena.size.x,arena.size.y]
	m.spawn = _pair(start)
	m.routes = {"fast":["learn","canopy_route","crown_approach","arena_entry"],
		"growth":["learn","root_route","crown_approach","arena_entry"],
		"high_return":["learn","root_route","cache_climb","cache_return","camp_return"]}
	m.pickups.append({"id":"camp_heart", "kind":"heart", "amount":1, "position":_pair(convergence+Vector2(-65,-5))})
	m.pickups.append({"id":"crown_note", "kind":"note", "amount":2, "position":_pair(prize+Vector2(-35,-5))})
	var main_edge: Dictionary = m.connections[1]
	var live_step: Dictionary = main_edge.steps[1]
	var live_at := Vector2(live_step.anchor[0], live_step.anchor[1])+Vector2(45,-12)
	m.enemies.append({"id":"lantern", "behavior_id":"forest_lantern", "position":_pair(live_at), "aerial":true, "patrol_radius":28.0})
	# A separate broad branch gives the rooted sentry a real supported target and safe retreat.
	var seed_step: Dictionary = m.connections[2].steps[-1]
	var seed_at := Vector2(seed_step.landing[0],seed_step.landing[1])+Vector2(-55,0)
	m.enemies.append({"id":"seed_sentry", "behavior_id":"forest_seed_sentry", "position":_pair(seed_at), "aerial":false, "patrol_radius":0.0})
	if map_index == 2:
		m.enemies.append({"id":"lantern_crown", "behavior_id":"forest_lantern", "position":_pair(prep+Vector2(-80,-125)), "aerial":true, "patrol_radius":24.0})
	var dropper := EnemyDropService.new()
	dropper.configure(seed_value, "thorn_forest/map_%s" % map_index)
	for e: Dictionary in m.enemies: m.enemy_drops[e.id] = dropper.settle(StringName(e.id))
	# Optional thorns remain below a broad receiving platform, never inside the pull corridor.
	var low := prize+Vector2(-75,55)
	m.dangers.append([low.x,low.y,110.0,18.0])
	m.world_bounds = [-650.0, prep.y-650.0, maxf(2800.0,arena.end.x+800), 600.0-(prep.y-650.0)+160.0]
	# The gate seals the arena approach, ending at the solid floor's underside.
	# Extending it to the forest floor cuts off lower branches that pass beneath
	# the arena before the player has reached the key ring.
	var arena_floor_bottom := 0.0
	for platform: Dictionary in m.platforms:
		if platform.id == "arena_floor": arena_floor_bottom = _rect(platform.rect).end.y
	m.vine_gate = {"id":"crown_vine", "key_anchor":"crown_approach_ring_0", "rect":[arena.position.x-28, m.world_bounds[1], 16.0, arena_floor_bottom-float(m.world_bounds[1])]}
	if mirror: _mirror(m)
	m.manifest_hash = _hash(m)
	return m

func _path(m: Dictionary, id: String, from: String, to: String, start: Vector2, directions: Array, rise: float) -> Vector2:
	var current := start
	var steps: Array = []
	for i: int in directions.size():
		var side: int = int(directions[i])
		var target := current+Vector2(side*170,-rise-12)
		var end := current+Vector2(side*140,-rise)
		var support_id := id+"_branch_%s" % i
		var anchor_id := id+"_ring_%s" % i
		var left := current.x-30 if side > 0 else current.x-170
		_platform(m,support_id,Rect2(left,end.y+18,200,20),true)
		m.hook_anchors.append({"id":anchor_id,"position":_pair(target)})
		steps.append({"takeoff":_pair(current),"landing":_pair(end),"support_id":support_id,"anchor_id":anchor_id,"anchor":_pair(target)})
		current = end
	m.connections.append({"id":id,"a":from,"b":to,"kind":"hook_steps","condition":"open","path":[_pair(start),_pair(current)],"steps":steps})
	return current

func _platform(m: Dictionary, id: String, rect: Rect2, one_way: bool) -> void:
	m.platforms.append({"id":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"one_way":one_way})

func _area(m: Dictionary, id: String, at: Vector2, label: String, role: String) -> void:
	m.areas.append({"id":id,"position":_pair(at),"label":label,"role":role})

func _mirror(m: Dictionary) -> void:
	for platform: Dictionary in m.platforms: platform.rect[0] = -float(platform.rect[0])-float(platform.rect[2])
	for anchor: Dictionary in m.hook_anchors: anchor.position[0] = -float(anchor.position[0])
	for area: Dictionary in m.areas: area.position[0] = -float(area.position[0])
	for edge: Dictionary in m.connections:
		for p: Array in edge.path: p[0] = -float(p[0])
		for step: Dictionary in edge.steps:
			for key: String in ["takeoff","landing","anchor"]: step[key][0] = -float(step[key][0])
	for key: String in ["spawn","merchant_position"]: m[key][0] = -float(m[key][0])
	for list: String in ["rewards","pickups","enemies"]:
		for row: Dictionary in m[list]: row.position[0] = -float(row.position[0])
	for r: Array in m.dangers: r[0] = -float(r[0])-float(r[2])
	m.vine_gate.rect[0] = -float(m.vine_gate.rect[0])-float(m.vine_gate.rect[2])
	m.boss_arena[0] = -float(m.boss_arena[0])-float(m.boss_arena[2])
	m.world_bounds[0] = -float(m.world_bounds[0])-float(m.world_bounds[2])

func validate(m: Dictionary, tuning: PlayerTuning) -> bool:
	if tuning == null or m.get("version") != VERSION or m.get("region") != "thorn_forest" or not m.get("seed") is String or str(m.seed).is_empty(): return false
	var map_number: Variant = m.get("map_index")
	if not (map_number is int or map_number is float) or not is_finite(float(map_number)) or float(map_number) != float(int(map_number)) or int(map_number) not in [1,2]: return false
	if m.get("player_tuning_hash") != GENERATION_TUNING_HASH or m.get("traversal_hash") != FileAccess.get_sha256("res://resources/player/traversal.tres"): return false
	if m.get("manifest_hash") != _hash(m) or m.get("requires") != ["grapple"]: return false
	if not m.get("family") in FAMILIES: return false
	# Compare arbitrary replay data before accessing nested geometry. Rehashed malformed
	# arrays/objects must be rejected cleanly, not raise a script error during loading.
	if not RandomStageGenerator.new()._same_data(m,_candidate(str(m.seed),int(map_number))): return false
	if m.platforms.is_empty() or m.hook_anchors.is_empty(): return false
	var ids: Dictionary = {}
	for platform: Dictionary in m.platforms:
		if ids.has(platform.id) or platform.rect.size() != 4 or _rect(platform.rect).size.x < 60: return false
		ids[platform.id] = true
	var points: Dictionary = {}
	for anchor: Dictionary in m.hook_anchors:
		if points.has(anchor.id): return false
		points[anchor.id] = anchor.position
	for edge: Dictionary in m.connections:
		for step: Dictionary in edge.steps:
			if not ids.has(step.support_id) or points.get(step.anchor_id,[]) != step.anchor: return false
			var origin := Vector2(step.takeoff[0],step.takeoff[1]-6)
			if origin.distance_to(Vector2(step.anchor[0],step.anchor[1])) > TRAVERSAL.hook_range-4: return false
	# Rebuild candidate from seed to reject edited geometry, enemies, route IDs or hidden capability changes.
	return RandomStageGenerator.new()._same_data(m,_candidate(str(m.seed),int(m.map_index)))

static func _pair(point: Vector2) -> Array: return [point.x,point.y]
static func _rect(row: Array) -> Rect2: return Rect2(row[0],row[1],row[2],row[3])
static func _hash(m: Dictionary) -> String:
	var value := m.duplicate(true)
	value.erase("manifest_hash")
	# Save/JSON parsing represents numeric values as floats. Hash that same public
	# representation on both producer and replay, without weakening geometry checks.
	var canonical: Variant = JSON.parse_string(JSON.stringify(value,"",true))
	return JSON.stringify(canonical,"",true).sha256_text()
