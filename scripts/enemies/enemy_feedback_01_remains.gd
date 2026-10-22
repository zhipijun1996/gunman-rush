class_name EnemyFeedback01Remains
extends Node2D
## Cosmetic body handoff. No Actor/Motor writes, collision objects or rewards.
## Tree-owned by the stage, lifetime-owned by its one presentation/health epoch.
const FLOOR_REACH := 2048.0
const GRAVITY := 720.0
const TURN_SECONDS := .38
const SETTLE_SECONDS := .20
static var _outline_cache: Dictionary = {}
var active := false
var settled := false
var restored := false
var age := 0.0
var accepted_starts := 0
var phase: StringName = &"inactive"
var source: Texture2D
var bounds := Rect2()
var flash_material := ShaderMaterial.new()
var _sample: EnemyFeedback01
var _receiver: Damageable
var _health: HealthState
var _motor: Node2D
var _host: Node2D
var _view: Callable
var _aerial := false
var _epoch := -1
var _last_serial := -1
var _begun := false
var _velocity_y := 0.0
var _settle_age := 0.0
var _start_angle := 0.0
var _rest_angle := 0.0
var _face := 1.0
var _start_y := 0.0
var _start_x := 0.0
var _anchor_x := 0.0
var _outline_uv := PackedVector2Array()
var _start_size := Vector2.ZERO
var _rest_size := Vector2.ZERO
var _rest_foot := 0.0
var _start_layers: Array[Dictionary] = []
var _restore_pending := false
var _support: WeakRef
var _support_center := Vector2.ZERO
var _floor_center := Vector2.ZERO
var _has_floor := false
var _disposed := false

func _init() -> void:
	flash_material.shader = preload("res://scripts/enemies/enemy_feedback_01_flash.gdshader")
	material = flash_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE

func bind(state: EnemyFeedback01, receiver: Damageable, health: HealthState, motor: Node2D, host: Node2D, aerial: bool, view: Callable) -> void:
	_sample = state
	_receiver = receiver
	_health = health
	_motor = motor
	_host = host
	_aerial = aerial
	_view = view
	_epoch = health.epoch
	_receiver.damaged.connect(_committed)
	_health.changed.connect(_initialized)
	_host.tree_exiting.connect(dispose)
	if health.terminal:
		_restore_static()
		_restore_pending = true

func _capture() -> void:
	var data: Dictionary = _view.call()
	source = data.get("rest_texture", data.texture)
	var rect: Rect2 = data.bounds
	var pose: Transform2D = data.transform
	var size := rect.size * Vector2(pose.x.length(), pose.y.length())
	_start_size = size
	_rest_size = data.get("rest_size", size)
	global_position = pose * rect.get_center()
	_face = float(data.face)
	_start_angle = float(data.angle)
	_rest_angle = float(data.get("rest_angle", .96 if _aerial else .22)) * _face
	flash_material.set_shader_parameter("readable_material", 1.0 if data.get("readable_material", false) else 0.0)
	flash_material.set_shader_parameter("copper_wings", 1.0 if _aerial else 0.0)
	flash_material.set_shader_parameter("lifeless", 0.0)
	rotation = _start_angle
	scale = Vector2.ONE
	_start_layers.clear()
	for layer: Dictionary in data.get("layers", []):
		_start_layers.append({"texture": layer.texture, "bounds": layer.bounds, "pose": global_transform.affine_inverse() * (layer.transform as Transform2D), "alpha": layer.alpha})
	_start_y = global_position.y
	_start_x = global_position.x
	_anchor_x = _motor.global_position.x
	var image := source.get_image()
	_outline_uv = _solid_outline(source, image)
	_set_size(_rest_size)
	_rest_foot = _foot(_rest_angle)
	_find_support()
	_set_size(_start_size)

func _set_size(size: Vector2) -> void:
	bounds = Rect2(-size * .5, size)

static func _solid_outline(texture: Texture2D, image: Image) -> PackedVector2Array:
	var key := texture.resource_path
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		key = atlas.atlas.resource_path + ":" + str(atlas.region)
	if key.is_empty(): key = str(texture.get_rid())
	if _outline_cache.has(key): return _outline_cache[key]
	var points := PackedVector2Array()
	# Row extrema preserve the actual alpha silhouette, including rotated wings.
	# Cache a small convex contour, not thousands of pixels per process frame.
	for y: int in image.get_height():
		var left := -1
		var right := -1
		for x: int in image.get_width():
			if image.get_pixel(x, y).a >= .5:
				left = x
				break
		if left < 0: continue
		for x: int in range(image.get_width()-1, left-1, -1):
			if image.get_pixel(x, y).a >= .5:
				right = x
				break
		for point: Vector2 in [Vector2(left, y), Vector2(right+1, y), Vector2(left, y+1), Vector2(right+1, y+1)]:
			points.append(point / texture.get_size() - Vector2(.5, .5))
	var outline := Geometry2D.convex_hull(points)
	_outline_cache[key] = outline
	return outline

func _find_support() -> void:
	# A corpse ends beneath the saved Actor x, never at an unsaved random toss x.
	# Probe only downward from the actual body centre, so an overhead platform
	# cannot become its floor. No body is moved and no collision layer is changed.
	var anchor_x := _anchor_x
	var half := 1.0
	for uv: Vector2 in _outline_uv:
		var corner := uv * bounds.size
		half = maxf(half, absf(Vector2(corner.x*_face, corner.y).rotated(_rest_angle).x))
	var best: Dictionary = {}
	var center_supported := false
	for dx: float in [0.0, -half, half]:
		var from := Vector2(anchor_x + dx, global_position.y)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, FLOOR_REACH), 1)
		query.collide_with_areas = false
		if _motor is CollisionObject2D: query.exclude = [(_motor as CollisionObject2D).get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP) < .65: continue
		if dx == 0: center_supported = true
		if best.is_empty() or (hit.position as Vector2).y < (best.position as Vector2).y: best = hit
	# A ledge beside an unsupported centre is not an invented floor in midair.
	_has_floor = center_supported and not best.is_empty()
	_support = null
	if not _has_floor: return
	_floor_center = Vector2(anchor_x, (best.position as Vector2).y - _rest_foot)
	if best.collider is Node2D:
		var support := best.collider as Node2D
		_support = weakref(support)
		_support_center = support.to_local(_floor_center)

func _foot(angle: float) -> float:
	var bottom := -INF
	for uv: Vector2 in _outline_uv:
		var corner := uv * bounds.size
		bottom = maxf(bottom, Vector2(corner.x * _face * scale.x, corner.y * scale.y).rotated(angle).y)
	return bottom

func _committed(context: Dictionary) -> void:
	if _disposed or _begun or not _health.terminal or not _sample.death_active: return
	if _sample.last_event_id != StringName(context.get("event_id", "")) or context.get("target_epoch", -1) != _epoch or _last_serial == _sample.impact_serial: return
	_last_serial = _sample.impact_serial
	_begun = true
	_capture()
	active = true
	visible = true
	restored = false
	settled = false
	age = 0
	_settle_age = 0
	_velocity_y = -18.0 if _aerial else -32.0
	phase = &"falling"
	accepted_starts += 1
	flash_material.set_shader_parameter("hit_flash", _sample.flash_strength())
	queue_redraw()

func _initialized(result: ActorResourceResult) -> void:
	if result == null or result.operation != &"initialize" or result.snapshot.epoch != _health.epoch: return
	_epoch = _health.epoch
	_begun = false
	active = false
	visible = false
	settled = false
	restored = false
	age = 0
	phase = &"inactive"
	_support = null
	flash_material.set_shader_parameter("hit_flash", 0.0)
	if _health.terminal:
		_restore_static()
		_restore_pending = true
	queue_redraw()

func _restore_static() -> void:
	_capture()
	_set_size(_rest_size)
	_begun = true
	active = true
	restored = true
	settled = true
	age = 0
	phase = &"resting"
	rotation = _rest_angle
	global_position = _floor_center if _has_floor else global_position
	# A void has no invented floating corpse. No new fall/flash/debris on restore.
	visible = _has_floor
	flash_material.set_shader_parameter("hit_flash", 0.0)
	flash_material.set_shader_parameter("lifeless", 1.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _disposed or not active or get_tree().paused: return
	if _epoch != _health.epoch: return
	if restored and _restore_pending:
		# Existing stages assign saved position/direction after Health.initialize.
		# Reconcile once after assembly, directly to static rest, without replay.
		_restore_pending = false
		_restore_static()
		return
	if _support != null:
		var support: Node2D = _support.get_ref() as Node2D
		if is_instance_valid(support):
			_floor_center = support.to_global(_support_center)
		elif _has_floor:
			_support = null
			_has_floor = false
			settled = false
			_velocity_y = 0
			_anchor_x = global_position.x
			_start_x = global_position.x
			_start_y = global_position.y
			phase = &"falling"
	if settled:
		if _has_floor: global_position = _floor_center
		return
	age += delta
	if phase == &"falling":
		# Attach only after contact. An airborne body must not home sideways
		# toward a ferry that has already moved out from underneath it.
		_set_size(_rest_size)
		_find_support()
	var turn := smoothstep(0, TURN_SECONDS, age)
	rotation = lerp_angle(_start_angle, _rest_angle, turn)
	_set_size(_start_size.lerp(_rest_size, turn))
	if _has_floor: global_position.x = lerpf(_start_x, _floor_center.x, turn)
	if phase == &"falling":
		_velocity_y += GRAVITY * delta
		global_position.y += _velocity_y * delta
		if _has_floor:
			var surface_y := _floor_center.y + _rest_foot
			var contact_y := surface_y - _foot(rotation)
			if _velocity_y >= 0 and global_position.y >= contact_y:
				global_position.y = contact_y
				phase = &"settling"
				_settle_age = 0
				_velocity_y = 0
		elif global_position.y > _start_y + FLOOR_REACH:
			visible = false
			active = false
			phase = &"void"
	elif phase == &"settling":
		_settle_age += delta
		# One small compression at contact, with a zero-slope stop. No flattening,
		# looping bob, repeated bounce, dissolve or death-particle fireworks.
		var press := sin(PI * clampf(_settle_age / SETTLE_SECONDS, 0, 1))
		scale = Vector2(1 + press * .02, 1 - press * .035)
		global_position.y = _floor_center.y + _rest_foot - _foot(rotation)
		if _settle_age >= SETTLE_SECONDS and age >= TURN_SECONDS:
			rotation = _rest_angle
			scale = Vector2.ONE
			global_position = _floor_center
			settled = true
			phase = &"resting"
	queue_redraw()

func _process(_delta: float) -> void:
	if _sample == null or not active or get_tree().paused: return
	if settled: return
	flash_material.set_shader_parameter("hit_flash", 0.0 if restored else _sample.flash_strength())
	flash_material.set_shader_parameter("lifeless", smoothstep(.12, .38, age))
	queue_redraw()

func _draw() -> void:
	if not active or source == null: return
	# The shader quiets material saturation; never hide a corpse in dark alpha.
	# Source pixels remain unchanged. Rotation is not a new authored death frame.
	var tint := Color.WHITE
	var blend := smoothstep(0, .18, age) if not restored else 1.0
	if not _start_layers.is_empty() and blend < 1:
		# Retain all original blended frames and the exact shear/basis on handoff.
		for layer: Dictionary in _start_layers:
			draw_set_transform_matrix(layer.pose)
			draw_texture_rect(layer.texture, layer.bounds, false, Color(tint, float(layer.alpha) * (1-blend)))
	if _start_layers.is_empty(): blend = 1
	draw_set_transform(Vector2.ZERO, 0, Vector2(_face, 1))
	draw_texture_rect(source, bounds, false, Color(tint, blend))

func dispose() -> void:
	if _disposed: return
	_disposed = true
	if is_instance_valid(_receiver) and _receiver.damaged.is_connected(_committed): _receiver.damaged.disconnect(_committed)
	if _health != null and _health.changed.is_connected(_initialized): _health.changed.disconnect(_initialized)
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(dispose): _host.tree_exiting.disconnect(dispose)
	_sample = null
	_receiver = null
	_health = null
	_motor = null
	_host = null
	_view = Callable()
	visible = false
	active = false
	queue_free()

func _exit_tree() -> void:
	dispose()
