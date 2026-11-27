extends RefCounted
## Small subsystem fixtures. These rooms have no game bindings or navigation routes.
const Chamber = preload("system_room_fixture.gd")

static func entity(id: String, kind: String, properties: Dictionary) -> Dictionary:
	return {"id":id,"definition_id":kind,"definition_version":1,"properties":properties}

static func document(id: String) -> Dictionary:
	var floor_y := 393 if id=="P18" else (482 if id=="R02" else 603)
	var doc := Chamber.flat(id,Vector2i(1776,774),floor_y)
	var sites := {"G12":["npc20_workshop"],"G08":["smith"],"A06":["wr_A06_primary"],"Y11":["npc20_canyon"],"M06":["wr_T17_primary"],"P08":["tp_P08"]}
	for site: String in sites.get(id,[]): doc.sites[site] = {"at":[430,floor_y-18]}
	if id in ["P08","Y23","G12"]:
		doc.entities.station = entity("station","recovery.station",{"position":[720,floor_y-18]})
	if id=="G08": doc.zone_areas = {"G08_catwalk":[0,0,900,774],"G08_bench":[900,0,876,774]}
	if id=="Y23": doc.zone_areas = {"Y23_prize":[0,0,1100,774],"Y23_east":[1100,0,676,774]}
	if id=="E03": doc.entities.hot_bed_694 = entity("hot_bed_694","hazard.area",{"rect":[690,574,123,32],"hazard_profile":"heat_wave"})
	if id=="E09":
		doc.entities.curtain = entity("curtain","zone.environment",{"bounds":[680,390,32,212],"mode":"phase_light"})
		doc.exits["d173"] = {"direction":[0,-1],"point":[250,0],"spawn":[250,585],"span":[180,320]}
	if id=="P18": doc.entities.floor_tuning_dummy = entity("floor_tuning_dummy","enemy.chime_target",{"point":[730,374]})
	if id=="R02":
		doc.entities.patrol_2 = entity("patrol_2","enemy.ground_fan_sentry",{"point":[1224,464]})
		doc.content_bindings = {"enemy_instances":{"patrol_2":{"species_id":"species.80276ebcb29b","drop_profile_id":"drop.80276ebcb29b.t1"}}}
	if id=="P07":
		doc.sites.enc_P07 = {"at":[1400,585],"waves":[["runner"],["lookout","guard"]],"victory_only":["runner","lookout","guard"]}
		for member: String in ["runner","lookout","guard"]:
			doc.entities[member] = entity(member,"enemy.ground_fan_sentry",{"point":[950,585]})
	return doc
