class_name WorldContentSites
extends Node2D
## Authored reachable places consume identities and terms from the pinned world.
## Receipts, story flags, quest items, currency and equipment share one revision.
signal station_departure(origin: String, destination: String, revision: int)
const REACH := 44.0
const INVENTORY := {"health_fragment":"health_shard","resonance_fragment":"resonance_shard","equipment_capacity_collectible":"capacity_upgrades","attack_alloy":"attack_alloy","skill_core":"skill_core"}
var session: OrdinaryRoomSession
var rows := {}
var positions := {}
var markers := {}
var quests := {}
var menu: WorldContentMenu
var hint: Label

func install(host: OrdinaryRoomSession, doc: Dictionary) -> void:
	session=host
	var sites: Dictionary=doc.get("sites",{})
	var ctx:=host.content_context
	var npc_events := {}
	for quest: Dictionary in host.content_catalog.table("quests").rows:
		quests[quest.id]=quest
		npc_events[quest.accept_event]=quest.giver_id
		npc_events[quest.completion_event]=quest.giver_id
	var door_events: Array=[]
	for link: Dictionary in ctx.connections:
		if link.get("discovery") is Dictionary: door_events.append(link.discovery.event)
		if link.get("physical_gate_contract",{}).has("upstream_hatch_event"): door_events.append(link.physical_gate_contract.upstream_hatch_event)
		if link.get("unlock_flag") is String: door_events.append(link.unlock_flag)
	for table: String in ["npcs","events","rewards","coin_caches"]:
		for row: Dictionary in ctx[table]:
			if not sites.has(row.id) or (table=="events" and npc_events.has(row.id)): continue
			if table=="events" and (row.id in door_events or row.get("interaction_kind")=="discovery"): continue
			if table=="rewards" and (row.get("existing_world_event")!=null or row.delivery_mode not in ["collection","ending_event"]): continue
			# Existing receipt IDs and visuals for these placed pickups remain authoritative.
			if doc.has("scenery") and (table=="coin_caches" or row.get("reward_kind") in ["lost_gear","health_fragment"]): continue
			add_site(row,table,sites[row.id])
	# The traveling smith has a second, explicitly authorized encounter on G08's upper catwalk.
	if sites.has("smith") and not rows.has("smith"):
		var smith:=host.content_catalog.lookup("events","smith")
		if smith.ok:
			for place: Dictionary in smith.row.interaction_sites:
				if place.room==doc.room_id and host.room.section_at(FixedWorldProvider.point(sites.smith.at))==place.zone:
					add_site(smith.row,"events",sites.smith)
	for station: Dictionary in host.content_catalog.object("transport").value.stations:
		if station.room==host.room.room_id and sites.has(station.id): add_site(station,"stations",sites[station.id])
	for id: String in npc_events:
		var giver: String=npc_events[id]
		if not positions.has(giver): continue
		var event:=host.content_catalog.lookup("events",id)
		if event.ok and event.row.room==host.room.room_id:
			rows[id]={"kind":"events","data":event.row,"host":giver}
	if rows.is_empty():
		set_physics_process(false)
		return
	host.controller.router.set_meta(&"world_up_interaction",true)
	menu=WorldContentMenu.new()
	menu.sites=self
	add_child(menu)
	hint=Label.new()
	hint.add_theme_font_override("font",EquipmentMenu.UI_FONT)
	hint.add_theme_font_size_override("font_size",17)
	hint.add_theme_constant_override("outline_size",4)
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.z_index=40
	add_child(hint)
	host.state.committed.connect(refresh)
	refresh(host.state.revision)

func add_site(row: Dictionary, kind: String, site: Dictionary) -> void:
	if not WorldRoomValidation.vector(site.get("at")): return
	positions[row.id]=FixedWorldProvider.point(site.at)
	rows[row.id]={"kind":kind,"data":row,"host":row.id}
	var mark:=Node2D.new()
	mark.position=positions[row.id]+Vector2(0,18)
	add_child(mark)
	markers[row.id]=mark
	if kind=="npcs" or (row.id=="smith" and session.room.room_id=="G08"):
		var npc:=Sprite2D.new()
		npc.texture=UnderworldActors.icon_texture(&"merchant")
		UnderworldActors.place_humanoid(npc,Vector2.ZERO)
		mark.add_child(npc)
	elif row.get("reward_kind")=="equipment" and EquipmentCatalog.ICONS.has(row.catalog_id):
		var seat:=RoomWaymarker.new()
		mark.add_child(seat)
		var icon:=Sprite2D.new()
		icon.texture=EquipmentCatalog.ICONS[row.catalog_id]
		icon.scale=Vector2.ONE*(22.0/maxf(icon.texture.get_width(),icon.texture.get_height()))
		icon.position.y=-20
		mark.add_child(icon)
	else:
		var signpost:=RoomWaymarker.new()
		signpost.notice=row.has("signpost_id") or row.has("dialogue")
		mark.add_child(signpost)

func eligible(row: Dictionary) -> bool:
	var required: Array=row.get("requires",[]).duplicate()
	for flag: String in row.get("completion_requires",[]):
		if flag not in required: required.append(flag)
	var result:=session.content_catalog.condition_match({"requires":required,"excludes":row.get("excludes",[])},session.state.value.flags,session.services.ledger().equipped)
	return result.ok and result.matches

func done(id: String) -> bool:
	return session.state.value.receipts.has(id) or (rows.has(id) and rows[id].kind=="events" and session.state.has(id))

func refresh(_revision: int) -> void:
	for id: String in markers:
		var info: Dictionary=rows[id]
		var node: Node2D=markers[id]
		node.visible=not (info.kind in ["rewards","coin_caches"] and done(id))
		if info.kind=="npcs" and (not eligible(info.data) or (info.data.services==["dialogue"] and text_for(id).is_empty() and giver_events(id).is_empty())): node.hide()
		node.modulate=Color.WHITE if eligible(info.data) else Color("9899a0")

func near(id: String) -> bool:
	if not rows.has(id) or not session.lifetime.active or not session.controller.active or not session.player.is_on_floor(): return false
	if session.controller.actor_resources.health.terminal or session.controller.has_pending_damage() or not session.pending_defeats.is_empty(): return false
	var host_id: String=rows[id].host
	if not markers[host_id].visible: return false
	var point: Vector2=positions[host_id]
	return session.player.position.distance_to(point)<=REACH and session.equipment.scene.clear_line(session.player.position,point)

func _physics_process(_delta: float) -> void:
	if menu==null: return
	var nearby:=choices()
	hint.visible=not nearby.is_empty() and not menu.visible_panel()
	if hint.visible:
		var id:=nearby[0]
		hint.text=session.controller.router.interact_prompt(title(rows[id].data))
		hint.position=positions[id]-Vector2(hint.get_minimum_size().x*.5,68)

func choices() -> Array[String]:
	var ids: Array[String]=[]
	for id: String in positions:
		if near(id): ids.append(id)
	ids.sort_custom(func(a:String,b:String)->bool: return session.player.position.distance_squared_to(positions[a])<session.player.position.distance_squared_to(positions[b]))
	return ids

func interact() -> bool:
	if menu==null: return false
	if menu.visible_panel(): return true
	var ids:=choices()
	if ids.is_empty(): return false
	if ids.size()==1: interact_site(ids[0])
	else: menu.actions(ids)
	return true

static func title(row: Dictionary) -> String:
	if row.id=="intro_active_skill": return "共鸣脉冲"
	return str(row.get("label",row.get("display_name",row.get("name",row.get("interaction","调查")))))

func giver_events(npc_id: String) -> Array[String]:
	var ids: Array[String]=[]
	for q: Dictionary in quests.values():
		if q.giver_id!=npc_id: continue
		var status:=session.content_catalog.quest_status(q.id,session.state.value.flags)
		if status.ok and status.next is Dictionary and status.next.id in [q.accept_event,q.completion_event] and eligible(status.next) and rows.has(status.next.id):
			ids.append(status.next.id)
	return ids

func text_for(id: String) -> String:
	var row: Dictionary=rows[id].data
	var lines:=PackedStringArray()
	if row.id=="intro_active_skill":
		return "朝目标瞄准，轻触技能键或按 Q。短暂蓄力后，脉冲将沿瞄准方向射出。"
	if row.has("dialogue"):
		for line: Dictionary in row.dialogue: lines.append(str(line.speaker)+"　"+str(line.text))
	elif rows[id].kind=="npcs":
		for dialogue: Dictionary in session.content_catalog.dialogues_for(session.room.room_id,session.state.value.flags,session.services.ledger().equipped,row.get("zone")).rows:
			if str(row.name).ends_with(str(dialogue.speaker)): lines.append_array(dialogue.lines)
	elif row.has("signpost_id"):
		for signpost: Dictionary in session.content_context.room.get("signposts",[]):
			if signpost.id!=row.signpost_id: continue
			for line: Dictionary in signpost.lines:
				if eligible(line): lines.append(str(line.direction)+"　"+str(line.label))
			lines.append(str(signpost.legend))
	elif rows[id].kind=="stations": lines.append("站钟已经敲响。")
	elif rows[id].kind=="coin_caches": lines.append("拾取 %d 金币。" % int(row.amount))
	else: lines.append(str(row.get("completion_text",row.get("action",row.get("reward_function",title(row))))))
	return "\n".join(lines)

func interact_site(id: String) -> void:
	if not near(id): return
	var row: Dictionary=rows[id].data
	if not eligible(row):
		menu.notice(title(row),"条件尚未满足。")
	elif id=="smith" and done(id) and workshop_here(id):
		menu.workshop(id)
	elif rows[id].kind=="stations":
		if not done(id) and not claim(id,session.state.revision):
			menu.notice(title(row),"站钟暂未记下，请重试。")
			return
		menu.stations(id)
	elif rows[id].kind=="npcs":
		menu.shop(id)
	elif row.get("reward_kind")=="ending":
		menu.endings(id)
	elif done(id) or claim(id,session.state.revision):
		menu.notice(title(row),text_for(id))
	else: menu.notice(title(row),"未能完成这次交互。")

func record(next: Dictionary, row: Dictionary) -> void:
	next.receipts[row.id]={"source":row.id,"source_hash":MetaSaveService.canonical_json(row).sha256_text(),"revision":session.state.revision+1}

func grant(next: Dictionary, row: Dictionary) -> bool:
	if next.receipts.has(row.id) or not eligible(row): return false
	var kind: String=row.reward_kind
	var quantity:=int(row.get("quantity",1)) if row.get("quantity")!=null else 1
	if kind=="equipment":
		var item:=str(row.catalog_id)
		if EquipmentCatalog.item(item).is_empty() or next.services.owned.has(item): return false
		next.services.owned[item]=int(row.equipment_level)
	elif INVENTORY.has(kind):
		var key: String=INVENTORY[kind]
		next.inventory[key]=int(next.inventory.get(key,0))+quantity
	elif kind=="lost_gear":
		var gear:=str(row.formal_item_id)
		if gear in next.gear_ids.carried or gear in next.gear_ids.delivered: return false
		next.gear_ids.carried.append(gear)
		next.inventory["time_gear"]=int(next.inventory.get("time_gear",0))+1
	elif kind=="branch_material":
		next.inventory[row.formal_item_id]=int(next.inventory.get(row.formal_item_id,0))+quantity
	elif kind=="active_skill":
		if row.id!="wr_P18_intro_skill" or row.existing_world_event!="intro_active_skill": return false
	elif kind not in ["main_story","core_repair","movement_ability","key","workshop_service","weapon_unlock","ending_qualification"]: return false
	record(next,row)
	return true

func claim(id: String, revision: int) -> bool:
	if not near(id) or revision!=session.state.revision or done(id): return false
	var row: Dictionary=rows[id].data
	if not eligible(row): return false
	var next:=session.state.candidate()
	match str(rows[id].kind):
		"events":
			if row.get("reward_key")!=null:
				var source:=session.content_catalog.lookup("rewards",row.reward_key)
				if not source.ok or source.row.room!=row.room or source.row.existing_world_event!=id or not grant(next,source.row): return false
			for q: Dictionary in quests.values():
				for item: Dictionary in q.task_items:
					if item.acquired_event==id: next.inventory[item.id]=int(item.quantity)
					if item.delivered_event==id and item.consume_on_delivery:
						if int(next.inventory.get(item.id,0))<int(item.quantity): return false
						next.inventory.erase(item.id)
			if id in ["B","weapon_shuriken"]: next.story_hosts["selected_weapon"]=id
			if id not in next.flags: next.flags.append(id)
			record(next,row)
		"stations":
			if row.has("activate_event") and row.activate_event not in next.flags: next.flags.append(row.activate_event)
			record(next,row)
		"rewards":
			if not grant(next,row): return false
		"coin_caches":
			if next.receipts.has("income:"+id): return false
			next=session.services.earned_candidate(next,id,int(row.amount))
			record(next,row)
		_: return false
	if not session.state.commit(next,revision): return false
	GameAudio.cue_committed_reward(self,&"item_get",&"confirm")
	return true

func available_endings(site_id: String) -> Array[Dictionary]:
	var applicable: Array[Dictionary]=[]
	if not rows.has(site_id) or rows[site_id].data.get("reward_kind")!="ending" or not eligible(rows[site_id].data): return applicable
	for ending: Dictionary in session.content_catalog.table("endings").rows:
		if ending.target==session.room.room_id and ending.requires_explicit_terminal_interaction and eligible(ending):
			applicable.append(ending)
	return applicable

func confirm_ending(site_id: String, id: String, revision: int) -> bool:
	if revision!=session.state.revision or not near(site_id): return false
	for ending: Dictionary in available_endings(site_id):
		if ending.id!=id: continue
		var key:="ending:"+id
		if session.state.value.receipts.has(key): return true
		var next:=session.state.candidate()
		next.receipts[key]={"source":key,"source_hash":MetaSaveService.canonical_json(ending).sha256_text(),"revision":revision+1}
		next.story_hosts["ending"]=id
		if not session.state.commit(next,revision): return false
		GameAudio.cue_committed_reward(self,&"item_get",&"confirm")
		return true
	return false

func workshop_here(id: String) -> bool:
	if not near(id) or not eligible(rows[id].data): return false
	var room_id:=session.room.room_id
	if room_id not in session.weapon_growth.workshop_rooms: return false
	var zone: String=session.weapon_growth.workshop_zones.get(room_id,"")
	if not zone.is_empty() and session.room.section_at(session.player.position)!=zone: return false
	return id=="smith" or (rows[id].kind=="npcs" and "equipment_upgrade" in rows[id].data.services)

func smith_available() -> bool:
	for id: String in positions:
		if rows[id].kind=="npcs" and "equipment_upgrade" in rows[id].data.services and eligible(rows[id].data) and near(id): return true
	return false

func exchange_offers(npc_id: String) -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	if not rows.has(npc_id) or rows[npc_id].kind!="npcs" or "equipment_upgrade" not in rows[npc_id].data.services: return found
	var growth: Dictionary=session.content_catalog.object("growth").value
	if session.room.room_id not in growth.gear_delivery_rooms: return found
	for offer: Dictionary in growth.exchanges:
		if offer.room==session.room.room_id: found.append(offer)
	return found

func deliver_gears(npc_id: String, revision: int) -> bool:
	if not near(npc_id) or revision!=session.state.revision or not eligible(rows[npc_id].data) or exchange_offers(npc_id).is_empty(): return false
	var next:=session.state.candidate()
	if next.gear_ids.carried.is_empty(): return false
	next.gear_ids.delivered.append_array(next.gear_ids.carried)
	next.gear_ids.carried.clear()
	next.inventory["time_gear"]=0
	next.inventory["delivered_gears"]=next.gear_ids.delivered.size()
	return session.state.commit(next,revision)

func exchange(npc_id: String, offer_id: String, revision: int) -> bool:
	if not near(npc_id) or revision!=session.state.revision or not eligible(rows[npc_id].data): return false
	for offer: Dictionary in exchange_offers(npc_id):
		if offer.id!=offer_id: continue
		var next:=session.state.candidate()
		if next.gear_ids.delivered.size()<int(offer.requires_delivered.lost_gear) or not offer.cost.is_empty(): return false
		var reward:=session.content_catalog.lookup("rewards",offer.reward_key)
		if not reward.ok or reward.row.room!=session.room.room_id or reward.row.delivery_mode!="exchange" or not grant(next,reward.row): return false
		return session.state.commit(next,revision)
	return false

func offers(npc_id: String) -> Array:
	var applicable: Array=[]
	for offer: Dictionary in session.content_catalog.table("shops").rows:
		if offer.npc_id==npc_id: applicable.append(offer)
	return applicable

func buy(npc_id: String, offer_id: String, revision: int) -> bool:
	if revision!=session.state.revision or not near(npc_id) or rows[npc_id].kind!="npcs" or not eligible(rows[npc_id].data): return false
	var quote:=session.content_catalog.shop_quote(offer_id)
	if not quote.ok or quote.npc_id!=npc_id or not eligible(quote): return false
	var reward:=session.content_catalog.lookup("rewards",quote.reward_id)
	if not reward.ok or reward.row.room!=session.room.room_id or reward.row.delivery_mode!="purchase" or reward.row.shop_offer_id!=offer_id: return false
	var next:=session.state.candidate()
	if next.services.gold<quote.price or not grant(next,reward.row): return false
	next.services.gold-=int(quote.price)
	return session.state.commit(next,revision)
