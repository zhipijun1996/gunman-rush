extends SceneTree
## Actual installed entities/pickups. Encounter count is NOT inferred from totals.
var failures := 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var records := []
	var kinds: Array[StringName] = [&"combat",&"combat",&"item_reward",&"shop",&"combat",&"item_reward",&"health_reward",&"boss"]
	for seed: String in ["polish-density-0","polish-density-1","polish-density-2"]:
		for index: int in range(1,9):
			var data := PlainsStageGenerator.new().generate(seed,index,kinds[index-1],PlayerTuning.load_default())
			if not data.ok:
				failures += 1
				push_error(data.error)
				continue
			var stage := GeneratedDemoStage.new()
			stage.configure(index,kinds[index-1],[])
			stage.configure_generated(data,PlayerTuning.load_default())
			root.add_child(stage)
			var coins := 0
			var notes := 0
			for pickup: Dictionary in stage.pickups:
				if pickup.kind == "coin": coins += int(pickup.amount)
				if pickup.kind == "note": notes += int(pickup.amount)
			var latch_types := []
			for bell: Dictionary in data.manifest.shot_latch_plan.latches: latch_types.append(bell.kind)
			records.append({"seed":seed,"room":index,"type":kinds[index-1],"blueprint":data.manifest.blueprint_plan.blueprint_id,"modules":data.manifest.nodes.size(),"bells":latch_types,"enemies_installed":stage.enemies.size(),"routes":stage.encounter_plan.routes,"coins_available":coins,"notes_available":notes,"enemy_kill_rewards":"unchanged config/enemy_drops.json; not earned in this report","encountered_enemies":null,"triggered_bells":null})
			stage.queue_free()
			await process_frame
			await process_frame
	DirAccess.make_dir_recursive_absolute("res://build/verification/polish-density")
	var output := FileAccess.open("res://build/verification/polish-density/current.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"scope":"fixed route type comparison fixture; installed counts, not real eight-room playtest","records":records},"\t"))
	output.close()
	print("POLISH DENSITY REPORT: 24 installed rooms, failures=",failures)
	quit(1 if failures else 0)
