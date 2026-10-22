extends "res://scripts/demo/demo_app.gd"
## Explicit local feedback only. One authored initial pose before Motor tick 1.
var fixture_area := "varied_observation"
var fixture_data: Dictionary = {}
var fixture_error := ""
func _load_stage() -> void:
	super._load_stage()
	if not is_instance_valid(player) or player.motion_steps != 0:
		fixture_error = "varied_fixture_refused_after_first_Motor_step"; return
	if not is_instance_valid(stage) or not stage.assembly_ok:
		fixture_error = "varied_fixture_actual_stage_missing"; return
	var actual: Array = []
	for row: Dictionary in stage.generated.manifest.areas:
		if str(row.id) == fixture_area: actual = row.position.duplicate()
	if actual.is_empty(): fixture_error = "varied_fixture_authored_area_missing"; return
	fixture_data = {"initial_fixture_spawn_override":true,"area":fixture_area,"original_formal_spawn":[player.global_position.x,player.global_position.y],"actual_fixture_spawn":actual,"motion_steps_before_override":player.motion_steps,"resource_or_health_override":false,"lifecycle":"actual_App_after_synchronous_assembly_before_first_Motor_step"}
	player.global_position = Vector2(actual[0],actual[1])
