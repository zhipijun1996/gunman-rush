class_name ForestBossArenaFactory
extends RefCounted
const VERSION := "forest-guardian-duel-arena-v4"
func from_prep(prep: Vector2, map_index: int, definition: BossDuelDefinition = null) -> Dictionary:
	if map_index == 2: return _queen_region_entry(prep)
	if map_index != 1: return {"ok":false,"version":VERSION,"reason":"Unknown forest map index"}
	var config := definition
	if config == null: config = load("res://resources/bosses/rootbell_guardian_v2.tres") as BossDuelDefinition
	if config == null or not config.is_valid() or not prep.is_finite(): return {"ok":false,"version":VERSION,"reason":"Invalid guardian definition/prep"}
	var left := prep.x + config.entrance_gap
	var floor_y := prep.y + config.player_half_height
	var center := Vector2(left + config.arena_size.x*.5,floor_y)
	var arena := Rect2(Vector2(left,floor_y-config.arena_size.y),config.arena_size)
	var entry := {"id":"boss_entry","rect":[prep.x-config.entrance_overlap,floor_y,config.entrance_overlap+config.entrance_gap+config.safe_inset,config.floor_depth],"one_way":false}
	var platforms: Array[Dictionary] = [entry]
	platforms.append(_platform("guardian_canopy_roof",Rect2(arena.position-Vector2(0,config.canopy_depth),Vector2(arena.size.x,config.canopy_depth)),false))
	platforms.append(_platform("boss_floor",Rect2(Vector2(left,floor_y),Vector2(config.arena_size.x,config.floor_depth)),false))
	platforms.append(_platform("counter_branch",Rect2(center+config.counter_offset-Vector2(config.counter_size.x*.5,0),config.counter_size),true))
	var branches: Array[Dictionary] = []
	var hooks: Array[Dictionary] = []
	var stands: Array = []
	for side: int in [-1,1]:
		var tag := "left" if side < 0 else "right"
		var root_rect := Rect2(center+Vector2(config.branch_offset.x*side,config.branch_offset.y)-Vector2(config.branch_size.x*.5,0),config.branch_size)
		var branch := _platform("guardian_branch_"+tag,root_rect,true)
		platforms.append(branch)
		branches.append(branch.duplicate(true))
		for kind: String in ["inner","return"]:
			var offset := config.inner_hook_offset if kind == "inner" else config.return_hook_offset
			hooks.append({"id":kind+"_"+tag,"position":_point(center+Vector2(offset.x*side,offset.y))})
		stands.append(_point(center+Vector2(config.counter_stand_offset.x*side,config.counter_stand_offset.y)))
	return {"ok":true,"version":VERSION,"boss_contract":"guardian-arrival-counter-golden","boss_arena":_rect(arena),"platforms":platforms,"entrance_connector":entry,"entrance_position":_point(Vector2(left+config.safe_inset,floor_y-config.player_half_height)),"root_supports":[],"side_branches":branches,"hook_anchors":hooks,"counter_stands":stands,"boss_position":_point(center+config.boss_offset),"safe_return":_point(Vector2(left+config.safe_inset,floor_y-config.player_half_height)),"arena_center":_point(center)}
func _queen_region_entry(prep: Vector2) -> Dictionary:
	# A v2 geometry consumer, not whole-Boss admission. Default region remains v1.
	var config := load("res://resources/bosses/thorn_queen_v2.tres") as ThornForestDefinition
	if config == null or not config.is_valid() or not prep.is_finite(): return {"ok":false,"reason":"Invalid Queen definition/prep"}
	var gap: Variant = config.get("entry_gap")
	var overlap: Variant = config.get("entry_overlap")
	var half: Variant = config.get("player_half_height")
	var observation: Variant = config.get("entrance_observation_offset")
	var size: Variant = config.get("arena_size")
	for value: Variant in [gap,overlap,half]:
		if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<=0: return {"ok":false,"reason":"Invalid Queen entry dimensions"}
	if not observation is Vector2 or not size is Vector2 or not (observation as Vector2).is_finite() or not (size as Vector2).is_finite(): return {"ok":false,"reason":"Invalid Queen observation geometry"}
	if absf(observation.y+float(half)-size.y)>.001 or observation.x<float(overlap) or observation.x>=size.x: return {"ok":false,"reason":"Queen entry must meet existing permanent floor"}
	var origin := Vector2(prep.x+float(gap),prep.y+float(half)-size.y)
	var result := queen_golden(config,origin)
	if not result.get("ok",false): return result
	var floor_y: float = origin.y+float(size.y)
	var connector := _platform("queen_entry_connector",Rect2(Vector2(prep.x-float(overlap),floor_y),Vector2(float(gap)+float(overlap)*2,float(config.get("floor_depth")))),false)
	result.platforms.append(connector)
	result["entrance_connector"] = connector
	result["entrance_position"] = _point(origin+observation)
	result["safe_return"] = _point(origin+observation)
	result["boss_contract"] = "queen-weave-region-experimental"
	result["admission"] = "experimental_whole_boss_pending"
	result["entry_mapping"] = {"prep":_point(prep),"origin":_point(origin),"existing_floor_y":floor_y,"observation":_point(origin+observation),"new_high_bridge":false}
	return result
func queen_canopy_from_prep(prep: Vector2) -> Dictionary:
	# The approach walks into the existing wide S root at its actual height.
	# Legacy queen_golden/from_prep keep their exact recorded bottom entrance.
	var config := load("res://resources/bosses/thorn_queen_canopy.tres") as ThornQueenCanopyDefinition
	if config==null or not config.is_valid() or not prep.is_finite(): return {"ok":false,"reason":"Invalid canopy definition/prep"}
	var local_prep := Vector2(config.canopy_arena.position.x-config.entry_gap,config.canopy_spawn.y)
	return config.build_geometry(prep-local_prep,true)

func _platform(id: String, rect: Rect2, one_way: bool) -> Dictionary:
	return {"id":id,"rect":_rect(rect),"one_way":one_way}
func _point(point: Vector2) -> Array: return [point.x,point.y]
func _rect(rect: Rect2) -> Array: return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func queen_golden(definition: ThornForestDefinition = null, origin: Vector2 = Vector2.ZERO) -> Dictionary:
	# Independent weave candidate. This does not open map2/from_prep.
	var config := definition
	if config == null:
		var path := "res://resources/bosses/thorn_queen_v2.tres"
		if not ResourceLoader.exists(path): return {"ok":false,"reason":"Queen weave definition not ready"}
		config = load(path) as ThornForestDefinition
	if config == null or not config.is_valid() or not origin.is_finite(): return {"ok":false,"reason":"Invalid Queen weave definition/origin"}
	var size: Variant = config.get("arena_size")
	var depth: Variant = config.get("floor_depth")
	var spawn: Variant = config.get("player_spawn_offset")
	var boss: Variant = config.get("boss_offset")
	var rows: Variant = config.get("platform_rows")
	var solid_rows: Variant = config.get("solid_rows")
	var waypoint_offsets: Variant = config.get("migration_waypoint_offsets")
	var offsets: Variant = config.get("hook_offsets")
	var perch_offsets: Variant = config.get("perch_offsets")
	var knots: Variant = config.get("weave_knots")
	var tips: Variant = config.get("weave_tips")
	var starts: Variant = config.get("weave_starts")
	var phase_two_perches: Variant = config.get("phase_two_perches")
	var phase_three_perches: Variant = config.get("phase_three_perches")
	var phase_two_waypoints: Variant = config.get("phase_two_waypoints")
	var phase_three_waypoints: Variant = config.get("phase_three_waypoints")
	if not size is Vector2 or not spawn is Vector2 or not boss is Vector2 or not perch_offsets is Array or not knots is Array or not tips is Array or not starts is Array or not rows is Array or not solid_rows is Array or not waypoint_offsets is Array or not offsets is Array or typeof(depth) not in [TYPE_INT,TYPE_FLOAT]:
		return {"ok":false,"reason":"Queen weave geometry fields missing"}
	if perch_offsets.is_empty() or knots.is_empty() or knots.size() != tips.size() or starts.size() != knots.size(): return {"ok":false,"reason":"Queen weave/perch rows incomplete"}
	var perches: Array[Dictionary] = []
	for index: int in perch_offsets.size():
		if not perch_offsets[index] is Vector2 or not (perch_offsets[index] as Vector2).is_finite(): return {"ok":false,"reason":"Queen perch offset invalid"}
		perches.append({"id":"queen_perch_%s" % index,"position":_point(origin+perch_offsets[index])})
	var fields: Array[Dictionary] = []
	for index: int in knots.size():
		if not starts[index] is Vector2 or not (starts[index] as Vector2).is_finite() or not knots[index] is Vector2 or not tips[index] is Vector2 or not (knots[index] as Vector2).is_finite() or not (tips[index] as Vector2).is_finite(): return {"ok":false,"reason":"Queen weave endpoints invalid"}
		fields.append({"id":"queen_weave_%s" % index,"knot_position":_point(origin+knots[index]),"strand_start":_point(origin+starts[index]),"strand_tip":_point(origin+tips[index])})
	var phase_perches: Array = []
	var base_perches: Array = []
	for perch: Dictionary in perches: base_perches.append(perch.position)
	phase_perches.append(base_perches)
	for phase_rows: Variant in [phase_two_perches,phase_three_perches]:
		if not phase_rows is Array or phase_rows.is_empty(): return {"ok":false,"reason":"Queen phase perches missing"}
		var positions: Array = []
		for offset: Variant in phase_rows:
			if not offset is Vector2 or not (offset as Vector2).is_finite(): return {"ok":false,"reason":"Queen phase perch invalid"}
			positions.append(_point(origin+offset))
		phase_perches.append(positions)
	var arena_size: Vector2 = size
	var floor_y := origin.y+arena_size.y
	var platforms: Array[Dictionary] = [_platform("queen_floor",Rect2(Vector2(origin.x,floor_y),Vector2(arena_size.x,float(depth))),false)]
	for index: int in rows.size():
		if not rows[index] is Rect2: return {"ok":false,"reason":"Queen platform row is not Rect2"}
		var rect: Rect2 = rows[index]
		rect.position += origin
		platforms.append(_platform("queen_branch_%s" % index,rect,true))
	for index: int in solid_rows.size():
		if not solid_rows[index] is Rect2: return {"ok":false,"reason":"Queen solid row is not Rect2"}
		var rect: Rect2 = solid_rows[index]
		if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0 or rect.size.y <= 0: return {"ok":false,"reason":"Queen solid row invalid"}
		rect.position += origin
		platforms.append(_platform("queen_root_%s" % index,rect,false))
	var waypoints: Array = []
	for offset: Variant in waypoint_offsets:
		if not offset is Vector2 or not (offset as Vector2).is_finite(): return {"ok":false,"reason":"Queen migration waypoint invalid"}
		waypoints.append(_point(origin+offset))
	var phase_waypoints: Array = [waypoints.duplicate(true)]
	for phase_rows: Variant in [phase_two_waypoints,phase_three_waypoints]:
		if not phase_rows is Array: return {"ok":false,"reason":"Queen phase waypoints missing"}
		var positions: Array = []
		for offset: Variant in phase_rows:
			if not offset is Vector2 or not (offset as Vector2).is_finite(): return {"ok":false,"reason":"Queen phase waypoint invalid"}
			positions.append(_point(origin+offset))
		phase_waypoints.append(positions)
	var hooks: Array[Dictionary] = []
	for index: int in offsets.size():
		if not offsets[index] is Vector2: return {"ok":false,"reason":"Queen hook offset is not Vector2"}
		hooks.append({"id":"queen_hook_%s" % index,"position":_point(origin+offsets[index])})
	return {"ok":true,"version":"forest-queen-weave-golden-v2","boss_contract":"queen-weave-golden-only","boss_arena":_rect(Rect2(origin,arena_size)),"platforms":platforms,"hook_anchors":hooks,"root_supports":[],"boss_position":_point(origin+boss),"player_spawn":_point(origin+spawn),"safe_return":_point(origin+spawn),"arena_center":_point(origin+arena_size*.5),"perches":perches,"phase_perches":phase_perches,"migration_waypoints":waypoints,"phase_waypoints":phase_waypoints,"weave_fields":fields,"knot_position":fields[0].knot_position,"strand_tip":fields[0].strand_tip}
