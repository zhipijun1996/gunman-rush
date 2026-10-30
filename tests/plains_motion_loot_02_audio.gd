extends RefCounted
## Isolated real-pool and accepted-Damageable fixtures, not listening or Router
## combat evidence. Each case owns a real GameAudio and drains its backend.

static func run(tree: SceneTree) -> Dictionary:
	var report := {"assertions":0,"failures":[],"checks":[],"samples":[],"scope":"Actual12voice pool/caps/preemption, accepted Actor hurt/death and restored/unloaded owner lifecycle; explicit isolated fixtures, not normal-speed listening or natural combat"}
	await _pool_caps(tree, report)
	await _critical_pool(tree, report)
	await _actor_lifecycle(tree, report)
	return report

static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.assertions += 1
	report.checks.append({"label":label,"passed":ok})
	if not ok:
		report.failures.append(label)
		printerr("FAIL: ", label)

static func _frames(tree: SceneTree, count: int) -> void:
	for _i: int in count: await tree.physics_frame

static func _voices(audio: GameAudio) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer: result.append(child as AudioStreamPlayer)
	return result

static func _active(audio: GameAudio, event: StringName = &"") -> int:
	var count := 0
	for voice: AudioStreamPlayer in _voices(audio):
		if voice.playing and (event.is_empty() or voice.get_meta("director_event", &"") == event): count += 1
	return count

static func _owned(audio: GameAudio, origin: Node, event: StringName = &"") -> int:
	var count := 0
	for voice: AudioStreamPlayer in _voices(audio):
		if not voice.playing or not voice.has_meta("director_origin"): continue
		var ref: Variant = voice.get_meta("director_origin")
		if ref is WeakRef and (ref as WeakRef).get_ref() == origin and (event.is_empty() or voice.get_meta("director_event", &"") == event): count += 1
	return count

static func _orphaned(audio: GameAudio) -> int:
	var count := 0
	for voice: AudioStreamPlayer in _voices(audio):
		if not voice.playing or not voice.has_meta("director_origin"): continue
		var ref: Variant = voice.get_meta("director_origin")
		var owner: Node = (ref as WeakRef).get_ref() as Node if ref is WeakRef else null
		if not is_instance_valid(owner) or not owner.is_inside_tree(): count += 1
	return count

static func _fixture(tree: SceneTree, name: String) -> Dictionary:
	var world := Node2D.new()
	world.name = name
	var audio := GameAudio.new()
	world.add_child(audio)
	tree.root.add_child(world)
	return {"world":world,"audio":audio}

static func _close(tree: SceneTree, world: Node2D, report: Dictionary, label: String) -> void:
	var reference: WeakRef = weakref(world)
	var audio_refs: Array[WeakRef] = []
	for audio: GameAudio in tree.get_nodes_in_group(&"game_audio"):
		if world.is_ancestor_of(audio): audio_refs.append(weakref(audio))
	var drain: bool = await load("res://tests/audio_teardown.gd").drain_world(world)
	_check(report, drain, label + " actual audio backend releases within original1000ms teardown bound")
	world.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(report, reference.get_ref() == null and audio_refs.all(func(ref: WeakRef) -> bool: return ref.get_ref() == null), label + " world/service nodes released without a retained owner")

static func _pool_caps(tree: SceneTree, report: Dictionary) -> void:
	var fixture := _fixture(tree, "PlainsAudioCapsFixture")
	var world: Node2D = fixture.world
	var audio: GameAudio = fixture.audio
	await _frames(tree, 1)
	_check(report, tree.get_nodes_in_group(&"game_audio").size() == 1, "caps fixture owns the sole actual GameAudio service")
	_check(report, _voices(audio).size() == 12, "actual service constructs exactly12 shared voices")
	var detached := Node2D.new()
	var stream: AudioStream = PlainsEnemyAudio.STREAMS[&"shell_death"]
	_check(report, not audio.play_enemy_material(&"death", stream, detached, &"plains_charger"), "detached owner cannot start a material voice")
	detached.free()
	var owner := Node2D.new()
	world.add_child(owner)
	_check(report, audio.play_enemy_material(&"death", stream, owner, &"plains_charger") and _owned(audio, owner) == 1, "real attached owner starts exactly one shared material voice")
	var event_count := audio.material_events.size()
	var owner_ref: WeakRef = weakref(owner)
	owner.queue_free()
	await tree.process_frame
	await tree.process_frame
	_check(report, owner_ref.get_ref() == null and _orphaned(audio) == 0 and _active(audio) == 0, "weak-owner cleanup stops live voice after actual owner leaves tree")
	_check(report, audio.material_events.size() == event_count, "owner cleanup does not create a new audio event")
	var origins: Array[Node2D] = []
	for i: int in 8:
		var origin := Node2D.new()
		origin.name = "BurstOrigin%s" % i
		world.add_child(origin)
		origins.append(origin)
	var accepted := {}
	for kind: StringName in [&"hurt", &"death", &"land"]:
		var count := 0
		var event := StringName("plains_enemy_" + String(kind))
		var cap := 3 if kind in [&"hurt", &"death"] else 2
		for origin: Node2D in origins:
			if audio.play_enemy_material(kind, stream, origin, &"plains_charger"): count += 1
			_check(report, _active(audio, event) <= cap and _active(audio) <= 12 and _voices(audio).size() == 12, "same-frame%s burst retains material cap%s and global12" % [kind,cap])
		accepted[String(kind)] = count
		_check(report, _active(audio, event) == cap, "same-frame%s burst reaches declared cap without extra nodes" % kind)
	_check(report, accepted.hurt == 3 and accepted.death == 8 and accepted.land == 2, "excess light/contact cues refuse while rapid deaths replace bounded tails")
	var before_pause := audio.material_events.size()
	var paused_before := tree.paused
	tree.paused = true
	var paused_refused := not audio.play_enemy_material(&"death", stream, origins[0], &"plains_charger")
	tree.paused = paused_before
	_check(report, paused_refused and audio.material_events.size() == before_pause, "paused world rejects new material playback without a delayed event")
	report.samples.append({"case":"same_frame_pool_caps","voices":_voices(audio).size(),"hurt":_active(audio,&"plains_enemy_hurt"),"death":_active(audio,&"plains_enemy_death"),"land":_active(audio,&"plains_enemy_land"),"accepted":accepted,"dropped":audio.material_dropped,"preemptions":audio.material_preemptions})
	await _close(tree,world,report,"caps")

static func _critical_snapshot(audio: GameAudio) -> Dictionary:
	var snapshot := {}
	for voice: AudioStreamPlayer in _voices(audio):
		if voice.playing and int(voice.get_meta("audio_priority",0)) == 90:
			snapshot[str(voice.get_instance_id())] = String(voice.get_meta("cue_id",&""))
	return snapshot

static func _critical_pool(tree: SceneTree, report: Dictionary) -> void:
	var fixture := _fixture(tree, "PlainsAudioCriticalFixture")
	var world: Node2D = fixture.world
	var audio: GameAudio = fixture.audio
	await _frames(tree, 1)
	var stream: AudioStream = PlainsEnemyAudio.STREAMS[&"shell_death"]
	# Explicit pool-load fixture: each ordinary cue uses the same real recorded
	# .39s stream through its supported override, so requests share one frame.
	for id: StringName in [&"hurt",&"death",&"warning",&"enemy_defeat",&"boss_impact"]:
		_check(report, audio.play(id,stream), "actual legacy critical cue fills real priority90 voice: " + String(id))
	for id: StringName in [&"coin",&"note",&"door",&"roar",&"core",&"armour"]:
		_check(report, audio.play(id,stream), "actual legacy ordinary cue fills real priority50 voice: " + String(id))
	var origin := Node2D.new()
	world.add_child(origin)
	_check(report, audio.play_enemy_material(&"hurt",stream,origin,&"plains_charger"), "one actual material hurt completes full12-voice load")
	var critical := _critical_snapshot(audio)
	_check(report, critical.size() == 5 and _active(audio) == 12 and _active(audio,&"plains_enemy_hurt") == 1, "preemption fixture contains five real critical, six ordinary and one hurt voice")
	var before := audio.material_preemptions
	_check(report, audio.play_enemy_material(&"death",stream,origin,&"plains_charger"), "full pool accepts material death by preemption")
	_check(report, audio.material_preemptions == before + 1 and _active(audio,&"plains_enemy_hurt") == 0 and _active(audio,&"plains_enemy_death") == 1, "death specifically preempts the lower-priority hurt before normal/critical voices")
	_check(report, _critical_snapshot(audio) == critical, "material death preserves every actual critical90 voice identity and cue")
	_check(report, not audio.play_enemy_material(&"hurt",stream,origin,&"plains_charger") and not audio.play_enemy_material(&"land",stream,origin,&"plains_charger"), "light hurt and contact cannot preempt a full protected/death pool")
	for i: int in 12:
		_check(report, audio.play_enemy_material(&"death",stream,origin,&"plains_charger") and _active(audio,&"plains_enemy_death") <= 3 and _active(audio) == 12 and _critical_snapshot(audio) == critical, "rapid kill%s retains death3/global12 and every critical90 voice" % i)
	report.samples.append({"case":"critical_pool_preemption","critical":critical,"after":_critical_snapshot(audio),"voices":_voices(audio).size(),"death":_active(audio,&"plains_enemy_death"),"preemptions":audio.material_preemptions})
	await _close(tree,world,report,"critical")

static func _damage(actor: EnemyActor, id: String, amount: float) -> Dictionary:
	return {"event_id":id,"amount":amount,"source_actor_id":987654321,"source_faction":&"player","target_actor_id":actor.damageable.actor_id,"target_epoch":actor.health.epoch,"hit_direction":Vector2.RIGHT,"hit_point":actor.motor.global_position}

static func _event_count(audio: GameAudio, event: String) -> int:
	var count := 0
	for row: Dictionary in audio.material_events:
		if row.event == event: count += 1
	return count

static func _actor_lifecycle(tree: SceneTree, report: Dictionary) -> void:
	var fixture := _fixture(tree, "PlainsAudioActorFixture")
	var world: Node2D = fixture.world
	var audio: GameAudio = fixture.audio
	var support := StaticBody2D.new()
	support.position = Vector2(0,100)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(800,40)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	support.add_child(collision)
	world.add_child(support)
	var motor := EnemyFactory.create_for_behavior(&"charger",{&"patrol_speed":0.0,&"patrol_half_width":0.0})
	_check(report,motor != null,"actual factory creates charger for accepted-audio lifecycle fixture")
	if motor == null:
		await _close(tree,world,report,"actor failure")
		return
	motor.position = Vector2(0,66)
	world.add_child(motor)
	await _frames(tree,3)
	var actor := motor.get_node("Actor") as EnemyActor
	var presentation: Node = motor.get_node("Presentation")
	var remains := presentation.get("feedback_remains") as EnemyFeedback01Remains
	_check(report,remains != null,"actual presentation exposes its stage-owned corpse consumer")
	var initial := actor.health.current
	_check(report,actor.damageable.receive_damage(_damage(actor,"audio-accepted-hurt",1.0)) and actor.health.current == initial - 1.0,"actual Damageable commits nonfatal HP loss before hurt audio")
	_check(report,_event_count(audio,"plains_enemy_hurt") == 1 and _event_count(audio,"plains_enemy_death") == 0,"accepted ordinary hit plays only one short material hurt")
	var hurt_before := _event_count(audio,"plains_enemy_hurt")
	var lethal := _damage(actor,"audio-accepted-lethal",actor.health.current)
	_check(report,actor.damageable.receive_damage(lethal) and actor.health.terminal,"actual Damageable commits lethal HP result")
	_check(report,_event_count(audio,"plains_enemy_death") == 1 and _event_count(audio,"plains_enemy_hurt") == hurt_before and _owned(audio,actor,&"plains_enemy_hurt") == 0,"lethal accepted Actor event adds distinct death and stops own hurt without another full hurt")
	var death_events := audio.material_events.size()
	_check(report,not actor.damageable.receive_damage(lethal),"terminal actor rejects actual lethal receipt replay")
	PlainsEnemyAudio.defeated(actor)
	_check(report,audio.material_events.size() == death_events,"duplicate visual death request cannot replay accepted death sound")
	_check(report,actor.restore_instance_health(0.0),"actual saved-dead initialization accepted without forged damage")
	await _frames(tree,4)
	_check(report,audio.material_events.size() == death_events,"saved-dead reconciliation plays neither new death nor landing audio")
	_check(report,actor.restore_instance_health(actor.definition.health_definition.max_health),"actual restore-live starts a new health epoch")
	await _frames(tree,3)
	_check(report,actor.damageable.receive_damage(_damage(actor,"audio-new-epoch-lethal",actor.health.current)),"new epoch accepts a new genuine lethal Damageable commit")
	var contact_before := _event_count(audio,"plains_enemy_land")
	await _frames(tree,100)
	_check(report,remains != null and remains.active and remains.settled and not remains.restored,"real accepted corpse settles on explicit actual support")
	_check(report,_event_count(audio,"plains_enemy_land") == contact_before + 1,"actual body landing generates exactly one material contact voice")
	await _frames(tree,12)
	_check(report,_event_count(audio,"plains_enemy_land") == contact_before + 1,"resting corpse never loops its landing sound")
	var release_observation: Dictionary = {}
	if remains != null:
		# Explicit active-tail lifecycle fixture. The natural short contact may
		# already have ended on a slower backend; reopen only this owned tail
		# through the public pool API before disposing the same real remains.
		GameAudio.stop_origin(remains,false)
		var stream: AudioStream = PlainsEnemyAudio.STREAMS[&"shell_land"]
		_check(report,audio.play_enemy_material(&"land",stream,remains,&"plains_charger") and _owned(audio,remains) == 1,"real stage-owned remains has an observable active contact tail before disposal")
		var before_dispose := audio.material_events.size()
		var remains_ref: WeakRef = weakref(remains)
		remains.dispose()
		_check(report,_owned(audio,remains) == 0 and audio.material_events.size() == before_dispose,"disposing still-in-tree remains stops only its owned contact tail without replay")
		_check(report,is_instance_valid(remains) and remains.is_queued_for_deletion(),"existing disposal queues its stage sibling for release after immediately stopping the owned tail")
		var motor_ref: WeakRef = weakref(motor)
		motor.queue_free()
		await tree.process_frame
		await tree.process_frame
		release_observation = {"host_released":motor_ref.get_ref() == null,"remains_released":remains_ref.get_ref() == null,"orphaned_playing_voices":_orphaned(audio),"events_unchanged":audio.material_events.size() == before_dispose}
		_check(report,bool(release_observation.host_released),"actual host unload releases the Motor")
		_check(report,bool(release_observation.remains_released),"existing queued disposal releases the stage-owned corpse sibling")
		_check(report,int(release_observation.orphaned_playing_voices) == 0 and bool(release_observation.events_unchanged),"host and corpse unload leave no orphaned playing voice or replayed event")
	report.samples.append({"case":"actual_actor_audio_lifecycle","events":audio.material_events.duplicate(true),"hurt":_event_count(audio,"plains_enemy_hurt"),"death":_event_count(audio,"plains_enemy_death"),"contact":_event_count(audio,"plains_enemy_land"),"release":release_observation,"scope":"Explicit supported charger/Damageable accepted fixture; final contact-tail replay is declared lifecycle stimulus, not natural combat"})
	await _close(tree,world,report,"actor")
