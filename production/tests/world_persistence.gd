extends SceneTree
## The same native slot is reopened by separate Godot processes. The additional
## bench exercises a second registered rest without editing the production room.
var bench: Vector2
var checks := 0
var failures := 0
var slot: PlayableWorldSave
var host: WorldGameHost
var outgoing: Array[WeakRef] = []

class WithBench extends WorldGameHost:
	func read_destination(id: String) -> Dictionary:
		var doc := super.read_destination(id)
		if id=="P02" and not doc.has("error"):
			doc.entities.test_station = {"definition_id":"recovery.station","definition_version":1,"id":"test_station","properties":{"position":doc.exits.d001.spawn}}
		return doc

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, detail: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL world persistence ",detail)

func ticks(n: int) -> void:
	for i in n: await physics_frame

func observe_removed(node: Node) -> void:
	if node is GameAudio or node is GameAmbience: outgoing.append_array(node._playbacks)

func open_host() -> bool:
	host = WithBench.new()
	host.storage = slot
	root.add_child(host)
	check(host.active!=null,"open full world host: "+host.last_error)
	await ticks(3)
	return is_instance_valid(host.active)

func close_host() -> void:
	if is_instance_valid(host.active):
		check(await host.active.audio_service.shutdown(),"release active audio")
	host.free()
	var until:=Time.get_ticks_msec()+2000
	while outgoing.any(func(track:WeakRef)->bool:return track.get_ref()!=null) and Time.get_ticks_msec()<until:
		await process_frame
	check(not outgoing.any(func(track:WeakRef)->bool:return track.get_ref()!=null),"release audio of previous rooms")
	await ticks(2)

func write_first_game() -> void:
	check(not slot.startup_room().has_save,"new native slot")
	if not await open_host():return
	var s:=host.active
	check(s.room.room_id=="P01" and s.opening!=null,"fresh boot runs authored opening")
	await ticks(108)
	s.player.reset_at(s.opening.position)
	await ticks(3)
	s.controller.router.request_action(&"interact")
	await ticks(4)
	check(s.state.has("gun") and s.state.value.receipts.has(PlainsOpening.TAKE),"claim genuine ground weapon")
	var chest:=s.room.physical_action("p01_loft_coin_chest")
	s.player.reset_at(chest.position)
	await ticks(4)
	s.controller.router.request_action(&"interact")
	await ticks(5)
	for i in 100:
		if s.room.loot.pickups.is_empty():break
		s.player.reset_at(s.room.loot.pickups[0].position+Vector2.UP*4)
		await ticks(1)
	check(s.services.ledger().gold==5 and s.state.value.receipts.has("p01_loft_coin_chest"),"open actual chest and collect all issued coins")
	host.enter_room("P02","d001")
	check(host.active.room.room_id=="P02","commit cross-room transfer")
	bench=FixedWorldProvider.point(host.active_doc.exits.d001.spawn)
	var field:=host.active
	field.player.reset_at(bench)
	await ticks(4)
	var before:=FileAccess.get_file_as_string(slot.path)
	DirAccess.make_dir_absolute(slot.path+".tmp")
	check(not field.equipment_transaction("rest","",field.state.revision) and field.state.value.rest.room=="P01","real write rejection does not register bench")
	host.enter_room("P03","d002")
	check(host.active==field and field.lifetime.active and FileAccess.get_file_as_string(slot.path)==before,"rejected door write leaves source playable and old file intact")
	DirAccess.remove_absolute(slot.path+".tmp")
	check(field.equipment_transaction("rest","",field.state.revision) and FixedWorldProvider.point(field.state.value.rest.point)==bench,"rest transaction registers exact supported bench after retry")
	host.enter_room("P03","d002")
	check(host.active.room.room_id=="P03" and host.active.checkpoint(),"durable room entrance and live checkpoint")
	await close_host()

func resume_and_die() -> void:
	bench=FixedWorldProvider.point(WorldRoomDocument.read("res://rooms/world/P02.json").exits.d001.spawn)
	check(slot.startup_room().room=="P03","new process reads last room")
	if not await open_host():return
	var s:=host.active
	check(s.state.has("gun") and s.services.ledger().gold==5 and s.state.value.receipts.has("p01_loft_coin_chest"),"permanent weapon, wallet and paid chest survive process exit")
	check(s.state.value.rest.room=="P02" and FixedWorldProvider.point(s.state.value.rest.point)==bench and s.state.value.entry=="d002","foreign rest and last entrance both survive")
	var health:=s.controller.actor_resources.health
	var hit:=DamageRequest.new()
	hit.target_id=&"player"
	hit.source_id=&"persistence_test"
	hit.event_id=&"fatal"
	hit.actor_epoch=s.lifetime.actor_epoch
	hit.token=s.lifetime.token()
	hit.health_epoch=health.epoch
	hit.amount=health.capacity
	await ticks(45)
	var cycle:int=s.state.value.cycle
	check(s.policy.submit(hit),"accept lethal request in resumed room")
	for i in 200:
		await physics_frame
		if host.active!=s and not host.crossing:break
	check(host.active!=s and host.active.room.room_id=="P02" and host.active.state.value.cycle==cycle+1 and host.active.player.position.distance_to(bench)<2,"death returns to precise bench in other room")
	check(host.active.controller.actor_resources.health.current==host.active.controller.actor_resources.health.capacity and host.active.state.has("gun") and host.active.services.ledger().gold==5,"respawn restores health and keeps permanent progress")
	await close_host()

func replacement() -> void:
	bench=FixedWorldProvider.point(WorldRoomDocument.read("res://rooms/world/P02.json").exits.d001.spawn)
	if not await open_host():return
	check(host.active.room.room_id=="P02" and host.active.player.position.distance_to(bench)<2,"restart immediately after death stands at registered bench")
	var old_host:=host.active
	var before:=FileAccess.get_file_as_string(slot.path)
	var dialog:=WorldNewGameDialog.mount(host)
	paused=true
	dialog.open()
	dialog.cancel()
	check(paused and FileAccess.get_file_as_string(slot.path)==before and host.active==old_host,"cancel new game preserves previous menu and disk")
	paused=false
	dialog.open()
	DirAccess.make_dir_absolute(slot.path+".tmp")
	dialog.confirm()
	check(dialog.window.visible and host.active==old_host and FileAccess.get_file_as_string(slot.path)==before,"new-game storage failure keeps previous world")
	DirAccess.remove_absolute(slot.path+".tmp")
	dialog.confirm()
	check(not dialog.window.visible and not paused and not slot.startup_room().has_save,"confirmed replacement survives immediate exit before P01 is opened")
	await close_host()

func corrupt_and_recover() -> void:
	check(not slot.startup_room().has_save,"new world marker survives new process")
	if not await open_host():return
	check(host.active.room.room_id=="P01" and host.active.opening.waking and not host.active.state.has("gun") and host.active.services.ledger().gold==0,"fresh replacement has no earlier equipment or income")
	await close_host()
	var backup:=slot.path+".backup"
	var original:=FileAccess.get_file_as_string(backup)
	var f:=FileAccess.open(slot.path,FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(slot.startup_room().ok and slot.status=="recovered_backup","recover valid backup after truncated primary")
	f=FileAccess.open(backup,FileAccess.WRITE)
	f.store_string("{broken backup")
	f.close()
	var result:=slot.startup_room()
	check(not result.ok and FileAccess.get_file_as_string(slot.path)=="{broken","corrupt primary and backup reported without overwriting them")
	f=FileAccess.open(backup,FileAccess.WRITE)
	f.store_string(original)
	f.close()
	check(slot.startup_room().ok and not slot.blocked,"recover prior backup found on retry")

func gear_doc() -> Dictionary:
	var doc:=WorldRoomDocument.read("res://tests/assembly_room.json")
	var source:String=EquipmentCatalog.REWARDS.data.find_key("B11")
	doc.entities.reward={"definition_id":"equipment.reward","definition_version":1,"id":"reward","properties":{"position":[160,366],"source_id":source}}
	doc.entities.bench={"definition_id":"recovery.station","definition_version":1,"id":"bench","properties":{"position":[160,366]}}
	return doc

func equipment_phase(restore: bool) -> void:
	var s:=OrdinaryRoomSession.new()
	root.add_child(s)
	check(s.open(gear_doc(),slot).is_empty(),"authored native equipment fixture opens")
	if s.room!=null:
		if not restore:
			s.player.reset_at(Vector2(160,366))
			await ticks(4)
			var origin:String=EquipmentCatalog.REWARDS.data.find_key("B11")
			check(s.equipment_transaction("claim",origin,s.state.revision) and s.equipment_transaction("equip","B11",s.state.revision),"physical reward and equipment station accept actual gear")
		else:
			check(s.services.level("B11")==1 and "B11" in s.services.ledger().equipped and s.equipment.has("B11"),"equipped reward restored in separate process and active runtime")
		await s.audio_service.shutdown()
	s.free()
	await ticks(2)

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()==2:
		slot=PlayableWorldSave.new()
		slot.configure_world(args[1],false,"regression")
		node_removed.connect(observe_removed)
		match args[0]:
			"seed": await write_first_game()
			"resume": await resume_and_die()
			"replace": await replacement()
			"corrupt": await corrupt_and_recover()
			"gear_write","gear_read": await equipment_phase(args[0]=="gear_read")
		print("WORLD STORAGE PHASE ",args[0]," failures=",failures," checks=",checks)
		quit(1 if failures else 0)
		return
	var path:="user://world_persistence_%d.json"%OS.get_process_id()
	for phase:String in ["seed","resume","replace","corrupt","gear_write","gear_read"]:
		var target:=path+".gear" if phase.begins_with("gear") else path
		var output:Array=[]
		var code:=OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--fixed-fps","60","--script","res://tests/world_persistence.gd","--",phase,target],output,true)
		var report:=str(output[0]) if not output.is_empty() else ""
		check(code==0 and "failures=0" in report and "ERROR:" not in report and "leaked at exit" not in report,phase+" native process: "+report)
		if failures:break
	for base in [path,path+".gear"]:
		for suffix in ["",".backup",".corrupt",".tmp"]:
			var file:String=base+suffix
			if FileAccess.file_exists(file) or DirAccess.dir_exists_absolute(file): DirAccess.remove_absolute(file)
	print("WORLD PERSISTENCE failures=",failures," native_processes=",checks)
	quit(1 if failures else 0)
