extends "res://tests/plains_environment_trace.gd"
## Reuse accepted Router/Motor traversal; never synthesize a prototype visit.
const REQUIRED_PROTOTYPES := ["wind_meadow", "postal_valley", "lee_court"]
var places_route_contract: Dictionary = {}
var places_waypoint_observations: Array = []

func attach(application: DemoApp, selected_strategy: String, wait_ticks: int, selected_policy: String = "blind_legacy") -> bool:
	if not super.attach(application, selected_strategy, wait_ticks, selected_policy): return false
	var instances: Variant = _plan.get("place_instances")
	var order: Variant = _plan.get("place_order")
	var prototypes: Variant = _plan.get("prototype_order")
	if not instances is Array or instances.size() != REQUIRED_PROTOTYPES.size() or not order is Array or not prototypes is Array:
		return reject_setup("three realized place instances/order missing")
	var actual_ids: Array = []
	var actual_prototypes: Array = []
	for row: Variant in instances:
		if not row is Dictionary or not row.get("id") is String or str(row.id).is_empty() or row.id in actual_ids:
			return reject_setup("place instance identity")
		if row.get("prototype_id") not in REQUIRED_PROTOTYPES or row.prototype_id in actual_prototypes:
			return reject_setup("distinct place prototype identity")
		var translation: Variant = row.get("translation")
		if not translation is Array or translation.size() != 2: return reject_setup("place translation")
		for value: Variant in translation:
			if not (value is int or value is float) or not is_finite(float(value)): return reject_setup("nonfinite place translation")
		var digest := str(row.get("source_measurement_sha256", ""))
		if digest.length() != 64 or not digest.is_valid_hex_number(false): return reject_setup("place measurement source identity")
		actual_ids.append(row.id)
		actual_prototypes.append(row.prototype_id)
	if actual_ids != order or actual_prototypes != prototypes: return reject_setup("actual instance/prototype order differs")
	places_route_contract = {"place_instances": instances.duplicate(true), "place_order": order.duplicate(), "prototype_order": prototypes.duplicate(), "scope": "Resolved identities/placements only; actual visited cases remain required and seed hash alone proves no spatial variety"}
	event("places_route_contract", places_route_contract)
	return true

func visit(id: String) -> bool:
	var ok := await super.visit(id)
	if environment_cases.is_empty() or environment_cases[-1].get("id") != id: return ok
	for instance: Dictionary in places_route_contract.get("place_instances", []):
		if not id.begins_with(str(instance.id) + "/"): continue
		var actual: Dictionary = environment_cases[-1]
		places_waypoint_observations.append({"waypoint_id": id, "place_instance_id": instance.id, "prototype_id": instance.prototype_id, "passed": ok, "start_tick": actual.start_tick, "end_tick": actual.end_tick, "position": actual.position, "supported": actual.supported})
		break
	return ok
