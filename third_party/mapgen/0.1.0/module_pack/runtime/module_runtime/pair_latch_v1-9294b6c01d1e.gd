extends ShotLatch
## Original projectile eligibility/identity/lifetime, two atomic real gates.
## This is an isolated Cell; original ShotLatch and character are unchanged.
var paired_gate_rect := Rect2()
var paired_gate_body: StaticBody2D
var paired_gate_shape: CollisionShape2D
var open_a := true
var blocked_count := 0
var pair_events: Array=[]
var frame_source
const BODY_HALF := Vector2(12,18)
const SAFETY_MARGIN := 6.0

func setup_pair(player: PlayerController, scope: DemoLifetime, bell: Vector2, first: Rect2, second: Rect2, initial_open: String, clock_source) -> void:
	frame_source=clock_source
	paired_gate_rect=second
	# motion_mode keeps the ORIGINAL receiver reusable. No motion_target exists;
	# _commit_open and _draw below own all pair behavior.
	motion_mode=true
	open_seconds=0.0
	super.setup(player,scope,bell,first)
	paired_gate_body=StaticBody2D.new()
	paired_gate_body.position=second.get_center()
	paired_gate_body.collision_layer=1
	paired_gate_body.collision_mask=0
	paired_gate_shape=CollisionShape2D.new()
	var shape:=RectangleShape2D.new();shape.size=second.size
	paired_gate_shape.shape=shape;paired_gate_body.add_child(paired_gate_shape)
	add_child(paired_gate_body)
	open_a=initial_open=="A"
	_apply_pair_state()

func _apply_pair_state() -> void:
	# Runs only during setup or the ORIGINAL deferred commit, outside queries.
	# Both assignments complete in one call before signals/observers can run.
	gate_body.collision_layer=0 if open_a else 1
	gate_shape.disabled=open_a
	paired_gate_body.collision_layer=1 if open_a else 0
	paired_gate_shape.disabled=not open_a
	is_open=open_a
	queue_redraw()

func _commit_open(request: Dictionary) -> void:
	# Same request/lifetime/player/health guard as original ShotLatch.
	if request.is_empty() or request.get("request_epoch",-1)!=_request_epoch or _cancelled or not is_inside_tree() or not lifetime.accepts(request.token) or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id!=request.session or health.epoch!=request.health_epoch:return
	var closing:=gate_rect if open_a else paired_gate_rect
	var body:=Rect2(to_local(controller.motor.global_position)-BODY_HALF,BODY_HALF*2.0)
	if closing.grow(SAFETY_MARGIN).intersects(body,true):
		blocked_count+=1
		pair_events.append({"frame":frame_source.frame,"type":"pair_switch_blocked","id":link_id,"closing":"A" if open_a else "B","reason":"body_clearance","body":[body.position.x,body.position.y,body.size.x,body.size.y]})
		_eligible_shots.clear();_seen.clear()
		_opened_at=_clock;_play_bell();queue_redraw()
		return
	open_a=not open_a
	_apply_pair_state()
	_opened_at=_clock;open_count+=1
	_eligible_shots.clear();_seen.clear()
	pair_events.append({"frame":frame_source.frame,"type":"pair_switch","id":link_id,"open":"A" if open_a else "B","switch_count":open_count,"airborne":not controller.motor.is_on_floor()})
	_play_bell();opened.emit();queue_redraw()

func snapshot_pair() -> Dictionary:
	return {"id":link_id,"open_a":open_a,"open_b":not open_a,"gate_a_layer":gate_body.collision_layer,"gate_b_layer":paired_gate_body.collision_layer,"gate_a_disabled":gate_shape.disabled,"gate_b_disabled":paired_gate_shape.disabled,"switch_count":open_count,"blocked_count":blocked_count,"events":pair_events.duplicate(true)}

func _draw() -> void:
	if not is_instance_valid(paired_gate_body):return
	var gold:=Color("e8bd65")
	var blue:=Color("69c9da")
	# Reuse original formal geometry artwork, with explicit complementary state.
	_draw_gate(gate_rect,0.20 if open_a else 1.0)
	_draw_gate(paired_gate_rect,1.0 if open_a else 0.20)
	draw_line(bell_position+Vector2(0,-62),bell_position+Vector2(0,-17),Color("8b6744"),3)
	if UnderworldActors.enabled(self):UnderworldTerrain.draw_mechanism_bell(self,bell_position,open_a,_opened_at>=0 and _clock-_opened_at<.16)
	elif PixelFormalActors.pixel_context(self):PixelFormalActors.bell(self,bell_position,open_a)
	else:draw_texture_rect_region(BELL_ART,Rect2(bell_position-Vector2(14,26),Vector2(28,49.4)),Rect2(200,8,746,1316))
	for item: Dictionary in [{"rect":gate_rect,"name":"A","open":open_a},{"rect":paired_gate_rect,"name":"B","open":not open_a}]:
		var r: Rect2=item.rect
		var tone:=blue if item.open else gold
		draw_polyline(PackedVector2Array([bell_position+Vector2(0,-40),Vector2(r.get_center().x,bell_position.y-40),r.get_center()]),Color(tone,.42),2)
		draw_string(ThemeDB.fallback_font,r.position+Vector2(-12,-10),str(item.name)+(" OPEN" if item.open else " CLOSED"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,tone)
	draw_string(ThemeDB.fallback_font,bell_position+Vector2(-52,-78),"SHOOT: SWAP A / B",HORIZONTAL_ALIGNMENT_LEFT,-1,14,gold)
