extends SceneTree
## Loaded import facts,not listening or proof of weapon-trigger lifecycle.
const BANK := preload("res://resources/player_presentation_01/weapon_sound_data_v2.gd").CLIPS
const EXPECTED: Array[StringName] = [&"pulse",&"machine",&"blade",&"hit",&"wall",&"blast",&"ion_start",&"ion_loop",&"ion_tail",&"blackhole_start",&"blackhole_loop",&"blackhole_burst",&"mine_beep",&"boomerang_return"]
const LOOPS: Array[StringName] = [&"ion_loop",&"blackhole_loop"]
var output := ""
var checks := 0
var errors: Array[String] = []
var records: Array[Dictionary] = []

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks+=1
	if not condition: errors.append(label)

func hash_bytes(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

func pcm_stats(raw: PackedByteArray) -> Dictionary:
	# Read actual source RIFF chunks. Imported resources may be QOA compressed;
	# don't mistake compressed byte magnitude for audible peak/RMS.
	var offset := 12
	var pcm := PackedByteArray()
	var valid_format := false
	while offset+8<=raw.size():
		var kind := raw.slice(offset,offset+4).get_string_from_ascii()
		var count := int(raw.decode_u32(offset+4))
		if count<0 or offset+8+count>raw.size(): return {"valid":false}
		if kind=="fmt " and count>=16:
			valid_format=raw.decode_u16(offset+8)==1 and raw.decode_u16(offset+10)==1 and raw.decode_u32(offset+12)==48000 and raw.decode_u16(offset+22)==16
		if kind=="data": pcm=raw.slice(offset+8,offset+8+count)
		offset+=8+count+(count%2)
	if not valid_format or pcm.size()<2 or pcm.size()%2!=0: return {"valid":false}
	var peak := 0
	var sum_squared := 0.0
	for i: int in range(0,pcm.size(),2):
		var value := int(pcm.decode_s16(i))
		peak=maxi(peak,absi(value))
		sum_squared+=float(value)*float(value)
	return {"valid":true,"frames":pcm.size()/2,"duration":float(pcm.size()/2)/48000.0,"peak":float(peak)/32767.0,"rms":sqrt(sum_squared/float(pcm.size()/2))/32767.0,"pcm_sha256":hash_bytes(pcm)}

func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):
		printerr("Fresh --output= path required")
		quit(1)
		return
	check(BANK.size()==EXPECTED.size(),"exact14 semantic categories")
	var distinct_primary: Dictionary = {}
	var distinct_paths: Dictionary = {}
	var loops_loaded := 0
	for cue: StringName in EXPECTED:
		check(BANK.has(cue),"bank category exists "+String(cue))
		if not BANK.has(cue): continue
		var clips: Array = BANK[cue]
		check(clips.size()==3,"three actual variants "+String(cue))
		for variant: int in clips.size():
			var stream := clips[variant] as AudioStreamWAV
			check(stream!=null,"actual imported AudioStreamWAV "+String(cue))
			if stream==null: continue
			var path := stream.resource_path
			check(not distinct_paths.has(path),"distinct resource path "+path)
			distinct_paths[path]=true
			var declared_duration := stream.get_length()
			check(is_finite(declared_duration) and declared_duration>=.03 and declared_duration<=2.0,"finite bounded duration "+path)
			check(stream.mix_rate==48000 and not stream.stereo,"actual48k mono imported stream "+path)
			check(stream.data.size()>0,"nonempty actual imported data "+path)
			var expected_mode := AudioStreamWAV.LOOP_FORWARD if cue in LOOPS else AudioStreamWAV.LOOP_DISABLED
			check(stream.loop_mode==expected_mode,"imported loop mode "+path)
			if stream.loop_mode==AudioStreamWAV.LOOP_FORWARD:
				loops_loaded+=1
				check(stream.loop_begin==0 and stream.loop_end>stream.loop_begin,"actual forward loop range "+path)
			var raw := FileAccess.get_file_as_bytes(path)
			var facts := pcm_stats(raw)
			check(bool(facts.valid),"actualsource PCM16 RIFF valid "+path)
			if not bool(facts.valid): continue
			check(float(facts.peak)>0 and float(facts.peak)<=.801,"actual source nonzero bounded peak "+path)
			check(float(facts.rms)>.0001,"actual source nonsilent RMS "+path)
			check(absf(float(facts.duration)-declared_duration)<=1.0/48000.0,"imported length matches real PCM source "+path)
			if variant==0: distinct_primary[facts.pcm_sha256]=true
			records.append({"cue":cue,"variant":variant,"path":path,"source_sha256":hash_bytes(raw),"actual_import_format":stream.format,"actual_import_bytes":stream.data.size(),"actual_import_length":declared_duration,"actual_import_loop_mode":stream.loop_mode,"actual_import_loop_begin":stream.loop_begin,"actual_import_loop_end":stream.loop_end,"source_pcm":facts})
	check(records.size()==42 and distinct_paths.size()==42,"all42 actual imported clips verified")
	check(loops_loaded==6,"exact6 actual imported infinite forward loops")
	check(distinct_primary.size()==14,"14 distinct category PCM textures,not duplicated samples")
	var report := {"status":"passed" if errors.is_empty() else "failed","checks":checks,"errors":errors,"records":records,"distinct_primary_pcm":distinct_primary.size(),"actual_forward_loops":loops_loaded,"scope":"Actual imported AudioStreamWAV bank and rawsource PCM checks only;does not claim naturalness,hearing/user/device acceptance or accepted-event voice lifecycle.","playback_scope":"No AudioStreamPlayer instantiated and no stream playback created;there are no playback weakrefs to drain."}
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	for error: String in errors: printerr(error)
	print("WEAPON AUDIO BANK V2: clips=",records.size()," checks=",checks," errors=",errors.size())
	quit(0 if errors.is_empty() else 1)
