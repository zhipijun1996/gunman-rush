class_name PlayerWeaponFeelAudio
extends PlayerMotionAudio
## Same twelve voices as movement, UI and original weapon phase sounds.
const WEAPONS := preload("res://resources/player_presentation_01/weapon_sound_data.gd").CLIPS
var weapon_clips: Dictionary = WEAPONS
var weapon_events: Array[Dictionary] = []
var weapon_dropped := 0
var weapon_preemptions := 0
var _weapon_serial := 0

func weapon_cue(id: StringName, owner: int, event: String, attenuation := 12.0, sustained := false, weapon_id: StringName = &"") -> bool:
	if _shutting_down or get_tree().paused or volume<=0 or not weapon_clips.has(id): return false
	# Explicit weapon identity keeps blade/other modes from borrowing the
	# shuriken or pulse audition. Missing events retain the earlier bank route.
	var director_id := director_event_for_weapon_cue(id, weapon_id)
	if is_director_event_suppressed(director_id): return false
	if director_profile_for_event(director_id) != "original":
		return play_director_event(director_id, "", instance_from_id(owner) as Node)
	var selected: AudioStreamPlayer
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			selected=voice
			break
	if selected==null:
		for replaceable: StringName in [&"step",&"motion_land",&"motion_jump",&"weapon_contact"]:
			for voice: AudioStreamPlayer in _voices:
				if voice.get_meta("cue_id",&"")==replaceable:
					selected=voice
					break
			if selected!=null: break
		if selected!=null:
			selected.stop()
			weapon_preemptions+=1
	if selected==null:
		weapon_dropped+=1
		return false
	var variant := _weapon_serial%3
	_weapon_serial+=1
	selected.stream=weapon_clips[id][variant]
	selected.process_mode=Node.PROCESS_MODE_PAUSABLE
	selected.set_meta("cue_id",&"weapon_"+id)
	_clear_director_metadata(selected)
	selected.bus = &"SFX"
	selected.set_meta("audio_priority", 65)
	selected.set_meta("weapon_owner",owner)
	selected.set_meta("weapon_sustained",sustained)
	selected.set_meta("attenuation",attenuation)
	selected.volume_db=linear_to_db(volume)-attenuation
	selected.play()
	if selected.has_stream_playback(): _playbacks.append(weakref(selected.get_stream_playback()))
	played[&"weapon_"+id]=int(played.get(&"weapon_"+id,0))+1
	weapon_events.append({"id":id,"variant":variant,"event":event,"owner":owner,"tick":Engine.get_physics_frames()})
	if weapon_events.size()>256: weapon_events.pop_front()
	return true


func director_event_for_weapon_cue(id: StringName, weapon_id: StringName = &"") -> StringName:
	if id == &"pulse" and weapon_id == &"pulse_gun" and has_director_event(&"shot_pulse"): return &"shot_pulse"
	if id == &"blade" and weapon_id == &"shadow_shuriken" and has_director_event(&"shot_shuriken"): return &"shot_shuriken"
	if id == &"blast" and weapon_id == &"recoil_bomb" and has_director_event(&"bomb_explode"): return &"bomb_explode"
	return &"shot" if id == &"pulse" else &"enemy_hit" if id == &"hit" else &""

func stop_weapon(owner: int, sustained_only := false) -> void:
	stop_director_family(owner, &"weapon", sustained_only)
	for voice: AudioStreamPlayer in _voices:
		if int(voice.get_meta("weapon_owner",-1))!=owner or not str(voice.get_meta("cue_id","")).begins_with("weapon_"): continue
		if sustained_only and not bool(voice.get_meta("weapon_sustained",false)): continue
		voice.stop()
		voice.stream=null
