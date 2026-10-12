extends "res://tests/windkeeper_runner.gd"
## Works on both ab51fca and current implementation; no simulated damage after entry.
func run() -> void:
	await fixture(Vector2(350,452))
	encounter.health.apply_damage(ActorResourceRequest.new(&"final_pier_fixture",encounter.health.epoch,8,encounter.health.get_instance_id()))
	await frames(310)
	var trace := FileAccess.open("user://final-pier-trace.csv",FileAccess.WRITE)
	trace.store_line("tick,phase,mode,pier,boss_x,clock,boss_hp,player_hp")
	var previous := boss.position.x
	var rewinds := 0
	for tick: int in 3000:
		await frames(1)
		if boss.position.x < previous - 10: rewinds += 1
		previous = boss.position.x
		trace.store_line("%s,%s,%s,%s,%.3f,%.3f,%.0f,%.0f" % [tick,encounter.stage_phase,encounter.mode,encounter.chase_segment,boss.position.x,encounter.clock,encounter.health.current,controller.actor_resources.health.current])
	trace.close()
	check(rewinds == 0, "missing all three windows must never rewind Boss")
	check(encounter.chase_segment == 2, "unbeaten Boss stays at final pier")
	print("FINAL PIER REPRO: rewinds=%s final_pier=%s x=%.3f assertions=%s failures=%s" % [rewinds,encounter.chase_segment,boss.position.x,assertions,failures])
	world.free()
	await process_frame
	quit(1 if failures else 0)
