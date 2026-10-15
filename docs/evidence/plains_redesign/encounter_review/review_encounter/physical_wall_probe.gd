extends "res://tests/plains_encounter_policy_runner.gd"
func run() -> void:
	await fixture("charger",true)
	for child: Node in world.get_children():
		if child is StaticBody2D and absf((child as StaticBody2D).position.x-335)<1:
			child.free()
	await fire(Vector2.RIGHT)
	await advance(40)
	verify(actor.health.current==actor.health.capacity,"independent native counterexample: removing REAL blocker must falsify original occlusion guard")
	print("INDEPENDENT WALL PROBE: hp=",actor.health.current," capacity=",actor.health.capacity," committed=",count_kind("committed")," failures=",failures)
	var f:=FileAccess.open("res://build/plains_redesign/review_encounter/physical_wall_probe.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"assertions":assertions,"failures":failures,"events":events,"frames":frames,"enemy_health":actor.health.current,"enemy_capacity":actor.health.capacity}));f.close()
	world.free()
	quit(1 if failures else 0)
