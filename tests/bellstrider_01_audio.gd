extends SceneTree
## Isolated consumer contract test. Mock records calls; it does not prove sound
## quality or actual GameAudio saturation, which require root's engine fixture.
const Consumer := preload("res://game/presentation/audio/bellstrider_audio.gd")
class FakeHealth extends RefCounted:
	var epoch := 1
class FakeEncounter extends Node:
	signal presentation_event(data: Dictionary)
	var health := FakeHealth.new()
	var active := true
class FakeAudio extends Node:
	var calls: Array[Dictionary] = []
	var stops := 0
	func play_boss_cue(event: StringName, stream: AudioStream, origin: Node, priority: int = 90, attenuation: float = 7.0) -> bool:
		calls.append({"event":event,"stream":stream,"origin":origin,"priority":priority,"attenuation":attenuation})
		return true
	func play_enemy_material(kind: StringName, stream: AudioStream, origin: Node, species: StringName) -> bool:
		calls.append({"event":kind,"stream":stream,"origin":origin,"priority":45,"species":species})
		return true
	func stop_director_family(_owner_id: int, _family: StringName, _sustained: bool = false) -> void:
		stops += 1
	func stop_director_cues(_origin: Node = null, _sustained: bool = false) -> void:
		stops += 1
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred(&"_run")

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _emit(encounter: FakeEncounter, event: StringName, age: float, extra: Dictionary = {}) -> void:
	var row := {"event":event,"age":age,"phase":1,"group":1}
	row.merge(extra,true)
	encounter.presentation_event.emit(row)

func _run() -> void:
	var audio := FakeAudio.new()
	root.add_child(audio)
	audio.add_to_group(&"game_audio")
	var encounter := FakeEncounter.new()
	root.add_child(encounter)
	var consumer := Consumer.new()
	root.add_child(consumer)
	consumer.bind(encounter)
	_emit(encounter,&"bellstrider_roll_warn",1.0,{"combo":true,"index":0})
	_check(audio.calls.size()==1,"first planned return warns once")
	_check(audio.calls[-1].stream == Consumer.STREAMS[&"roll_warn_double"],"planned return doublebeat before first charge")
	_check(audio.calls[-1].origin == consumer and audio.calls[-1].priority==90,"warning origin and priority retained")
	for i: int in 6: _emit(encounter,&"bellstrider_bell_hit",1.01+i*.10)
	_check(audio.calls.size()==1 and consumer.suppressed_hits==6,"10Hz accepted hit chatter suppressed during warning")
	_emit(encounter,&"bellstrider_bell_hit",1.8)
	_emit(encounter,&"bellstrider_bell_hit",1.9)
	_check(audio.calls.size()==2 and audio.calls[-1].priority==45,"postwarning hit heard with material priority and bounded cadence")
	_emit(encounter,&"bellstrider_armour_hit",2.0)
	_check(audio.calls[-1].stream==Consumer.STREAMS[&"armour_hit"],"armour has distinct muffled stream")
	_emit(encounter,&"bellstrider_roll_warn",2.5,{"combo":true,"index":1})
	_check(audio.calls[-1].stream==Consumer.STREAMS[&"roll_warn"],"actual second charge uses single warning")
	var count := audio.calls.size()
	_emit(encounter,&"bellstrider_ring_strike",3.5,{"wave":1})
	_emit(encounter,&"bellstrider_ring_strike",3.5,{"wave":1})
	_emit(encounter,&"bellstrider_ring_strike",3.8,{"wave":2})
	_check(audio.calls.size()==count+2,"one cue per actual distinct wave; duplicate ignored")
	for name: StringName in [&"lob_aim",&"lob_lock",&"lob_release",&"lob_impact",&"phase",&"brake",&"turn"]:
		count=audio.calls.size()
		_emit(encounter,StringName("bellstrider_"+name),4.0+float(count))
		_check(audio.calls.size()==count+1 and audio.calls[-1].stream==Consumer.STREAMS[name],"distinct accepted cue "+name)
	count=audio.calls.size()
	paused=true
	_emit(encounter,&"bellstrider_ring_strike",20.0,{"wave":3})
	paused=false
	_check(audio.calls.size()==count,"paused events do not play or defer")
	var stops := audio.stops
	_emit(encounter,&"bellstrider_audio_cancel",21.0)
	_check(audio.stops==stops+1,"explicit attack cancel stops origin tails")
	_emit(encounter,&"bellstrider_roll_start",22.0)
	_check(audio.calls.size()==count+1,"attack cancellation permits future actual events")
	stops=audio.stops
	_emit(encounter,&"bellstrider_death",23.0)
	_check(audio.stops==stops+1,"death clears previous attack tails")
	count=audio.calls.size()
	_emit(encounter,&"bellstrider_roll_warn",23.01)
	_emit(encounter,&"bellstrider_bell_hit",23.1)
	_check(audio.calls.size()==count,"death suppresses obsolete attack/hit events")
	for name: StringName in [&"death_jam",&"death_impact",&"death_final"]:
		count=audio.calls.size()
		_emit(encounter,StringName("bellstrider_"+name),24.0+float(count))
		_check(audio.calls.size()==count+1 and audio.calls[-1].priority==80,"accepted death layer "+name)
	consumer.bind(encounter)
	count=audio.calls.size()
	encounter.health.epoch+=1
	_emit(encounter,&"bellstrider_roll_warn",40.0)
	_check(audio.calls.size()==count,"old health epoch is silent")
	consumer.bind(encounter)
	count=audio.calls.size()
	consumer.cancel()
	_emit(encounter,&"bellstrider_ring_strike",41.0)
	_check(audio.calls.size()==count,"cancelled consumer cannot replay events")
	consumer.bind(encounter)
	for i: int in 140: _emit(encounter,&"bellstrider_lob_release",50.0+i)
	_check(consumer.receipts.size()<=128 and consumer._seen.size()<=Consumer.RECEIPT_LIMIT,"receipt and dedup storage bounded")
	count=audio.calls.size()
	encounter.free()
	consumer.consume_event({"event":&"bellstrider_ring_strike","age":300.0})
	_check(audio.calls.size()==count,"encounter exit cancels consumer")
	consumer.free()
	audio.free()
	print("Bellstrider audio consumer: %s checks / %s failures" % [checks,failures])
	quit(1 if failures else 0)
