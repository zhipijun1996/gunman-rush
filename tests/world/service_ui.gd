extends "res://tests/world/first_loop.gd"
## Replays a copy of the genuine first-loop save; no injected funds, item grants or HP writes.
func button_id(id: String) -> bool:
	await ticks(3)
	var button:=app.ui.root.find_child(id,true,false) as Button
	if button==null or not button.is_visible_in_tree(): check(false,"visible service button "+id);return false
	if app.ui.shell!=null: app.ui.shell.scroll.ensure_control_visible(button)
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
	await walk(Vector2(at,286),"P-R01")
	await ticks(4);await click_named("交谈")
func rest() -> void:
	await walk(Vector2(448,286),"P-R01")
	await ticks(4);await click_named("休息");await settle();await ticks(4)
func run() -> void:
	root.size=Vector2i(1280,720)
	var destination:="user://world_service_ui_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(destination+suffix)
	DirAccess.copy_absolute(ProjectSettings.globalize_path("user://world_route_test.json"),ProjectSettings.globalize_path(destination))
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path=destination
	app.settings_path="user://world_service_ui_settings.json"
	root.add_child(app)
	check(app.continue_world(),"service UI starts from genuine earned first-loop save")
	await settle();await ticks(4)
	await rest()
	await talk(240)
	await button_id("Service_buy_trial_heart")
	await button_id("Service_buy_trial_lamp")
	await button_id("Service_buy_trial_flask")
	check(app.services.owns("trial_heart") and app.services.owns("trial_lamp") and app.services.owns("trial_flask"),"actual merchant touch buys unique trial inventory with earned currency")
	await click_named("背包与装配")
	var hp:=app.controller.actor_resources.health.current
	await button_id("Service_equip_trial_heart")
	check(app.controller.actor_resources.health.capacity==8 and app.controller.actor_resources.health.current==hp,"existing BuildState applies equipped health source without free heal")
	await button_id("Service_equip_trial_lamp")
	check(not app.services.active("lamp"),"real UI refuses over-capacity loadout")
	await click_named("关闭")
	await rest()
	await inventory()
	await button_id("Service_unequip_trial_filter")
	await button_id("Service_equip_trial_lamp")
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
	await talk(680)
	var cycle: int=app.state.value.cycle
	await button_id("Service_repair_trial_filter")
	check(not app.services.ledger().owned.trial_filter.broken and app.controller.actor_resources.health.current==4 and app.state.value.cycle==cycle,"real repair restores only equipment state")
	await button_id("Service_upgrade_trial_filter")
	check(app.services.ledger().owned.trial_filter.level==2 and app.services.active("filter"),"real Weaver upgrade persists same active instance")
	await click_named("告别")
	await click_named("菜单")
	await click_named("保存并返回标题")
	check(app.title.visible,"service flow saves back to original title")
	app.queue_free();await ticks(5)
	print("WORLD SERVICE UI: %d failures" % failures);quit(failures)
