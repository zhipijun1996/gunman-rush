class_name ShotLatch
extends Node2D
## Local, one-way shot switch. Actual projectile collision owns hit delivery.
signal opened
const GATE_ART := preload("res://assets/plains_v3/windchime_gate_beam.png")
const BELL_ART := preload("res://assets/plains_v3/windchime_switch.png")
const BELL_SOUND := preload("res://assets/audio/kenney/bell.ogg")
var access_bodies: Array[StaticBody2D] = []
var access_positions: Array[Vector2] = []
var _bell_audio: AudioStreamPlayer2D
var link_id := "A"
var sigil_index := 0
var motion_target: ModuleMovingPlatform
var motion_mode := false
var link_color := Color("e8bd65")
var _clock := 0.0
var prompt_text := ""
var formal_presentation := false
var region_presentation := false
var _opened_at := -1.0
var controller: PlayerController
var lifetime: DemoLifetime
var health := HealthState.new()
var receiver: Damageable
var bell_body: StaticBody2D
var gate_body: StaticBody2D
var gate_shape: CollisionShape2D
var bell_position := Vector2.ZERO
var gate_rect := Rect2()
var is_open := false
var open_seconds := 0.0
var sequence_offset := Vector2.ZERO
var sequence_gate_rect:=Rect2()
var sequence_gate_body:StaticBody2D
var sequence_gate_shape:CollisionShape2D
var sequence_step := 0
var _second_body: StaticBody2D
var _second_receiver: Damageable
var open_count := 0
var _pending: Dictionary = {}
var _seen: Dictionary = {}
var _eligible_shots: Dictionary = {}
var _cancelled := false
var _request_epoch := 0

func setup(player: PlayerController, scope: DemoLifetime, bell: Vector2, gate: Rect2) -> void:
	controller = player
	lifetime = scope
	bell_position = bell
	gate_rect = gate
	process_physics_priority = 1150
	_bell_audio = AudioStreamPlayer2D.new()
	_bell_audio.stream = BELL_SOUND
	_bell_audio.volume_db = -10.0
	_bell_audio.max_distance = 1200.0
	_bell_audio.max_polyphony = 1
	_bell_audio.position = bell
	add_child(_bell_audio)
	var definition := HealthDefinition.new()
	definition.resource_id = &"practice_shot_latch"
	definition.max_health = 1.0
	definition.initial_current = 1.0
	health.configure(definition)
	bell_body = StaticBody2D.new()
	bell_body.position = bell
	bell_body.collision_layer = 8
	bell_body.collision_mask = 0
	var bell_shape := CollisionShape2D.new()
	var bell_rectangle := RectangleShape2D.new()
	bell_rectangle.size = Vector2(28, 34)
	bell_shape.shape = bell_rectangle
	bell_body.add_child(bell_shape)
	receiver = Damageable.new()
	receiver.name = "Damageable"
	receiver.faction = &"mechanism"
	receiver.actor_id = bell_body.get_instance_id()
	bell_body.add_child(receiver)
	add_child(bell_body)
	receiver.bind_health(health)
	receiver.damage_sink = _receive_projectile
	if not sequence_offset.is_zero_approx():
		_second_body = StaticBody2D.new()
		_second_body.position = bell + sequence_offset
		_second_body.collision_layer = 8
		_second_body.collision_mask = 0
		var second_shape := CollisionShape2D.new()
		second_shape.shape = bell_rectangle.duplicate()
		_second_body.add_child(second_shape)
		_second_receiver = Damageable.new()
		_second_receiver.name = "Damageable"
		_second_receiver.faction = &"mechanism"
		_second_receiver.actor_id = _second_body.get_instance_id()
		_second_body.add_child(_second_receiver)
		add_child(_second_body)
		_second_receiver.bind_health(health)
		_second_receiver.damage_sink = _receive_projectile
	gate_body = StaticBody2D.new()
	gate_body.position = gate.get_center()
	gate_body.collision_layer = 1
	gate_shape = CollisionShape2D.new()
	var gate_rectangle := RectangleShape2D.new()
	gate_rectangle.size = gate.size
	gate_shape.shape = gate_rectangle
	gate_body.add_child(gate_shape)
	add_child(gate_body)
	if sequence_gate_rect.has_area():
		sequence_gate_body=StaticBody2D.new();sequence_gate_body.position=sequence_gate_rect.get_center();sequence_gate_body.collision_layer=1
		sequence_gate_shape=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=sequence_gate_rect.size;sequence_gate_shape.shape=shape;sequence_gate_body.add_child(sequence_gate_shape);add_child(sequence_gate_body)
	controller.shoot_ability.shot_fired.connect(_register_shot)
	queue_redraw()

func _register_shot(_direction: Vector2, shot_id: int) -> void:
	if not _cancelled and (not is_open or motion_mode) and lifetime.active and controller.active:
		_eligible_shots["%s:%s" % [controller.session_id, shot_id]] = {"token": lifetime.token(), "actor_position":controller.motor.global_position, "expires": _clock + controller.motor.tuning.projectile_lifetime + 1.0 / 60.0}

func _receive_projectile(context: Dictionary) -> bool:
	var key := "%s:%s" % [context.get("session_id", -1), context.get("shot_id", -1)]
	var eligibility: Dictionary = _eligible_shots.get(key, {})
	var token: DemoToken = eligibility.get("token")
	var id := str(context.get("event_id", ""))
	if _cancelled or (is_open and not motion_mode) or not _pending.is_empty() or not lifetime.accepts(token) or id.is_empty() or _seen.has(id):
		return false
	if not controller.active or controller.actor_resources.health.terminal or context.get("source_faction", &"") != &"player" or context.get("source_actor_id", -1) != controller.motor.get_instance_id() or context.get("session_id", -1) != controller.session_id:
		return false
	var expected := _second_receiver if sequence_step == 1 else receiver
	if context.get("target_actor_id", -1) != expected.actor_id or context.get("target_epoch", -1) != health.epoch:
		return false
	_pending = {"id": id, "token": token, "session": controller.session_id, "health_epoch": health.epoch, "request_epoch": _request_epoch}
	_seen[id] = true
	return true

func _physics_process(delta: float) -> void:
	_clock += delta
	if is_open and open_seconds > 0 and _clock - _opened_at >= open_seconds:
		# Never close a timed gate on the player. Both sides are stable waiting floor.
		var actor := to_local(controller.motor.global_position)
		if not gate_rect.grow(24).has_point(actor):
			is_open = false
			gate_body.collision_layer = 1
			gate_shape.set_deferred("disabled", false)
			bell_body.collision_layer = 8
			for access: StaticBody2D in access_bodies: access.collision_layer = 8
			queue_redraw()
	for key: String in _eligible_shots.keys():
		if _eligible_shots[key].expires < _clock:
			_eligible_shots.erase(key)
	if motion_mode or _opened_at>=0 and _clock-_opened_at < 0.70:
		queue_redraw()
	if _pending.is_empty():
		return
	var request := _pending
	_pending = {}
	_commit_open.call_deferred(request)

func _commit_open(request: Dictionary) -> void:
	if request.is_empty() or request.get("request_epoch", -1) != _request_epoch or _cancelled or (is_open and not motion_mode) or not is_inside_tree() or not lifetime.accepts(request.token) or not is_instance_valid(controller) or not controller.active or controller.actor_resources.health.terminal or controller.session_id != request.session or health.epoch != request.health_epoch:
		return
	if not sequence_offset.is_zero_approx() and sequence_step == 0:
		sequence_step = 1
		restore_sequence_gate()
		_opened_at=_clock
		prompt_text = "CLIMB / FIND REMOTE RING 2" if sequence_gate_rect.has_area() else "NOW RING 2 / RETRY ANYTIME"
		_play_bell()
		queue_redraw()
		return
	if motion_mode:
		is_open=not motion_target.motion_running
		motion_target.set_motion_running(is_open)
		_opened_at=_clock
		open_count+=1
		_eligible_shots.clear();_seen.clear()
		_play_bell();opened.emit();queue_redraw()
		return
	if open_seconds <= 0:
		var result := health.apply_damage(ActorResourceRequest.new(StringName(request.id), health.epoch, 1.0, health.get_instance_id()))
		if not result.accepted(): return
	is_open = true
	_opened_at = _clock
	_eligible_shots.clear()
	_seen.clear()
	open_count += 1
	gate_body.collision_layer = 0
	gate_shape.disabled = true
	bell_body.collision_layer = 0
	for access: StaticBody2D in access_bodies: access.collision_layer = 0
	if is_instance_valid(_second_body): _second_body.collision_layer = 0
	_play_bell()
	opened.emit()
	queue_redraw()

func cancel_pending() -> void:
	if is_instance_valid(_bell_audio):
		_bell_audio.stop()
	_request_epoch += 1
	_seen.clear()
	_pending = {}
	_eligible_shots.clear()

func cancel() -> void:
	_cancelled = true
	cancel_pending()

func set_region_presentation(enabled: bool) -> void:
	region_presentation = enabled
	for child: Node in get_children():
		if child is Label and child.text == "RETURN / RIGHT SIDE": child.visible = not enabled
	queue_redraw()

func _context_visible() -> bool:
	return is_instance_valid(controller) and controller.motor.is_on_floor() and to_local(controller.motor.global_position).distance_to(bell_position) < 210

func _draw() -> void:
	if sequence_gate_rect.has_area() and sequence_step==0:_draw_gate(sequence_gate_rect,1.0)
	if not sequence_offset.is_zero_approx():
		var second := bell_position + sequence_offset
		draw_line(second + Vector2(0,-62),second + Vector2(0,-17),Color("8b6744"),3)
		if PixelFormalActors.pixel_context(self): PixelFormalActors.bell(self,second,sequence_step==1 or is_open)
		else: draw_texture_rect_region(BELL_ART,Rect2(second-Vector2(14,26),Vector2(28,49.4)),Rect2(200,8,746,1316), Color.WHITE if sequence_step == 1 else Color(.55,.55,.55))
		draw_string(ThemeDB.fallback_font, bell_position+Vector2(-4,-36), "1", HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		draw_string(ThemeDB.fallback_font, second+Vector2(-4,-36), "2", HORIZONTAL_ALIGNMENT_LEFT,-1,16)
	# The closed gate has matching solid collision, never a misleading platform.
	var gold := link_color if not is_open else Color("89d5ac")
	draw_line(bell_position + Vector2(0, -62), bell_position + Vector2(0, -17), Color("8b6744"), 3)
	if region_presentation:
		draw_set_transform(bell_position-Vector2(34,64),-PI*.5)
		if PixelFormalActors.pixel_context(self): PixelFormalActors.gate(self,Rect2(0,0,8,68),1)
		else: draw_texture_rect_region(GATE_ART,Rect2(0,0,8,68),Rect2(366,127,105,892.5))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(bell_position - Vector2(34, 64), Vector2(68, 8)), Color("765b41"))
	var opened_time := _clock - _opened_at if _opened_at>=0 else 1.0
	var swing := sin(opened_time * 28.0) * 0.16 * maxf(0.0, 1.0-opened_time/0.5) if is_open else 0.0
	draw_set_transform(bell_position, swing)
	if PixelFormalActors.pixel_context(self): PixelFormalActors.bell(self,Vector2.ZERO,is_open)
	else: draw_texture_rect_region(BELL_ART, Rect2(Vector2(-14,-26), Vector2(28,49.4)), Rect2(200,8,746,1316))
	draw_set_transform(Vector2.ZERO)
	if opened_time < 0.65 and _opened_at>=0:
		for ring: int in 2:
			var age := maxf(0.0, opened_time - float(ring) * 0.10)
			draw_arc(bell_position, 15.0 + age * 75.0, 0.0, TAU, 32, Color(gold, maxf(0.0, 1.0 - age / 0.55) * 0.7), 1.4)
		for glint: int in 8:
			var direction := Vector2.RIGHT.rotated(float(glint) * TAU / 8.0)
			var point := bell_position + direction * (12.0 + opened_time * 40.0)
			draw_line(point, point + direction * 3.0, Color("ffe7a0", maxf(0.0, 1.0 - opened_time / 0.65)), 1.5)
	if not formal_presentation:
		draw_rect(Rect2(bell_position - Vector2(14, 17), Vector2(28, 34)), gold, false, 2)
	var wire_y := gate_rect.position.y + 40.0
	if not formal_presentation:
		draw_polyline(PackedVector2Array([bell_position + Vector2(0,-65), Vector2(bell_position.x,wire_y), Vector2(gate_rect.get_center().x,wire_y), Vector2(gate_rect.get_center().x,gate_rect.position.y)]), Color(gold,0.5), 2)
	if not is_open and not motion_mode:
		_draw_gate(gate_rect, 1.0)
	elif not motion_mode:
		if opened_time < 0.35:
			var raised := gate_rect
			raised.position.y -= gate_rect.size.y * opened_time/0.35
			_draw_gate(raised, 1.0-opened_time/0.35)
		draw_line(gate_rect.position, gate_rect.position + Vector2(gate_rect.size.x, 0), gold, 4)
	var caption := ("MOVING / SHOOT TO PARK" if is_open else "PARKED / SHOOT TO START") if motion_mode else "OPEN" if is_open else (prompt_text if not prompt_text.is_empty() else "SHOOT " + link_id)
	var caption_position := bell_position + Vector2(-37, -78)
	if region_presentation:
		caption = ("SHOOT TO PARK" if is_open else "SHOOT TO START") if motion_mode else "OPEN" if is_open else ("RING 2" if sequence_step>0 else "RING 1") if not sequence_offset.is_zero_approx() else "SHOOT"
		if not _context_visible() or (is_open and not motion_mode and opened_time > 0.8): caption = ""
	if formal_presentation and not caption.is_empty():
		# A readable local sign; painted distant scenery must not swallow the lesson.
		var text_size := ThemeDB.fallback_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		var plaque := Rect2(caption_position + Vector2(-5, -18), Vector2(text_size.x + 10, 25))
		draw_rect(plaque, Color(0.12, 0.19, 0.17, 0.94))
		draw_rect(plaque, Color(gold, 0.65), false, 1)
	draw_string(ThemeDB.fallback_font, caption_position, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)

	if formal_presentation:
		var target:=motion_target.position if motion_mode and is_instance_valid(motion_target) else gate_rect.position
		_draw_sigil(bell_position+Vector2(-28,-45),sigil_index,28)
		_draw_sigil(target+Vector2(12,-38),sigil_index,32)
		if not region_presentation: _draw_link_label(bell_position+Vector2(18,-35),gold)
		if not region_presentation: _draw_link_label(target+Vector2(-20,-62),gold)
		for access:Vector2 in access_positions:
			_draw_sigil(access+Vector2(-28,-28),sigil_index,25)
			if not region_presentation: _draw_link_label(access+Vector2(15,-28),gold)
		if _opened_at>=0 and opened_time<.7:
			for i:int in 12:
				var progress:float=fposmod(opened_time*1.8+float(i)/12,1)
				draw_circle(bell_position.lerp(target,progress),2,Color(gold,(1-opened_time/.7)*.8))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(gate_rect.position.x-4,gate_rect.position.y-12),link_id,HORIZONTAL_ALIGNMENT_LEFT,-1,20,gold)

func _draw_gate(rect: Rect2, opacity: float) -> void:
	if PixelFormalActors.pixel_context(self):
		PixelFormalActors.gate(self,rect,opacity)
		return
	# Preserve the brass end caps; crop the oak shaft at a single uniform scale.
	# Region provenance is recorded in windchime_gate_beam.json.
	var scale_value := rect.size.x / 105.0
	var top_height := minf(80.0 * scale_value, rect.size.y * 0.5)
	var bottom_height := minf(72.0 * scale_value, rect.size.y - top_height)
	var tint := Color(1, 1, 1, opacity)
	draw_texture_rect_region(GATE_ART, Rect2(rect.position, Vector2(rect.size.x, top_height)), Rect2(366,47,105,top_height/scale_value), tint)
	var y := rect.position.y + top_height
	while y < rect.end.y - bottom_height - 0.001:
		var height := minf(1620.0 * scale_value, rect.end.y - bottom_height - y)
		draw_texture_rect_region(GATE_ART, Rect2(rect.position.x,y,rect.size.x,height), Rect2(366,127,105,height/scale_value), tint)
		y += height
	draw_texture_rect_region(GATE_ART, Rect2(rect.position.x,rect.end.y-bottom_height,rect.size.x,bottom_height), Rect2(366,1747,105,bottom_height/scale_value), tint)

func _play_bell() -> void:
	if get_tree().get_first_node_in_group(&"game_audio") != null: GameAudio.cue(self, &"bell")
	else: _bell_audio.play()

# Multiple receivers belong to the same mechanism actor and health epoch. Both
# entry sides use actual projectile collisions and the same accepted-shot policy.
func add_access_bell(location: Vector2, second := false, return_side_only := false) -> void:
	var primary := _second_receiver if second else receiver
	if not is_instance_valid(primary): return
	var body := StaticBody2D.new()
	body.position = location
	body.collision_layer = 8
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(28,34)
	shape.shape = rectangle
	body.add_child(shape)
	var access := Damageable.new()
	access.name = "Damageable"
	access.faction = &"mechanism"
	access.actor_id = primary.actor_id
	body.add_child(access)
	add_child(body)
	access.bind_health(health)
	access.damage_sink = func(context: Dictionary) -> bool:
		if return_side_only:
			var key: String="%s:%s" % [context.get("session_id",-1),context.get("shot_id",-1)]
			var shot: Dictionary=_eligible_shots.get(key,{})
			if not shot.has("actor_position") or to_local(shot.actor_position).x<gate_rect.end.x+12: return false
		return _receive_projectile(context)
	access_bodies.append(body)
	access_positions.append(location)
	if return_side_only:
		var hint:=Label.new();hint.text="RETURN / RIGHT SIDE";hint.position=location+Vector2(-65,-58);hint.add_theme_font_size_override("font_size",12);add_child(hint)
	if not sequence_offset.is_zero_approx():
		var marker:=Label.new()
		marker.text="2" if second else "1"
		marker.position=location+Vector2(-5,-38)
		add_child(marker)
	var sprite := Sprite2D.new()
	sprite.texture = PixelFormalActors.icon_texture(&"bell") if PixelFormalActors.pixel_context(self) else BELL_ART
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if PixelFormalActors.pixel_context(self) else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	sprite.scale = Vector2(28,34)/sprite.texture.get_size() if PixelFormalActors.pixel_context(self) else Vector2(38,48)/BELL_ART.get_size()
	sprite.position = location
	add_child(sprite)

func bind_motion(platform:ModuleMovingPlatform)->void:
	motion_target=platform
	motion_mode=true
	platform.bind_bell_control()
	gate_body.collision_layer=0
	gate_shape.set_deferred("disabled",true)

func _draw_link_label(at:Vector2,color:Color)->void:
	var size:Vector2=ThemeDB.fallback_font.get_string_size(link_id,HORIZONTAL_ALIGNMENT_LEFT,-1,13)
	draw_rect(Rect2(at+Vector2(-3,-15),size+Vector2(6,5)),Color(.06,.12,.1,.92))
	draw_string(ThemeDB.fallback_font,at,link_id,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)

func restore_sequence_gate()->void:
	if is_instance_valid(sequence_gate_body):
		sequence_gate_body.collision_layer=0 if sequence_step>0 else 1
		sequence_gate_shape.set_deferred("disabled",sequence_step>0)
		if sequence_step>0:prompt_text="CLIMB / FIND REMOTE RING 2"

func _draw_sigil(at: Vector2, index: int, size: float) -> void:
	if PixelFormalActors.pixel_context(self): PixelFormalActors.sigil(self,at,index,size)
	else: PlainsInteractiveArt.draw_sigil(self,at,index,size)

func refresh_pixel_presentation() -> void:
	if not PixelFormalActors.pixel_context(self): return
	for child: Node in get_children():
		if child is Sprite2D and child.texture==BELL_ART:
			child.texture=PixelFormalActors.icon_texture(&"bell")
			child.scale=Vector2(28,34)/child.texture.get_size()
			child.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
