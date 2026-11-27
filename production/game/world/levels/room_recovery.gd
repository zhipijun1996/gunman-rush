class_name RoomRecovery
extends RefCounted

var entry_point := Vector2.INF
var entry_verified := false
var selected := {}
var section := ""
var occupied := {}

func observe(room: FixedWorldRoom,player: PlayerMotor) -> void:
	var prior := str(selected.get("id",""))
	var area := room.section_at(player.position)
	if area != section:
		section = area
		selected = {}
		occupied.clear()
	for anchor: Dictionary in room.retry_anchors:
		if anchor.section != section: continue
		var id := str(anchor.id)
		var inside := FixedWorldProvider.rect(anchor.bounds).has_point(player.position)
		if inside and not occupied.get(id,false):
			var point := FixedWorldProvider.point(anchor.point)
			if room.section_at(point) == section and safe(room,player,point,true): selected = anchor
		occupied[id] = inside
	var current := str(selected.get("id",""))
	if prior != current:
		for id: String in [prior,current]:
			var marker: RoomWaymarker = room.recovery_markers.get(id)
			if marker:
				marker.selected = id == current
				marker.queue_redraw()

func observe_arrival(room: FixedWorldRoom, player: PlayerMotor) -> void:
	if entry_verified or not player.is_on_floor(): return
	if not safe(room, player, entry_point):
		if not safe(room, player, player.position): return
		entry_point = player.position
	entry_verified = true

func safe(room: FixedWorldRoom, player: PlayerMotor, point: Vector2, check_approach := false) -> bool:
	var shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var space := player.get_world_2d().direct_space_state
	var center := room.to_global(point)
	var half := (shape.shape as RectangleShape2D).size*0.5
	var query := PhysicsShapeQueryParameters2D.new()
	var clearance := RectangleShape2D.new()
	clearance.size = half*2.0-Vector2(0.2,0.2)
	query.shape = clearance
	query.transform = Transform2D(0,center+shape.position)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	if not space.intersect_shape(query,1).is_empty(): return false
	var rest_box := Rect2(query.transform.origin-half,half*2)
	for danger: Rect2 in room.hazards:
		if rest_box.intersects(room.global_transform * danger): return false
	for strip: Dictionary in room.spike_strips:
		if rest_box.intersects(room.global_transform * FixedWorldProvider.rect(strip.bounds)): return false
	for zone: Dictionary in room.environment_zones:
		if zone.mode in ["phase_light","thorns","water","gas"] and rest_box.intersects(room.global_transform * FixedWorldProvider.rect(zone.bounds)): return false
	for component: Node in room.element_runtime.nodes.values():
		if component is WorldHazardArea and rest_box.intersects(component.global_transform * component.rect): return false
	# Both feet must be supported. A narrow corner cannot serve as a safe restart.
	for side: float in [-1.0,1.0]:
		var foot := center+shape.position+Vector2(side*(half.x-1),half.y)
		var ray := PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,3),1,query.exclude)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y >= -0.7: return false
		var support := hit.collider as Node
		if not (support.has_meta(&"world_ground") or support.has_meta(&"world_ground_polygon") or support is WorldMotionSurface): return false
	if center.distance_squared_to(player.global_position)>0.1 and check_approach:
		query.transform = shape.global_transform
		query.motion = center-player.global_position
		if space.cast_motion(query)[0] < 1.0: return false
	return true

func retry(session: OrdinaryRoomSession) -> void:
	if not session.controller.active or session.controller.actor_resources.health.terminal: return
	var point := entry_point
	var reset_section := session.room.section_at(session.player.position)
	if not selected.is_empty():
		point = FixedWorldProvider.point(selected.point)
		if reset_section != section or session.room.section_at(point) != section: return
	elif not session.room.retry_anchors.is_empty():
		# Authored segments choose their own safe side.
		return
	if not point.is_finite() or not safe(session.room,session.player,point): return
	if session.controller.return_to_segment(point):
		session.lifetime.invalidate_actor()
		session.room.element_runtime.reset_section(reset_section)
		session.policy.protect_player()
