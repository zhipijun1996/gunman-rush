extends "res://tests/forest_depth_region_trace.gd"
## Same real map and whole normal-input route. Counterfactual changes ONE shot direction.
var error_control := false
var changed_shot := false
func request(kind: StringName, aim:=Vector2.ZERO) -> void:
	if error_control and not changed_shot and kind==&"shoot_release" and phase=="hollow_upper_hook":
		changed_shot=true
		var wrong_aim:=Vector2(-1,1).normalized()
		event("thorn_wrong_recoil_direction",{"purpose_aim":pair(aim),"actual_aim":pair(wrong_aim),"reason":"down-left shot lifts body toward visible thorn ceiling instead of horizontal rightward exit"})
		super.request(kind,wrong_aim)
	else: super.request(kind,aim)
func begin() -> void:
	await super.begin()
	if initialized:
		app.segment.returned.connect(_actual_segment_return)
func _actual_segment_return(anchor_id: StringName) -> void:
	# The formal App/Policy/Segment already performed this return; the driver
	# only selects its next input from the real returned support. No body write.
	event("actual_thorn_segment_return",{"anchor_id":String(anchor_id),"actor_epoch":app.lifetime.actor_epoch,"supports":supports()})
	if error_control and changed_shot and leg_index<itinerary.size() and itinerary[leg_index].kind=="hollow_upper":
		last_hook=""
		controller.router.clear("thorn_error_retry")
		set_phase("align")
