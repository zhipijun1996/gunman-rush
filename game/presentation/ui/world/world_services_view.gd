class_name WorldServicesView
extends RefCounted
## Read-only service screens. Button closures bind the revision displayed to the player.
var ui: FixedWorldUI
var services: WorldServices
var submit: Callable
func button(modal: DemoUiModalShell,label: String,kind: String,id: String) -> Button:
	var revision:=services.state.revision
	var control:=modal.button(label,func() -> void: submit.call(kind,id,revision))
	control.name="Service_"+kind+"_"+id
	return control
func show_greeting(npc: Dictionary) -> void:
	var lines: Dictionary=services.definitions.dialogues.get(npc.id,{})
	var line:=str(lines.get("after_quest" if services.state.has(str(services.definitions.quest.flag)) else "after_h" if services.state.has("H") else "greeting",npc.identity))
	var modal:=ui.panel("dialogue",npc.display_name,line)
	(modal as WorldDialogue).portrait(WorldNpc.visual_for(str(npc.id),str(npc.get("chapter",""))))
	if not npc.get("services",[]).is_empty():modal.button(WorldText.text("dialogue.services"),func() -> void: show_npc(npc))
	modal.button(WorldText.text("dialogue.leave"),func() -> void: ui.command.emit("close",""))
	modal.focus_first()
func show_npc(npc: Dictionary,message: String="") -> void:
	var data:=services.ledger()
	var content: Dictionary=services.definitions.dialogues.get(npc.id,{})
	var line:=str(content.get("greeting",npc.identity))
	if services.state.has("H"): line=str(content.get("after_h",line))
	if services.state.has(str(services.definitions.quest.flag)): line=str(content.get("after_quest",line))
	var modal:=ui.panel("npc",npc.display_name,line+"\n"+message)
	(modal as WorldDialogue).portrait(WorldNpc.visual_for(str(npc.id),str(npc.get("chapter",""))))
	modal.text(WorldText.text("world_services_view.00") % [data.gold,services.used_load(data.equipped),services.capacity()])
	if "gear_delivery" in npc.services:
		var carried:=int(services.state.value.inventory.get("time_gear",0))
		modal.text("时间齿轮：随身 %d · 已交付 %d" % [carried,int(services.state.value.inventory.get("delivered_gears",0))])
		button(modal,"交付随身时间齿轮","deliver_gears","deliver_time_gears").disabled=carried==0
		for action: Dictionary in services.state.content.data.actions:
			if action.id not in services.state.content.data.gear_milestones or action.room_id!=npc.room_id:continue
			var done: bool=services.state.value.receipts.has(action.id)
			var threshold:=str(action.requires[0][0]).get_slice(">=",1)
			var title:="累计 %s 枚 · %s%s" % [threshold,str(action.description),"（已领取）" if done else ""]
			button(modal,title,"claim_milestone",str(action.id)).disabled=done or not services.state.holds(action.requires)
		var quest: Dictionary=services.definitions.quest
		modal.text(quest.description+WorldText.text("world_services_view.01")+{"accepted":WorldText.text("world_services_view.02"),"completed":WorldText.text("world_services_view.03")}.get(data.quests.get(quest.id,""),WorldText.text("world_services_view.04")))
		button(modal,WorldText.text("world_services_view.05"), "deliver",str(quest.id))
	if "station_supply_shop" in npc.services:
		modal.text(WorldText.text("world_services_view.06"))
		for item: Dictionary in services.definitions.items:
			var owned:=services.owns(item.id)
			var b:=modal.button((WorldText.text("world_services_view.07") if owned else WorldText.text("world_services_view.08") % item.price)+item.name,func() -> void: submit.call("buy",str(item.id),services.state.revision))
			# Capture exactly the rendered revision, rather than looking it up after a second click.
			for connection: Dictionary in b.pressed.get_connections(): b.pressed.disconnect(connection.callable)
			var revision:=services.state.revision
			b.pressed.connect(func() -> void: submit.call("buy",str(item.id),revision))
			b.name="Service_buy_"+str(item.id)
			b.disabled=owned
	if "equipment_gold_upgrade" in npc.services:
		for id: String in data.owned:
			var definition:=services.item(id)
			var owned: Dictionary=data.owned[id]
			if definition.is_empty(): continue
			modal.text("%s · Lv.%d · %s" % [definition.name,owned.level,WorldText.text("world_services_view.09") if owned.broken else WorldText.text("world_services_view.10")])
			button(modal,WorldText.text("world_services_view.11") % definition.upgrade_price,"upgrade",id).disabled=owned.level>=definition.max_level
			button(modal,WorldText.text("world_services_view.12") % definition.repair_price,"repair",id).disabled=not owned.broken
	modal.button(WorldText.text("world_services_view.13"),func() -> void: ui.command.emit("inventory",""))
	modal.button(WorldText.text("world_services_view.14"),func() -> void: ui.command.emit("close",""))
	modal.focus_first()
func show_inventory(message: String="") -> void:
	var data:=services.ledger()
	var items: Array=[]
	for id: String in data.owned:
		var row:=services.item(id)
		var owned: Dictionary=data.owned[id]
		var unavailable:=row.is_empty()
		if unavailable: row={"name":id,"load":9999,"icon_key":"map","max_level":owned.level,"description":WorldText.text("equipment.unavailable"),"effect":""}
		items.append({"instance_id":StringName(id),"unavailable":unavailable,"definition":ItemCatalogV5.get_item(&"G11"),"display_name":row.name,"gear_cost":row.load,"icon_key":row.icon_key,"level":int(owned.level),"max_level":row.max_level,"broken":owned.broken,"equipped":id in data.equipped,"locked":id in data.locked,"effect_text":row.description,"usable":row.effect=="heal","remaining_uses":int(row.get("uses_per_cycle",0))-int(data.cycle_uses.get(id,0))})
	var collected: PackedStringArray=[]
	for id: String in services.state.value.inventory:
		if id.begins_with("equipment:") and int(services.state.value.inventory[id])>0:
			collected.append(WorldText.text("collection."+id.trim_prefix("equipment:"),"旅途行装包"))
	var summary:="时间齿轮 %d · 已交付 %d · 血量片 %d · 共鸣片 %d" % [int(services.state.value.inventory.get("time_gear",0)),int(services.state.value.inventory.get("delivered_gears",0)),int(services.state.value.inventory.get("health_shard",0)),int(services.state.value.inventory.get("resonance_shard",0))]
	if not collected.is_empty():summary+="\n已收存行装："+"、".join(collected)
	message=summary+"\n"+message
	ui.close();ui.page="inventory"
	ui.equipment.submit=submit
	ui.equipment.show_build(WorldText.text("equipment.hp") % [services.state.value.hp,services.state.value.get("max_hp",5)])
	ui.equipment.set_equipment_view({"lifetime":"world","rarity_label":WorldText.text("equipment.trial"),"items":items,"capacity":services.capacity(),"used":services.used_load(data.equipped),"coins":data.gold,"revision":services.state.revision,"session":int(services.state.value.cycle),"message":message,"lock_text":WorldText.text("equipment.locked"),"growth_hint":WorldText.text("equipment.growth"),"upgrade":{"reason":WorldText.text("equipment.capacity")}})
