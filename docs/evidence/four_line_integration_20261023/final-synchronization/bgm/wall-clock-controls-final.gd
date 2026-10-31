extends "/workspace/scratch/bgm-seek-current-20261023/runner-candidate-final-external.gd"
var controls: Array=[]
var control_failures:=0
func run() -> void:
	for mode: String in ["longframe_monotonic","non_looping","paused"]:
		for id: StringName in [&"home",&"plains",&"plains_boss",&"forest",&"forest_boss"]:
			var source: AudioStreamMP3=GameMusic.TRACKS[id]
			var voice:=AudioStreamPlayer.new();voice.playback_type=AudioServer.PLAYBACK_TYPE_STREAM;voice.volume_db=-80
			voice.stream=source.duplicate(true) if mode=="non_looping" else source
			if mode=="non_looping":voice.stream.loop=false
			root.add_child(voice);voice.play()
			await frames()
			if mode=="paused":voice.stream_paused=true
			await process_frame
			OS.delay_msec(250)
			var before:=audio_clock(voice)
			voice.seek(source.get_length()-.05)
			var queued:=audio_clock(voice)
			await wait_audio_wall(.2) # Exact helper compiled from the candidate.
			var after:=audio_clock(voice)
			var accepted: bool=voice.playing and voice.get_stream_playback().get_loop_count()>0
			var correct: bool=before.loop_count==0 and accepted==(mode=="longframe_monotonic") and after.monotonic_usec-queued.monotonic_usec>=200000 and source.loop
			var weak: WeakRef=playback_ref(voice) if voice.has_stream_playback() else null
			voice.stop();voice.stream=null
			var release_deadline:=Time.get_ticks_usec()+1000000
			while weak!=null and weak.get_ref()!=null and Time.get_ticks_usec()<release_deadline:await process_frame
			var released: bool=weak==null or weak.get_ref()==null
			if not correct or not released:control_failures+=1
			var row:={"id":id,"mode":mode,"length":source.get_length(),"source_sha256":FileAccess.get_sha256(source.resource_path),"source_loop":source.loop,"before":before,"queued":queued,"after":after,"wall_usec":after.monotonic_usec-queued.monotonic_usec,"original_loop_assertion_passed":accepted,"expected_accepted":mode=="longframe_monotonic","correct":correct,"released_within_1s":released}
			controls.append(row);print("WALL_CLOCK_CONTROL ",JSON.stringify(row));voice.free();await process_frame
	var file:=FileAccess.open("/workspace/scratch/bgm-seek-current-20261023/wall-clock-controls-final.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":controls.size(),"failures":control_failures,"controls":controls,"driver":AudioServer.get_driver_name(),"probe_sha256":FileAccess.get_sha256("/workspace/scratch/bgm-seek-current-20261023/wall-clock-controls-final.gd"),"compiled_candidate_sha256":FileAccess.get_sha256("/workspace/scratch/bgm-seek-current-20261023/runner-candidate-final-external.gd"),"scope":"fresh real backend baseline0; same actual MP3 files;250ms pre-seek longframe; exact candidate monotonic200ms helper; paused/nonloop are explicit local fixtures, never production resource edits"},"  "));file.close()
	print("BGM WALL CLOCK CONTROLS: ",controls.size()," checks, ",control_failures," failures");quit(1 if control_failures else 0)
