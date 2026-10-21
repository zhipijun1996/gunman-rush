class_name ForestBibleAmbience
extends Node2D
## FOREST-BIBLE-V2-01 / Bible §2.3, §12. Local presentation only.
## No gameplay RNG, transforms, collision, resources, camera or save writes.
const LAYOUT := "forest-bible-world-v15"
const MAX_PATCHES := 64
const MAX_VISIBLE_PATCHES := 12
const MAX_BURSTS := 4
const WIND_INTERVAL := 9.0
var _enabled := false
var _reduced := false
var _actor: WeakRef
var _patches: Array[Vector2] = []
var _fruit_keepouts: Array[Vector2] = []
var _bursts: Array[Dictionary] = []
var _clock := 0.0
var _wind_due := 3.0
var _fruit_due := 0.0
var _web_due := 0.0
var _redraw_due := 0.0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure(manifest: Dictionary, actor: Node2D, reduced_effects: bool = false) -> void:
	_enabled = manifest.get("layout_version") == LAYOUT
	_actor = weakref(actor) if is_instance_valid(actor) else null
	_reduced = reduced_effects
	_patches.clear()
	_fruit_keepouts.clear()
	_bursts.clear()
	_clock = 0.0
	_wind_due = 3.0
	_fruit_due = 0.0
	_web_due = 0.0
	_redraw_due = 0.0
	if _enabled:
		# Retain only derived positions, never the caller's mutable manifest.
		for row: Dictionary in manifest.get("hook_anchors", []):
			_fruit_keepouts.append(_point(row.position))
		for row: Dictionary in manifest.get("fruit_boughs", []):
			var path: Array = row.get("points", [])
			if path.size() >= 2: _append_patch(_point(path[path.size()-2]))
		for row: Dictionary in manifest.get("platforms", []):
			if not bool(row.get("one_way", false)): continue
			var rect: Array = row.rect
			# Leaf root stays attached to an actual branch underside. The solid
			# body and its standing edge never move with this local leaf tip.
			_append_patch(Vector2(float(rect[0])+float(rect[2])-9.0, float(rect[1])+float(rect[3])-1.0))
	set_process(_enabled)
	queue_redraw()

func set_reduced_effects(value: bool) -> void:
	_reduced = value
	if value: _bursts.clear()
	queue_redraw()

## Call only at an already accepted fruit-hook event, never for an attempt.
func notify_fruit(world_position: Vector2) -> void:
	if not _can_hear(world_position) or _clock < _fruit_due: return
	_fruit_due = _clock+0.20
	GameAudio.cue(self, &"forest_fruit")
	if _reduced: return
	if _bursts.size() >= MAX_BURSTS: _bursts.pop_front()
	_bursts.append({"origin":world_position+Vector2(0, 12), "born":_clock})
	queue_redraw()

## Call once on a real web growing/state-entry event, never every state tick.
func notify_web(world_position: Vector2) -> void:
	if not _can_hear(world_position) or _clock < _web_due: return
	_web_due = _clock+0.45
	GameAudio.cue(self, &"forest_web")

func _process(delta: float) -> void:
	if not _enabled: return
	_clock += delta
	if _clock >= _wind_due:
		_wind_due = _clock+WIND_INTERVAL
		if _actor_node() != null: GameAudio.cue(self, &"forest_wind")
	for index: int in range(_bursts.size()-1, -1, -1):
		if _clock-float(_bursts[index].born) >= 0.7: _bursts.remove_at(index)
	if _clock >= _redraw_due:
		_redraw_due = _clock+1.0/30.0
		queue_redraw()

func _draw() -> void:
	if not _enabled or _reduced or not is_inside_tree(): return
	var view := _world_view().grow(20.0)
	var shown := 0
	for root: Vector2 in _patches:
		if shown >= MAX_VISIBLE_PATCHES: break
		if not view.has_point(root) or not _clear_for_actor(root): continue
		var wind := _wind(root)
		var tip := root+Vector2(2.5+wind*2.4, 8.0)
		draw_line(to_local(root), to_local(tip), Color(0.29, 0.40, 0.26, 0.70), 1.0, false)
		_leaf(tip, wind*0.15, Color(0.42, 0.52, 0.30, 0.67))
		_leaf(tip+Vector2(-4.0, 2.0), -0.4+wind*0.12, Color(0.31, 0.43, 0.28, 0.58))
		# One dim mote per visible patch; its small orbit follows the same
		# wind field as the leaf, in world space rather than camera space.
		var phase := root.x*0.013+root.y*0.009
		var dust := root+Vector2(sin(_clock*0.13+phase)*21.0+wind*5.0, 23.0+sin(_clock*0.19+phase)*11.0)
		if _clear_for_actor(dust): draw_circle(to_local(dust), 0.8, Color(0.71, 0.73, 0.46, 0.24))
		shown += 1
	for burst: Dictionary in _bursts:
		var age := _clock-float(burst.born)
		var origin: Vector2 = burst.origin
		if not view.has_point(origin): continue
		for index: int in 3:
			var drift := Vector2((float(index)-1.0)*11.0+_wind(origin)*8.0, 10.0+age*20.0)
			var at := origin+drift*age
			if _clear_for_actor(at): _leaf(at, age+index, Color(0.48, 0.57, 0.33, (1.0-age/0.7)*0.5))

func _leaf(at: Vector2, angle: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for offset: Vector2 in [Vector2(-3, 0), Vector2(0, -1.5), Vector2(3, 0), Vector2(0, 1.5)]:
		points.append(to_local(at+offset.rotated(angle)))
	draw_colored_polygon(points, tint)

func _wind(at: Vector2) -> float:
	return sin(_clock*0.65+at.x*0.003+at.y*0.001)*0.65+sin(_clock*1.2+at.y*0.005)*0.25

func _append_patch(at: Vector2) -> void:
	if _patches.size() >= MAX_PATCHES: return
	for existing: Vector2 in _patches:
		if existing.distance_squared_to(at) < 72.0*72.0: return
	for fruit: Vector2 in _fruit_keepouts:
		if fruit.distance_squared_to(at) < 32.0*32.0: return
	_patches.append(at)

func _clear_for_actor(at: Vector2) -> bool:
	var actor := _actor_node()
	return actor == null or actor.global_position.distance_squared_to(at) > 64.0*64.0

func _actor_node() -> Node2D:
	return _actor.get_ref() as Node2D if _actor != null else null

func _can_hear(at: Vector2) -> bool:
	if not _enabled or not is_inside_tree() or get_tree().paused or not at.is_finite(): return false
	var actor := _actor_node()
	return actor != null and actor.global_position.distance_squared_to(at) <= 800.0*800.0

func _world_view() -> Rect2:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport_rect().size
	return Rect2(inverse*Vector2.ZERO, (inverse*size)-(inverse*Vector2.ZERO))

static func _point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

func _exit_tree() -> void:
	GameAudio.stop_region(self)
	_enabled = false
	set_process(false)
	_actor = null
	_patches.clear()
	_fruit_keepouts.clear()
	_bursts.clear()
