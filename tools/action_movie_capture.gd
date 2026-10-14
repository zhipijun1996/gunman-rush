extends "res://tests/action_budget_capture.gd"
func drive()->void:
	super.drive()
	if trace.is_empty() or not is_instance_valid(studio):return
	var runtime := studio.controller.shoot_ability.behavior()
	var points: Array=[]
	for point: Vector2 in runtime.beam_visual_segment():points.append([point.x,point.y])
	var muzzle := (studio.player.get_node("CourierVisual") as CourierVisual).visible_muzzle_position()
	trace[-1]["beam_visual"]=points
	trace[-1]["beam_muzzle"]=[muzzle.x,muzzle.y]
