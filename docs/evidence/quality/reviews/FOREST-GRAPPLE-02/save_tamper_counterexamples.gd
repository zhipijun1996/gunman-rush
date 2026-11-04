extends SceneTree
const MANIFEST := preload("res://scripts/run/run_manifest.gd")
var checks: Array=[]
var failures := 0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks.append({"passed":value,"label":label})
	if not value:failures+=1;printerr("SAVE TAMPER FAIL: "+label)
func run() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/quality/reviews/FOREST-GRAPPLE-02/save_counterexamples04.json"))
	for case: Dictionary in source.cases:
		var label := "%s/map%s" % [case.mode,case.map_index]
		var original: Dictionary=case.snapshot
		check(MANIFEST.from_snapshot(original)!=null,label+" actual positive snapshot")
		var historical:=original.duplicate(true)
		historical.stages[0].outputs.stage_tuning.focus_time_scale=.2
		var before:=JSON.stringify(historical,"",true)
		var restored:=MANIFEST.from_snapshot(historical)
		check(restored!=null and restored.canonical_json()==before and JSON.stringify(historical,"",true)==before,label+" known historical focus accepted without mutation")
		for mutation: String in ["focus","gravity","items","unknown_hash","missing","extra"]:
			var bad:=historical.duplicate(true)
			var output: Dictionary=bad.stages[0].outputs
			match mutation:
				"focus":output.stage_tuning.focus_time_scale=.19
				"gravity":output.stage_tuning.gravity+=1
				"items":output.capability_snapshot.items=["missing_item"]
				"unknown_hash":
					output.generated_layout.player_tuning_hash="f".repeat(64)
					output.generated_layout.manifest_hash=RandomStageGenerator.new()._manifest_hash(output.generated_layout)
				"missing":output.stage_tuning.erase("gravity")
				"extra":output.stage_tuning.unknown_physics=1
			check(MANIFEST.from_snapshot(bad)==null,label+" rejects "+mutation)
	finish.call_deferred()
func finish() -> void:
	var file:=FileAccess.open("res://docs/quality/reviews/FOREST-GRAPPLE-02/save_tamper_counterexamples01.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}));file.close()
	print("SAVE TAMPER INDEPENDENT: ",checks.size()," checks / ",failures," failures")
	quit(1 if failures else 0)
