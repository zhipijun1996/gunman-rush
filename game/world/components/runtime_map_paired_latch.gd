class_name RuntimeMapPairedLatch
extends ShotLatch
## Original module-pack pair semantics: atomic complementary gates, real actor
## clearance, and the inherited projectile/lifetime transaction.
var paired_gate_rect:=Rect2()
var paired_gate_body: StaticBody2D
var paired_gate_shape: CollisionShape2D
var open_a:=true
var blocked_count:=0
var reward_only:=false
func setup_pair(player: PlayerController, scope: DemoLifetime, bell: Vector2, first: Rect2, second: Rect2, initial_open: String) -> void:
	repeatable=true
	paired_gate_rect=second
	super.setup(player,scope,bell,first)
	paired_gate_body=StaticBody2D.new();paired_gate_body.position=second.get_center();paired_gate_body.collision_mask=0
	paired_gate_shape=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new();rectangle.size=second.size
	paired_gate_shape.shape=rectangle;paired_gate_body.add_child(paired_gate_shape);add_child(paired_gate_body)
	open_a=initial_open=="A"
	_apply_pair_state()
	if reward_only: bell_body.collision_layer=0
func _register_shot(direction: Vector2,id: int) -> void:
	if not reward_only:super._register_shot(direction,id)
func _receive_projectile(hit: Dictionary) -> bool:
	return false if reward_only else super._receive_projectile(hit)
func accept_claim(id: String) -> void:
	if not reward_only or not open_a or id.is_empty():return
	_commit_open({"id":id,"token":lifetime.token(),"session":controller.session_id,"health_epoch":health.epoch,"request_epoch":_request_epoch,"claimed":true})
func _commit_open(request: Dictionary) -> void:
	if not request_is_current(request) or reward_only and not request.get("claimed",false):return
	var closing:=gate_rect if open_a else paired_gate_rect
	var shape:=RectangleShape2D.new();shape.size=closing.size+Vector2.ONE*12
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape;query.transform=global_transform*Transform2D(0,closing.get_center());query.collision_mask=0xFFFFFFFF
	query.collide_with_bodies=true;query.collide_with_areas=false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query,1024):
		if hit.collider is CharacterBody2D:
			blocked_count+=1;_eligible_shots.clear();_seen.clear();_opened_at=_clock;_play_bell();return
	open_a=not open_a
	_apply_pair_state()
	_opened_at=_clock;open_count+=1;_eligible_shots.clear();_seen.clear();_play_bell();opened.emit()
func _apply_pair_state() -> void:
	# Close first, then open, without a query, signal or yield in between.
	var closing: StaticBody2D=paired_gate_body if open_a else gate_body
	var opening: StaticBody2D=gate_body if open_a else paired_gate_body
	var closed_shape: CollisionShape2D=paired_gate_shape if open_a else gate_shape
	var open_shape: CollisionShape2D=gate_shape if open_a else paired_gate_shape
	closing.collision_layer=1;closed_shape.disabled=false
	opening.collision_layer=0;open_shape.disabled=true
	is_open=open_a;queue_redraw()
func region_snapshot() -> Dictionary:
	var data:=super.region_snapshot();data["pair_open_a"]=open_a;return data
func restore_region_state(data: Dictionary) -> void:
	super.restore_region_state(data);open_a=bool(data.pair_open_a);_apply_pair_state()
func restore_region_opened(_recorded: bool) -> void:pass
func _draw() -> void:
	if not is_instance_valid(paired_gate_body):return
	_draw_gate(gate_rect,.18 if open_a else 1)
	_draw_gate(paired_gate_rect,1 if open_a else .18)
	if not reward_only:
		UnderworldTerrain.draw_mechanism_bell(self,bell_position,open_a,_opened_at>=0 and _clock-_opened_at<.16)
		_draw_sigil(bell_position+Vector2(-28,-45),sigil_index,28)
	_draw_sigil(gate_rect.position+Vector2(12,-22),sigil_index,24)
	_draw_sigil(paired_gate_rect.position+Vector2(12,-22),sigil_index,24)
