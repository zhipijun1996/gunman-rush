class_name ThornQueenCanopyDefinition
extends ThornQueenWeaveDefinition
## Typed reuse of existing Knot/Band configuration, with an independent content contract.
## Legacy WeaveDefinition coordinates are not consumed by this geometry builder.
const VERSION := "forest-queen-canopy-v3"
const CONTRACT := "forest-queen-canopy-v3"
@export var canopy_arena := Rect2(400,0,560,600)
@export var canopy_platforms: Array[Rect2] = [Rect2(400,600,560,36),Rect2(400,360,100,240),Rect2(650,260,50,340),Rect2(720,560,240,76),Rect2(400,20,560,40)]
@export var canopy_platform_ids: Array[String] = ["floor","central_rib","right_rib","right_bank","canopy"]
@export var canopy_hooks: Array[Vector2] = [Vector2(640,300),Vector2(800,250),Vector2(575,490)]
@export var canopy_hook_ids: Array[String] = ["A","B","low_recovery"]
@export var canopy_spawn := Vector2(450,342)
@export var canopy_boss := Vector2(550,440)
@export var canopy_reward := Vector2(550,582)
@export var canopy_speed := 360.0
@export var canopy_preview := 0.65
@export var canopy_path_a: Array[Vector2] = [Vector2(550,440),Vector2(550,310),Vector2(426,310),Vector2(600,200),Vector2(740,200),Vector2(740,410)]
@export var canopy_path_b: Array[Vector2] = [Vector2(740,410),Vector2(740,510),Vector2(930,510),Vector2(930,110)]
@export var canopy_path_c: Array[Vector2] = [Vector2(930,110),Vector2(426,110),Vector2(550,110)]
@export var canopy_path_d: Array[Vector2] = [Vector2(550,110),Vector2(550,550),Vector2(530,550),Vector2(620,550),Vector2(550,440)]
@export var high_knot := Vector2(730,150)
@export var high_strand := PackedVector2Array([Vector2(700,230),Vector2(760,230)])
@export var receiver_ids: Array[String] = ["S","low","right"]
@export var receiver_supports: Array[Rect2] = [Rect2(400,360,100,240),Rect2(500,600,150,36),Rect2(720,560,240,76)]
@export var receiver_knots: Array[Vector2] = [Vector2(480,220),Vector2(575,450),Vector2(850,410)]
@export var receiver_starts: Array[Vector2] = [Vector2(412,340),Vector2(512,580),Vector2(732,540)]
@export var receiver_tips: Array[Vector2] = [Vector2(488,340),Vector2(638,580),Vector2(948,540)]
func is_valid() -> bool:
	if stable_id.is_empty() or definition_version<1 or health_definition==null or not health_definition.is_valid() or knot_health_definition==null or not knot_health_definition.is_valid(): return false
	if not collision_size.is_finite() or collision_size.x<=0 or collision_size.y<=0: return false
	for value: float in [canopy_speed,canopy_preview,intro_seconds,repeat_intro_seconds,entry_gap,entry_overlap,player_half_height,knot_collision_size.x,knot_collision_size.y,strand_radius,preview_seconds,grow_seconds,strand_damage,strand_interval]:
		if not is_finite(value) or value<=0: return false
	if not is_finite(phase_two_threshold) or not is_finite(phase_three_health) or not 0<phase_three_health or not phase_three_health<phase_two_threshold or not phase_two_threshold<1: return false
	if canopy_platforms.size()!=canopy_platform_ids.size() or canopy_hooks.size()!=canopy_hook_ids.size() or high_strand.size()!=2: return false
	if receiver_ids.size()!=3 or receiver_supports.size()!=3 or receiver_knots.size()!=3 or receiver_starts.size()!=3 or receiver_tips.size()!=3: return false
	for rect: Rect2 in canopy_platforms+[canopy_arena]+receiver_supports:
		if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x<=0 or rect.size.y<=0: return false
	for point: Vector2 in canopy_hooks+[canopy_spawn,canopy_boss,canopy_reward,high_knot]+receiver_knots+receiver_starts+receiver_tips+Array(high_strand):
		if not point.is_finite(): return false
	var paths: Array = [canopy_path_a,canopy_path_b,canopy_path_c,canopy_path_d]
	for index: int in paths.size():
		var path: Array=paths[index]
		if path.size()<2: return false
		for point: Vector2 in path:
			if not point.is_finite(): return false
		if path.back()!=paths[(index+1)%paths.size()][0]: return false
	return canopy_path_a[0]==canopy_boss and knot_health_definition.max_health==2 and health_definition.max_health==24
func build_geometry(origin: Vector2, include_connector := false) -> Dictionary:
	if not is_valid() or not origin.is_finite(): return {"ok":false,"reason":"Invalid canopy definition/origin"}
	var platforms: Array[Dictionary]=[]
	for index: int in canopy_platforms.size(): platforms.append({"id":canopy_platform_ids[index],"rect":_rect(Rect2(origin+canopy_platforms[index].position,canopy_platforms[index].size)),"one_way":false})
	var hooks: Array[Dictionary]=[]
	for index: int in canopy_hooks.size(): hooks.append({"id":canopy_hook_ids[index],"position":_point(origin+canopy_hooks[index])})
	var paths: Array=[]
	for path: Array[Vector2] in [canopy_path_a,canopy_path_b,canopy_path_c,canopy_path_d]:
		var shifted: Array=[]
		for point: Vector2 in path: shifted.append(_point(origin+point))
		paths.append(shifted)
	var receivers: Array[Dictionary]=[]
	for index: int in receiver_ids.size():
		receivers.append({"id":receiver_ids[index],"support":_rect(Rect2(origin+receiver_supports[index].position,receiver_supports[index].size)),"knot_position":_point(origin+receiver_knots[index]),"strand_start":_point(origin+receiver_starts[index]),"strand_tip":_point(origin+receiver_tips[index])})
	var entry_point := origin+canopy_spawn-Vector2(entry_gap+50,0)
	var entry := {"id":"canopy_entry","rect":_rect(Rect2(Vector2(entry_point.x-entry_overlap,origin.y+360),Vector2(entry_gap+entry_overlap*2,24))),"one_way":false}
	if include_connector: platforms.append(entry)
	return {"ok":true,"version":VERSION,"boss_contract":CONTRACT,"origin":_point(origin),"boss_arena":_rect(Rect2(origin+canopy_arena.position,canopy_arena.size)),"platforms":platforms,"hook_anchors":hooks,"root_supports":[],"boss_position":_point(origin+canopy_boss),"player_spawn":_point(origin+canopy_spawn),"safe_return":_point(origin+canopy_spawn),"reward_position":_point(origin+canopy_reward),"entrance_position":_point(origin+canopy_spawn),"external_prep":_point(entry_point),"entrance_connector":entry if include_connector else {},"arena_center":_point(origin+canopy_arena.get_center()),"motion_paths":paths,"receiver_fields":receivers,"high_field":{"id":"high","knot_position":_point(origin+high_knot),"strand_start":_point(origin+high_strand[0]),"strand_tip":_point(origin+high_strand[1])},"admission":"candidate_whole_boss_pending"}
static func _point(point: Vector2) -> Array: return [point.x,point.y]
static func _rect(rect: Rect2) -> Array: return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
