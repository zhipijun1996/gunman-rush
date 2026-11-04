class_name BellstriderAudio
extends Node
## Accepted encounter events only. All voices belong to the existing GameAudio
## pool. No independent players, timers, random sources or gameplay writes.
const STREAMS := {
	&"armour_hit": preload("res://assets/audio/bellstrider_01/armour_hit.wav"),
	&"weak_hit": preload("res://assets/audio/bellstrider_01/weak_hit.wav"),
	&"roll_warn": preload("res://assets/audio/bellstrider_01/roll_warn.wav"),
	&"roll_warn_double": preload("res://assets/audio/bellstrider_01/roll_warn_double.wav"),
	&"roll_start": preload("res://assets/audio/bellstrider_01/roll_start.wav"),
	&"brake": preload("res://assets/audio/bellstrider_01/brake.wav"),
	&"turn": preload("res://assets/audio/bellstrider_01/turn.wav"),
	&"ring_strike": preload("res://assets/audio/bellstrider_01/ring_strike.wav"),
	&"lob_aim": preload("res://assets/audio/bellstrider_01/lob_aim.wav"),
	&"lob_lock": preload("res://assets/audio/bellstrider_01/lob_lock.wav"),
	&"lob_release": preload("res://assets/audio/bellstrider_01/lob_release.wav"),
	&"lob_impact": preload("res://assets/audio/bellstrider_01/lob_impact.wav"),
	&"phase": preload("res://assets/audio/bellstrider_01/phase.wav"),
	&"death": preload("res://assets/audio/bellstrider_01/death.wav"),
	&"death_jam": preload("res://assets/audio/bellstrider_01/death_jam.wav"),
	&"death_impact": preload("res://assets/audio/bellstrider_01/death_impact.wav"),
	&"death_final": preload("res://assets/audio/bellstrider_01/death_final.wav")
}
const CRITICAL := [&"roll_warn", &"ring_strike", &"lob_lock", &"phase"]
const DEATH := [&"death", &"death_jam", &"death_impact", &"death_final"]
const SPECIES := &"bellstrider"
# 10Hz weak-point streams retain sampled feedback without masking the warning.
const WEAK_INTERVAL := .17
const ARMOUR_INTERVAL := .14
const RECEIPT_LIMIT := 96
var receipts: Array[Dictionary] = []
var suppressed_hits := 0
var _encounter: Node
var _origin: Node
var _health: Object
var _health_epoch := -1
var _cancelled := true
var _dying := false
var _seen: Array[String] = []
var _last_weak := -100.0
var _last_armour := -100.0
var _critical_until := -100.0

func bind(encounter: Node, origin: Node = null, restored_terminal := false) -> void:
	cancel()
	_disconnect()
	_encounter = encounter
	_origin = origin if is_instance_valid(origin) else self
	_cancelled = not is_instance_valid(_encounter) or not _encounter.has_signal(&"presentation_event")
	if _cancelled: return
	_dying = restored_terminal
	_seen.clear()
	_last_weak = -100.0
	_last_armour = -100.0
	_critical_until = -100.0
	receipts.clear()
	suppressed_hits = 0
	_health = _encounter.get("health") as Object
	_health_epoch = int(_health.get("epoch")) if is_instance_valid(_health) else -1
	_encounter.connect(&"presentation_event",consume_event)
	_encounter.tree_exiting.connect(cancel)
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_process(true)

func _service() -> Node:
	if not is_instance_valid(_origin) or not _origin.is_inside_tree(): return null
	return _origin.get_tree().get_first_node_in_group(&"game_audio")

func _process(_delta: float) -> void:
	# Lifetime checks only; attack, hit and death sounds never poll a mode.
	if _cancelled: return
	if not is_instance_valid(_encounter) or not _encounter.is_inside_tree() or not is_instance_valid(_origin) or not _origin.is_inside_tree():
		cancel()
	elif is_instance_valid(_health) and int(_health.get("epoch")) != _health_epoch:
		cancel()
	elif not _dying and not bool(_encounter.get("active")):
		stop_cues()

func consume_event(data: Dictionary) -> void:
	if _cancelled or not is_inside_tree() or get_tree().paused: return
	if is_instance_valid(_health) and int(_health.get("epoch")) != _health_epoch:
		cancel()
		return
	var event := StringName(data.get("event", &""))
	if event == &"bellstrider_audio_cancel":
		stop_cues()
		return
	var name := String(event).trim_prefix("bellstrider_")
	if name == "bell_hit": name = "weak_hit"
	if name == "armor_hit": name = "armour_hit"
	var cue := StringName(name)
	if not STREAMS.has(cue) or (_dying and cue not in DEATH): return
	# These are actual committed event clock values, not wall time or a
	# presentation oscillator. Distinct waves/volleys keep their own receipt.
	var clock := float(data.get("source_clock", data.get("age", -1.0)))
	if not is_finite(clock) or clock < 0.0: return
	var identity := "%s:%s:%s:%s:%s:%s" % [event,clock,data.get("group",-1),data.get("wave",-1),data.get("volley",-1),data.get("event_id","")]
	if identity in _seen: return
	_seen.append(identity)
	if _seen.size() > RECEIPT_LIMIT: _seen.pop_front()
	if cue == &"death":
		_dying = true
		stop_cues()
	if cue in [&"weak_hit", &"armour_hit"]:
		var last := _last_weak if cue == &"weak_hit" else _last_armour
		var interval := WEAK_INTERVAL if cue == &"weak_hit" else ARMOUR_INTERVAL
		if clock < _critical_until or clock-last < interval:
			suppressed_hits += 1
			return
		if cue == &"weak_hit": _last_weak = clock
		else: _last_armour = clock
	var stream_id := &"roll_warn_double" if cue == &"roll_warn" and bool(data.get("combo",false)) and int(data.get("index",0)) == 0 else cue
	var audio := _service()
	if audio == null: return
	var accepted := false
	var priority := 90 if cue in CRITICAL else 80 if cue in DEATH else 65 if cue in [&"lob_impact", &"roll_start", &"brake", &"turn"] else 60
	if cue in [&"weak_hit", &"armour_hit"]:
		if audio.has_method(&"play_enemy_material"):
			accepted = bool(audio.call(&"play_enemy_material",&"hurt",STREAMS[stream_id],_origin,SPECIES))
	else:
		if cue in CRITICAL:
			# Finish low-priority reactions before a charge/lock/strike is heard.
			if audio.has_method(&"stop_director_family"):
				audio.call(&"stop_director_family",_origin.get_instance_id(),&"enemy_material")
		if audio.has_method(&"play_boss_cue"):
			accepted = bool(audio.call(&"play_boss_cue",event,STREAMS[stream_id],_origin,priority,7.0 if cue in CRITICAL else 8.0))
	if accepted and cue in CRITICAL:
		_critical_until = maxf(_critical_until,clock+(.70 if cue == &"roll_warn" else .30 if cue == &"lob_lock" else .36))
	receipts.append({"event":event,"stream":stream_id,"source_clock":clock,"phase":int(data.get("phase",1)),"combo":bool(data.get("combo",false)),"priority":priority if cue not in [&"weak_hit", &"armour_hit"] else 45,"accepted":accepted})
	if receipts.size() > 128: receipts.pop_front()

func stop_cues() -> void:
	var audio := _service()
	if audio != null and audio.has_method(&"stop_director_cues"):
		audio.call(&"stop_director_cues",_origin,false)
	_critical_until = -100.0

func cancel() -> void:
	stop_cues()
	_cancelled = true
	set_process(false)

func _disconnect() -> void:
	if not is_instance_valid(_encounter): return
	if _encounter.is_connected(&"presentation_event",consume_event): _encounter.disconnect(&"presentation_event",consume_event)
	if _encounter.tree_exiting.is_connected(cancel): _encounter.tree_exiting.disconnect(cancel)

func _exit_tree() -> void:
	cancel()
	_disconnect()
