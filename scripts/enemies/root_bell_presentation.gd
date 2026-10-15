class_name RootBellPresentation
extends Node2D
## Independent artwork and ground telegraph. Presentation never changes AI/HP.
var actor: EnemyActor
var _clock := 0.0
var _hurt := 0.0
var _death := 0.0
var _pose := "idle"
var _old_pose := "idle"
var _blend := 1.0
var _manifest: Dictionary = {}
var _atlas: Texture2D

func _ready() -> void:
	actor.health.changed.connect(_health_changed)
	var path := "res://assets/region_production_v3/enemies/root_bell/manifest.json"
	if FileAccess.file_exists(path):
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
		_atlas = load("res://assets/region_production_v3/enemies/root_bell/source/master.png") as Texture2D

func _health_changed(result: ActorResourceResult) -> void:
	if result != null and result.status == ActorResourceResult.Status.APPLIED and result.amount_applied < 0: _hurt = .16

func _process(delta: float) -> void:
	if get_tree().paused: return
	_clock += delta
	_hurt = maxf(0, _hurt - delta)
	if actor.health.terminal: _death += delta
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var next := "death" if actor.health.terminal else "hurt" if _hurt > 0 else "telegraph" if state == &"telegraph" else "attack" if state == &"attack" else "recovery" if state == &"recovery" else "idle"
	if next != _pose:
		_old_pose = _pose
		_pose = next
		_blend = 0
	_blend = minf(1, _blend + delta / .07)
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
		elif behavior.state == &"attack":
			var bounds := behavior.pulse_bounds()
			for i: int in 5:
				var x := bounds.position.x + bounds.size.x * (float(i) + .5) / 5.0
				var base := to_local(Vector2(x, bounds.end.y))
				draw_colored_polygon(PackedVector2Array([base + Vector2(-4,0), base + Vector2(0,-bounds.size.y), base + Vector2(4,0)]), Color("b27a34"))
	if _atlas != null and not _manifest.is_empty():
		var tint := Color(1, .65, .45) if _hurt > 0 else Color.WHITE
		tint.a = maxf(0, 1 - _death / .8) if actor.health.terminal else 1
		if _blend < 1: _draw_pose(_old_pose, Color(tint, tint.a * (1 - _blend)))
		_draw_pose(_pose, Color(tint, tint.a * _blend))
	draw_set_transform(Vector2.ZERO)
	if not actor.health.terminal:
		for i: int in ceili(actor.health.current):
			draw_circle(Vector2(-8 + i * 8, -actor.definition.collision_size.y * .5 - 9), 2, Color("f6cd80"))

func _draw_pose(id: String, tint: Color) -> void:
	var frame: Dictionary = _manifest.frames[id]
	var region: Array = frame.region_xywh
	var anchor: Array = frame.anchor_px
	var factor := float(_manifest.scale)
	var breathing := sin(_clock * 3) * .018 if _pose == "idle" else 0.0
	var lean := -.05 * sin(_hurt * 30) if _hurt > 0 else 0.0
	var feet := Vector2(0, actor.definition.collision_size.y * .5)
	draw_set_transform_matrix(Transform2D(Vector2(float(actor.brain.direction) * (1 + breathing), 0), Vector2(lean, 1 - breathing), feet))
	draw_texture_rect_region(_atlas, Rect2(-Vector2(anchor[0], anchor[1]) * factor, Vector2(region[2], region[3]) * factor), Rect2(region[0], region[1], region[2], region[3]), tint)
	draw_set_transform(Vector2.ZERO)
