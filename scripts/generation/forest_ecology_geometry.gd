class_name ForestEcologyGeometry
extends RefCounted
## One data source for the woven-crown local golden and formal placement consumers.
## Extraction after ecology-combination03; the extraction itself needs fresh native validation.
const VERSION := "forest-woven-crown-v1"
const LOCAL_SPAWN := Vector2(10,282)
const LOCAL_EXIT := Vector2(450,282)

static func woven_crown(entry: Vector2 = LOCAL_SPAWN, facing := 1) -> Dictionary:
	if not entry.is_finite() or facing not in [-1,1]: return {}
	var local_spawn := LOCAL_SPAWN
	var offset := entry-Vector2(local_spawn.x*facing,local_spawn.y)
	var lantern: Resource=load("res://resources/enemies/forest_lantern.tres")
	var spider: Resource=load("res://resources/enemies/forest_thread_spider.tres")
	var data := {"version":VERSION,"physical_class":"woven_crown_H_R_dual_route",
		"admission":"extracted_pending_fresh_native_and_formal_return",
		"spawn":[local_spawn.x,local_spawn.y],
		"platforms":[
			{"id":"woven_root_floor","rect":[-1200,300,2600,50],"one_way":false,"role":"root_floor"},
			{"id":"woven_main_branch","rect":[210,220,190,16],"one_way":true,"role":"main_branch"}],
		"hook_anchors":[{"id":"woven_fixed_ring","position":[140,90]}],"dangers":[],
		"enemies":[
			{"id":"woven_thread_spider","behavior_id":"forest_thread_spider","position":[290,282],
			"aerial":bool(spider.get("aerial")),"patrol_radius":float(spider.get("patrol_half_width")),
			"line_start":[120,282],"line_end":[240,282]},
			{"id":"woven_lantern","behavior_id":"forest_lantern","position":[170,165],
			"aerial":bool(lantern.get("aerial")),"patrol_radius":float(lantern.get("patrol_half_width"))}],
		"observation":{"position":[local_spawn.x,local_spawn.y],"protected_points_in_original_golden":[],"preview":"whole line and both targets visible from the normal entry"},
		"main_branch_goal":{"support_id":"woven_main_branch","role":"main_branch","position":[300,202]},
		"exit":{"position":[LOCAL_EXIT.x,LOCAL_EXIT.y],"support_id":"woven_root_floor","condition":"x beyond exit and grounded, player alive"},
		"return_contract":{"required":true,"native_verified":false,"from":[LOCAL_EXIT.x,LOCAL_EXIT.y],"to":[local_spawn.x,local_spawn.y],
			"supports":["woven_root_floor","woven_main_branch"],"fixed_anchors":["woven_fixed_ring"],
			"strategies":["ground wait plus normal jump around live body/old line","fixed ring upper detour"],
			"invariants":["same enemy health and phase","no reset/refill/teleport","alive/dead/inactive fixed support remains"]},
		"definition_hashes":{"lantern":FileAccess.get_sha256("res://resources/enemies/forest_lantern.tres"),"spider":FileAccess.get_sha256("res://resources/enemies/forest_thread_spider.tres")}}
	for platform: Dictionary in data.platforms:
		var rect: Array=platform.rect
		rect[0]=(float(rect[0]) if facing==1 else -float(rect[0])-float(rect[2]))+offset.x
		rect[1]=float(rect[1])+offset.y
	for rows: Array in [data.hook_anchors,data.enemies]:
		for row: Dictionary in rows:
			row.position=_point(row.position,offset,facing)
			if row.has("line_start"):
				row.line_start=_point(row.line_start,offset,facing)
				row.line_end=_point(row.line_end,offset,facing)
	data.spawn=_point(data.spawn,offset,facing)
	for row: Dictionary in [data.observation,data.main_branch_goal,data.exit]: row.position=_point(row.position,offset,facing)
	data.return_contract.from=_point(data.return_contract.from,offset,facing)
	data.return_contract.to=_point(data.return_contract.to,offset,facing)
	data.facing=facing
	return data

static func _point(point: Array, offset: Vector2, facing: int) -> Array:
	return [float(point[0])*facing+offset.x,float(point[1])+offset.y]
