class_name EnemyPresentation
extends Node2D
## Original generated acorn beetle skin; AI and collision remain independent.
@export var actor: EnemyActor
var _size := Vector2.ZERO
var _clock := 0.0
var _hurt_time := 0.0
var _death_time := 0.0
var _frame_weights: Dictionary = {}
var _weight := Vector2.ONE
var _lean := 0.0
static var _action_manifest: Dictionary = {}
static var _action_textures: Dictionary = {}
var feedback_sample: EnemyFeedback01
var feedback_particles: EnemyFeedback01Particles
func _ready() -> void:
	_size = actor.definition.collision_size
	if EnemyFeedback01.supports(actor.definition):
		feedback_sample = EnemyFeedback01.new(actor.health, actor.definition)
		feedback_particles = EnemyFeedback01Particles.new()
		feedback_particles.name = "AcceptedHitChips"
		feedback_particles.z_index = 1
		add_child(feedback_particles)
		feedback_particles.bind(feedback_sample, actor.damageable)
		actor.health.changed.connect(_feedback_initialized)
	else:
		actor.health.changed.connect(_health_changed)
	queue_redraw()
func _exit_tree() -> void:
	if feedback_sample != null: feedback_sample.dispose()
	if is_instance_valid(actor) and actor.health.changed.is_connected(_health_changed): actor.health.changed.disconnect(_health_changed)
	if is_instance_valid(actor) and actor.health.changed.is_connected(_feedback_initialized): actor.health.changed.disconnect(_feedback_initialized)
func _feedback_initialized(result: ActorResourceResult) -> void:
	if result == null or result.operation != &"initialize" or result.snapshot.epoch != actor.health.epoch: return
	_hurt_time = 0
	_death_time = 0
	feedback_particles.clear_for_epoch()
	queue_redraw()
func _process(delta: float) -> void:
	if get_tree().paused: return
	_clock += delta
	if feedback_sample != null:
		feedback_sample.advance(delta)
		_hurt_time = feedback_sample.hurt_remaining
		_death_time = feedback_sample.death_elapsed
	else:
		if actor.health.terminal: _death_time += delta
		_hurt_time = maxf(0, _hurt_time - delta)
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var desired := Vector2(1.12,.9) if state in [&"telegraph",&"attack"] else Vector2(.97,1.025) if state == &"recovery" else Vector2.ONE
	if actor.health.terminal: desired = Vector2(1.12,.45)
	if feedback_sample != null:
		desired = feedback_sample.pose() if actor.health.terminal else desired * feedback_sample.pose()
	_weight = _weight.lerp(desired,1-exp(-delta/.075))
	_lean = lerpf(_lean,clampf(actor.motor.velocity.x/350,-1,1)*.09,1-exp(-delta/.07))
	_update_frame_weights(state,delta)
	queue_redraw()
func _health_changed(result: ActorResourceResult) -> void:
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
		_hurt_time = 0.14
	queue_redraw()
func _draw() -> void:
	if actor == null:
		return
	if feedback_sample != null and (feedback_sample.restored_terminal or (actor.health.terminal and not feedback_sample.death_active)): return
	var texture := PlainsRefreshAssets.object_texture(&"enemy_left" if actor.brain.direction < 0 else &"enemy_right")
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var facing := float(actor.brain.direction)
	if not actor.health.terminal:
		if state == &"telegraph":
			draw_arc(Vector2(0, -8), 27, -PI, 0, 16, Color("f8cf74"), 2)
			draw_line(Vector2(0, -40), Vector2(0, -30), Color("fff3bc"), 3)
			if actor.definition.behavior_id in [&"diver",&"hopper"]:
				var goal:=to_local(actor.attack_behavior.attack_goal)
				draw_arc(goal,18,0,TAU,24,Color(1,.75,.3,.75),2)
				for i: int in 5:
					draw_line(goal*float(i)/5.0,goal*(float(i)+.4)/5.0,Color(1,.75,.3,.35),1.5)
			elif actor.definition.behavior_id in [&"sentry",&"fan_sentry"]:
				var aim:=actor.attack_behavior.locked_direction
				for angle: float in ([-.18,0.0,.18] if actor.definition.behavior_id==&"fan_sentry" else [0.0]):
					draw_line(aim.rotated(angle)*25,aim.rotated(angle)*90,Color(1,.75,.3,.45),1.5)
		elif state == &"attack":
			draw_line(Vector2(-facing * 32, 2), Vector2(-facing * 15, 2), Color(0.95, 0.82, 0.50, 0.6), 3)
			draw_line(Vector2(-facing * 28, 8), Vector2(-facing * 10, 8), Color(0.95, 0.82, 0.50, 0.4), 2)
	var size := Vector2(_size.x * 1.45, _size.y * 1.45)
	var bob := sin(_clock * 7) * 1.2 if not actor.health.terminal else 0.0
	size *= _weight
	var tint := Color(1.0, 0.50, 0.43) if _hurt_time > 0 else Color.WHITE
	if feedback_sample != null: tint = feedback_sample.tint()
	if actor.health.terminal:
		tint = Color(0.65, 0.62, 0.51, maxf(0.18, 0.8 - _death_time * 0.5))
		if feedback_sample != null: tint.a = .8 * maxf(0, 1 - _death_time / EnemyFeedback01.DEATH_SECONDS)
		for mote: int in 6:
			var angle := TAU * float(mote) / 6.0
			var alpha := maxf(0, 1.0 - _death_time / EnemyFeedback01.DEATH_SECONDS) if feedback_sample != null else maxf(0, 1.0 - _death_time * 1.6)
			draw_circle(Vector2(cos(angle), sin(angle)) * minf(_death_time * 35, 25), 2, Color(0.95, 0.80, 0.48, alpha))

	if ForestBibleActors.draw_enemy_body(self, actor, _clock): return
	if actor.definition.aerial:
		var atlas := preload("res://assets/plains_v4/spatial/actors.png")
		var tilt := _lean + sin(_clock*2)*.035 + (feedback_sample.tilt() if feedback_sample != null else 0.0)
		draw_set_transform(Vector2(0,bob),tilt,Vector2(-facing,1))
		draw_texture_rect_region(atlas,Rect2(-size.x*.6,-size.y*.65,size.x*1.2,size.y*1.3),Rect2(935,570,580,445),tint)
		draw_set_transform(Vector2.ZERO)
	else:
		if actor.definition.behavior_id in [&"charger", &"sentry",&"hopper",&"fan_sentry",&"patrol"]:
			_draw_action_frame(state, facing, tint)
		else:
			draw_texture_rect(texture, Rect2(Vector2(-size.x / 2, -size.y / 2 + bob), size), false, tint)
	draw_set_transform(Vector2.ZERO)
	if actor.health.capacity>8:
		var bar := Rect2(-_size.x/2,-_size.y/2-12,_size.x,4)
		draw_rect(bar,Color(.15,.2,.15,.8))
		bar.size.x*=actor.health.current/actor.health.capacity
		draw_rect(bar,Color(1,.76,.42))
	else:
		for index: int in ceili(actor.health.current):
			draw_circle(Vector2(-8 + index * 8, -_size.y / 2 - 9), 2.0, Color(1, 0.76, 0.42))

func _draw_action_frame(state: StringName, facing: float, tint: Color) -> void:
	var root := "res://assets/plains_v3/enemies/meadow_actions/"
	if _action_manifest.is_empty():
		_action_manifest = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
	var species := "sentry" if actor.definition.behavior_id in [&"sentry",&"fan_sentry"] else "beetle"
	var data: Dictionary = _action_manifest.species[species]
	var frame_id := "death" if actor.health.terminal else "idle_a" if state == &"idle" and int(_clock * 7) % 2 == 0 else "idle_b" if state == &"idle" else "recovery" if state==&"blocked" else str(state)
	var total := 0.0
	for weight: float in _frame_weights.values(): total += weight
	for id: String in _frame_weights:
		_draw_named_frame(data,species,id,facing,Color(tint,tint.a*float(_frame_weights[id])/maxf(total,.001)))

func _draw_named_frame(data: Dictionary, species: String, frame_id: String, facing: float, tint: Color) -> void:
	var root := "res://assets/plains_v3/enemies/meadow_actions/"
	for frame: Dictionary in data.frames:
		if frame.id != frame_id: continue
		var key := species + ":" + frame_id
		if not _action_textures.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(root + str(data.texture)) as Texture2D
			atlas.region = Rect2(frame.region_xywh[0], frame.region_xywh[1], frame.region_xywh[2], frame.region_xywh[3])
			_action_textures[key] = atlas
		var factor := float(data.uniform_scale_at_default_actor) * _size.y / 32.0
		var origin := Vector2(0, _size.y / 2) - Vector2(frame.anchor_px[0], frame.anchor_px[1]) * factor
		draw_set_transform_matrix(Transform2D(Vector2(facing*_weight.x,0),Vector2(_lean,_weight.y),Vector2(0,_size.y/2*(1-_weight.y))))
		draw_texture_rect(_action_textures[key], Rect2(origin, Vector2(frame.region_xywh[2], frame.region_xywh[3]) * factor), false, tint)
		draw_set_transform(Vector2.ZERO)
		return

func _update_frame_weights(state: StringName, delta: float) -> void:
	var frame_id := "death" if actor.health.terminal else "idle_a" if state == &"idle" and int(_clock*7)%2==0 else "idle_b" if state==&"idle" else "recovery" if state==&"blocked" else str(state)
	if _frame_weights.is_empty(): _frame_weights[frame_id]=1.0
	for id: String in _frame_weights.keys():
		_frame_weights[id]=move_toward(float(_frame_weights[id]),1.0 if id==frame_id else 0.0,delta/.075)
		if float(_frame_weights[id])<=0: _frame_weights.erase(id)
	if not _frame_weights.has(frame_id): _frame_weights[frame_id]=minf(1,delta/.075)
