extends "res://tests/player_presentation_01/weapon_feedback_v2.gd"
## Actual Home/Plains/reentry consumers,not only the unmodified old bank constant.
var bindings: Array[Dictionary] = []
var consumers: Array[String] = []

func run() -> void:
	node_added.connect(_observe_audio)
	await super.run()

func _observe_audio(node: Node) -> void:
	if node is PlayerWeaponFeelAudioV2: _audit_audio.call_deferred(node)
	# _attach_feel assigns audio before add_child; inspect immediately because
	# the existing lifecycle test can replace its Home leaf on the same tick.
	if node is PlayerWeaponFeelV2: _audit_consumer(node)

func _audit_consumer(feel: PlayerWeaponFeelV2) -> void:
	check(is_instance_valid(feel) and feel.audio==app.weapon_audio,"real presentation leaf shares persistent preview audio")
	if is_instance_valid(feel):
		check(feel.audio.weapon_clips[&"mine_beep"][0].resource_path=="res://assets/player_presentation_01/mine_beep_v3/timer_beep.wav","real Home/reentry/Plains leaf consumes new timer")
		consumers.append(str(feel.get_path()))

func _audit_audio(audio: PlayerWeaponFeelAudioV2) -> void:
	if not is_instance_valid(audio):
		check(false,"actual V2 audio survived until ready audit")
		return
	var clips: Array=audio.weapon_clips[&"mine_beep"]
	var old: Array=preload("res://resources/player_presentation_01/weapon_sound_data_v2.gd").CLIPS[&"mine_beep"]
	check(clips.size()==3,"actual V2 timer has three compatible selection slots")
	var paths: Array[String]=[]
	for i: int in clips.size():
		var stream := clips[i] as AudioStreamWAV
		check(stream!=null and stream.resource_path=="res://assets/player_presentation_01/mine_beep_v3/timer_beep.wav","actual ready consumer uses new CC0 timer")
		check(stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and absf(stream.get_length()-.085)<1.0/48000.0,"actual imported beep85ms one-shot")
		check(clips[i]==clips[0],"stable tone across parent serial selection slots")
		check(old[i].resource_path=="res://assets/player_presentation_01/weapon_audio_v2/mine_beep_%s.wav" % i,"original shared bank remains unchanged")
		paths.append(stream.resource_path)
	check(audio._voices.size()==12,"actual original twelve-voice budget retained")
	bindings.append({"owner":str(audio.get_path()),"paths":paths,"duration":clips[0].get_length(),"loop_mode":clips[0].loop_mode,"scope":"Actual post-ready V2 consumer;does not prove hearing/naturalness"})

func finish() -> void:
	check(bindings.size()==1 and consumers.size()>=3,"one persistent audio service across actual Home,reentry and Plains leaves")
	FileAccess.open(output+".bindings.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"bindings":bindings,"consumers":consumers},"\t"))
	await super.finish()
