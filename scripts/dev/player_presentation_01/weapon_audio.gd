class_name PlayerWeaponFeelAudio
extends PlayerMotionAudio
## Same twelve voices as movement, UI and original weapon phase sounds.
const WEAPONS := preload("res://resources/player_presentation_01/weapon_sound_data.gd").CLIPS
var weapon_events: Array[Dictionary] = []
var weapon_dropped := 0
var weapon_preemptions := 0
var _weapon_serial := 0

func weapon_cue(id: StringName, owner: int, event: String, attenuation := 12.0, sustained := false) -> bool:
	if _shutting_down or get_tree().paused or volume<=0 or not WEAPONS.has(id): return false
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
	selected.stream=WEAPONS[id][variant]
	selected.process_mode=Node.PROCESS_MODE_PAUSABLE
	selected.set_meta("cue_id",&"weapon_"+id)
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

func stop_weapon(owner: int, sustained_only := false) -> void:
	for voice: AudioStreamPlayer in _voices:
		if int(voice.get_meta("weapon_owner",-1))!=owner or not str(voice.get_meta("cue_id","")).begins_with("weapon_"): continue
		if sustained_only and not bool(voice.get_meta("weapon_sustained",false)): continue
		voice.stop()
		voice.stream=null
