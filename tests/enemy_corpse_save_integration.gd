extends "res://tests/enemy_feedback_01_formal.gd"
## Original strict formal consumer plus exact persisted pixel/support pose checks.
var saved_poses: Dictionary = {}

func verify_actual_reload() -> void:
	var current := app.stage as PlainsRegionStage
	current.capture_state()
	for result: Dictionary in results:
		if result.status != "verified": continue
		var saved: Dictionary = app.region_state.actors[result.id]
		var pose: Dictionary = saved.get("presentation_remains",{})
		check(not pose.is_empty(),"actual settled corpse has an optional versioned presentation snapshot")
		if not pose.is_empty(): saved_poses[result.id]=pose.duplicate(true)
		for index: int in current.enemies.size():
			if str(current.enemy_manifest[index].id) != str(result.id): continue
			var remains := (current.enemies[index].get_node("Presentation") as UnderworldEnemy).feedback_remains
			print("CORPSE_SAVE_BEFORE ",result.id," pose=",JSON.stringify(pose)," support=",remains.support_node().get_path() if is_instance_valid(remains.support_node()) else "missing"," settled=",remains.settled)
	await super.verify_actual_reload()
	var rebuilt := app.stage as PlainsRegionStage
	for index: int in rebuilt.enemies.size():
		var id: String = rebuilt.enemy_manifest[index].id
		if not saved_poses.has(id): continue
		var art := rebuilt.enemies[index].get_node("Presentation") as UnderworldEnemy
		var remains := art.feedback_remains
		var pose: Dictionary = saved_poses[id]
		print("CORPSE_SAVE_AFTER ",id," position=",remains.position," status=",remains.restore_support_status," visible=",remains.visible)
		var support := remains.support_node()
		var anchor := Vector2(pose.support_anchor[0],pose.support_anchor[1])
		var foot := remains.global_position+Vector2(0,float(remains.get("_frame_foot")))
		check(is_instance_valid(support) and foot.distance_to(support.to_global(anchor))<.01,"formal reload retains actual support-local corpse foot while its carrier moves")
		check(remains.restore_support_verified and remains.restore_support_status==&"saved_support_contact","formal corpse resolves its stable saved support and local contact")
