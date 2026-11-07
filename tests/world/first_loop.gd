extends SceneTree
## Real Router/Motor route. No position writes, granted flags, HP changes or fake Boss death.
var app: FixedWorldApp
var failures := 0
var steps := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,text: String) -> void:
	print("CHECK ",ok," ",text)
	if not ok: failures += 1
func ticks(count: int) -> void:
	for i: int in count: await physics_frame
func settle() -> void:
	for i: int in 180:
		await physics_frame
		if not app.busy and app.room != null: return
func walk(point: Vector2,room_id: String,timeout: int = 800) -> bool:
	var held := 0
	for tick: int in timeout:
		await physics_frame
		if app.busy: continue
		if app.room.room_id != room_id: return true
		var at := app.player.position
		if absf(at.x-point.x)<24 and absf(at.y-point.y)<8 and app.player.is_on_floor():
			app.controller.router.set_source_axis(&"keyboard_mouse",0)
			app.controller.router.set_jump_held(&"keyboard_mouse",false)
			return true
		var dx := point.x-at.x
		var above := point.y<at.y-30
		if point.y>at.y+40 and absf(dx)<30 and app.player.is_on_floor():
			app.controller.router.request_action(&"drop_through")
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>10 else 0)
		if app.player.is_on_floor() and (above or (room_id=="P-R06" and ((at.x>820 and at.x<990 and point.x>990) or (at.x>990 and point.x<890)))) and absf(dx)<245:
			app.controller.router.set_jump_held(&"keyboard_mouse",false)
			app.controller.router.set_jump_held(&"keyboard_mouse",true)
			held = 34
		elif held>0:
			held -= 1
			if held==0: app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if room_id=="P-R03" and not app.state.has("intro_complete") and tick%36==0 and not app.player.is_on_floor():
			var aim := Vector2.LEFT
			if app.room.enemies.has("P-R03:practice:01"):
				var enemy: EnemyActor = app.room.enemies["P-R03:practice:01"]
				if not enemy.health.terminal: aim = (enemy.motor.position-at).normalized()
			app.controller.router.request_action(&"shoot_release",aim)
		if tick%180==0: print("WALK ",room_id," ",at," -> ",point," ",app.status)
	print("STUCK ",room_id," ",app.player.position," -> ",point," ",app.status)
	return false
func path(points: Array,room_id: String) -> bool:
	for point: Vector2 in points:
		if not await walk(point,room_id): return false
	return true
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
func run() -> void:
	root.size=Vector2i(1280,720)
	app = preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path = "user://world_route_test.json"
	for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(app.save_path+suffix)
	root.add_child(app)
	check(app.start_new(),"new world starts from title")
	await settle()
	await ticks(5)
	var player_id := app.player.get_instance_id()
	check(await path([Vector2(600,512),Vector2(880,432),Vector2(1250,352),Vector2(1600,302),Vector2(2810,302)],"P-R03"),"tutorial traversal")
	await settle()
	check(app.room.room_id=="P-R01","crossed real tutorial door to station")
	if app.room.room_id!="P-R01":
		await finish()
		return
	await walk(Vector2(240,286),"P-R01")
	await ticks(4)
	check(not app.ui.interact.visible and app.context_target().get("kind","")=="npc","nearby NPC is eligible for Up interaction without a HUD button")
	await click_named("交谈")
	check(app.paused and app.ui.page=="npc","actual touch opens NPC and pauses safely")
	await click_named("购买 5金币 · 试制滤芯")
	check(app.services.owns("trial_filter") and not app.services.active("filter"),"actual merchant purchase uses earned tutorial gold without auto-equipping")
	await click_named("背包与装配")
	await click_named("装配")
	check(app.services.active("filter"),"actual inventory touch equips filter")
	await click_named("关闭")
	await walk(Vector2(448,286),"P-R01")
	await ticks(4)
	await click_named("休息")
	await settle()
	check(app.state.value.cycle==2,"explicit station rest advances cycle")
	await walk(Vector2(905,286),"P-R01")
	await settle()
	check(app.room.room_id=="P-R08","station connects through original corridor")
	if app.room.room_id!="P-R08":
		await finish()
		return
	check(await path([Vector2(176,694),Vector2(420,606),Vector2(176,518),Vector2(420,430),Vector2(176,342),Vector2(420,254),Vector2(384,174),Vector2(304,126),Vector2(384,-15)],"P-R08"),"corridor physical ascent")
	await settle()
	check(app.room.room_id=="P-R06","vertical connection to junction")
	if app.room.room_id!="P-R06":
		await finish()
		return
	check(await path([Vector2(624,702),Vector2(860,614),Vector2(1040,614)],"P-R06"),"jump across real thorns to the safe pickup ledge")
	await ticks(4)
	await click_named("拾取")
	check(int(app.state.value.inventory.get("trial_part",0))==1,"actual placed quest material acquired once")
	check(await path([Vector2(860,614),Vector2(624,526),Vector2(384,438),Vector2(160,398),Vector2(5,398)],"P-R06"),"junction to Boss")
	await settle()
	check(app.room.room_id=="P-R14","Boss room entered")
	check(app.player.get_instance_id()==player_id,"shared player survives all rooms")
	check(await path([Vector2(1470,550),Vector2(1360,654)],"P-R14"),"enter real arena")
	check(await fight(),"real battle commits permanent victory")
	if not app.state.has("boss_P_WINDKEEPER_defeated"):
		await finish()
		return
	await path([Vector2(1196,524),Vector2(1256,524),Vector2(1360,654)],"P-R14")
	await ticks(120)
	check(app.services.ledger().gold>=20,"physically collect the Boss coin shower before leaving")
	await path([Vector2(1480,654)],"P-R14")
	await ticks(4)
	await click_named("领取钩索 H")
	await ticks(4)
	check(app.state.has("H"),"real reward interaction grants H")
	var receipts: int = app.state.value.receipts.size()
	app.controller.router.request_action(&"interact")
	await ticks(4)
	check(app.state.value.receipts.size()==receipts,"duplicate interaction grants nothing twice")
	check(await path([Vector2(1530,550),Vector2(1616,462),Vector2(1755,462)],"P-R14"),"return from Boss via entrance")
	await settle()
	check(app.room.room_id=="P-R06","returned to junction")
	await path([Vector2(384,438),Vector2(624,526),Vector2(750,830)],"P-R06")
	await settle()
	check(app.room.room_id=="P-R08","actual down connection returns to corridor")
	app.controller.router.request_action(&"grapple",(app.room.hook_points[0]-app.player.position).normalized())
	var attached:=false
	for i: int in 65:
		await physics_frame
		if app.controller.traversal.state==&"hook_hang": attached=true;break
	check(attached,"earned H attaches to real authored return anchor")
	app.controller.router.set_jump_held(&"keyboard_mouse",true)
	await ticks(10)
	app.controller.router.set_jump_held(&"keyboard_mouse",false)
	await path([Vector2(420,254),Vector2(420,606),Vector2(176,694),Vector2(144,782),Vector2(5,782)],"P-R08")
	await settle()
	check(app.room.room_id=="P-R01","first loop returns to station")
	check(app.state.value.cycle==2,"ordinary return never rests or refreshes cycle")
	await walk(Vector2(240,286),"P-R01")
	await ticks(4)
	await click_named("交谈")
	await click_named("交付零件")
	check(app.state.has("trial_station_repaired") and app.services.ledger().quests.trial_station_repair=="completed","actual return NPC commits material delivery and visible world result")
	await click_named("告别")
	check(not app.state.has("Q"),"normal route never grants Q early")
	check(app.state.value.explored.size()==5,"only visited rooms recorded")
	app.return_title()
	await ticks(4)
	check(app.title.visible,"save and exit to normal title")
	await finish()
func fight() -> bool:
	for tick: int in 7200:
		await physics_frame
		if app.busy: continue
		if app.room.room_id!="P-R14":
			print("BATTLE DEATH ",app.status)
			return false
		if app.state.has("boss_P_WINDKEEPER_defeated"): return true
		var encounter := app.room.encounter as WindkeeperPressureEncounter
		var at := app.player.position
		var target := app.room.boss.position-Vector2(0,70)
		var destination := 1260.0
		if absf(target.x-at.x)<200: destination = 680 if target.x>1000 else 1260
		app.controller.router.set_source_axis(&"keyboard_mouse",signf(destination-at.x) if absf(destination-at.x)>25 else 0)
		if app.player.is_on_floor() and (at.y>550 or "warning" in str(encounter.mode)):
			app.controller.router.set_jump_held(&"keyboard_mouse",false)
			app.controller.router.set_jump_held(&"keyboard_mouse",true)
		elif tick%45==0: app.controller.router.set_jump_held(&"keyboard_mouse",false)
		if tick%20==0: app.controller.router.request_action(&"shoot_release",(target-at).normalized())
		if tick%180==0: print("BATTLE ",at," boss ",encounter.health.current," player ",app.controller.actor_resources.health.current," ",encounter.mode)
	return false
func finish() -> void:
	app.queue_free()
	await ticks(5)
	print("WORLD LOOP: ",failures," failures")
	quit(failures)
