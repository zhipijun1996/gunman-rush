extends RefCounted
## A flat test chamber for subsystem regressions whose consumers need a real room.
## World services still resolve the supplied identity against the current version lock.
static func flat(id: String, size := Vector2i(1776,774), ground_y := 603) -> Dictionary:
	return {
		"schema":3,"room_id":id,"bounds":[0,0,size.x,size.y],
		"root":{"definition_id":"room.standard","definition_version":1,"properties":{"start_point":[160,ground_y-18],"terrain_material":"windchime_plains"}},
		"entities":{"floor":{"id":"floor","definition_id":"platform.solid","definition_version":1,"properties":{"rect":[0,ground_y,size.x,size.y-ground_y]}}},
		"exits":{}, "sites":{}
	}

static func duel(id: String, encounter: String, species: String, member: String) -> Dictionary:
	var doc := flat(id)
	doc.entities[member] = {"id":member,"definition_id":species,"definition_version":1,"properties":{"point":[1000,575]}}
	doc.sites[encounter] = {"at":[520,585],"start_at":[420,585],"waves":[[member]],"victory_only":[member]}
	doc.camera = {"zones":[{"id":"main","trigger":doc.bounds,"display":doc.bounds},
		{"id":"arena","profile":"fixed_arena","trigger":[200,200,1350,540],"display":[130,165,1500,570],"priority":100,"encounter":encounter}]}
	return doc
