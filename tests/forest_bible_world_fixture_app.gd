extends "res://scripts/demo/demo_app.gd"
## EXPLICIT LOCAL FEEDBACK FIXTURE. The formal fullspawn runner never uses this.
## One initial spawn at the authored root fork, before the first Motor step.
var fixture_data: Dictionary = {}
var fixture_error := ""
func _load_stage() -> void:
	super._load_stage()
	if not is_instance_valid(player) or player.motion_steps != 0:
		fixture_error = "fixture_refused_after_first_Motor_step"; return
	if not is_instance_valid(stage) or not stage.assembly_ok:
		fixture_error = "fixture_actual_stage_missing"; return
	var pose := Vector2.ZERO
	for row: Dictionary in stage.generated.manifest.areas:
		if str(row.id) == "bible_root_fork": pose = Vector2(row.position[0],row.position[1])
	if pose == Vector2.ZERO: fixture_error = "fixture_authored_root_fork_missing"; return
	fixture_data = {"initial_fixture_spawn_override":true,"original_formal_spawn":[player.global_position.x,player.global_position.y],"actual_fixture_spawn":[pose.x,pose.y],"motion_steps_before_override":player.motion_steps,"resource_or_health_override":false,"lifecycle":"actual_App_after_synchronous_stage_assembly_before_first_Motor_step"}
	player.global_position = pose
