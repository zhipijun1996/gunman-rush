class_name RootBellPresentation
extends Node2D
## Independent artwork and ground telegraph. Presentation never changes AI/HP.
var actor: EnemyActor
var _clock := 0.0
var _hurt := 0.0
var _death := 0.0
var _pose := "idle"
var _transition_time := 1.0
var _previous_state: StringName = &"idle"
var _burst_tail := false
var _burst_manifest: Dictionary = {}
var _burst_atlas: Texture2D
var _manifest: Dictionary = {}
var _atlas: Texture2D
var hit_template: EnemyHitTemplate
var body_motion := PlainsMotion02.new(&"legacy")
var _body_textures: Dictionary = {}

func _ready() -> void:
	actor.health.changed.connect(_health_changed)
	hit_template = EnemyHitTemplate.install(actor, self)
	body_motion.sample = hit_template.sample
	var path := "res://assets/region_production_v3/enemies/root_bell/manifest.json"
	if FileAccess.file_exists(path):
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
		_atlas = load("res://assets/region_production_v3/enemies/root_bell/source/master.png") as Texture2D
	var burst_path := "res://assets/region_production_v3/enemies/root_bell_burst/manifest.json"
	if FileAccess.file_exists(burst_path):
		_burst_manifest = JSON.parse_string(FileAccess.get_file_as_string(burst_path))
		_burst_atlas = load("res://assets/region_production_v3/enemies/root_bell_burst/source/master.png") as Texture2D

func _health_changed(result: ActorResourceResult) -> void:
	if result != null and result.operation == &"initialize" and result.snapshot.epoch == actor.health.epoch:
		body_motion.advance(actor, 0.0)
		_hurt = 0.0
		_death = .8 if actor.health.terminal else 0.0
		_pose = "death" if actor.health.terminal else "idle"
		_burst_tail = false
		_previous_state = &"idle"
		_transition_time = 1.0
		queue_redraw()
		return
	if result != null and result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0: _hurt = .16

func _process(delta: float) -> void:
	if get_tree().paused: return
	_clock += delta
	body_motion.advance(actor, delta)
	_hurt = maxf(0, _hurt - delta)
	if actor.health.terminal: _death += delta
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var next := "death" if actor.health.terminal else "hurt" if _hurt > 0 else "telegraph" if state == &"telegraph" else "attack" if state == &"attack" else "recovery" if state == &"recovery" else "idle"
	if state != _previous_state:
		_burst_tail = state == &"attack" or (state == &"recovery" and _previous_state == &"attack")
		_previous_state = state
	if next != _pose:
		_pose = next
		_transition_time = 0
	_transition_time += delta
	queue_redraw()

func _draw() -> void:
	if actor == null: return
	if not actor.health.terminal and actor.attack_behavior is RootBellBehavior:
		var behavior := actor.attack_behavior as RootBellBehavior
		var center := to_local(behavior.attack_goal)
		if behavior.state == &"telegraph":
			var progress := clampf(behavior.state_time / actor.definition.telegraph_duration, 0, 1)
			var half := actor.definition.pulse_size.x * .5
			draw_line(center + Vector2(-half, -1), center + Vector2(half, -1), Color("df9c48"), 3)
			draw_arc(center + Vector2(0, -8), half, PI, PI + TAU * .5 * progress, 24, Color("ffd686"), 2)
			for side: int in [-1, 1]:
				draw_line(center + Vector2(side * half, 0), center + Vector2(side * half, -12), Color("f9d285"), 2)
			if actor.definition.telegraph_duration-behavior.state_time < .06: _draw_burst(center,"emerge",.8)
		elif behavior.state == &"attack":
			_draw_burst(center,"strike" if behavior.state_time < actor.definition.attack_duration*.5 else "bend",1)
		elif behavior.state == &"recovery" and _burst_tail and behavior.state_time < .10:
			_draw_burst(center,"fold" if behavior.state_time < .05 else "settled",1-behavior.state_time/.10)
	if _atlas != null and not _manifest.is_empty():
		var tint := Color(1, .65, .45) if _hurt > 0 else Color.WHITE
		if hit_template != null: tint = hit_template.tint()
		tint.a = maxf(0, 1 - _death / .8) if actor.health.terminal else 1
		_draw_pose("death" if actor.health.terminal else "idle", tint)
	draw_set_transform(Vector2.ZERO)
	if not actor.health.terminal:
		for i: int in ceili(actor.health.current):
			draw_circle(Vector2(-8 + i * 8, -actor.definition.collision_size.y * .5 - 9), 2, Color("f6cd80"))

func _draw_pose(id: String, tint: Color) -> void:
	var frame: Dictionary = _manifest.frames[id]
	var region: Array = frame.region_xywh
	var anchor: Array = frame.anchor_px
	var factor := float(_manifest.scale)
	var feet := Vector2(0, actor.definition.collision_size.y * .5)
	if not _body_textures.has(id):
		var texture := AtlasTexture.new()
		texture.atlas = _atlas
		texture.region = Rect2(region[0],region[1],region[2],region[3])
		texture.filter_clip = true
		_body_textures[id] = texture
	# One source, trunk/root contact and continuous branch pivots throughout
	# telegraph/attack/hurt/recovery. The ground pulse is drawn separately.
	draw_set_transform(feet,0.0,Vector2(float(actor.brain.direction),1.0))
	body_motion.draw_body(self,actor,_body_textures[id],Rect2(-Vector2(anchor[0],anchor[1])*factor,Vector2(region[2],region[3])*factor),tint)
	draw_set_transform(Vector2.ZERO)

func _draw_burst(center: Vector2, id: String, opacity: float) -> void:
	if _burst_atlas == null or _burst_manifest.is_empty(): return
	var frame: Dictionary = _burst_manifest.frames[id]
	var raw: Array = frame.region_xywh
	var size_data: Array = frame.display_size
	var size := Vector2(size_data[0],size_data[1])
	# Active frames exactly cover the actual pulse envelope, on its fixed foot.
	if id in ["strike","bend"]: size = actor.definition.pulse_size
	draw_texture_rect_region(_burst_atlas,Rect2(center-Vector2(size.x*.5,size.y),size),Rect2(raw[0],raw[1],raw[2],raw[3]),Color(1,1,1,opacity))
