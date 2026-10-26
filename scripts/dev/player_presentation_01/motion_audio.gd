class_name PlayerMotionAudio
extends GameAudio
## Task app service subclass. All cues share the ORIGINAL twelve-voice pool.
## Other GameAudio methods/cues/volume/mute/pause/shutdown remain inherited.
const MOTION := {
	&"jump":[preload("res://assets/player_presentation_01/feel_audio_v1/jump_0.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/jump_1.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/jump_2.wav")],
	&"land":[preload("res://assets/player_presentation_01/feel_audio_v1/land_0.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/land_1.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/land_2.wav")],
	&"heavy":[preload("res://assets/player_presentation_01/feel_audio_v1/heavy_0.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/heavy_1.wav"),preload("res://assets/player_presentation_01/feel_audio_v1/heavy_2.wav")],
}
var motion_events: Array[Dictionary] = []
var _serial: Dictionary = {}
var motion_preemptions := 0
var motion_dropped := 0

func motion_cue(id: StringName, strength: float, owner_id: int) -> bool:
	if _shutting_down or get_tree().paused or volume <= 0 or not MOTION.has(id): return false
	var director_id := &"land" if id == &"heavy" else id
	if audio_profile != "original" and has_director_event(director_id):
		return play_director_event(director_id, "", instance_from_id(owner_id) as Node)
	var selected: AudioStreamPlayer
	for voice: AudioStreamPlayer in _voices:
		if voice.playing: continue
		selected = voice
		break
	if selected == null:
		# Preserve critical hurt/death/warnings/shots; footsteps cannot swallow a
		# confirmed landing when the unchanged pool is full.
		for replaceable: StringName in [&"step",&"motion_jump",&"motion_land",&"jump",&"land"]:
			for voice: AudioStreamPlayer in _voices:
				if voice.get_meta("cue_id",&"") == replaceable:
					selected = voice
					break
			if selected != null: break
		if selected != null:
			selected.stop()
			motion_preemptions += 1
	if selected == null:
		motion_dropped += 1
		return false
	var voice := selected
	var index := int(_serial.get(id,0)) % 3
	_serial[id] = index + 1
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	voice.set_meta("cue_id",&"motion_" + id)
	_clear_director_metadata(voice)
	voice.bus = &"SFX"
	voice.set_meta("audio_priority", 50)
	voice.set_meta("motion_owner",owner_id)
	voice.stream = MOTION[id][index]
	var attenuation := 12.0 if id == &"jump" else lerpf(16,11,clampf(strength,0,1)) if id == &"land" else 9.0
	voice.set_meta("attenuation",attenuation)
	voice.volume_db = linear_to_db(volume) - attenuation
	voice.play()
	if voice.has_stream_playback(): _playbacks.append(weakref(voice.get_stream_playback()))
	played[&"motion_"+id] = int(played.get(&"motion_"+id,0))+1
	motion_events.append({"id":id,"variant":index,"strength":strength,"owner":owner_id,"tick":Engine.get_physics_frames()})
	if motion_events.size()>128: motion_events.pop_front()
	return true

func stop_motion(owner_id: int) -> void:
	stop_director_family(owner_id, &"motion")
	for voice: AudioStreamPlayer in _voices:
		if int(voice.get_meta("motion_owner",-1)) == owner_id and str(voice.get_meta("cue_id","")).begins_with("motion_"):
			voice.stop()
			voice.stream = null
