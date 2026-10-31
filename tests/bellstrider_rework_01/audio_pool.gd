extends SceneTree
## Real GameAudio and actual Bellstrider scene regressions. Pool saturation and
## forced mode transitions are explicit component fixtures, not natural combat,
## audible mix, human listening or device-performance evidence.
const CONSUMER := preload("res://scripts/audio/bellstrider_audio.gd")
const TEARDOWN := preload("res://tests/audio_teardown.gd")
const HOLD: AudioStream = preload("res://assets/audio/bellstrider_01/death_final.wav")
var assertions := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var world: Node2D
var audio: GameAudio

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ",label)

func frames(count: int = 2) -> void:
	for index: int in count: await process_frame

func voices() -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for child: Node in audio.get_children():
		if child is AudioStreamPlayer: result.append(child as AudioStreamPlayer)
	return result

func active(event: StringName = &"") -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in voices():
		if voice.playing and (event.is_empty() or voice.get_meta("director_event",&"") == event): result.append(voice)
	return result

func owned(origin: Node) -> Array[AudioStreamPlayer]:
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in active():
		var reference: Variant = voice.get_meta("director_origin")
		if reference is WeakRef and (reference as WeakRef).get_ref() == origin: result.append(voice)
	return result

func retained_owned(origin: Node) -> Array[AudioStreamPlayer]:
	# Godot reports playing=false for a paused but retained backend. Ownership
	# during pause must inspect the assigned stream and actual playback object.
	var result: Array[AudioStreamPlayer] = []
	for voice: AudioStreamPlayer in voices():
		if voice.stream==null or not voice.has_stream_playback() or not voice.has_meta("director_origin"): continue
		var reference: Variant = voice.get_meta("director_origin")
		if reference is WeakRef and (reference as WeakRef).get_ref()==origin: result.append(voice)
	return result

func identities(items: Array[AudioStreamPlayer]) -> Array[int]:
	var result: Array[int] = []
	for voice: AudioStreamPlayer in items: result.append(voice.get_instance_id())
	return result

func pool_snapshot(label: String) -> void:
	var rows: Array[Dictionary] = []
	for voice: AudioStreamPlayer in voices():
		var reference: Variant = voice.get_meta("director_origin") if voice.has_meta("director_origin") else null
		var origin: Node = (reference as WeakRef).get_ref() as Node if reference is WeakRef else null
		rows.append({"voice_id":voice.get_instance_id(),"playing":voice.playing,"stream_paused":voice.stream_paused,"stream":voice.stream.resource_path if voice.stream!=null else "","has_stream_playback":voice.has_stream_playback(),"position":voice.get_playback_position(),"can_process":voice.can_process(),"process_mode":voice.process_mode,"event":String(voice.get_meta("director_event",&"")),"origin_is_weakref":reference is WeakRef,"origin_valid":is_instance_valid(origin),"origin_id":origin.get_instance_id() if is_instance_valid(origin) else 0,"origin_inside_tree":origin.is_inside_tree() if is_instance_valid(origin) else false,"origin_queued":origin.is_queued_for_deletion() if is_instance_valid(origin) else false})
	var snapshot: Dictionary = {"case":label,"process_frame":Engine.get_process_frames(),"physics_frame":Engine.get_physics_frames(),"wall_msec":Time.get_ticks_msec(),"tree_paused":paused,"world_inside_tree":world.is_inside_tree(),"world_can_process":world.can_process(),"audio_can_process":audio.can_process(),"audio_process_mode":audio.process_mode,"audio_clock":audio._clock,"director_events":audio.director_events.size(),"voices":rows}
	samples.append(snapshot)
	print("BELLSTRIDER_AUDIO_POOL_SNAPSHOT ",JSON.stringify(snapshot))

func observed_mixes(label: String, required: int, voice: AudioStreamPlayer) -> bool:
	# Observe actual AudioServer cycle resets rather than assuming that a wall
	# sleep or a rendered frame means the queued mixer command has completed.
	# A missing/stalled mixer is an explicit bounded failure, never a skip.
	var started: int = Time.get_ticks_msec()
	var previous: float = AudioServer.get_time_since_last_mix()
	var observed: int = 0
	var timeline: Array[Dictionary] = [{"wall_msec":started,"process_frame":Engine.get_process_frames(),"since_last_mix":previous,"position":voice.get_playback_position(),"paused":voice.stream_paused}]
	while observed<required and Time.get_ticks_msec()-started<500:
		await process_frame
		if Time.get_ticks_msec()-started>=500: break
		var current: float = AudioServer.get_time_since_last_mix()
		if is_finite(current) and is_finite(previous) and current<previous:
			observed+=1
			timeline.append({"wall_msec":Time.get_ticks_msec(),"process_frame":Engine.get_process_frames(),"previous_since_last_mix":previous,"since_last_mix":current,"position":voice.get_playback_position(),"paused":voice.stream_paused,"observed_mix":observed})
		previous=current
	var receipt: Dictionary = {"case":label,"required_mix_resets":required,"observed_mix_resets":observed,"elapsed_msec":Time.get_ticks_msec()-started,"deadline_msec":500,"tree_paused":paused,"final_position":voice.get_playback_position(),"timeline":timeline}
	samples.append(receipt)
	print("BELLSTRIDER_AUDIO_MIX_SYNC ",JSON.stringify(receipt))
	return observed>=required

func owner_node() -> Node:
	var origin: Node = Node.new()
	world.add_child(origin)
	return origin

func clear() -> void:
	audio.stop_director_cues()
	# Explicit fixture isolation also clears original cue rate gates.
	audio._director_last.clear()
	audio._last.clear()

func boss_event(event: StringName) -> int:
	return int(audio.played.get(event,0))

func pool_contract() -> void:
	var origin: Node = owner_node()
	var other: Node = owner_node()
	check(voices().size()==12 and world.find_children("*","AudioStreamPlayer",true,false).size()==12,"exactly twelve existing shared SFX voices; no boss pool")
	var detached: Node = Node.new()
	check(not audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,detached),"detached origin cannot play")
	detached.free()
	check(not audio.play_boss_cue(&"warning",HOLD,origin) and not audio.play_boss_cue(&"bellstrider_roll_warn",null,origin),"foreign event and missing stream rejected")
	check(not audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin,90,NAN),"nonfinite attenuation rejected before playback")
	check(audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin,999),"attached origin starts authored warning in shared pool")
	var warning: AudioStreamPlayer = active(&"bellstrider_roll_warn")[0]
	check(int(warning.get_meta("audio_priority"))==90 and warning.get_meta("director_family")==&"bellstrider" and warning.process_mode==Node.PROCESS_MODE_PAUSABLE,"boss metadata retains clamped priority, family and pause ownership")
	check(owned(origin).size()==1 and warning.bus==&"SFX" and warning.stream==HOLD,"actual warning stream belongs to explicit weak origin")
	check(audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,other),"second same event accepted across origins")
	var preemptions: int = audio.director_preemptions
	check(not audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin) and active(&"bellstrider_roll_warn").size()==2 and audio.director_preemptions==preemptions,"third same event refused at global cap two even with free voices")
	audio.stop_director_cues(origin,false)
	check(owned(origin).is_empty() and owned(other).size()==1,"origin stop preserves other boss tails")
	clear()
	# Explicit saturation: eleven distinct authored boss calls plus the existing
	# material API establish a real full twelve-voice backend in this frame.
	for index: int in 11:
		check(audio.play_boss_cue(StringName("bellstrider_load_%s" % index),HOLD,other,70),"pool load voice%s starts" % index)
	check(audio.play_enemy_material(&"hurt",HOLD,origin,&"bellstrider"),"real priority45 material completes twelve-voice saturation")
	var protected: Array[int] = identities(owned(other))
	preemptions=audio.director_preemptions
	check(audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin,90),"critical warning preempts lower priority material in full pool")
	check(audio.director_preemptions==preemptions+1 and active(&"plains_enemy_hurt").is_empty() and identities(owned(other))==protected,"lowest45 voice replaced once; all eleven70 voice identities retained")
	warning=active(&"bellstrider_roll_warn")[0]
	var warning_id: int = warning.get_instance_id()
	check(not audio.play_enemy_material(&"hurt",HOLD,origin,&"bellstrider") and active(&"bellstrider_roll_warn")[0].get_instance_id()==warning_id,"later material hit cannot steal warning from saturated pool")
	check(active().size()==12 and voices().size()==12,"preemption never grows shared pool")
	samples.append({"case":"warning_preempts_material","voices":voices().size(),"active":active().size(),"preemptions":audio.director_preemptions,"material_dropped":audio.material_dropped})
	clear()
	origin.free()
	other.free()

func player_priority_contract() -> void:
	var origin: Node = owner_node()
	check(audio.configure_candidate_bank(SelectedSfxRuntime.MANIFEST_PATH,SelectedSfxRuntime.RULES_PATH),"actual selected V3 bank and rules load")
	check(audio.configure_selected_profiles({"hurt":"C"}) and audio.configure_candidate_revision(&"hurt",SelectedSfxRuntime.HURT_CANDIDATES.A) and audio.set_audio_profile("selected"),"exact user-selected hurtA revision configures through existing API")
	check(audio.play_director_event(&"hurt","",origin),"actual selected player hurtA starts at its existing priority")
	var hurt: Array[AudioStreamPlayer] = active(&"hurt")
	check(hurt.size()==1 and hurt[0].stream.resource_path=="res://assets/audio/feedback_06/hurt_a.wav" and int(hurt[0].get_meta("audio_priority"))==90,"selected hurtA bytes and priority90 remain actual playback")
	for index: int in 11:
		check(audio.play_boss_cue(StringName("bellstrider_protected_%s" % index),HOLD,origin,90),"protected saturation slot%s starts" % index)
	var before: Array[int] = identities(active())
	var preemptions: int = audio.director_preemptions
	check(active().size()==12 and not audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin,90),"warning cannot preempt equal priority90 full pool")
	check(identities(active())==before and audio.director_preemptions==preemptions and active(&"hurt").size()==1,"existing player hurtA and every equal priority voice remain untouched")
	# Higher priorities can exist in another director bank. This explicit metadata
	# fixture exercises comparison without changing any production rule/bank.
	var higher: AudioStreamPlayer = active()[0]
	higher.set_meta("audio_priority",100)
	check(not audio.play_boss_cue(&"bellstrider_phase",HOLD,origin,500) and int(higher.get_meta("audio_priority"))==100 and identities(active())==before,"clamped90 request cannot steal an existing higher100 voice or equal90 peers")
	check(audio._candidate_revisions[&"hurt"].id=="hurt_feedback_06_a" and audio.director_profile_for_event(&"hurt")=="C","boss dispatch preserves exact selected hurtA mapping")
	clear()
	check(audio.set_audio_profile("original"),"priority fixture restores original profile without retained tails")
	origin.free()

func pause_and_lifetime_contract() -> void:
	var origin: Node = owner_node()
	var other: Node = owner_node()
	check(audio.play_boss_cue(&"bellstrider_death_final",HOLD,origin,80),"real death final tail starts")
	check(audio.play_boss_cue(&"bellstrider_lob_aim",HOLD,other,60),"unrelated origin cue starts alongside death tail")
	var voice: AudioStreamPlayer = active(&"bellstrider_death_final")[0]
	pool_snapshot("lifetime_before_pause")
	check(await observed_mixes("lifetime_playback_warmup",2,voice),"real playback warmup observes two mixer cycles within500ms")
	paused=true
	await frames()
	check(await observed_mixes("lifetime_pause_command_settlement",2,voice),"queued pause settles across two observed mixer cycles within500ms")
	pool_snapshot("lifetime_paused_settled_baseline")
	var before_position: float = voice.get_playback_position()
	var before_events: int = audio.director_events.size()
	check(not audio.play_boss_cue(&"bellstrider_roll_warn",HOLD,origin) and not audio.play_enemy_material(&"hurt",HOLD,origin,&"bellstrider"),"paused world rejects new warning and material requests")
	check(await observed_mixes("lifetime_paused_observation_window",3,voice),"paused position window spans three observed mixer cycles within500ms")
	check(voice.stream_paused and not voice.can_process() and absf(voice.get_playback_position()-before_position)<.004,"actual owned death tail remains frozen while world pauses")
	check(audio.director_events.size()==before_events,"pause creates no delayed queued event")
	var origin_ref: WeakRef = weakref(origin)
	pool_snapshot("lifetime_paused_before_origin_free")
	origin.queue_free()
	await frames(3)
	pool_snapshot("lifetime_paused_after_origin_free")
	check(origin_ref.get_ref()==null and active(&"bellstrider_death_final").is_empty() and voice.stream==null,"GameAudio ALWAYS cleanup stops death tail when origin exits during pause")
	check(retained_owned(other).size()==1 and retained_owned(other)[0].stream_paused,"orphan cleanup preserves unrelated paused owned stream and backend")
	paused=false
	await frames()
	pool_snapshot("lifetime_after_resume")
	check(audio.director_events.size()==before_events,"resume does not replay refused paused request")
	world.remove_child(other)
	await frames()
	pool_snapshot("lifetime_after_other_detach")
	check(active().is_empty(),"detached but still allocated origin also loses its voice")
	other.free()
	clear()

func presentation_contract() -> void:
	var target: Node2D = Node2D.new()
	target.position=Vector2(900,535)
	world.add_child(target)
	var boss: BossMotor = preload("res://scenes/bosses/bellstrider.tscn").instantiate() as BossMotor
	boss.position=Vector2(600,535)
	world.add_child(boss)
	var encounter: BellstriderEncounter = boss.get_node("Encounter") as BellstriderEncounter
	encounter.set_physics_process(false)
	await frames(3)
	check(encounter.configure_arena(100,1100,target) and encounter.activate(),"actual Bellstrider arena activates for presentation consumer fixture")
	encounter.skip_intro()
	var presentation: BellstriderPresentation = boss.get_node("Presentation") as BellstriderPresentation
	var service: BellstriderAudio = presentation.get_node_or_null("BellstriderAudio") as BellstriderAudio
	check(service!=null and world.find_children("BellstriderAudio","Node",true,false).size()==1,"actual scene presentation binds exactly one Bellstrider consumer")
	if service==null:
		encounter.cancel()
		boss.free()
		target.free()
		return
	clear()
	# Exact actual encounter state entry emits the attack event once. Advancing
	# only the read-only presenter must neither create cues nor attack waves.
	encounter._group={"return_roll":true,"roll_index":0}
	var warnings: int = boss_event(&"bellstrider_roll_warn")
	var legacy: Dictionary = audio.played.duplicate()
	encounter._enter(&"roll_warning",.8)
	check(boss_event(&"bellstrider_roll_warn")==warnings+1 and owned(service).size()==1,"actual warning state entry produces one dedicated shared voice")
	check(active(&"bellstrider_roll_warn")[0].stream==CONSUMER.STREAMS[&"roll_warn_double"],"actual planned-return state uses doublebeat stream")
	var chatter_materials: int = audio.material_events.size()
	var suppressed_before: int = service.suppressed_hits
	for index: int in 6:
		encounter._fight_age=.01+index*.10
		var chatter: ActorResourceRequest = ActorResourceRequest.new(StringName("bellstrider/audio/chatter/%s" % index),encounter.health.epoch,1.0,encounter.health.get_instance_id())
		check(encounter.health.apply_damage(chatter).status==ActorResourceResult.Status.APPLIED,"10Hz warning fixture keeps legal HP loss%s" % index)
	check(audio.material_events.size()==chatter_materials and service.suppressed_hits==suppressed_before+6 and active(&"bellstrider_roll_warn").size()==1,"real accepted 10Hz weak hits retain HP loss while suppressing chatter under actual warning")
	for index: int in 20: presentation._process(.016)
	check(boss_event(&"bellstrider_roll_warn")==warnings+1,"repeated Presentation samples do not duplicate warning")
	for key: StringName in [&"warning",&"bell",&"armour",&"enemy_defeat",&"boss_impact"]:
		check(int(audio.played.get(key,0))==int(legacy.get(key,0)),"old Presentation cue absent during dedicated warning: "+String(key))
	encounter.cancel_pending_attacks()
	check(owned(service).is_empty(),"actual cancel_pending_attacks event stops the warning origin immediately")
	# Source clocks are advanced solely as an explicit component fixture. HP is
	# changed only by real HealthState requests; replays must produce no sound.
	encounter._fight_age=10.0
	var materials: int = audio.material_events.size()
	var health_before: float = encounter.health.current
	var request: ActorResourceRequest = ActorResourceRequest.new(&"bellstrider/audio/accepted-hit",encounter.health.epoch,1.0,encounter.health.get_instance_id())
	var result: ActorResourceResult = encounter.health.apply_damage(request)
	check(result.status==ActorResourceResult.Status.APPLIED and encounter.health.current==health_before-1,"real HealthState commits one weakpoint audio fixture damage")
	check(audio.material_events.size()==materials+1 and active(&"plains_enemy_hurt").size()==1,"one committed HP loss creates one distinct bell material reaction")
	encounter.health.apply_damage(request)
	for index: int in 20: presentation._process(.016)
	check(audio.material_events.size()==materials+1,"replayed Health request and visual polling create no duplicate hit cue")
	encounter._fight_age=11.0
	var armour_health: float = encounter.health.current
	encounter.armour_hit.emit(boss.global_position)
	check(encounter.health.current==armour_health and audio.material_events.size()==materials+2,"armour contact creates material feedback while HP stays unchanged")
	check(active(&"plains_enemy_hurt")[-1].stream==CONSUMER.STREAMS[&"armour_hit"],"actual armour contact uses muffled armour stream")
	clear()
	encounter._event(&"bellstrider_death")
	check(active(&"bellstrider_death").size()==1,"accepted death event begins dedicated tail")
	encounter.cancel()
	check(owned(service).is_empty(),"actual encounter cancel stops dedicated death tail")
	service.bind(encounter)
	encounter._event(&"bellstrider_death")
	var health_definition: HealthDefinition = encounter.definition.health_definition
	encounter.health.configure(health_definition)
	service._process(0)
	check(owned(service).is_empty(),"real health epoch replacement cancels prior death audio")
	service.bind(encounter)
	encounter._event(&"bellstrider_death")
	encounter._event(&"bellstrider_death_final")
	var exit_voice: AudioStreamPlayer = active(&"bellstrider_death_final")[0] if not active(&"bellstrider_death_final").is_empty() else null
	check(exit_voice!=null,"final tail exists before actual scene unload")
	boss.queue_free()
	await frames(3)
	check(exit_voice!=null and not exit_voice.playing and exit_voice.stream==null,"actual scene unload releases its final-tail voice")
	check(voices().size()==12 and world.find_children("*","AudioStreamPlayer",true,false).size()==12,"actual Presentation creates no private AudioStreamPlayer or expanded pool")
	target.free()
	clear()

func restore_boundary_contract() -> void:
	# Formal stage reconstruction replaces Health after Presentation._ready.
	# Exercise the public complete-restore binding rather than private audio.bind.
	var target: Node2D = Node2D.new()
	target.position=Vector2(900,535)
	world.add_child(target)
	var boss: BossMotor = preload("res://scenes/bosses/bellstrider.tscn").instantiate() as BossMotor
	boss.position=Vector2(600,535)
	world.add_child(boss)
	var encounter: BellstriderEncounter = boss.get_node("Encounter") as BellstriderEncounter
	encounter.set_physics_process(false)
	await frames(3)
	check(encounter.configure_arena(100,1100,target) and encounter.activate(),"restore fixture activates actual Bellstrider scene")
	encounter.skip_intro()
	var presentation: BellstriderPresentation = boss.get_node("Presentation") as BellstriderPresentation
	var service: BellstriderAudio = presentation.get_node_or_null("BellstriderAudio") as BellstriderAudio
	check(service!=null,"restore fixture uses actual Presentation-owned consumer")
	if service==null:
		encounter.cancel()
		boss.free()
		target.free()
		return
	clear()
	encounter._group={"kind":&"roll","phase":1,"direction":-1,"return_roll":false,"roll_index":0,"count":1}
	encounter._fight_age=5.0
	encounter._enter(&"roll_warning",.8)
	var old_voice: AudioStreamPlayer = active(&"bellstrider_roll_warn")[0]
	var old_epoch: int = encounter.health.epoch
	var live_snapshot: Dictionary = JSON.parse_string(JSON.stringify(encounter.combat_snapshot()))
	var warning_count: int = boss_event(&"bellstrider_roll_warn")
	check(owned(service).size()==1,"live restore begins with an actual old warning tail")
	check(encounter.health.configure(encounter.definition.health_definition) and encounter.health.epoch==old_epoch+1,"formal-style Health.configure replaces live epoch after Presentation ready")
	service._process(0)
	check(service._cancelled and old_voice.stream==null and retained_owned(service).is_empty(),"old Health epoch still cancels consumer and stops assigned old tail")
	encounter.damageable.bind_health(encounter.health)
	encounter.restore_combat_state(live_snapshot)
	var before_sync: int = audio.director_events.size()
	EnemyPresentationBinding.synchronize(encounter)
	check(not service._cancelled and service._health_epoch==encounter.health.epoch,"actual complete-restore presentation boundary rearms current live epoch")
	check(audio.director_events.size()==before_sync and boss_event(&"bellstrider_roll_warn")==warning_count and old_voice.stream==null,"live synchronize replays neither saved warning nor old tail")
	encounter._fight_age+=.1
	encounter._enter(&"roll_warning",.8)
	check(boss_event(&"bellstrider_roll_warn")==warning_count+1 and retained_owned(service).size()==1,"first real postrestore warning plays exactly once through rearmed consumer")
	for index: int in 20: presentation._process(.016)
	check(boss_event(&"bellstrider_roll_warn")==warning_count+1,"postrestore visual samples cannot duplicate warning")
	# Build a real accepted terminal state, save before jam/impact, then restore
	# with the same ordering used by the stage loader: prepare, Health0, combat
	# snapshot, complete presentation synchronize. No private service rebind.
	var kill: ActorResourceRequest = ActorResourceRequest.new(&"bellstrider/audio/restore-kill",encounter.health.epoch,encounter.health.current,encounter.health.get_instance_id())
	var kill_result: ActorResourceResult = encounter.health.apply_damage(kill)
	check(kill_result.status==ActorResourceResult.Status.APPLIED and encounter.health.terminal and encounter.mode==&"dead","terminal restore source comes from actual committed lethal Health transaction")
	encounter.physics_tick(.20)
	var terminal_snapshot: Dictionary = JSON.parse_string(JSON.stringify(encounter.combat_snapshot()))
	var definition: BellstriderDefinition = encounter.definition as BellstriderDefinition
	check(encounter._death_age<.38 and encounter._death_age<definition.reward_impact_seconds,"actual terminal snapshot precedes future jam and body impact")
	var death_count: int = boss_event(&"bellstrider_death")
	var jam_count: int = boss_event(&"bellstrider_death_jam")
	var impact_count: int = boss_event(&"bellstrider_death_impact")
	var final_count: int = boss_event(&"bellstrider_death_final")
	var restore_epoch: int = encounter.health.epoch
	var terminal_health: HealthDefinition = encounter.definition.health_definition.duplicate(true) as HealthDefinition
	terminal_health.initial_current=0.0
	encounter.prepare_terminal_restore()
	check(encounter.health.configure(terminal_health) and encounter.health.epoch==restore_epoch+1 and encounter.health.terminal,"terminal prepare precedes actual zero-Health epoch reconstruction")
	encounter.damageable.bind_health(encounter.health)
	encounter.restore_combat_state(terminal_snapshot)
	service._process(0)
	check(service._cancelled and retained_owned(service).is_empty(),"terminal old epoch cancels before complete-restore synchronization")
	before_sync=audio.director_events.size()
	EnemyPresentationBinding.synchronize(encounter)
	check(not service._cancelled and service._dying and service._health_epoch==encounter.health.epoch,"actual terminal restore boundary rearms future death layers for current epoch")
	check(audio.director_events.size()==before_sync and boss_event(&"bellstrider_death")==death_count and boss_event(&"bellstrider_death_jam")==jam_count and boss_event(&"bellstrider_death_impact")==impact_count and boss_event(&"bellstrider_death_final")==final_count,"Health0 bind and terminal synchronize replay no past death or future layer")
	check(is_equal_approx(encounter._death_age,.20) and not encounter.active,"terminal synchronize preserves saved dead pose clock and inactive combat")
	encounter.physics_tick(.19)
	service._process(0)
	check(boss_event(&"bellstrider_death_jam")==jam_count+1 and active(&"bellstrider_death_jam").size()==1,"first actual future jam tick produces one retained death layer")
	await frames(2)
	check(not service._cancelled and active(&"bellstrider_death_jam").size()==1,"terminal consumer process preserves future jam while encounter remains inactive")
	encounter.physics_tick(definition.reward_impact_seconds-encounter._death_age+.01)
	service._process(0)
	check(boss_event(&"bellstrider_death_impact")==impact_count+1 and active(&"bellstrider_death_impact").size()==1,"actual restored death clock emits future body impact once")
	await frames(2)
	check(active(&"bellstrider_death_impact").size()==1,"terminal process does not stop restored impact tail")
	encounter.physics_tick(definition.death_seconds-encounter._death_age+.01)
	service._process(0)
	check(boss_event(&"bellstrider_death_final")==final_count+1 and active(&"bellstrider_death_final").size()==1,"actual restored final tick emits one retained final bell tail")
	await frames(2)
	encounter.physics_tick(.5)
	service._process(0)
	check(active(&"bellstrider_death_final").size()==1 and boss_event(&"bellstrider_death")==death_count and boss_event(&"bellstrider_death_jam")==jam_count+1 and boss_event(&"bellstrider_death_impact")==impact_count+1 and boss_event(&"bellstrider_death_final")==final_count+1,"finished restored death keeps final tail and never replays past death layers")
	samples.append({"case":"actual_presentation_restore_boundary","live_epoch_before":old_epoch,"terminal_epoch":encounter.health.epoch,"death_age":encounter._death_age,"replayed_start_death":boss_event(&"bellstrider_death")-death_count,"future_jam":boss_event(&"bellstrider_death_jam")-jam_count,"future_impact":boss_event(&"bellstrider_death_impact")-impact_count,"future_final":boss_event(&"bellstrider_death_final")-final_count,"service_cancelled":service._cancelled,"service_dying":service._dying})
	encounter.cancel()
	boss.queue_free()
	await frames(3)
	target.free()
	clear()

func run() -> void:
	world=Node2D.new()
	root.add_child(world)
	audio=GameAudio.new()
	world.add_child(audio)
	await frames()
	pool_contract()
	player_priority_contract()
	await pause_and_lifetime_contract()
	await presentation_contract()
	await restore_boundary_contract()
	paused=false
	check(await TEARDOWN.drain_world(world),"actual backend releases within original1000ms teardown budget")
	world.free()
	await frames()
	var report: Dictionary = {"assertions":assertions,"failures":failures,"samples":samples,"scope":"Real12voice pooling, origin/pause/epoch/cancel, exact hurtA mapping and actual Presentation accepted-event fixture; no natural battle or listening approval"}
	DirAccess.make_dir_recursive_absolute("res://build/bellstrider_01")
	var file: FileAccess = FileAccess.open("res://build/bellstrider_01/audio-pool-report.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"  ")+"\n")
	print("BELLSTRIDER_AUDIO_POOL assertions=%s failures=%s" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
