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
	modal.button(WorldText.text("dialogue.services"),func() -> void: show_npc(npc))
	modal.button(WorldText.text("dialogue.leave"),func() -> void: ui.command.emit("close",""))
	modal.focus_first()
func show_npc(npc: Dictionary,message: String="") -> void:
	var data:=services.ledger()
	var content: Dictionary=services.definitions.dialogues.get(npc.id,{})
	var line:=str(content.get("greeting",npc.identity))
	if services.state.has("H"): line=str(content.get("after_h",line))
	if services.state.has(str(services.definitions.quest.flag)): line=str(content.get("after_quest",line))
	var modal:=ui.panel("npc",npc.display_name,line+"\n"+message)
	modal.text(WorldText.text("world_services_view.00") % [data.gold,services.used_load(data.equipped),services.definitions.capacity])
	if "gear_delivery" in npc.services:
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
	ui.close();ui.page="inventory"
	ui.equipment.submit=submit
	ui.equipment.show_build(WorldText.text("equipment.hp") % [services.state.value.hp,services.state.value.get("max_hp",5)])
	ui.equipment.set_equipment_view({"lifetime":"world","rarity_label":WorldText.text("equipment.trial"),"items":items,"capacity":services.definitions.capacity,"used":services.used_load(data.equipped),"coins":data.gold,"revision":services.state.revision,"session":int(services.state.value.cycle),"message":message,"lock_text":WorldText.text("equipment.locked"),"growth_hint":WorldText.text("equipment.growth"),"upgrade":{"reason":WorldText.text("equipment.capacity")}})
