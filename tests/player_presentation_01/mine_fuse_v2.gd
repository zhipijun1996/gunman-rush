extends SceneTree
## Actual formal Home actor, original wall and Router; no player pose/resource writes.
## Short-fuse cases equip a clearly labelled test-only Definition duplicate.
var world: Node2D
var home: HomeScene
var controller: PlayerController
var runtime: WeaponActionRuntime
var checks := 0
var errors: Array[String] = []
var events: Array[Dictionary] = []
var blasts: Array[Dictionary] = []
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: errors.append(message)

func tick(count: int = 1) -> void:
	for unused: int in count:
		await process_frame
		await physics_frame

func close_world() -> void:
	if not is_instance_valid(world): return
	check(await load("res://tests/audio_teardown.gd").drain_world(world),"actual audio owners release")
	world.free()
	await process_frame

func fixture(id: String, seconds: float = -1.0) -> void:
	await close_world()
	world=Node2D.new()
	root.add_child(world)
	var audio := GameAudio.new()
	audio.volume=0 # Muted gameplay-only fixture; no listening acceptance.
	world.add_child(audio)
	home=HomeScene.new()
	world.add_child(home)
	controller=home.controller
	controller.router.activate_device(&"gamepad")
	await tick(12)
	var definition := load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
	if seconds>0:
		definition=definition.duplicate() as WeaponDefinition
		definition.mine_fuse_seconds=seconds
		definition.entity_lifetime=seconds
	check(definition.is_valid(),"fixture Definition valid "+id)
	check(controller.shoot_ability.equip(definition),"original equip accepted "+id)
	await tick(2)
	runtime=controller.shoot_ability.runtime
	blasts=[]
	runtime.blast_fired.connect(func(point: Vector2) -> void:
		var event := {"kind":"blast","tick":Engine.get_physics_frames(),"point":[point.x,point.y],"weapon":id,"fuse":definition.mine_fuse_seconds,"runtime_entities":runtime.entities.size()}
		blasts.append(event)
		events.append(event))

func launch(axis: Vector2 = Vector2.LEFT) -> WeaponEntity:
	controller.router.request_action(&"shoot_release",axis)
	await tick()
	for item: WeaponEntity in runtime.entities:
		if is_instance_valid(item) and not item.spent: return item
	check(false,"actual accepted mine spawned")
	return null

func wait_attached(item: WeaponEntity) -> void:
	for unused: int in 100:
		if not is_instance_valid(item) or item.spent or item.phase==&"attached": break
		await tick()
	check(is_instance_valid(item) and not item.spent and item.phase==&"attached","mine attached to original Home wall")

func expiry(id: String) -> void:
	await fixture(id)
	var item := await launch()
	if not is_instance_valid(item): return
	await wait_attached(item)
	var spawn_tick := Engine.get_physics_frames()-int(round(item.age*60))
	while is_instance_valid(item) and not item.spent and item.age<5.9:
		await tick()
	check(blasts.is_empty(),id+" never explodes before max fuse")
	var last_age := item.age if is_instance_valid(item) else -1.0
	for unused: int in 12:
		await tick()
		if not blasts.is_empty(): break
	check(blasts.size()==1,id+" expiry explodes exactly once")
	if not blasts.is_empty():
		var elapsed: int=int(blasts[0].tick)-spawn_tick
		check(elapsed>=359 and elapsed<=361,id+" six-second spawn deadline within one physics tick")
		events.append({"kind":"deadline_observation","weapon":id,"elapsed_ticks":elapsed,"last_observed_age":last_age})
	check(not is_instance_valid(item) or item.spent,id+" detonated entity retired")
	await tick(30)
	check(blasts.size()==1,id+" no repeated explosion after retirement")

func configured_flight() -> void:
	await fixture("magnetic_mine",.10)
	var item := await launch(Vector2.UP)
	if not is_instance_valid(item): return
	check(item.phase==&"outbound","short configured fuse starts during true flight")
	await tick(10)
	check(blasts.size()==1,"configured fuse expires in flight before attachment")
	check(not is_instance_valid(item) or item.spent,"same lifetime/fuse deadline explodes rather than fizzling")

func manual_and_pause() -> void:
	await fixture("magnetic_mine")
	var item := await launch()
	if not is_instance_valid(item): return
	await wait_attached(item)
	var before := item.age
	paused=true
	for unused: int in 20: await process_frame
	check(is_equal_approx(item.age,before) and blasts.is_empty(),"pause freezes actual mine age and fuse")
	paused=false
	controller.router.request_action(&"weapon_context")
	await tick(3)
	check(blasts.size()==1,"manual context still detonates original attached mine")
	await tick(370)
	check(blasts.size()==1,"manual detonation cannot later repeat at deadline")

func cancellation(reason: StringName) -> void:
	await fixture("magnetic_mine",.65)
	var item := await launch()
	if not is_instance_valid(item): return
	await wait_attached(item)
	if reason==&"death":controller.die()
	elif reason==&"equipment":controller.shoot_ability.equip(preload("res://resources/weapons/pulse_gun.tres"))
	else:runtime.cancel(reason)
	await tick(50)
	check(blasts.is_empty(),"cancelled mine emits no delayed blast "+String(reason))
	check(not is_instance_valid(item) or item.spent,"cancelled mine is retired "+String(reason))

func host_removed_at_deadline(free_host: bool) -> void:
	await fixture("magnetic_mine")
	var item := await launch()
	if not is_instance_valid(item): return
	await wait_attached(item)
	var delta := 1.0/float(Engine.physics_ticks_per_second)
	while is_instance_valid(item) and not item.spent and item.age+delta<runtime.definition().mine_fuse_seconds:
		await tick()
	check(is_instance_valid(item) and not item.spent and blasts.is_empty(),"deadline-host regression reaches final live physics step")
	if not is_instance_valid(item) or item.spent: return
	var before := item.age
	var host := item.attached
	# Explicit destructive fixture action: remove the real attached Home wall on
	# the exact step that would otherwise expire the fuse. Never move the player.
	if free_host:host.free()
	else:host.get_parent().remove_child(host)
	await tick(2)
	check(blasts.is_empty(),"missing attached host wins over simultaneous fuse deadline "+str(free_host))
	check(not is_instance_valid(item) or item.spent,"missing host retires mine at deadline "+str(free_host))
	events.append({"kind":"deadline_host_removed","free_host":free_host,"age_before_next_step":before,"next_step_delta":delta,"blasts":blasts.size()})
	if is_instance_valid(host):host.free()
	await tick(5)
	check(blasts.is_empty(),"removed attached host cannot cause delayed stale blast "+str(free_host))

func validation() -> void:
	for id: String in WeaponCatalog.IDS:
		var definition := load("res://resources/weapons/%s.tres" % id) as WeaponDefinition
		check(definition.is_valid(),"every original Definition remains valid "+id)
		check(definition.mine_fuse_seconds==(6.0 if definition.mode==WeaponDefinition.Mode.MINE else 0.0),"fuse configured only on mine family "+id)
	var mine := preload("res://resources/weapons/magnetic_mine.tres").duplicate() as WeaponDefinition
	for value: float in [NAN,INF,-1.0,0.0,31.0,6.1]:
		mine.mine_fuse_seconds=value
		check(not mine.is_valid(),"invalid mine max fuse rejected "+str(value))

func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output): quit(1);return
	root.size=Vector2i(1280,720)
	validation()
	await expiry("magnetic_mine")
	await expiry("magnetic_storm")
	await configured_flight()
	await manual_and_pause()
	await host_removed_at_deadline(false)
	await host_removed_at_deadline(true)
	for reason: StringName in [&"equipment",&"death",&"reset",&"respawn",&"segment_return",&"scene_changed"]:
		await cancellation(reason)
	await fixture("pulse_gun")
	controller.router.request_action(&"shoot_release",Vector2.UP)
	await tick(370)
	check(blasts.is_empty() and runtime.entities.is_empty(),"non-mine actual primary receives no timed explosion")
	await close_world()
	var report := {"checks":checks,"errors":errors,"events":events,"scope":"Actual original Home/actor/Router,wall attachment,real six-second Lv2 and Lv3-primary expiry,pause/manual/cancel,actual attached-host detach/free on simultaneous deadline. Shortfuse config duplicates explicitly test fixtures;no actor position/HP/resource writes. Not earned Lv3 skill,visual/audio/device/player acceptance."}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for error: String in errors: printerr(error)
	print("MINE FUSE V2: checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
