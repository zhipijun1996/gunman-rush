class_name WindkeeperPressureAudio
extends Node
## Only accepted encounter events. Uses GameAudio's existing twelve voices,
## including its pause/volume/AudioServer teardown. No extra player or timer.
@export var encounter: WindkeeperEncounter
const FAMILY := &"windkeeper_pressure"
const MAX_OWN_VOICES := 4
const RECEIPT_LIMIT := 128
const STREAMS := {
	&"stomp_warning": preload("res://assets/audio/windkeeper_pressure_01/stomp_warning.wav"),
	&"stomp_warning_double": preload("res://assets/audio/windkeeper_pressure_01/stomp_warning_double.wav"),
	&"lunge_warning": preload("res://assets/audio/windkeeper_pressure_01/lunge_warning.wav"),
	&"sweep_warning": preload("res://assets/audio/windkeeper_pressure_01/sweep_warning.wav"),
	&"gust_warning": preload("res://assets/audio/windkeeper_pressure_01/gust_warning.wav"),
	&"seeds_warning": preload("res://assets/audio/windkeeper_pressure_01/seeds_warning.wav"),
	&"platform_warning": preload("res://assets/audio/windkeeper_pressure_01/platform_warning.wav"),
	&"stomp_strike": preload("res://assets/audio/windkeeper_pressure_01/stomp_strike.wav"),
	&"lunge_start": preload("res://assets/audio/windkeeper_pressure_01/lunge_start.wav"),
	&"lunge_land": preload("res://assets/audio/windkeeper_pressure_01/lunge_land.wav"),
	&"sweep_release": preload("res://assets/audio/windkeeper_pressure_01/sweep_release.wav"),
	&"gust_release": preload("res://assets/audio/windkeeper_pressure_01/gust_release.wav"),
	&"seeds_release": preload("res://assets/audio/windkeeper_pressure_01/seeds_release.wav"),
	&"platform_impact": preload("res://assets/audio/windkeeper_pressure_01/platform_impact.wav"),
	&"link": preload("res://assets/audio/windkeeper_pressure_01/link.wav"),
	&"recover": preload("res://assets/audio/windkeeper_pressure_01/recover.wav"),
	&"phase": preload("res://assets/audio/windkeeper_pressure_01/phase.wav"),
	&"hit": preload("res://assets/audio/windkeeper_pressure_01/hit.wav"),
	&"death": preload("res://assets/audio/windkeeper_pressure_01/death.wav"),
	&"death_impact": preload("res://assets/audio/windkeeper_pressure_01/death_impact.wav"),
	&"death_final": preload("res://assets/audio/windkeeper_pressure_01/death_final.wav"),
	&"stomp_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/stomp_warning_combo3.wav"),
	&"lunge_warning_combo2": preload("res://assets/audio/windkeeper_pressure_01/lunge_warning_combo2.wav"),
	&"lunge_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/lunge_warning_combo3.wav"),
	&"sweep_warning_combo2": preload("res://assets/audio/windkeeper_pressure_01/sweep_warning_combo2.wav"),
	&"sweep_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/sweep_warning_combo3.wav"),
	&"gust_warning_combo2": preload("res://assets/audio/windkeeper_pressure_01/gust_warning_combo2.wav"),
	&"gust_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/gust_warning_combo3.wav"),
	&"seeds_warning_combo2": preload("res://assets/audio/windkeeper_pressure_01/seeds_warning_combo2.wav"),
	&"seeds_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/seeds_warning_combo3.wav"),
	&"platform_warning_combo2": preload("res://assets/audio/windkeeper_pressure_01/platform_warning_combo2.wav"),
	&"platform_warning_combo3": preload("res://assets/audio/windkeeper_pressure_01/platform_warning_combo3.wav")
}
const DEATH := [&"death", &"death_impact", &"death_final"]
var receipts: Array[Dictionary] = []
var suppressed_hits := 0
var dropped := 0
var _origin: Node
var _health: Object
var _health_epoch := -1
var _cancelled := true
var _dying := false
var _restored_terminal := false
var _resuming_terminal := false
var _resume_impact_pending := false
var _resume_final_pending := false
var _seen: Array[String] = []
var _last_hit := -100.0
var _critical_until := -100.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if is_instance_valid(encounter):
		bind(encounter, get_parent())


func bind(owner_encounter: WindkeeperEncounter, origin: Node = null, restored_terminal := false) -> void:
	cancel()
	_disconnect()
	encounter = owner_encounter
	_origin = origin if is_instance_valid(origin) else self
	_cancelled = not is_instance_valid(encounter)
	if _cancelled:
		return
	_dying = restored_terminal
	_restored_terminal = restored_terminal
	_resuming_terminal = false
	_resume_impact_pending = false
	_resume_final_pending = false
	if restored_terminal and encounter is WindkeeperPressureEncounter:
		# The health flag alone cannot distinguish a cold corpse from a saved
		# airborne/unfinished collapse. Read the actual persisted once flags.
		var saved: Dictionary = (encounter as WindkeeperPressureEncounter).combat_snapshot().get("pressure", {})
		if encounter.mode == &"dead" and not bool(saved.get("death_final_sent", true)):
			_restored_terminal = false
			_resuming_terminal = true
			_resume_impact_pending = not bool(saved.get("death_impact_sent", true))
			_resume_final_pending = true
	_seen.clear()
	receipts.clear()
	suppressed_hits = 0
	dropped = 0
	_last_hit = -100.0
	_critical_until = -100.0
	_health = encounter.health
	_health_epoch = int(_health.get("epoch"))
	encounter.presentation_event.connect(consume_event)
	encounter.tree_exiting.connect(cancel)
	set_process(true)


func _service() -> GameAudio:
	if not is_instance_valid(_origin) or not _origin.is_inside_tree():
		return null
	return _origin.get_tree().get_first_node_in_group(&"game_audio") as GameAudio


func _process(_delta: float) -> void:
	if _cancelled:
		return
	if not is_instance_valid(encounter) or not encounter.is_inside_tree() or not is_instance_valid(_origin) or not _origin.is_inside_tree():
		cancel()
	elif is_instance_valid(_health) and int(_health.get("epoch")) != _health_epoch:
		cancel()
	elif not _dying and not encounter.active:
		stop_cues()


func consume_event(data: Dictionary) -> void:
	if _cancelled or not is_inside_tree() or get_tree().paused:
		return
	if is_instance_valid(_health) and int(_health.get("epoch")) != _health_epoch:
		cancel()
		return
	var event := StringName(data.get("event", &""))
	if event == &"windkeeper_audio_cancel":
		stop_cues()
		return
	if _restored_terminal:
		return # Loading a corpse never replays even a late death-layer event.
	var cue := StringName(String(event).trim_prefix("windkeeper_"))
	if _resuming_terminal:
		# Initial jam already happened before the save. Resume only the layers
		# that the authoritative saved encounter has not emitted yet.
		if cue == &"death" or (cue == &"death_impact" and not _resume_impact_pending) or (cue == &"death_final" and not _resume_final_pending):
			return
	# State/group observation is not an additional sound trigger. Each actual
	# warning, foot contact and release has one accepted encounter event.
	if not STREAMS.has(cue) or "_combo" in String(cue) or cue == &"stomp_warning_double" or (_dying and cue not in DEATH):
		return
	if not is_instance_valid(encounter) or (not encounter.active and cue not in DEATH):
		return
	var clock := float(data.get("source_clock", data.get("age", -1.0)))
	if not is_finite(clock) or clock < 0.0:
		return
	var identity := "%s:%s:%s:%s:%s:%s:%s" % [event, clock, data.get("group", -1), data.get("attack_index", -1), data.get("foot", -1), data.get("wave", -1), data.get("event_id", "")]
	if identity in _seen:
		return
	_seen.append(identity)
	if _seen.size() > RECEIPT_LIMIT:
		_seen.pop_front()
	if _resuming_terminal:
		if cue == &"death_impact": _resume_impact_pending = false
		elif cue == &"death_final": _resume_final_pending = false
	if cue == &"death":
		_dying = true
		stop_cues()
	var warning := String(cue).ends_with("_warning") or cue == &"phase"
	if cue == &"hit":
		if clock < _critical_until or clock - _last_hit < .17:
			suppressed_hits += 1
			return
		_last_hit = clock
	var stream_id := cue
	var plan: Dictionary = data.get("plan", {})
	var attack_index := int(data.get("attack_index", 0))
	var group_total := int(data.get("group_total", 1))
	if warning and cue != &"phase" and attack_index == 0 and group_total in [2, 3]:
		stream_id = &"stomp_warning_double" if cue == &"stomp_warning" and group_total == 2 else StringName(String(cue) + "_combo%s" % group_total)
	elif cue == &"stomp_warning" and attack_index == 0 and bool(data.get("double_stomp", plan.get("double_stomp", false))):
		stream_id = &"stomp_warning_double"
	var priority := 95 if warning else 85 if cue in DEATH else 40 if cue == &"hit" else 55 if cue in [&"link", &"recover"] else 80
	if warning:
		_stop_reactions()
	var accepted := _play(cue, STREAMS[stream_id], priority, 6.5 if warning else 9.5 if cue == &"hit" else 8.0)
	if accepted and warning:
		_critical_until = maxf(_critical_until, clock + .54)
	receipts.append({"event": event, "stream": stream_id, "source_clock": clock, "priority": priority, "accepted": accepted, "phase": int(data.get("phase", 1)), "group": int(data.get("group", -1))})
	if receipts.size() > RECEIPT_LIMIT:
		receipts.pop_front()


func _owned_voice(voice: AudioStreamPlayer) -> bool:
	if voice.get_meta("director_family", &"") != FAMILY:
		return false
	var owner_ref: Variant = voice.get_meta("director_origin", null)
	return owner_ref is WeakRef and (owner_ref as WeakRef).get_ref() == _origin


func _stop_reactions() -> void:
	var audio := _service()
	if audio == null:
		return
	var voices: Array = audio.get("_voices")
	for voice: AudioStreamPlayer in voices:
		if _owned_voice(voice) and int(voice.get_meta("audio_priority", 100)) < 60:
			voice.stop()
			voice.stream = null
			audio._clear_director_metadata(voice)


func _play(cue: StringName, stream: AudioStream, priority: int, attenuation: float) -> bool:
	var audio := _service()
	if audio == null or audio.volume <= 0:
		dropped += 1
		return false
	var voices: Array = audio.get("_voices")
	var selected: AudioStreamPlayer
	var replaceable: AudioStreamPlayer
	var weakest := priority
	var own_count := 0
	for voice: AudioStreamPlayer in voices:
		if not voice.playing:
			if selected == null:
				selected = voice
			continue
		if _owned_voice(voice):
			own_count += 1
		# Never evict the protagonist's accepted hurt/death, even for a warning.
		if voice.get_meta("cue_id", &"") in [&"hurt", &"death"] and not _owned_voice(voice):
			continue
		var candidate_priority := int(voice.get_meta("audio_priority", 100))
		if candidate_priority < weakest:
			replaceable = voice
			weakest = candidate_priority
	if own_count >= MAX_OWN_VOICES:
		# Cap only this encounter; other consumer pools are never enlarged.
		replaceable = null
		weakest = priority
		for voice: AudioStreamPlayer in voices:
			if voice.playing and _owned_voice(voice) and int(voice.get_meta("audio_priority", 100)) < weakest:
				replaceable = voice
				weakest = int(voice.get_meta("audio_priority", 100))
		selected = null
	if selected == null and replaceable != null:
		replaceable.stop()
		replaceable.stream = null
		audio._clear_director_metadata(replaceable)
		# _play_original selects the first free slot, which may precede the one
		# freed here. Re-scan the real shared pool before tagging its owner.
		for voice: AudioStreamPlayer in voices:
			if not voice.playing:
				selected = voice
				break
	if selected == null:
		dropped += 1
		return false
	var legacy := &"warning" if String(cue).ends_with("_warning") or cue == &"phase" else &"boss_impact" if cue in [&"stomp_strike", &"lunge_land", &"platform_impact", &"death_impact"] else &"armour" if cue == &"hit" else &"death" if cue in DEATH else &"enemy_shot"
	if not audio._play_original(legacy, stream, false, _origin):
		dropped += 1
		return false
	selected.set_meta("director_event", StringName("windkeeper_" + String(cue)))
	selected.set_meta("director_origin", weakref(_origin))
	selected.set_meta("director_sustained", false)
	selected.set_meta("director_family", FAMILY)
	selected.set_meta("audio_priority", priority)
	selected.set_meta("attenuation", attenuation)
	selected.volume_db = linear_to_db(audio.volume) - attenuation
	return true


func stop_cues() -> void:
	var audio := _service()
	if audio != null and is_instance_valid(_origin):
		audio.stop_director_family(_origin.get_instance_id(), FAMILY, false)
	_critical_until = -100.0


func cancel() -> void:
	stop_cues()
	_cancelled = true
	set_process(false)


func _disconnect() -> void:
	if not is_instance_valid(encounter):
		return
	if encounter.presentation_event.is_connected(consume_event):
		encounter.presentation_event.disconnect(consume_event)
	if encounter.tree_exiting.is_connected(cancel):
		encounter.tree_exiting.disconnect(cancel)


func _exit_tree() -> void:
	cancel()
	_disconnect()
