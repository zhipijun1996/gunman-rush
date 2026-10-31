extends SceneTree
## Controlled event/occupancy fixtures test the actual shared AudioStreamPlayers.
## These do not claim gameplay timing, natural fight or subjective listening.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
class EventOwner:
	extends WindkeeperEncounter
	func _ready() -> void:
		var health_definition := HealthDefinition.new()
		health_definition.resource_id = &"windkeeper_audio_fixture"
		health_definition.max_health = 60
		health_definition.initial_current = 60
		health.configure(health_definition)
		active = true
		set_physics_process(false)
# Controlled saved-state owner uses the actual Pressure serializer/type. Its
# physics/arena are deliberately absent: this tests audio resume admission,
# not physical landing or a natural terminal fight (covered by support App).
class PressureSnapshotOwner:
	extends WindkeeperPressureEncounter
	func _ready() -> void:
		var saved_health := HealthDefinition.new()
		saved_health.resource_id = &"windkeeper_audio_terminal_snapshot_fixture"
		saved_health.max_health = 60
		saved_health.initial_current = 0
		health.configure(saved_health)
		active = false
		mode = &"dead"
		set_physics_process(false)
var world: Node
var service: GameAudio
var owner: EventOwner
var audio: WindkeeperPressureAudio
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ", label)

func ticks(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func event(cue: StringName, age: float, extra: Dictionary = {}) -> void:
	var row := {"event": StringName("windkeeper_" + String(cue)), "age": age, "group": 1, "phase": 2}
	row.merge(extra, true)
	owner.presentation_event.emit(row)

func own_count() -> int:
	var count := 0
	for voice: AudioStreamPlayer in service._voices:
		if voice.playing and audio._owned_voice(voice):
			count += 1
	return count

func stop_all_fixture_voices() -> void:
	for voice: AudioStreamPlayer in service._voices:
		voice.stop()
		voice.stream = null
		service._clear_director_metadata(voice)

func terminal_snapshot_audio() -> void:
	var pressure := PressureSnapshotOwner.new()
	world.add_child(pressure)
	var cases: Array[Dictionary] = [
		{"name": "airborne fatal", "age": 0.0, "impact": false, "final": false, "airborne": true},
		{"name": "ground collapse before impact", "age": .4, "impact": false, "final": false, "airborne": false},
		{"name": "after saved impact", "age": 1.2, "impact": true, "final": false, "airborne": false},
		{"name": "settled corpse", "age": 1.9, "impact": true, "final": true, "airborne": false}
	]
	for fixture: Dictionary in cases:
		pressure._death_age = float(fixture.age)
		pressure._death_impact_sent = bool(fixture.impact)
		pressure._death_final_sent = bool(fixture.final)
		pressure._hop_active = bool(fixture.airborne)
		var saved: Dictionary = pressure.combat_snapshot().get("pressure", {})
		check(pressure.health.terminal and not pressure.active
			and bool(saved.death_impact_sent) == bool(fixture.impact)
			and bool(saved.death_final_sent) == bool(fixture.final)
			and bool(saved.support_motion.active) == bool(fixture.airborne),
			"actual Pressure snapshot retains declared terminal once/flight fixture: " + String(fixture.name))
		audio.bind(pressure, pressure, pressure.health.terminal)
		await ticks(4)
		check(audio._dying and audio._restored_terminal == bool(fixture.final),
			"terminal bind distinguishes unfinished collapse from settled corpse: " + String(fixture.name))
		pressure.presentation_event.emit({"event": &"windkeeper_death", "age": 200.0})
		pressure.presentation_event.emit({"event": &"windkeeper_seeds_release", "age": 200.1})
		check(audio.receipts.is_empty(), "saved terminal never replays initial jam or attack: " + String(fixture.name))
		pressure.presentation_event.emit({"event": &"windkeeper_death_impact", "age": 201.0})
		var impact_expected := not bool(fixture.impact) and not bool(fixture.final)
		check(audio.receipts.size() == (1 if impact_expected else 0)
			and (not impact_expected or bool(audio.receipts[-1].accepted)),
			"only previously un-emitted terminal impact is audible: " + String(fixture.name))
		var before := audio.receipts.size()
		pressure.presentation_event.emit({"event": &"windkeeper_death_impact", "age": 201.5})
		check(audio.receipts.size() == before, "resumed impact stays once despite a late distinct event: " + String(fixture.name))
		await ticks(4)
		pressure.presentation_event.emit({"event": &"windkeeper_death_final", "age": 202.0})
		var final_expected := not bool(fixture.final)
		check(audio.receipts.size() == before + (1 if final_expected else 0)
			and (not final_expected or bool(audio.receipts[-1].accepted)),
			"unfinished saved collapse retains final bell while corpse stays quiet: " + String(fixture.name))
		before = audio.receipts.size()
		pressure.presentation_event.emit({"event": &"windkeeper_death_final", "age": 203.0})
		check(audio.receipts.size() == before, "resumed final bell is not replayable: " + String(fixture.name))
		audio.stop_cues()
		check(own_count() == 0, "terminal resume origin releases all own shared voices: " + String(fixture.name))
	audio.cancel()
	pressure.free()

func run() -> void:
	world = Node.new()
	root.add_child(world)
	service = GameAudio.new()
	world.add_child(service)
	owner = EventOwner.new()
	world.add_child(owner)
	audio = WindkeeperPressureAudio.new()
	world.add_child(audio)
	audio.bind(owner, owner)
	await ticks(4)
	check(service._voices.size() == 12, "existing GameAudio pool retains twelve voices")
	check(audio.find_children("*", "AudioStreamPlayer", true, false).is_empty(), "Boss audio allocates no independent player")
	check(WindkeeperPressureAudio.STREAMS.size() == 32, "all distinct warning/release/terminal recorded-material cues exist")
	var sequence := 0
	for cue: StringName in WindkeeperPressureAudio.STREAMS:
		if cue == &"stomp_warning_double" or "_combo" in String(cue) or cue in WindkeeperPressureAudio.DEATH:
			continue
		audio.bind(owner, owner)
		await ticks(4)
		sequence += 1
		event(cue, float(sequence))
		check(audio.receipts.size() == 1 and bool(audio.receipts[0].accepted), "actual shared pool accepts " + String(cue))
		check(own_count() == 1, "exactly one real owned voice for " + String(cue))
		audio.stop_cues()
		check(own_count() == 0, "origin cleanup stops " + String(cue))
	audio.bind(owner, owner)
	await ticks(4)
	event(&"stomp_warning", 40, {"plan": {"double_stomp": true}, "attack_index": 0, "group_total": 2})
	check(audio.receipts.size() == 1 and audio.receipts[0].stream == &"stomp_warning_double", "frozen double-stomp plan chooses two-beat warning")
	var before := audio.receipts.size()
	event(&"stomp_warning", 40, {"plan": {"double_stomp": true}, "attack_index": 0, "group_total": 2})
	check(audio.receipts.size() == before and own_count() == 1, "duplicate accepted event cannot replay a warning")
	event(&"hit", 40.10)
	check(audio.suppressed_hits == 1 and audio.receipts.size() == before, "rapid hit reaction yields to actual warning interval")
	# Advance the actual shared-service clock as well as the disclosed event
	# timestamp; its unchanged armour throttle is 0.16 seconds.
	await ticks(36)
	event(&"hit", 40.60)
	check(audio.receipts.size() == before + 1 and bool(audio.receipts[-1].accepted), "hit feedback resumes after warning guard")
	event(&"hit", 40.65)
	check(audio.suppressed_hits == 2, "continuous hits are rate limited independently of attack state")
	await ticks(4)
	event(&"stomp_warning", 41, {"plan": {"double_stomp": true}, "attack_index": 1, "group_total": 2})
	check(audio.receipts[-1].stream == &"stomp_warning", "second stomp warning cannot repeat the group-start two-beat announcement")
	for warning: StringName in [&"stomp_warning", &"lunge_warning", &"sweep_warning", &"gust_warning", &"seeds_warning", &"platform_warning"]:
		for count: int in [2, 3]:
			audio.bind(owner, owner)
			await ticks(4)
			sequence += 1
			event(warning, 100.0 + sequence, {"attack_index": 0, "group_total": count})
			var expected := &"stomp_warning_double" if warning == &"stomp_warning" and count == 2 else StringName(String(warning) + "_combo%s" % count)
			check(audio.receipts.size() == 1 and audio.receipts[0].stream == expected and bool(audio.receipts[0].accepted), "frozen first-warning bell count for %s/%s" % [warning, count])
			check(own_count() == 1, "combo warning keeps one actual shared voice")
	before = audio.receipts.size()
	paused = true
	event(&"lunge_start", 41)
	check(audio.receipts.size() == before, "paused world never starts new Boss attack sound")
	paused = false
	event(&"audio_cancel", 42)
	check(own_count() == 0, "accepted cancel clears only Boss-owned cues")
	await ticks(4)
	# Occupancy fixture: fill the same twelve real players, not another pool.
	for index: int in service._voices.size():
		var voice := service._voices[index]
		voice.stream = WindkeeperPressureAudio.STREAMS[&"death_final"]
		voice.set_meta("audio_priority", 20)
		voice.set_meta("cue_id", &"step")
		voice.play()
	var protected := service._voices[0]
	protected.set_meta("cue_id", &"hurt")
	protected.set_meta("audio_priority", 90)
	audio.bind(owner, owner)
	event(&"sweep_warning", 50)
	check(audio.receipts.size() == 1 and bool(audio.receipts[0].accepted), "danger warning preempts low-priority full-pool occupancy")
	check(protected.playing and protected.get_meta("cue_id") == &"hurt", "Boss warning does not evict protagonist hurt")
	check(service._voices.size() == 12, "pool stress never grows voice count")
	stop_all_fixture_voices()
	await ticks(4)
	audio.bind(owner, owner)
	# Ownership stress fixture: four occupied Boss voices at higher priority.
	for index: int in 4:
		var voice := service._voices[index]
		voice.stream = WindkeeperPressureAudio.STREAMS[&"death_final"]
		voice.set_meta("director_family", WindkeeperPressureAudio.FAMILY)
		voice.set_meta("director_origin", weakref(owner))
		voice.set_meta("audio_priority", 80)
		voice.play()
	event(&"hit", 60)
	check(not bool(audio.receipts[-1].accepted) and own_count() == 4, "low-priority hit cannot exceed four owned voices")
	event(&"platform_warning", 60.2)
	check(bool(audio.receipts[-1].accepted) and own_count() <= 4, "critical warning replaces owned low-priority release at cap")
	audio.stop_cues()
	await ticks(4)
	audio.bind(owner, owner)
	event(&"lunge_warning", 70)
	owner.active = false
	event(&"death", 70.1)
	check(audio._dying and bool(audio.receipts[-1].accepted), "terminal event cancels attack sound and starts jam layer")
	before = audio.receipts.size()
	event(&"seeds_release", 70.2)
	check(audio.receipts.size() == before, "no attack layer can sound after terminal event")
	await ticks(4)
	event(&"death_impact", 71)
	check(bool(audio.receipts[-1].accepted), "actual terminal impact event has independent fall layer")
	await ticks(4)
	event(&"death_final", 72)
	check(bool(audio.receipts[-1].accepted), "final bells can finish after active combat stops")
	audio.bind(owner, owner, true)
	before = audio.receipts.size()
	event(&"death", 80)
	event(&"death_final", 82)
	check(audio.receipts.size() == before and own_count() == 0, "restored terminal corpse does not replay death layers")
	owner.active = true
	audio.bind(owner, owner)
	var replacement := HealthDefinition.new()
	replacement.resource_id = &"windkeeper_audio_epoch_fixture"
	replacement.max_health = 60
	replacement.initial_current = 60
	owner.health.configure(replacement)
	event(&"stomp_warning", 90)
	check(audio._cancelled and audio.receipts.is_empty(), "health epoch replacement rejects old sound owner")
	await terminal_snapshot_audio()
	check(await TEARDOWN.drain_world(world), "actual original shared audio backend releases")
	world.free()
	await ticks(2)
	print("WINDKEEPER_PRESSURE_AUDIO assertions=", assertions, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
