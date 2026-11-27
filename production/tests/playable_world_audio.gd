extends SceneTree
## Follow the shipping shell signals, actual room admissions and persistent volume settings.
var checks := 0
var failures := 0
var base_path := "user://world-audio-proof-%s" % Time.get_ticks_usec()

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("FAIL world audio ",message)

func frames(count: int) -> void:
	for i in count: await process_frame

func run() -> void:
	var shell:=preload("res://game/application/world_shell.tscn").instantiate() as WorldShell
	var slot:=PlayableWorldSave.new()
	slot.configure_world(base_path+".json")
	shell.storage=slot
	root.add_child(shell)
	var audio:=shell.get_node("WorldAudio") as PlayableWorldAudio
	var music:=audio.music
	var bed:=audio.ambience
	await frames(3)
	check(music.starts=={&"home":1} and bed.candidate.is_empty(),"title starts the old music alone")
	shell.request_new_game()
	var host:=shell.world
	if not is_instance_valid(host):
		check(false,"new game admitted from title")
		quit(1)
		return
	await frames(8)
	check(host.active!=null and host.active.room.room_id=="P01","actual P01 startup")
	check(music.requested_track==&"plains" and bed.candidate=="wind_a","P01 meadow and selected quiet wind")
	var revision:=host.active.state.revision
	var state:=host.active.state.value.duplicate(true)
	var starts:=music.starts.duplicate()
	var beds:=bed.starts.duplicate()
	audio.enter_room(host.active)
	check(music.starts==starts and bed.starts==beds and host.active.state.revision==revision and host.active.state.value==state,"audio notification leaves save and both playheads alone")
	await frames(108)
	host.enter_room("P02","d001")
	await frames(5)
	check(host.active.room.room_id=="P02" and music.starts==starts and bed.starts==beds,"normal same-region replacement retains score and wind")
	host.enter_room("F01","")
	await frames(95)
	check(music.requested_track==&"forest" and bed.candidate=="woods_a","forest selects its own music and selected bird bed")
	check(music._ids.count(&"")==1 and bed._bed_ids.count("")==1,"outgoing streams released after fades")
	var settings:=WorldSettings.new()
	settings.open(base_path+"-prefs.json","audio_proof")
	var next:=settings.value.duplicate(true)
	next.volume=0.0
	check(settings.save(next) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")),"settings mute the real output")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Music"))==&"Master" and AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience"))==&"Master","score and ambience obey master")
	var revision_at_mute:=host.active.state.revision
	shell.open_pause()
	await frames(80)
	check(music._duck<=0.51 and bed._beds.any(func(v: AudioStreamPlayer):return v.stream!=null and v.stream_paused),"pause ducks the score and pauses the bed")
	shell.resume_world()
	next.volume=0.35
	check(settings.save(next) and not AudioServer.is_bus_mute(0) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.35),"saved volume restores without double scaling")
	check(host.active.state.revision==revision_at_mute,"preferences do not commit the world")
	host.enter_room("G19","")
	await frames(12)
	var fight: WorldRoomEncounter=host.active.encounters[0]
	check(music.requested_track==&"plains" and bed.candidate=="draft_a" and not fight.battle_active(),"quiet optional arena before challenge")
	var qualified:=host.active.state.candidate()
	qualified.flags.append_array(["W","H"])
	check(host.active.state.commit(qualified,host.active.state.revision),"prepare actual encounter eligibility")
	host.active.player.reset_at(fight.position+fight.start_offset)
	await frames(10)
	check(fight.confirm(),"challenge accepted")
	await frames(10)
	check(fight.battle_active() and music.requested_track==&"plains_boss","real wave starts combat cue")
	var entry_count: int=music.starts.get(&"plains_boss",0)
	await frames(45)
	check(music.starts.get(&"plains_boss",0)==entry_count,"fight does not start another voice each frame")
	await host.active.audio_service.shutdown()
	shell.open_pause()
	shell.return_title()
	await frames(90)
	check(music.requested_track==&"home" and bed.candidate.is_empty() and bed._beds.all(func(v: AudioStreamPlayer):return v.stream==null),"return to title releases fight and ambience")
	check(not is_instance_valid(host) and audio.host==null,"old host and room signal released")
	var catalog:=WorldContentCatalog.new()
	catalog.load_locked()
	for region: Dictionary in catalog.table("regions").rows:
		check(PlayableWorldAudio.REGION.has(region.id),"v27 region "+str(region.id))
	var playbacks:=music._playbacks.duplicate()
	check(await music.shutdown() and await bed.shutdown(),"audio backends release before shutdown")
	shell.free()
	await frames(2)
	check(playbacks.all(func(ref: WeakRef):return ref.get_ref()==null),"playback resources released")
	for suffix: String in [".json",".json.backup","-prefs.json","-prefs.json.backup"]:
		if FileAccess.file_exists(base_path+suffix):DirAccess.remove_absolute(base_path+suffix)
	print("PLAYABLE WORLD AUDIO checks=",checks," failures=",failures)
	quit(1 if failures else 0)
