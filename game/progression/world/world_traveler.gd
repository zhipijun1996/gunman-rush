class_name WorldTraveler
extends RefCounted
## The newest eligible chapter owns a single saved host; walking past is not a conversation.
const ID := "NPC_TRAVELER_AQI"
static func chapter(state: FixedWorldState, room_id: String) -> Dictionary:
	var selected: Dictionary={}
	var latest_claimed:=0
	for entry: Dictionary in state.content.data.get("traveler_story",{}).get("chapters",[]):
		if state.value.get("story_hosts",{}).has(entry.id):latest_claimed=maxi(latest_claimed,int(entry.order))
	for row: Dictionary in state.content.data.get("traveler_story",{}).get("chapters",[]):
		if int(row.order)<latest_claimed:continue
		if not state.holds(row.get("requires_world",[])):continue
		var expired:=false
		for flag: String in row.get("valid_until_any",[]):
			if state.has(flag):expired=true
		if expired:continue
		if row.id=="AQI_T01" and room_id=="P-R24" and "P-R23" in state.value.explored:
			selected=row.duplicate(true)
			selected.dialogue=[str(row.optional_followup_tableau.line)]
			selected["visual_chapter"]="AQI_T01_LOOKOUT"
			continue
		var locked:=str(state.value.get("story_hosts",{}).get(row.id,""))
		for host: Dictionary in row.get("hosts",[]):
			if host.room_id==room_id and (locked.is_empty() or locked==room_id) and state.holds(host.get("requires_world",[])):selected=row
	return selected
static func prepare(state: FixedWorldState, candidate: Dictionary, room_id: String) -> Dictionary:
	var row:=chapter(state,room_id)
	if not candidate.has("story_hosts"):candidate.story_hosts={}
	if not row.is_empty():candidate.story_hosts[row.id]=room_id
	return candidate
static func identity(state: FixedWorldState, room_id: String) -> Dictionary:
	var row:=chapter(state,room_id)
	if row.is_empty():return {}
	var lines: Array=row.get("dialogue_variants",{}).get(room_id,row.get("dialogue",[]))
	var text: String="\n".join(lines)
	if ID not in state.value.services.met:text=str(row.get("first_contact_line",""))+"\n\n"+text
	return {"id":ID,"display_name":"阿栖","room_id":room_id,"identity":text,"services":[],"chapter":row.get("visual_chapter",row.id),"receipt_id":row.receipt_id}
static func talk_candidate(state: FixedWorldState, room_id: String) -> Dictionary:
	var row:=chapter(state,room_id)
	if row.is_empty():return {}
	var candidate:=state.value.duplicate(true)
	var id:=str(row.receipt_id)
	if candidate.receipts.has(id):return candidate
	candidate.receipts[id]={"source":id,"source_hash":MetaSaveService.canonical_json(row).sha256_text(),"revision":state.revision+1}
	if ID not in candidate.services.met:candidate.services.met.append(ID)
	return candidate
