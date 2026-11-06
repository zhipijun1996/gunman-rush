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
	var modal:=ui.panel("inventory",WorldText.text("world_services_view.15"),WorldText.text("world_services_view.16")+message)
	modal.text(WorldText.text("world_services_view.17") % [services.used_load(data.equipped),services.definitions.capacity,data.gold])
	if data.owned.is_empty(): modal.text(WorldText.text("world_services_view.18"))
	for id: String in data.owned:
		var item:=services.item(id)
		var owned: Dictionary=data.owned[id]
		if item.is_empty():
			modal.text(WorldText.text("world_services_view.19")+id+WorldText.text("world_services_view.20"))
			if id in data.equipped: button(modal,WorldText.text("world_services_view.21"),"unequip",id)
			continue
		modal.text(WorldText.text("world_services_view.22") % [item.name,owned.level,item.load,item.description,WorldText.text("world_services_view.23") if owned.broken else WorldText.text("world_services_view.24"),WorldText.text("world_services_view.25") if id in data.equipped else WorldText.text("world_services_view.26")])
		if item.get("effect","")=="heal" and id in data.equipped: button(modal,WorldText.text("world_services_view.27"),"use",id)
		button(modal,WorldText.text("world_services_view.28") if id in data.equipped else WorldText.text("world_services_view.29"),"unequip" if id in data.equipped else "equip",id)
	modal.button(WorldText.text("world_services_view.30"),func() -> void: ui.command.emit("close",""))
	modal.focus_first()
