class_name PlayerWeaponFeelAudioV2
extends PlayerWeaponFeelAudio
## Actual licensed game samples; original twelve voices and user volume remain.
func _ready() -> void:
	weapon_clips=preload("res://resources/player_presentation_01/weapon_sound_data_v2.gd").CLIPS
	super._ready()

func weapon_cue(id: StringName, owner: int, event: String, attenuation := 12.0, sustained := false) -> bool:
	if _shutting_down or get_tree().paused or volume<=0 or not weapon_clips.has(id): return false
	# Reserve four slots for original hurt/death/warning/UI consumers.
	var own_count := 0
	for voice: AudioStreamPlayer in _voices:
		if voice.playing and str(voice.get_meta("cue_id","")).begins_with("weapon_"): own_count+=1
	if own_count>=8:
		var replacement: AudioStreamPlayer
		for low: StringName in [&"weapon_wall",&"weapon_mine_beep",&"weapon_machine",&"weapon_pulse",&"weapon_blade"]:
			for voice: AudioStreamPlayer in _voices:
				if voice.playing and voice.get_meta("cue_id",&"")==low:
					replacement=voice
					break
			if replacement!=null: break
		if replacement==null:
			weapon_dropped+=1
			return false
		replacement.stop()
		replacement.stream=null
		weapon_preemptions+=1
	return super.weapon_cue(id,owner,event,attenuation,sustained)
