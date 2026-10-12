class_name EnemyPresentation
extends Node2D
## Original generated acorn beetle skin; AI and collision remain independent.
@export var actor: EnemyActor
var _size := Vector2.ZERO
var _clock := 0.0
var _hurt_time := 0.0
var _death_time := 0.0
static var _action_manifest: Dictionary = {}
static var _action_textures: Dictionary = {}
func _ready() -> void:
	_size = actor.definition.collision_size
	actor.health.changed.connect(_health_changed)
	queue_redraw()
func _process(delta: float) -> void:
	_clock += delta
	if actor.health.terminal: _death_time += delta
	_hurt_time = maxf(0, _hurt_time - delta)
	queue_redraw()
func _health_changed(result: ActorResourceResult) -> void:
	if result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0:
		_hurt_time = 0.14
	queue_redraw()
func _draw() -> void:
	if actor == null:
		return
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
	if state == &"telegraph" and not actor.health.terminal:
		size *= Vector2(1.15, 0.86)
	elif state == &"attack" and not actor.health.terminal:
		size *= Vector2(1.20, 0.87)
	elif state == &"recovery" and not actor.health.terminal:
		size *= Vector2(0.96, 1.04)
	var tint := Color(1.0, 0.50, 0.43) if _hurt_time > 0 else Color.WHITE
	if actor.health.terminal:
		tint = Color(0.65, 0.62, 0.51, maxf(0.18, 0.8 - _death_time * 0.5))
		for mote: int in 6:
			var angle := TAU * float(mote) / 6.0
			draw_circle(Vector2(cos(angle), sin(angle)) * minf(_death_time * 35, 25), 2, Color(0.95, 0.80, 0.48, maxf(0, 1.0 - _death_time * 1.6)))
		size.y *= 0.45
	if actor.definition.aerial:
		var atlas := preload("res://assets/plains_v4/spatial/actors.png")
		var tilt := facing*.28 if state == &"attack" else sin(_clock*2)*.06
		draw_set_transform(Vector2(0,bob),tilt,Vector2(-facing,1))
		draw_texture_rect_region(atlas,Rect2(-size.x*.6,-size.y*.65,size.x*1.2,size.y*1.3),Rect2(935,570,580,445),tint)
		draw_set_transform(Vector2.ZERO)
	else:
		if actor.definition.behavior_id in [&"charger", &"sentry",&"hopper"]:
			_draw_action_frame(state, facing, tint)
		else:
			draw_texture_rect(texture, Rect2(Vector2(-size.x / 2, -size.y / 2 + bob), size), false, tint)
	draw_set_transform(Vector2.ZERO)
	for index: int in ceili(actor.health.current):
		draw_circle(Vector2(-8 + index * 8, -_size.y / 2 - 9), 2.0, Color(1, 0.76, 0.42))

func _draw_action_frame(state: StringName, facing: float, tint: Color) -> void:
	var root := "res://assets/plains_v3/enemies/meadow_actions/"
	if _action_manifest.is_empty():
		_action_manifest = JSON.parse_string(FileAccess.get_file_as_string(root + "manifest.json"))
	var species := "sentry" if actor.definition.behavior_id == &"sentry" else "beetle"
	var data: Dictionary = _action_manifest.species[species]
	var frame_id := "death" if actor.health.terminal else "idle_a" if state == &"idle" and int(_clock * 7) % 2 == 0 else "idle_b" if state == &"idle" else "recovery" if state==&"blocked" else str(state)
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
		draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
		draw_texture_rect(_action_textures[key], Rect2(origin, Vector2(frame.region_xywh[2], frame.region_xywh[3]) * factor), false, tint)
		draw_set_transform(Vector2.ZERO)
		return
