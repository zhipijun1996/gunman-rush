extends "res://tests/forest_bible_world_air_case.gd"
## Actual-input v18 recovery; historical air phrases retain their old reader.
var hang_recovery := preload("res://tests/forest_places_hang_recovery_case.gd").new()
func drive(trace: Node, leg: Dictionary) -> void:
	if bool(leg.get("places_fixed_hang_recovery",false)):
		hang_recovery.drive(trace,leg)
	else:
		super.drive(trace,leg)
