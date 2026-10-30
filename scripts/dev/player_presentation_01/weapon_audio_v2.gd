class_name PlayerWeaponFeelAudioV2
extends PlayerWeaponFeelAudio
## Licensed game samples plus CC0 recorded timer beep; same twelve voices/volume.
const TIMER_BEEP := preload("res://assets/player_presentation_01/mine_beep_v3/timer_beep.wav")
const WALL_FEEDBACK := [preload("res://assets/audio/feedback_05/wall_1.wav"), preload("res://assets/audio/feedback_05/wall_2.wav"), preload("res://assets/audio/feedback_05/wall_3.wav")]
var _last_wall := -100.0
func _ready() -> void:
	weapon_clips=preload("res://resources/player_presentation_01/weapon_sound_data_v2.gd").CLIPS.duplicate()
	weapon_clips[&"wall"] = WALL_FEEDBACK
	# A timer keeps one stable tone; only the actual entity age speeds its cadence.
	weapon_clips[&"mine_beep"]=[TIMER_BEEP,TIMER_BEEP,TIMER_BEEP]
	super._ready()

func weapon_cue(id: StringName, owner: int, event: String, attenuation := 12.0, sustained := false, weapon_id: StringName = &"") -> bool:
	if _shutting_down or get_tree().paused or volume<=0 or not weapon_clips.has(id): return false
	if id == &"wall":
		var wall_count := 0
		for voice: AudioStreamPlayer in _voices:
			if voice.playing and voice.get_meta("cue_id", &"") == &"weapon_wall": wall_count += 1
		if _director_clock - _last_wall < 0.06 or wall_count >= 2:
			weapon_dropped += 1
			return false
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
	var accepted := super.weapon_cue(id,owner,event,attenuation,sustained,weapon_id)
	if accepted and id == &"wall": _last_wall = _director_clock
	return accepted
