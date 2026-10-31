extends SceneTree
## Real Home consumer + deterministic transport/scheduler fixtures.
## Position/clock fixtures are explicit; this runner is not natural traversal media.
const TEARDOWN := preload("res://tests/audio_teardown.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	checks += 1
	if not value:
		failures.append(reason)
		push_error(reason)

func ticks(count: int = 3) -> void:
	for unused: int in count: await process_frame

func only_source_due(adapter: HomeAmbienceAudition, slot: String, delta: float = 23.0) -> void:
	# Deterministic scheduler fixture, not an elapsed gameplay-time claim.
	for row: Dictionary in adapter._sources: row.due = adapter._clock + delta if str(row.slot_id) == slot else adapter._clock + 100.0
	adapter._process(delta)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node.new()
	root.add_child(world)
	var audio := GameAudio.new()
	world.add_child(audio)
	var home := HomeScene.new()
	world.add_child(home)
	var adapter := HomeAmbienceAudition.new()
	world.add_child(adapter)
	await ticks(4)
	home.controller.active = false
	var phantom := Sprite2D.new()
	phantom.set_meta(&"home_function", "herbs")
	phantom.set_meta(&"home_root", Vector2(1770, HomeScene.FLOOR_Y))
	home.world.add_child(phantom)
	check(adapter.configure(home, audio), "Real Home configures via the existing audio component")
	check(audio._voices.size() == 12 and audio.ambience._beds.size() == 2 and audio.ambience._details.size() == 2, "No parallel player pool or extra voice allocation")
	var initial := adapter.snapshot()
	check(initial.source_anchors.size() == 4, "Only four actual active keepers are discovered; reserved fake herbs is excluded")
	var expected := {"character": "cloth", "upgrade": "wood", "arms": "tools", "achievements": "page"}
	for row: Dictionary in initial.source_anchors:
		check(expected.get(str(row.slot_id)) == row.family, "Actual keeper uses the correct Foley family")
		var foot := home.slot_world_foot(StringName(row.slot_id)) + Vector2(48, 0)
		check(Vector2(row.source_position[0], row.source_position[1]).is_equal_approx(home.world.to_global(foot)), "Source uses the actual NPC home_root rather than label or hardcoded world coordinates")
		check(float(row.due) >= 12.0 and float(row.due) <= 22.0, "Initial schedule preserves the normal sparse interval")
	check(audio.ambience.region == "home" and audio.ambience.profile == "A", "Home is an explicit audition, not formal rollout")
	check(audio.ambience._bank.home.A.path == HomeAmbienceAudition.BED_PATH and is_equal_approx(float(audio.ambience._bank.home.A.gain_db), -2.0), "User-selected quiet plains A is reused with only the authored extra two-dB runtime reduction")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HomeAmbienceAudition.MANIFEST_PATH))
	check(adapter.validate_manifest(valid), "Actual manifest identities are accepted")
	for bad_path: String in ["res://assets/audio/ambience_v1/home/missing.wav", "res://assets/audio/ambience_v1/home/../plains_a.ogg", HomeAmbienceAudition.BED_PATH]:
		var invalid := valid.duplicate(true)
		invalid.regions.home.profiles.A.details[0].path = bad_path
		check(not adapter.validate_manifest(invalid), "Unknown, traversal or wrong-role detail paths are refused")
	var duplicate := valid.duplicate(true)
	duplicate.regions.home.profiles.A.details[1] = duplicate.regions.home.profiles.A.details[0].duplicate(true)
	check(not adapter.validate_manifest(duplicate), "Duplicate detail identity cannot hide a missing take")
	var extra := valid.duplicate(true)
	extra.regions.home.profiles.A.details.append(extra.regions.home.profiles.A.details[0].duplicate(true))
	check(not adapter.validate_manifest(extra), "Additional detail rows are refused")
	var wrong_region := valid.duplicate(true)
	wrong_region.regions.other = wrong_region.regions.home.duplicate(true)
	check(not adapter.validate_manifest(wrong_region), "Additional dynamic region is refused")
	check(not adapter.set_mode("unknown") and adapter.snapshot().mode == "life", "Rejected mode preserves current audition")
	# Explicit position fixture isolates one real keeper within the true radius.
	home.player.global_position = home.world.to_global(home.slot_world_foot(&"character") + Vector2(48, -18))
	await ticks()
	only_source_due(adapter, "character")
	check(adapter.snapshot().events.size() == 1, "Due nearby actual keeper starts one sparse sound")
	var first: Dictionary = adapter.snapshot().events.back()
	check(first.event_id == "home_cloth_1" and first.path == HomeAmbienceAudition.DETAIL_PATHS.home_cloth_1, "Accepted first take records actual ID and path")
	check(first.slot == "character" and float(first.distance) < 240.0 and float(first.volume_db) < 0.0, "Recorded accepted source has real spatial attenuation")
	check(audio.ambience._details.filter(func(voice: AudioStreamPlayer) -> bool: return voice.playing).size() == 1, "Global life Foley concurrency is one despite two available detail players")
	only_source_due(adapter, "character")
	check(adapter.snapshot().events.size() == 1, "Busy sound is dropped rather than overlapped or queued")
	audio.ambience._stop_details()
	only_source_due(adapter, "character")
	check(adapter.snapshot().events.size() == 2 and adapter.snapshot().events.back().event_id == "home_cloth_2", "Successful family requests alternate real takes without consecutive repetition")
	check(audio.ambience._details.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "Same-frame panel/pause counterexample begins with an actual sounding life take")
	home.input_blocked = true
	paused = true
	adapter._process(0.0)
	check(audio.ambience._details.all(func(voice: AudioStreamPlayer) -> bool: return not voice.playing and voice.stream == null), "Same-frame Home block plus tree pause stops and releases existing life sound before pause can retain its tail")
	check(audio.ambience.candidate == "home_a", "Panel preserves the quiet environment bed")
	var blocked_count: int = adapter.snapshot().events.size()
	only_source_due(adapter, "character")
	check(adapter.snapshot().events.size() == blocked_count, "Blocked Home refuses new life sound")
	home.input_blocked = false
	paused = false
	adapter._process(0.0)
	await ticks()
	check(audio.ambience._details.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == null and not voice.playing), "Closing the paused panel cannot revive the old life tail")
	check(adapter.snapshot().events.size() == blocked_count and adapter._sources.all(func(row: Dictionary) -> bool: return float(row.due) > adapter._clock), "Closing panel reschedules sparse events instead of replaying a backlog")
	var beds_before_pause: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio.ambience._beds:
		if voice.stream != null: beds_before_pause.append(voice)
	var sounding_before_pause: bool = not beds_before_pause.is_empty() and beds_before_pause.all(func(voice: AudioStreamPlayer) -> bool: return voice.playing)
	var before_pause_snapshot: Dictionary = audio.ambience.snapshot()
	paused = true
	await ticks()
	var active_paused_beds: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in audio.ambience._beds:
		if voice.stream != null: active_paused_beds.append(voice)
	var pause_snapshot: Dictionary = audio.ambience.snapshot()
	print("AUDIO_HOME_PAUSE_SNAPSHOT ", JSON.stringify({"before": before_pause_snapshot, "paused": pause_snapshot}))
	check(sounding_before_pause and active_paused_beds.size() == beds_before_pause.size() and beds_before_pause.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream != null) and active_paused_beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream_paused), "Existing component pauses every previously sounding, still-assigned bed; idle stream-null slots are not playback: " + JSON.stringify(pause_snapshot))
	var paused_clock: float = adapter.snapshot().clock
	adapter._process(100.0)
	check(adapter.snapshot().clock == paused_clock, "Paused presentation time does not accumulate missed work")
	paused = false
	await ticks()
	check(adapter.snapshot().events.size() == blocked_count, "Pause resume cannot burst accumulated events")
	# A far/out-of-view NPC expires its request without admitting a source.
	home.player.global_position = Vector2(3000, HomeScene.FLOOR_Y - 18)
	await ticks()
	only_source_due(adapter, "character")
	check(adapter.snapshot().events.size() == blocked_count, "Distant real keeper request is discarded")
	check(adapter._sources.all(func(row: Dictionary) -> bool: return float(row.due) > adapter._clock), "Discarded requests do not wait for listener arrival")
	check(adapter.set_mode("bed"), "Bed-only mode is explicit")
	check(adapter.snapshot().mode == "bed" and audio.ambience.candidate == "home_a", "Bed-only keeps the selected bed")
	check(adapter.set_mode("original"), "Original mode is explicit")
	check(audio.ambience.candidate.is_empty(), "Original comparison clears all new ambience")
	check(adapter.set_mode("life"), "Life audition can restart")
	# Rebinding fixture: keep the original Home and old service alive throughout.
	home.player.global_position = home.world.to_global(home.slot_world_foot(&"character") + Vector2(48, -18))
	await ticks()
	only_source_due(adapter, "character")
	check(audio.ambience._beds.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing) and audio.ambience._details.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "Service-rebind counterexample begins with an actual old bed and life sound")
	var old_audio := audio
	var rejected_audio := GameAudio.new()
	world.add_child(rejected_audio)
	check(await rejected_audio.shutdown(), "Rejected proposal uses an actual closed service")
	check(not adapter.configure(home, rejected_audio), "A failed new service proposal is rejected")
	check(adapter._audio_node() == old_audio and old_audio.ambience._beds.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing) and old_audio.ambience._details.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "Failed service proposal leaves the old live audition intact")
	rejected_audio.free()
	var next_audio := GameAudio.new()
	world.add_child(next_audio)
	check(adapter.configure(home, next_audio), "A second actual live service can replace the old service")
	check(is_instance_valid(home) and home.is_inside_tree(), "Old Home remains alive during the service replacement")
	check(old_audio.ambience._beds.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == null and not voice.playing) and old_audio.ambience._details.all(func(voice: AudioStreamPlayer) -> bool: return voice.stream == null and not voice.playing), "Successful service replacement clears both old beds and old life sound")
	check(next_audio.ambience.candidate == "home_a" and next_audio.ambience._beds.any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "Replacement service owns the actual new bed")
	audio = next_audio
	home.controller.active = true
	home.controller.die()
	check(not home.controller.active and audio.ambience.candidate.is_empty() and adapter.snapshot().mode == "original", "Actual Controller.die disables the controller and clears bed and life even though PlayerMotor has no died signal")
	check(not adapter.set_mode("life"), "Dead context cannot silently restart")
	check(adapter.configure(home, audio, "bed"), "Fresh explicit configuration can establish a new session")
	world.remove_child(home)
	check(audio.ambience.candidate.is_empty(), "Real Home tree exit clears its sound immediately")
	home.free()
	check(await TEARDOWN.drain_world(world), "Real world audio backends release within original bounded teardown")
	world.free()
	await ticks(4)
	print("AUDIO_HOME_RUNTIME checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
