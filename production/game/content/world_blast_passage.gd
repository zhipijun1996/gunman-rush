class_name WorldBlastPassage
extends RefCounted
## A destructible mouth and its persistent passage receipt share the rock's
## accepted transaction. Observation may record the secret before demolition.
static func prepare(doc: Dictionary, context: Dictionary) -> Dictionary:
	var bindings: Dictionary={}
	for door: Dictionary in context.connections:
		var site: Dictionary=doc.get("sites",{}).get(door.id,{})
		if not site.has("breakable"): continue
		var discovery: Dictionary=door.get("discovery",{})
		var secret: bool=discovery.get("runtime_plan",{}).get("kind")=="breakable_cover"
		var owner: Variant=discovery.get("source_room") if secret else door.get("one_way_from")
		if owner!=doc.room_id or (not secret and door.get("unlock_flag")!="mine_service_blast_open"):
			return {"error":"blast_passage_source_invalid:"+str(door.id)}
		var id: String=str(site.breakable)
		var row: Dictionary=doc.get("entities",{}).get(id,{})
		var p: Dictionary=row.get("properties",{})
		if not WorldRoomValidation.vector(site.get("at")) or row.get("definition_id")!="terrain.breakable" or p.get("accepted_attacks")!=["bomb"] or p.get("break_mode","whole")!="whole" or p.get("state_scope","permanent")!="permanent" or bindings.has(id):
			return {"error":"blast_passage_requires_dedicated_bomb_rock:"+str(door.id)}
		bindings[id]={"door":door,"at":FixedWorldProvider.point(site.at),"event":str(discovery.get("event",""))}
	return {"bindings":bindings}

static func record(next: Dictionary, key: String, row: Dictionary, revision: int) -> void:
	next.receipts[key]={"source":key,"source_hash":MetaSaveService.canonical_json(row).sha256_text(),"revision":revision+1}

static func observe(s: OrdinaryRoomSession) -> void:
	if not s.lifetime.active or not s.controller.active or not s.player.is_on_floor() or s.controller.has_pending_damage(): return
	for link: Dictionary in s.blast_passages.values():
		var id: String=link.event
		if id.is_empty() or s.state.has(id) or s.player.position.distance_to(link.at)>30 or not s.equipment.scene.clear_line(s.player.position,link.at): continue
		var event:=s.content_catalog.lookup("events",id)
		if not event.ok or not s.content_catalog.condition_match(event.row,s.state.value.flags,s.services.ledger().equipped).matches: continue
		var next:=s.state.candidate()
		next.flags.append(id)
		record(next,id,event.row,s.state.revision)
		s.state.commit(next,s.state.revision)
		return

static func stage(s: OrdinaryRoomSession, next: Dictionary, rock: String, state: Dictionary) -> bool:
	if not s.blast_passages.has(rock) or not state.data.hp.all(func(value:Variant)->bool: return value==0): return true
	var link: Dictionary=s.blast_passages[rock]
	var door: Dictionary=link.door
	var required: Array=door.requires.duplicate()
	required.erase(link.event)
	if not s.content_catalog.condition_match({"requires":required},next.flags,next.services.equipped).matches: return false
	if not link.event.is_empty() and not link.event in next.flags:
		var event:=s.content_catalog.lookup("events",link.event)
		if not event.ok or not s.content_catalog.condition_match(event.row,next.flags,next.services.equipped).matches: return false
		next.flags.append(link.event)
		record(next,link.event,event.row,s.state.revision)
	if door.get("unlock_flag")!=null and not door.unlock_flag in next.flags:
		next.flags.append(door.unlock_flag)
		record(next,door.unlock_flag,door,s.state.revision)
	record(next,"passage_break:"+str(door.id),door,s.state.revision)
	return true
