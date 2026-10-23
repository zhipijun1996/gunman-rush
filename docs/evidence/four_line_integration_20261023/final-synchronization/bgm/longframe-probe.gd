extends SceneTree
var results: Array=[]
func _initialize() -> void: run.call_deferred()
func sample(voice: AudioStreamPlayer) -> Dictionary:
	var playback: AudioStreamPlayback=voice.get_stream_playback() if voice.has_stream_playback() else null
	return {"monotonic_usec":Time.get_ticks_usec(),"position":voice.get_playback_position(),"backend_position":playback.get_playback_position() if playback else -1,"loop_count":playback.get_loop_count() if playback else -1,"playing":voice.playing,"since_mix":AudioServer.get_time_since_last_mix(),"to_next_mix":AudioServer.get_time_to_next_mix(),"mix_rate":AudioServer.get_mix_rate()}
func run() -> void:
	for mode: String in ["normal","pre_seek_longframe"]:
		for id: StringName in [&"home",&"plains",&"plains_boss",&"forest",&"forest_boss"]:
			var music:=GameMusic.new();root.add_child(music);music.request_track(id)
			for unused: int in 3:await physics_frame;await process_frame
			var voice: AudioStreamPlayer=music._voices[music._ids.find(id)]
			var length:=voice.stream.get_length()
			await process_frame
			if mode=="pre_seek_longframe":OS.delay_msec(250)
			var before:=sample(voice)
			var before_delta:=music.get_process_delta_time()
			voice.seek(length-.05)
			var queued:=sample(voice)
			var timer_start:=Time.get_ticks_usec()
			var timer:=create_timer(.2,true,false,true)
			await timer.timeout
			var after:=sample(voice)
			var row:={"id":id,"mode":mode,"length":length,"path":voice.stream.resource_path,"source_sha256":FileAccess.get_sha256(voice.stream.resource_path),"before":before,"queued":queued,"after":after,"timer_elapsed_usec":after.monotonic_usec-timer_start,"process_delta_before_seek":before_delta,"process_delta_after_timer":music.get_process_delta_time(),"shutdown_1s":await music.shutdown()}
			results.append(row);music.free();await process_frame;await process_frame
			print("LONGFRAME_MP3 ",JSON.stringify(row))
	var f:=FileAccess.open("/workspace/scratch/bgm-seek-current-20261023/longframe-probe.json",FileAccess.WRITE);f.store_string(JSON.stringify({"rows":results,"driver":AudioServer.get_driver_name(),"probe_sha256":FileAccess.get_sha256("/workspace/scratch/bgm-seek-current-20261023/longframe-probe.gd"),"runtime_sha256":FileAccess.get_sha256("res://scripts/audio/game_music.gd"),"scope":"causal timer diagnostic; original seek and 200ms SceneTreeTimer, fresh real backend per track; deliberate250ms main-thread longframe before seek"},"  "));f.close();quit()
