extends SceneTree
## Actual moving Area2D lifecycle and existing ledger; no App route or hook proof.
const PRODUCER := preload("res://scripts/generation/thorn_forest_region_v2_v15.gd")
const AUDIO := preload("res://tests/audio_teardown.gd")
var assertions := 0
var failures := 0
var checks: Array[Dictionary] = []
var cases: Array[Dictionary] = []
var motion_frames: Array[Dictionary] = []
var output := "res://build/region_bible_v2/practice-bell/native"
var world: Node2D

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok: failures += 1
	checks.append({"label":label,"passed":ok})
	print("PRACTICE BELL RESTORE CHECK: ","PASS " if ok else "FAIL ",label)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func new_bell(row: Dictionary) -> ForestPracticeBell:
	var bell: ForestPracticeBell = ForestPracticeBell.new()
	check(bell.configure(row),"new practice target accepts finite authored row")
	world.add_child(bell)
	return bell

func rejection_cases(bell: ForestPracticeBell) -> void:
	var intact: Dictionary = bell.snapshot_state()
	for field: String in ForestPracticeBell.SNAPSHOT_FIELDS:
		var missing: Dictionary = intact.duplicate(true)
		missing.erase(field)
		check(not bell.restore_state(missing) and bell.snapshot_state() == intact,"missing "+field+" rejected without changing live state")
	var patches: Array[Dictionary] = [
		{"field":"version","value":0}, {"field":"version","value":true},
		{"field":"clock","value":-1.0}, {"field":"clock","value":"0.5"},
		{"field":"clock","value":INF}, {"field":"clock","value":1.0e308},
		{"field":"phase","value":NAN}, {"field":"phase","value":TAU},
		{"field":"position","value":[0]}, {"field":"position","value":[INF,0]},
		{"field":"accepted_kicks","value":-1}, {"field":"accepted_kicks","value":1.25},
		{"field":"accepted_kicks","value":"2"}, {"field":"accepted_kicks","value":true}
	]
	for patch: Dictionary in patches:
		var edited: Dictionary = intact.duplicate(true)
		edited[patch.field] = patch.value
		check(not bell.restore_state(edited) and bell.snapshot_state() == intact,"invalid "+str(patch.field)+" scalar/shape rejected atomically")
	for mutation: String in ["identity","period","radius","tether","route","clock_phase","phase","pose","extra"]:
		var edited: Dictionary = intact.duplicate(true)
		match mutation:
			"identity": edited.authored_row.id = "different_bell"
			"period": edited.authored_row.motion.period += 0.01
			"radius": edited.authored_row.motion.radius[0] += 1.0
			"tether": edited.authored_row.tether_root[0] += 1.0
			"route": edited.authored_row.route_id = "different_route"
			"clock_phase": edited.clock += 0.01
			"phase": edited.phase = fposmod(float(edited.phase)+0.01,TAU)
			"pose": edited.position[0] += 0.01
			"extra": edited.unexpected = true
		check(not bell.restore_state(edited) and bell.snapshot_state() == intact,"inconsistent "+mutation+" rejected with clock phase pose and counter untouched")
	var detached: Dictionary = bell.snapshot_state()
	detached.authored_row.motion.radius[0] += 1.0
	check(bell.snapshot_state() == intact,"exported snapshot does not alias the configured motion row")
	bell._physics_process(NAN)
	check(bell.snapshot_state() == intact,"invalid delta cannot poison moving target state")
	cases.append({"id":"atomic_rejections","missing_fields":ForestPracticeBell.SNAPSHOT_FIELDS.size(),"scalar_shapes":patches.size(),"inconsistencies":9,"state_unchanged":bell.snapshot_state() == intact})

func configure_cases(row: Dictionary) -> void:
	for mutation: String in ["missing_id","kind","center","radius","period","tether","damage","reward"]:
		var edited: Dictionary = row.duplicate(true)
		match mutation:
			"missing_id": edited.erase("id")
			"kind": edited.motion.kind = "unknown_motion"
			"center": edited.motion.center[0] += 1.0
			"radius": edited.motion.radius[0] = -1.0
			"period": edited.motion.period = 0.0
			"tether": edited.tether_root = [NAN,0]
			"damage": edited.damage = true
			"reward": edited.reward = "false"
		var invalid: ForestPracticeBell = ForestPracticeBell.new()
		check(not invalid.configure(edited) and invalid.snapshot_state().is_empty(),"invalid authored "+mutation+" leaves target unconfigured")
		invalid.free()
	cases.append({"id":"row_guards","rejected":8})

func actual_app_case() -> void:
	var app: DemoApp = DemoApp.new()
	app.meta_persistence_enabled = false
	root.add_child(app)
	check(app.start_debug_region(&"thorn_forest",1,"forest-depth-hollow-00",ThornForestRegionGenerator.DEPTH_VERSION,ThornForestRegionGenerator.DEPTH_LAYOUT_BIBLE),"actual App explicitly enters the authored practice map")
	for index: int in 120:
		if not app._stage_pending: break
		await frames(1)
	check(app.stage is ThornForestRegionStage and app.stage.assembly_ok and not app._stage_pending,"actual App stage and assembler finish practice target setup")
	if app.stage is ThornForestRegionStage and app.stage.assembly_ok:
		var stage: ThornForestRegionStage = app.stage as ThornForestRegionStage
		var rows: Array = stage.generated.manifest.get("training_bells",[])
		check(rows.size() == 1 and rows[0].motion.kind == "pendulum" and rows[0].motion.center == rows[0].position,"actual runtime row has the real motion kind and center used by configure")
		if rows.size() == 1:
			var id: String = str(rows[0].id)
			var target: Variant = (stage.assembler as ThornForestRegionAssembler).hook_targets.get(id)
			check(target is ForestPracticeBell,"actual assembler registers the configured practice bell in hook_targets")
			if target is ForestPracticeBell:
				var bell: ForestPracticeBell = target as ForestPracticeBell
				await frames(17)
				app._pause_for_menu()
				var before: Dictionary = bell.snapshot_state()
				var key: String = "practice_bell/"+id
				stage.capture_state()
				check(float(before.clock) > 0.0 and app.region_state.mechanisms.get(key) == before,"actual Stage.capture_state records the nonzero bell mechanism state")
				var old_stage: int = stage.get_instance_id()
				var old_target: int = bell.get_instance_id()
				var old_hash: String = str(stage.generated.manifest.manifest_hash)
				await app._load_stage()
				var next_stage: ThornForestRegionStage = app.stage as ThornForestRegionStage
				check(next_stage != null and next_stage.assembly_ok and next_stage.get_instance_id() != old_stage,"actual App unload and rebuild creates a new admitted stage")
				if next_stage != null and next_stage.assembly_ok:
					var next_target: Variant = (next_stage.assembler as ThornForestRegionAssembler).hook_targets.get(id)
					check(next_target is ForestPracticeBell,"actual rebuilt assembler restores the saved practice target")
					if next_target is ForestPracticeBell:
						var loaded: ForestPracticeBell = next_target as ForestPracticeBell
						var retained: bool = loaded.get_instance_id() != old_target and loaded.snapshot_state() == before and str(next_stage.generated.manifest.manifest_hash) == old_hash
						check(retained,"actual App retains authored identity clock phase pose and kick count across reload")
						for index: int in 5: await process_frame
						check(loaded.snapshot_state() == before and paused,"rebuilt bell retains the same phase while actual App remains paused")
						app._resume_from_menu()
						await frames(3)
						var resumed: Dictionary = loaded.snapshot_state()
						check(float(resumed.clock) > float(before.clock) and resumed.accepted_kicks == before.accepted_kicks,"actual App resume advances the restored clock without resetting accepted kicks")
						cases.append({"id":"actual_app_reload","retained":retained,"manifest_hash":old_hash,"key":key,"before":before,"resumed":resumed,"position_or_resource_injection":false,"player_hook_execution":false})
	paused = false
	if app.lifetime.active: app.abandon_run()
	await frames(4)
	check(app.director.state == DemoRunDirector.State.HOME,"actual App practice test returns HOME")
	check(await AUDIO.drain_world(app),"actual App practice audio drains")
	app.free()
	await frames(2)

func run() -> void:
	var manifest: Dictionary = PRODUCER.new()._candidate("forest-depth-hollow-00/thorn_forest/map_1",1)
	var row: Dictionary = manifest.training_bells[0].duplicate(true)
	check(row.id == "bible_guardian_practice_bell" and row.motion.kind == "pendulum","fixture consumes actual v15 authored practice row")
	world = Node2D.new()
	root.add_child(world)
	world.add_child(GameAudio.new())
	var source: ForestPracticeBell = new_bell(row)
	check(source.is_in_group(&"grapple_target") and source.collision_layer == 8 and source.collision_mask == 0,"real Area2D remains a harmless shared grapple target")
	check(not source.configure(row),"reconfigure cannot silently reset an existing bell phase or kick count")
	await frames(53)
	check(source._clock > 0.0 and source.position.distance_to(Vector2(row.position[0],row.position[1])) > 1.0,"native physics advances the actual authored moving target")
	# Counter setup exercises its accepted-contact callback only. This is not an
	# assertion that a real Player performed H; no traversal evidence is claimed.
	source.accepted_contact()
	source.accepted_contact()
	var saved: Dictionary = source.snapshot_state()
	check(saved.accepted_kicks == 2 and saved.clock > 0.0,"snapshot contains actual callback count and nonzero motion debt")
	var restored: ForestPracticeBell = new_bell(row)
	check(restored.restore_state(saved) and restored.snapshot_state() == saved,"fresh target restores exact phase pose clock and counter")
	var continuous: bool = true
	for index: int in 80:
		await frames(1)
		continuous = continuous and source.snapshot_state() == restored.snapshot_state()
		motion_frames.append({"tick":Engine.get_physics_frames(),"clock":source._clock,"source":[source.position.x,source.position.y],"restored":[restored.position.x,restored.position.y],"restored_clock":restored._clock})
	check(continuous,"restored target follows uninterrupted native physics for eighty frames")
	cases.append({"id":"phase_continuity","frames":motion_frames.size(),"identical":continuous,"saved_clock":saved.clock,"accepted_kicks":saved.accepted_kicks})
	var frozen: Dictionary = source.snapshot_state()
	paused = true
	for index: int in 8: await process_frame
	check(source.snapshot_state() == frozen and restored.snapshot_state() == frozen,"real SceneTree pause freezes both target phase pose and counter")
	paused = false
	await frames(2)
	check(source._clock > float(frozen.clock) and source.snapshot_state() == restored.snapshot_state(),"resume continues both native targets from the retained phase")
	cases.append({"id":"pause_resume","frozen_clock":frozen.clock,"resumed_clock":source._clock,"identical":source.snapshot_state() == restored.snapshot_state()})
	var state: PlainsRegionState = PlainsRegionState.new()
	check(state.bind_map(str(manifest.manifest_hash)),"existing ledger binds the actual manifest")
	var key: String = "practice_bell/"+str(row.id)
	state.mechanisms[key] = source.snapshot_state()
	var parsed: Variant = JSON.parse_string(JSON.stringify(state.snapshot(),"",true,true))
	var replay: PlainsRegionState = PlainsRegionState.new()
	check(parsed is Dictionary and replay.restore(parsed,str(manifest.manifest_hash)),"existing RegionState version2 survives actual JSON serialization")
	var before_unload: Dictionary = source.snapshot_state()
	var old_id: int = restored.get_instance_id()
	world.remove_child(restored)
	restored.free()
	restored = new_bell(row)
	check(restored.get_instance_id() != old_id and restored.restore_state(replay.mechanisms[key]),"unloaded target rebuild consumes the existing mechanism ledger")
	check(restored.snapshot_state() == before_unload,"JSON mechanism reload retains exact current target phase and callback count")
	await frames(3)
	check(source.snapshot_state() == restored.snapshot_state(),"rebuilt target keeps moving in phase after actual unload")
	cases.append({"id":"ledger_unload","schema_version":state.snapshot().version,"key":key,"accepted_kicks":restored.accepted_kicks,"identical":source.snapshot_state() == restored.snapshot_state()})
	rejection_cases(restored)
	configure_cases(row)
	check(await AUDIO.drain_world(world),"practice callback audio actually drains")
	world.free()
	await frames(3)
	await actual_app_case()
	DirAccess.make_dir_recursive_absolute(output)
	var file: FileAccess = FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	if file == null:
		push_error("Practice bell restore capture could not be written")
		quit(1)
		return
	file.store_string(JSON.stringify({"scope":"real moving practice Area2D, ledger JSON and actual App unload/rebuild; no traversal admission","assertions":assertions,"failures":failures,"checks":checks,"cases":cases,"motion_frames":motion_frames,"row":row,"manifest_hash":manifest.manifest_hash,"accepted_contact_scope":"local callback setup only, not real player H evidence"},"  "))
	file.close()
	print("FOREST PRACTICE BELL RESTORE: %s assertions, %s failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
