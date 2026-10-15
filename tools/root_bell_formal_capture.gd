extends "res://tools/level_formal_capture.gd"
func make_application() -> DemoApp:
	var result := DemoApp.new()
	var fields: Array = result.get_property_list().map(func(p: Dictionary):return p.name)
	if "root_bell_pilot_requested" in fields:
		var pilot := "--root-bell-default" not in OS.get_cmdline_user_args()
		result.set("root_bell_pilot_requested",pilot)
		report["root_bell_admission_scope"] = "explicit encounter-v2 pilot in original formal generated DemoApp; default production gate remains false pending independent review" if pilot else "default admitted encounter-v2 through ordinary DemoApp run configuration; no pilot override"
	else:
		report["root_bell_admission_scope"] = "legacy comparison with identical observer; no root pilot or promotion claim"
	return result
func make_driver() -> RefCounted:
	return preload("res://tests/root_bell_formal_trace.gd").new()
func save_report() -> bool:
	if driver != null:
		report["root_bell_cases"] = driver.root_cases
		report["root_bell_identity"] = driver.root_id
	return super.save_report()
func policy_basis() -> Dictionary:
	var result := super.policy_basis()
	collect_driver_sources("res://tools/root_bell_formal_capture.gd",result.driver_sources)
	return result
