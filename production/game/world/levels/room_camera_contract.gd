extends RefCounted
## Schema 3 room camera data. All rectangles, offsets and anchors are in
## room-local world units, in the same basis as the player's position.
const PROFILES := ["bounded_follow","horizontal_follow","vertical_follow","fixed_arena"]
const SHARED := ["profile","zoom","offset","look_up","look_down"]
const ZONE := ["id","trigger","display","anchor","follow_range","priority","look_y","conceal","encounter"]
const LINK := ["a","b","band","display","axis","direction"]
const CONDITIONS := ["requires","mechanism"]

static func _unknown(row: Dictionary, allowed: Array) -> String:
	for key: Variant in row:
		if not key in allowed: return "unknown_field:"+str(key)
	return ""

static func _composition(row: Dictionary) -> String:
	if row.has("profile") and not row.profile in PROFILES: return "profile"
	if row.has("zoom") and (not WorldRoomValidation.number(row.zoom) or row.zoom <= 0): return "zoom"
	if row.has("offset") and not WorldRoomValidation.vector(row.offset): return "offset"
	for key: String in ["look_up","look_down"]:
		if row.has(key) and not row[key] is bool: return key
	return ""

static func _zone_error(zone: Dictionary, room: Rect2) -> String:
	var error := _unknown(zone,SHARED+ZONE+CONDITIONS)
	if error.is_empty(): error = _composition(zone)
	if not error.is_empty(): return error
	if not zone.get("id") is String or zone.id.is_empty(): return "id"
	if not WorldRoomValidation.rectangle(zone.get("trigger")) or not WorldRoomValidation.rectangle(zone.get("display")): return "rect"
	var trigger := FixedWorldProvider.rect(zone.trigger)
	if not room.encloses(trigger) or not trigger.intersects(FixedWorldProvider.rect(zone.display)): return "extent"
	if zone.has("priority") and (not WorldRoomValidation.number(zone.priority) or floorf(zone.priority) != zone.priority): return "priority"
	if zone.has("anchor") and not WorldRoomValidation.vector(zone.anchor): return "anchor"
	if zone.has("follow_range"):
		if not WorldRoomValidation.vector(zone.follow_range): return "follow_range"
		for value: float in zone.follow_range:
			if value < 0 and value != -1: return "follow_range"
	if zone.has("look_y") and (not WorldRoomValidation.vector(zone.look_y) or zone.look_y[0] > zone.look_y[1]): return "look_y"
	if not zone.get("conceal",[]) is Array: return "conceal"
	for mask: Variant in zone.get("conceal",[]):
		if not WorldRoomValidation.rectangle(mask) or not room.encloses(FixedWorldProvider.rect(mask)): return "conceal"
	return ""

static func _link_error(link: Dictionary, triggers: Dictionary, room: Rect2) -> String:
	var error := _unknown(link,LINK+CONDITIONS)
	if not error.is_empty(): return error
	if not link.get("a") is String or not link.get("b") is String: return "endpoints"
	if link.a == link.b or not triggers.has(link.a) or not triggers.has(link.b): return "endpoints"
	if link.get("axis") not in ["x","y"] or not WorldRoomValidation.number(link.get("direction")) or absf(float(link.direction)) != 1.0: return "direction"
	if not WorldRoomValidation.rectangle(link.get("band")) or not WorldRoomValidation.rectangle(link.get("display")): return "rect"
	var band := FixedWorldProvider.rect(link.band)
	if not room.encloses(band) or not FixedWorldProvider.rect(link.display).intersects(band): return "extent"
	# A player leaving either lip in the specified direction must actually enter
	# that endpoint's trigger. A reversed sign would otherwise jump at one end.
	var normal := Vector2.RIGHT if link.axis == "x" else Vector2.DOWN
	var inset := normal * band.size * .4999 * float(link.direction)
	if not (triggers[link.a] as Rect2).has_point(band.get_center()-inset): return "source_lip"
	if not (triggers[link.b] as Rect2).has_point(band.get_center()+inset): return "destination_lip"
	return ""

static func _condition_error(row: Dictionary, entities: Dictionary) -> String:
	if row.has("requires"):
		if not row.requires is Array: return "requires"
		for clause: Variant in row.requires:
			if not clause is Array or clause.is_empty(): return "requires_clause"
			for flag: Variant in clause:
				if not flag is String or flag.strip_edges().is_empty(): return "requires_flag"
				if flag.begins_with("equipped:") and flag.trim_prefix("equipped:").strip_edges().is_empty(): return "requires_equipment"
				if ">=" in flag:
					var parts: PackedStringArray = flag.split(">=")
					if parts.size()!=2 or parts[0].is_empty() or not parts[1].is_valid_int() or parts[1].to_int()<0: return "requires_quantity"
	if not row.has("mechanism"): return ""
	if not row.mechanism is String or not entities.get(row.mechanism) is Dictionary: return "mechanism_missing"
	var entity: Dictionary = entities[row.mechanism]
	var catalog := WorldElementCatalog.catalog()
	var definition: Dictionary = catalog.definitions.get(entity.get("definition_id",""),{})
	var behavior: Dictionary = catalog.behaviors.get(definition.get("component",""),{})
	var scope: Variant = entity.properties.get("state_scope",definition.get("defaults",{}).get("state_scope"))
	if scope != "permanent" or behavior.get("state",{}).get("active",{}).get("type","") != "bool": return "mechanism_not_persistent_bool"
	return ""

static func validate(camera: Variant, bounds: Variant, sites: Variant = {}, entities: Dictionary = {}) -> String:
	if not camera is Dictionary or not WorldRoomValidation.rectangle(bounds): return "room_camera_invalid"
	var error := _unknown(camera,SHARED+["zones","links"])
	if error.is_empty(): error = _composition(camera)
	if not error.is_empty(): return "room_camera_invalid:"+error
	if not camera.get("zones",[]) is Array or not camera.get("links",[]) is Array: return "room_camera_rows_invalid"
	var room := FixedWorldProvider.rect(bounds)
	var triggers := {}
	var encounters := {}
	var available_by_default := false
	for zone: Variant in camera.get("zones",[]):
		if not zone is Dictionary: return "camera_zone_invalid"
		error = _zone_error(zone,room)
		if error.is_empty(): error = _condition_error(zone,entities)
		if not error.is_empty(): return "camera_zone_invalid:"+error
		if triggers.has(zone.id): return "camera_zone_duplicate:"+str(zone.id)
		triggers[zone.id] = FixedWorldProvider.rect(zone.trigger)
		if zone.has("encounter"):
			if zone.get("profile",camera.get("profile","bounded_follow")) != "fixed_arena": return "camera_encounter_profile:"+zone.id
			var id: Variant = zone.encounter
			if not id is String or not id.begins_with("enc_") or not sites is Dictionary: return "camera_encounter_invalid:"+zone.id
			var site: Variant = sites.get(id)
			if not site is Dictionary or not site.get("waves") is Array or site.waves.is_empty(): return "camera_encounter_unknown:"+str(id)
			encounters[zone.id] = id
		if not zone.has("encounter") and zone.get("requires",[]).is_empty() and not zone.has("mechanism"): available_by_default = true
	if not triggers.is_empty() and not available_by_default: return "camera_fallback_missing"
	var passages: Array[Dictionary] = []
	for link: Variant in camera.get("links",[]):
		if not link is Dictionary: return "camera_link_invalid"
		error = _link_error(link,triggers,room)
		if error.is_empty(): error = _condition_error(link,entities)
		if not error.is_empty(): return "camera_link_invalid:"+error
		if encounters.has(link.a) or encounters.has(link.b): return "camera_encounter_link_invalid"
		var band := FixedWorldProvider.rect(link.band)
		for previous: Dictionary in passages:
			if (link.a in [previous.a,previous.b] or link.b in [previous.a,previous.b]) and band.intersects(previous.band):
				return "camera_link_ambiguous"
		passages.append({"a":link.a,"b":link.b,"band":band})
	return ""

static func resolve(document: Dictionary) -> Dictionary:
	var source: Dictionary = document.get("camera",{}).duplicate(true)
	var composition := {"profile":source.get("profile","bounded_follow")}
	for key: String in SHARED:
		if source.has(key): composition[key] = source[key]
	var zones: Array = source.get("zones",[]).duplicate(true)
	if zones.is_empty():
		zones.append({"id":"main","trigger":document.bounds.duplicate(),"display":document.bounds.duplicate()})
	for zone: Dictionary in zones:
		zone.merge(composition)
		if zone.has("encounter"):
			zone.arena = true
			zone.look_up = false
			zone.look_down = false
	return {"profile":composition.profile,"zones":zones,"links":source.get("links",[]).duplicate(true)}
