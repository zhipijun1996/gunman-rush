extends SceneTree
# Match the existing manifest-first integration runner load order.
const MANIFEST = preload("res://scripts/run/run_manifest.gd")
var result: Dictionary = {}
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var helper: Node=load("res://docs/quality/reviews/FOREST-GRAPPLE-02/save_counterexample_case.gd").new()
 root.add_child(helper)
 await helper.run()
 result={"checks":helper.checks.duplicate(true),"failures":helper.failures,"cases":helper.cases.duplicate(true)}
 helper.free()
 finish.call_deferred()
func finish() -> void:
 var file := FileAccess.open("res://docs/quality/reviews/FOREST-GRAPPLE-02/save_counterexamples04.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(result));file.close()
 print("SAVE INDEPENDENT: ",result.checks.size()," checks / ",result.failures," failures")
 quit(1 if result.failures else 0)
