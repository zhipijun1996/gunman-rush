extends "res://tests/enemy_feedback_01_support.gd"
## JSON/save compatibility and true support movement/release. Accepted deaths use
## the inherited real Router/projectile fixture; bad-save injection is explicit.

func snapshot_case(underworld: bool) -> void:
	fixture_mode=&"supported"
	await actual_charger_death(underworld)
	await ticks(90,"snapshot_real_landed_D4")
	var remains := art.get("feedback_remains") as EnemyFeedback01Remains
	var identity := {"kind":"module","module":"ExplicitSupportCarrier","body":"ExplicitSupportFloor"}
	var pose := remains.presentation_snapshot(identity)
	check(EnemyFeedback01Remains.valid_presentation_snapshot(pose),"real settled D4 produces valid optional pose")
	var state := PlainsRegionState.new();state.bind_map("corpse-snapshot-explicit-fixture")
	state.actors["actual_charger"]={"health":0,"presentation_remains":pose}
	var loaded := PlainsRegionState.new()
	check(loaded.restore(JSON.parse_string(JSON.stringify(state.snapshot())),state.manifest_hash),"original region ledger JSON roundtrip preserves optional presentation field")
	pose=loaded.actors.actual_charger.presentation_remains
	check(EnemyFeedback01Remains.valid_presentation_snapshot(pose),"JSON float numeric representation is accepted without relabeling version")
	var starts := remains.accepted_starts
	var bursts: int=art.get("feedback_particles").emitted_bursts
	var cues: int=audio.played.get(&"enemy_defeat",0)
	check(actor.restore_instance_health(0),"initialize terminal through official Actor API")
	enemy.hide()
	check(remains.restore_presentation(pose,support_floor),"versioned corpse restores saved position/frame/support anchor")
	await ticks(3,"restored_D4_short_contact")
	check(remains.is_visible_in_tree() and remains.settled and remains.restore_support_verified,"static saved corpse is visible despite terminal Motor remaining hidden")
	var point: Array=pose.position
	check(remains.position.distance_to(Vector2(point[0],point[1]))<.01 and remains.frame_index==7,"static geometry restores exact saved pixel pose and D4")
	var before := remains.global_position
	var movement := Vector2(43,-17)
	support_carrier.position+=movement
	await ticks(3,"restored_support_translation")
	check(remains.global_position.distance_to(before+movement)<.01,"restored corpse follows actual moving support local anchor")
	var invalid: Array[Dictionary]=[]
	for key: String in ["version","frame","position","support_anchor","face","support"]:
		var missing:=pose.duplicate(true);missing.erase(key);invalid.append(missing)
	for mutation: Dictionary in [{"version":2},{"version":"1"},{"frame":6},{"position":[NAN,0]},{"position":[1e300,0]},{"support_anchor":[INF,0]},{"face":0},{"support":{"kind":"unknown"}},{"support":{"kind":"module","module":"known","body":"@StaticBody2D@7"}},{"support":{"kind":"module","module":"known","body":"../wrong"}}]:
		var bad:=pose.duplicate(true);bad.merge(mutation,true);invalid.append(bad)
	for bad: Dictionary in invalid:
		check(not remains.restore_presentation(bad,support_floor),"bad/missing/future presentation snapshot uses safe legacy fallback")
		await ticks(2,"invalid_pose_no_death_replay")
		check(remains.global_position.is_finite() and remains.frame_index==7 and remains.accepted_starts==starts,"invalid pose never corrupts position/frame or creates new accepted death")
	# A known stable ID whose body has disappeared is different from malformed
	# data: retain the recorded pose and let D4 fall within existing finite rules.
	check(remains.restore_presentation(pose,null),"valid snapshot tolerates released support identity")
	check(remains.position.distance_to(Vector2(point[0],point[1]))<.01,"missing support keeps true saved world pose instead of snapping to another floor")
	await ticks(3,"missing_saved_support_no_replay")
	check(remains.restored and remains.frame_index==7 and remains.accepted_starts==starts,"missing support keeps final pixels without a new death animation")
	check(remains.restore_presentation(pose,support_floor),"valid support can be rebound after fallback probes")
	await ticks(3,"restored_weak_support_before_release")
	var reference: WeakRef=weakref(support_floor)
	support_carrier.queue_free()
	await ticks(3,"restored_support_released")
	check(reference.get_ref()==null,"saved support references never retain released collision lifecycle")
	var frames := await wait_for_void(remains,"restored_support_bounded_D4_fall")
	check(frames<300 and not remains.active and not remains.visible,"released restored corpse terminates within original finite fall bound")
	check(remains.accepted_starts==starts and art.get("feedback_particles").emitted_bursts==bursts and int(audio.played.get(&"enemy_defeat",0))==cues,"all restore/corrupt/released cases preserve death/audio/particle idempotence")
	await cleanup()

func run() -> void:
	for underworld: bool in [false,true]: await snapshot_case(underworld)
	print("ENEMY_CORPSE_SNAPSHOT checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
