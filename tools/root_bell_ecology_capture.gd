extends "res://tools/level_formal_capture.gd"
func make_application() -> DemoApp:
	var result := DemoApp.new()
	var fields: Array = result.get_property_list().map(func(p: Dictionary):return p.name)
	if "root_bell_pilot_requested" in fields:
		var pilot := "--root-bell-default" not in OS.get_cmdline_user_args()
		result.set("root_bell_space_pilot_requested",pilot)
		report["root_bell_admission_scope"] = "explicit encounter-v3 pilot in original formal generated DemoApp; no default-path validation claim" if pilot else "default admitted encounter-v3 limited runtime candidate through ordinary DemoApp run configuration; no pilot override; commercial/user/device acceptance unverified"
	else:
		report["root_bell_admission_scope"] = "legacy comparison with identical observer; no root pilot or promotion claim"
	return result
func make_driver() -> RefCounted:
	return preload("res://tests/root_bell_ecology_trace.gd").new()
func save_report() -> bool:
	if driver != null:
		report["captured_scope"]["target_activity_counterfactual"] = "inactive_target_cancel_fixture explicitly sets controller.active=false for three native ticks; separate from 17 Router movement/combat cases and one production pause callback; no resource or position assignment"
		report["root_bell_cases"] = driver.root_cases
		report["root_bell_identity"] = driver.root_id
	return super.save_report()
func policy_basis() -> Dictionary:
	var result := super.policy_basis()
	collect_driver_sources("res://tools/root_bell_ecology_capture.gd",result.driver_sources)
	return result
