extends "pair_latch_v1-9294b6c01d1e.gd"
## V2 retains the V1 player guard and also refuses to close through real actors.
## Query Godot's actual collision shapes; never test an enemy centre alone.
func _commit_open(request: Dictionary) -> void:
	if request.is_empty() or request.get("request_epoch",-1)!=_request_epoch or _cancelled or not is_inside_tree() or not lifetime.accepts(request.token) or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id!=request.session or health.epoch!=request.health_epoch:return
	var closing:=gate_rect if open_a else paired_gate_rect
	var shape:=RectangleShape2D.new();shape.size=closing.size+Vector2.ONE*SAFETY_MARGIN*2.0
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape
	query.transform=global_transform*Transform2D(0,closing.get_center())
	query.collision_mask=0xFFFFFFFF;query.collide_with_bodies=true;query.collide_with_areas=false
	query.exclude=[gate_body.get_rid(),paired_gate_body.get_rid(),bell_body.get_rid()]
	var blockers: Array=[]
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query,1024):
		var body: Object=hit.collider
		if not body is CharacterBody2D:continue
		var at: Vector2=to_local(body.global_position)
		blockers.append({"kind":"player" if body is PlayerMotor else "enemy" if body is EnemyMotor else "character_body","position":[at.x,at.y]})
	if not blockers.is_empty():
		blocked_count+=1
		pair_events.append({"frame":frame_source.frame,"type":"pair_switch_blocked","id":link_id,"closing":"A" if open_a else "B","reason":"actual_actor_collision_shape","blockers":blockers})
		_eligible_shots.clear();_seen.clear();_opened_at=_clock;_play_bell();queue_redraw()
		return
	super._commit_open(request)
