class_name EnemyFeedback01Remains
extends Node2D
## The task's one death leaf, reused for v5 burst-and-disappear.
## Stage-owned, host/health-epoch lifetime; never writes gameplay or parent clocks.
const FLASH_HOLD := .045
const DURATION := .55
const CREAM := Color("fff2b3")
const BRASS := Color("d7a85a")
var active := false
var settled := false # Completed visual receipt, not a physical resting body.
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
var _host: Node2D
var _view: Callable
var _aerial := false
var _epoch := -1
var _last_serial := -1
var _begun := false
var _disposed := false
var _layers: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _fragment_texture: Texture2D
var _uv_origin := Vector2.ZERO

func _init() -> void:
	flash_material.shader = preload("res://scripts/enemies/enemy_feedback_01_flash.gdshader")
	material = flash_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	process_mode = Node.PROCESS_MODE_PAUSABLE

func bind(state: EnemyFeedback01, receiver: Damageable, health: HealthState, _motor: Node2D, host: Node2D, aerial: bool, view: Callable) -> void:
	_sample = state
	_receiver = receiver
	_health = health
	_host = host
	_aerial = aerial
	_view = view
	_epoch = health.epoch
	_receiver.damaged.connect(_committed)
	_health.changed.connect(_initialized)
	_host.tree_exiting.connect(dispose)
	if health.terminal: _restore_spent()

func _capture() -> void:
	var data: Dictionary = _view.call()
	# Capture the current body, never the old canonical corpse/death frame.
	source = data.texture
	_fragment_texture = source
	_uv_origin = Vector2.ZERO
	if source is AtlasTexture:
		var atlas := source as AtlasTexture
		_fragment_texture = atlas.atlas
		_uv_origin = atlas.region.position
	bounds = data.bounds
	global_transform = data.transform
	flash_material.set_shader_parameter("readable_material", 1.0 if data.get("readable_material", false) else 0.0)
	flash_material.set_shader_parameter("copper_wings", 1.0 if _aerial else 0.0)
	flash_material.set_shader_parameter("lifeless", 0.0)
	_layers.clear()
	for layer: Dictionary in data.get("layers", []):
		_layers.append({"texture": layer.texture, "bounds": layer.bounds, "pose": global_transform.affine_inverse() * (layer.transform as Transform2D), "alpha": layer.alpha})
	_pieces.clear()
	var image := source.get_image()
	var size := source.get_size()
	var cell := Vector2(maxf(2, ceilf(size.x / 10)), maxf(2, ceilf(size.y / 8)))
	var index := 0
	for y: int in ceili(size.y / cell.y):
		for x: int in ceili(size.x / cell.x):
			var region := Rect2(Vector2(x, y) * cell, cell).intersection(Rect2(Vector2.ZERO, size))
			var opaque := false
			for iy: int in range(int(region.position.y), int(region.end.y)):
				for ix: int in range(int(region.position.x), int(region.end.x)):
					if image.get_pixel(ix, iy).a > .5:
						opaque = true
						break
				if opaque: break
			if not opaque: continue
			var piece := Rect2(bounds.position + region.position / size * bounds.size, region.size / size * bounds.size)
			var axis := (piece.get_center() - bounds.get_center()).normalized()
			if axis.is_zero_approx(): axis = Vector2.UP
			axis = axis.rotated((float((index * 7) % 11) / 10 - .5) * .6)
			var speed := 62.0 + float((index * 13) % 49)
			if _aerial: speed *= 1.12
			var cut := .08 * float(index % 3)
			var shape := PackedVector2Array([Vector2(-.5, -.22), Vector2(-.15+cut, -.5), Vector2(.5, -.12+cut), Vector2(.28-cut, .5), Vector2(-.34, .30)])
			_pieces.append({"region": region, "bounds": piece, "shape": shape, "velocity": axis * speed + Vector2(0, -16), "life": .20 + float((index * 5) % 7) * .024, "spin": (float(index % 5) - 2) * 2.4})
			index += 1

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
	phase = &"flash"
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
	_layers.clear()
	_pieces.clear()
	flash_material.set_shader_parameter("hit_flash", 0.0)
	if _health.terminal: _restore_spent()
	queue_redraw()

func _restore_spent() -> void:
	# The latest user request replaces persistent bodies with disappearance.
	# Reconstruct only the spent receipt: never recapture, burst, flash or drop.
	_begun = true
	restored = true
	settled = true
	active = false
	visible = false
	age = 0
	phase = &"spent"
	flash_material.set_shader_parameter("hit_flash", 0.0)

func _process(delta: float) -> void:
	if _disposed or not active or get_tree().paused: return
	if _epoch != _health.epoch: return
	age = minf(DURATION, age + delta)
	if age >= DURATION:
		active = false
		visible = false
		settled = true
		phase = &"spent"
		_pieces.clear()
		_layers.clear()
		flash_material.set_shader_parameter("hit_flash", 0.0)
	else:
		phase = &"flash" if age < FLASH_HOLD else &"burst" if age < .25 else &"tail"
		# Ordinary hit flash stays unchanged. Only this lethal handoff returns
		# quickly to its own material, avoiding a white checkerboard of fragments.
		var death_flash := clampf((.08 - age) / (.08-FLASH_HOLD), 0, 1)
		flash_material.set_shader_parameter("hit_flash", _sample.flash_strength() * death_flash)
	queue_redraw()

func _draw() -> void:
	if not active or source == null: return
	if age < FLASH_HOLD:
		if _layers.is_empty(): draw_texture_rect(source, bounds, false)
		else:
			for layer: Dictionary in _layers:
				draw_set_transform_matrix(layer.pose)
				draw_texture_rect(layer.texture, layer.bounds, false, Color(1, 1, 1, float(layer.alpha)))
			draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	var t := age - FLASH_HOLD
	# Texture-bearing chips preserve each skin, with a single outward impulse.
	# No flipped whole sprite, floor probing, full-screen flash or fireball art.
	for piece: Dictionary in _pieces:
		var progress := t / float(piece.life)
		if progress >= 1: continue
		var rect: Rect2 = piece.bounds
		var center := rect.get_center() + (piece.velocity as Vector2) * t * (1-.35*progress) + Vector2(0, 95*t*t)
		draw_set_transform(center, float(piece.spin) * t)
		var shrink := lerpf(.72, .20, progress * progress)
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		var region: Rect2 = piece.region
		for corner: Vector2 in piece.shape:
			points.append(corner * rect.size * shrink)
			uvs.append((_uv_origin + region.position + (corner+Vector2(.5,.5))*region.size) / _fragment_texture.get_size())
		draw_polygon(points, PackedColorArray([Color(1, 1, 1, pow(1-progress, .65))]), uvs, _fragment_texture)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var center := bounds.get_center()
	var pressure := 1-clampf(t/.13, 0, 1)
	if pressure > 0:
		var radius := lerpf(4, 25 if _aerial else 22, 1-pressure)
		for arc: int in 3:
			var start := float(arc) * TAU/3 + .18
			draw_arc(center, radius, start, start+.75, 7, Color(CREAM, pressure * .8), 1, false)
	for i: int in 16:
		var life := .26 + float(i%5)*.035
		var progress := t/life
		if progress >= 1: continue
		var axis := Vector2.RIGHT.rotated(float(i)*2.399963 + .17)
		var speed := 75 + float((i*11)%61)
		var point := center + axis*speed*t*(1-.25*progress) + Vector2(0, 55*t*t)
		var color := CREAM if progress < .25 and i%3 == 0 else BRASS
		color.a = pow(1-progress, 1.4)
		draw_line(point-axis*(3 if progress < .4 else 1), point, color, 1, false)

func dispose() -> void:
	if _disposed: return
	_disposed = true
	if is_instance_valid(_receiver) and _receiver.damaged.is_connected(_committed): _receiver.damaged.disconnect(_committed)
	if _health != null and _health.changed.is_connected(_initialized): _health.changed.disconnect(_initialized)
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(dispose): _host.tree_exiting.disconnect(dispose)
	_sample = null
	_receiver = null
	_health = null
	_host = null
	_view = Callable()
	_layers.clear()
	_pieces.clear()
	source = null
	_fragment_texture = null
	active = false
	visible = false
	queue_free()

func _exit_tree() -> void:
	dispose()
