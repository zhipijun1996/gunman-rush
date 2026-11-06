extends SceneTree
## Declared resource/damage fixtures; raw device events drive the actual held action.
var app: FixedWorldApp
var failures:=0
var checks:=0
var damage_id:=0
var shots:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("HEAL CHECK ",ok," ",label)
	if not ok: failures+=1
func ticks(n: int) -> void:
	for i: int in n: await physics_frame
func settle() -> void:
	for i: int in 180:
		await physics_frame
		if not app.busy: return
func key(down: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_C;event.pressed=down
	root.push_input(event,true)
func pad(down: bool) -> void:
	var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=down
	root.push_input(event,true)
func touch(down: bool,canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new();event.index=21;event.pressed=down;event.canceled=canceled
	event.position=app.ui.heal.get_global_transform_with_canvas()*(app.ui.heal.size/2)
	root.push_input(event,true)
func hurt(amount: float=1) -> void:
	await ticks(45)
	damage_id+=1
	app.submit_damage(&"focus_fixture",DamageRequest.Kind.MONSTER,amount,StringName("focus_damage:"+str(damage_id)))
	await ticks(4)
func run() -> void:
	root.size=Vector2i(960,540)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate()
	app.save_path="user://world_focus_heal_test.json";app.settings_path="user://world_focus_heal_settings.json"
	for path: String in [app.save_path,app.settings_path]:
		for suffix: String in ["",".backup",".tmp",".corrupt"]: DirAccess.remove_absolute(path+suffix)
	root.add_child(app);app.start_new();await settle()
	app.controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_packet: int) -> void: shots+=1)
	app.load_room("P-R01","START-P03-P01:P-R01");await settle();await ticks(45)
	var health:=app.controller.actor_resources.health
	var energy:=app.controller.combat_energy
	energy.grant("declared_energy_fixture",100)
	key(true);await ticks(65);key(false);await ticks(2)
	check(health.current==5 and energy.current==100,"full health rejects without spending")
	await hurt(2)
	check(health.current==3,"accepted damage establishes missing health")
	key(true);await ticks(25);key(false);await ticks(50)
	check(health.current==3 and energy.current==100 and app.focus_heal.ratio()==0,"release discards partial charge at no cost")
	key(true);await ticks(64);key(false);await ticks(2)
	check(health.current==4 and energy.current==65,"real C hold heals one for exactly 35 resonance")
	check(app.state.value.hp==4 and app.state.value.combat_energy==65,"health and energy commit in the same durable world revision")
	await hurt()
	await ticks(45) # Let the preceding hit's real invulnerability expire.
	key(true);await ticks(20)
	app.submit_damage(&"focus_fixture",DamageRequest.Kind.MONSTER,1,&"focus_interrupt")
	await ticks(75)
	check(health.current==2 and energy.current==65 and app.focus_heal.blocked,"accepted hit cancels and requires a fresh press")
	key(false);await ticks(2)
	key(true);await ticks(20);app.toggle_pause();await ticks(70)
	check(health.current==2 and energy.current==65 and not app.controller.router.focus_heal_held(),"pause cancels held intent and cannot heal in a menu")
	app.toggle_pause();key(false);await ticks(2)
	key(true);await ticks(20)
	app.controller.router._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await ticks(65)
	check(health.current==2 and energy.current==65,"focus loss cancels without spending")
	app.controller.router._notification(NOTIFICATION_APPLICATION_FOCUS_IN);key(false);await ticks(2)
	key(true);await ticks(20);app.controller.router.set_source_axis(&"keyboard_mouse",1,true);await ticks(4)
	app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(65)
	check(health.current==2 and energy.current==65,"movement cancels and does not resume while held")
	key(false);await ticks(15)
	key(true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(3)
	app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(80)
	check(health.current==2 and energy.current==65,"actual jump cancels charge")
	key(false);await ticks(4)
	key(true);await ticks(20);app.load_room("P-R03","");await settle();await ticks(65)
	check(health.current==2 and energy.current==65 and app.focus_heal.ratio()==0,"room change preserves currency and cancels action lifetime")
	key(false);app.load_room("P-R01","START-P03-P01:P-R01");await settle();await ticks(45)
	app.state.storage.blocked=true
	key(true);await ticks(65);key(false);await ticks(3)
	check(health.current==2 and energy.current==65,"failed durable write spends no health or resonance")
	app.state.storage.blocked=false
	health.normal_healing_blocked=true
	key(true);await ticks(65);key(false);await ticks(2)
	check(health.current==2 and energy.current==65,"ordinary healing policy cannot be bypassed")
	health.normal_healing_blocked=false
	pad(true);await ticks(64);pad(false);await ticks(2)
	check(health.current==3 and energy.current==30,"real gamepad B hold uses the same resource transaction")
	key(true);await ticks(65);key(false);await ticks(2)
	check(health.current==3 and energy.current==30,"insufficient shared currency rejects")
	energy.grant("touch_fixture",70);await ticks(3)
	touch(true);await ticks(20);touch(false,true);await ticks(65)
	check(health.current==3 and energy.current==100 and not app.controller.router.focus_heal_held(),"actual canceled touch releases capture without healing")
	touch(true);await ticks(64);touch(false);await ticks(2)
	check(health.current==4 and energy.current==65 and shots==0,"actual mobile hold heals exactly once with no weapon shot")
	key(true);await ticks(20);app.controller.router.activate_device(&"gamepad");await ticks(65);key(false);await ticks(2)
	check(health.current==4 and energy.current==65,"device ownership change cancels old held source")
	key(true);await ticks(20);energy.consume("declared_other_skill",40);await ticks(65);key(false);await ticks(2)
	check(health.current==4 and energy.current==25,"another accepted consumer prevents double spending the same resonance")
	app.player.reset_at(app.room.rest_point);await ticks(3);app._interact();await ticks(4)
	check(health.current==5 and energy.current==25 and app.state.value.combat_energy==25,"rest heals without granting or resetting resonance")
	await hurt();await ticks(45);energy.grant("fatal_fixture",75)
	key(true)
	for i: int in 90:
		await physics_frame
		if app.focus_heal.elapsed>=float(app.focus_heal.settings.charge_seconds)-.02: break
	check(app.focus_heal.elapsed>=.98,"fatal fixture reaches the final charging frame")
	app.submit_damage(&"fatal_fixture",DamageRequest.Kind.MONSTER,99,&"focus_fatal")
	await ticks(8);await settle();await ticks(65);key(false)
	check(health.current==5 and energy.current==0 and app.state.value.combat_energy==0,"fatal arbitration wins near completion; death clears resonance")
	# Produce a real accepted heal save for the independent-process restore check.
	await hurt(2);await ticks(45);energy.grant("restart_fixture",100)
	key(true);await ticks(64);key(false);await ticks(2)
	check(health.current==4 and energy.current==65,"final accepted heal provides independent restart evidence")
	app.return_title();await ticks(3)
	check(await WorldAudioLifecycle.drain_world(app),"existing audio lifecycle releases playback before process exit")
	app.queue_free();await ticks(5)
	print("WORLD HEAL: %d assertions, %d failures" % [checks,failures]);quit(failures)
