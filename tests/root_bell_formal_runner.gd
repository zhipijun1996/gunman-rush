extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var suite := preload("res://tests/root_bell_formal_tests.gd").new()
	var result := suite.audit("--current-g1" in OS.get_cmdline_user_args())
	result["physical_negatives"] = suite.physical_negatives()
	result["legacy_live_loader_compatibility"] = await suite.compatibility(self)
	if not result.physical_negatives.failures.is_empty() or not result.legacy_live_loader_compatibility.passed:result.failures.append("physical_negative_or_legacy_loader")
	result["run_manifest_replay"] = await suite.run_manifest_replay(self)
	if not result.run_manifest_replay.passed: result.failures.append("run_manifest_versioned_replay")
	var output := "res://build/region_production_v3/enemy_encounter_v2/audit_01.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	if FileAccess.file_exists(output):quit(1);return
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(result)+"\n")
	var admitted: Array = result.rows.filter(func(r: Dictionary) -> bool:return r.candidate.replaced==1)
	print("ROOT BELL V2 AUDIT: rows=",result.rows.size()," eligible=",admitted.size()," failures=",result.failures.size())
	for row: Dictionary in admitted:print("V2 ELIGIBLE: ",row.root_seed," map",row.map_index," ",row.candidate.module)
	# Let completed async save/loader states and queued frees release before exit.
	var exit_code := 0 if result.failures.is_empty() else 1
	suite = null
	await process_frame
	await process_frame
	quit.call_deferred(exit_code)
