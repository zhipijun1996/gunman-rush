extends "res://tests/world/plains_intro.gd"
## Declared 100-coin service fixture; purchases, equip, repair and use go through real UI.
func click_named(prefix: String,touch: bool=true) -> bool:
	if prefix.begins_with("交谈") or prefix.begins_with("休息") or prefix.begins_with("拾取") or prefix.begins_with("领取"):
		for down: bool in [true,false]:
			var event:=InputEventKey.new();event.physical_keycode=KEY_UP;event.pressed=down
			root.push_input(event,true);await ticks(3)
		if app.ui.page=="dialogue" and app.context_target().get("kind","")=="npc": await click_named("查看服务",touch)
		return true
	await ticks(3)
	var selected: Button
	for node: Node in app.ui.root.find_children("*","Button",true,false):
		var button:=node as Button
		if button.is_visible_in_tree() and button.text.begins_with(prefix): selected=button;break
	if selected==null:
		check(false,"missing visible UI button "+prefix)
		return false
	var scroll:=app.ui.shell.scroll if app.ui.shell!=null else null
	if scroll==null:
		var ancestor: Node=selected.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer: scroll=ancestor as ScrollContainer;break
			ancestor=ancestor.get_parent()
	if scroll!=null: scroll.ensure_control_visible(selected)
	await ticks(3)
	var point:=selected.get_global_transform_with_canvas()*(selected.size/2)
	for down: bool in [true,false]:
		if touch:
			var event:=InputEventScreenTouch.new()
			event.index=7;event.position=point;event.pressed=down
			root.push_input(event,true)
		else:
			var event:=InputEventMouseButton.new()
			event.position=point;event.global_position=point
			event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
			root.push_input(event,true)
		await ticks(2)
	return true

func button_id(id: String) -> bool:
	await ticks(3)
	var button:=app.ui.root.find_child(id,true,false) as Button
	if button==null and app.ui.page=="inventory":
		var item_id:=id.substr(id.find("trial_"))
		app.ui.equipment._select_equipment(StringName(item_id))
		await ticks(3)
		for candidate: Node in app.ui.equipment.find_children("*","Button",true,false):
			if candidate.get_meta(&"world_service","")==id: button=candidate as Button;break
	if button==null or not button.is_visible_in_tree(): check(false,"visible service button "+id);return false
	button.grab_focus()
	if app.ui.shell!=null: app.ui.shell.scroll.ensure_control_visible(button)
	else:
		var ancestor:=button.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer: (ancestor as ScrollContainer).ensure_control_visible(button);break
			ancestor=ancestor.get_parent()
	await ticks(3)
	var at:=button.get_global_transform_with_canvas()*(button.size/2)
	for down: bool in [true,false]:
		var e:=InputEventScreenTouch.new();e.index=8;e.pressed=down;e.position=at
		root.push_input(e,true);await ticks(3)
	return true
func inventory() -> void:
	await ticks(3)
	await click_named("菜单")
	await click_named("背包与装配")
func talk(at: float) -> void:
	await walk(Vector2(at,app.room.rest_point.y),"P-R01")
	await ticks(4);await click_named("交谈")
func rest() -> void:
	await walk(app.room.rest_point,"P-R01")
	await ticks(4);await click_named("休息");await settle();await ticks(4)
func run() -> void:
	root.size=Vector2i(1280,720)
	var destination:="user://world_service_ui_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(destination+suffix)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path=destination
	app.settings_path="user://world_service_ui_settings.json"
	root.add_child(app)
	check(app.start_new(),"service UI starts new isolated world")
	await settle();app.load_room("P-R01","");await settle()
	var funded:=app.state.value.duplicate(true);funded.services.gold=100;app.state.commit(funded,app.state.revision)
	await settle();await ticks(4)
	await rest()
	await talk(560)
	await button_id("Service_buy_trial_filter")
	await button_id("Service_buy_trial_heart")
	await button_id("Service_buy_trial_lamp")
	await button_id("Service_buy_trial_flask")
	check(app.services.owns("trial_heart") and app.services.owns("trial_lamp") and app.services.owns("trial_flask"),"actual merchant touch buys unique trial inventory with declared fixture currency")
	await click_named("背包与装配")
	var hp:=app.controller.actor_resources.health.current
	await button_id("Service_equip_trial_heart")
	check(app.controller.actor_resources.health.capacity==8 and app.controller.actor_resources.health.current==hp,"existing BuildState applies equipped health source without free heal")
	await button_id("Service_equip_trial_lamp")
	check(app.services.active("lamp"),"v07 initial eight-slot capacity accepts this combination")
	await click_named("关闭")
	await rest()
	await inventory()
	await button_id("Service_unequip_trial_heart")
	check(app.controller.actor_resources.health.capacity==5 and app.state.value.hp<=5,"removing source reconciles actor and persisted HP")
	await button_id("Service_equip_trial_filter")
	await button_id("Service_equip_trial_flask")
	await click_named("关闭")
	# Declared accepted-damage fixture, after normal income/purchases. No invulnerability or HP overrides.
	for i: int in 3:
		app.submit_damage(&"durability_fixture",DamageRequest.Kind.MONSTER,1,StringName("durability_hit:"+str(i)))
		await ticks(100)
	check(app.services.ledger().owned.trial_filter.broken and not app.services.active("filter"),"real accepted hits break equipped filter")
	await inventory()
	await button_id("Service_use_trial_flask")
	check(app.controller.actor_resources.health.current==4 and app.services.ledger().cycle_uses.trial_flask==1,"actual cycle use commits charge and applies accepted heal")
	await button_id("Service_use_trial_flask")
	check(app.controller.actor_resources.health.current==4 and app.services.ledger().cycle_uses.trial_flask==1,"second actual touch cannot refresh cycle quota")
	await click_named("关闭")
	await talk(816)
	var cycle: int=app.state.value.cycle
	await button_id("Service_repair_trial_filter")
	check(not app.services.ledger().owned.trial_filter.broken and app.controller.actor_resources.health.current==4 and app.state.value.cycle==cycle,"real repair restores only equipment state")
	await button_id("Service_upgrade_trial_filter")
	check(app.services.ledger().owned.trial_filter.level==2 and app.services.active("filter"),"real Weaver upgrade persists same active instance")
	await click_named("告别")
	await click_named("菜单")
	await click_named("保存并返回标题")
	check(app.title.visible,"service flow saves back to original title")
	await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
	print("WORLD SERVICE UI: %d failures" % failures);quit(failures)
