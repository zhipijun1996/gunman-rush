class_name EnemyFeedback01Remains
extends Node2D
## Stage-owned authored D1-D4 handoff. Cosmetic support queries never move Actor.
## Optional stage-ledger pose restores actual settled pixels, never a guessed floor.
const DEATH_SECONDS := EnemyFeedback01Frames.DEATH_SECONDS
const FRAME_SECONDS := DEATH_SECONDS / 4.0
const FLOOR_REACH := 2048.0
const GRAVITY := 720.0
const VOID_SECONDS := 4.0
const CONTACT_SLOP := 2.0
var active := false
var settled := false
var restored := false
var age := 0.0
var accepted_starts := 0
var phase: StringName = &"inactive"
var source: Texture2D
var bounds := Rect2()
var frame_index := 4
var restore_support_status: StringName = &"not_restored"
var restore_support_verified := false
var flash_material := ShaderMaterial.new()
var _sample: EnemyFeedback01
var _receiver: Damageable
var _health: HealthState
var _motor: Node2D
var _host: Node2D
var _view: Callable
var _frames: EnemyFeedback01Frames
var _aerial := false
var _face := 1.0
var _epoch := -1
var _last_serial := -1
var _begun := false
var _disposed := false
var _restore_pending := false
var _landed := false
var _finished_death := false
var _velocity_y := 0.0
var _fall_age := 0.0
var _fall_start_y := 0.0
var _contact_age := 0.0
var _support: WeakRef
var _support_anchor := Vector2.ZERO
var _floor_point := Vector2.ZERO
var _has_floor := false
var _frame_foot := 0.0
var _saved_collision_foot := Vector2.ZERO
var _feet: Dictionary = {}
var _saved_presentation: Dictionary = {}
var _saved_support: WeakRef
var _kill_hold_remaining := 0.0
var _landing_sound_played := false

func _feedback_actor() -> EnemyActor:
	return _motor.get_node_or_null("Actor") as EnemyActor if is_instance_valid(_motor) else null

func _reset_death_feedback() -> void:
	_kill_hold_remaining = 0.0
	_landing_sound_played = false

func _advance_after_kill_hold(delta: float) -> float:
	if restored or _kill_hold_remaining <= 0.0: return delta
	var held := minf(delta, _kill_hold_remaining)
	_kill_hold_remaining -= held
	return delta - held

func _play_landing_feedback(stream_override: AudioStream = null) -> void:
	if restored or _landing_sound_played: return
	_landing_sound_played = true
	PlainsEnemyAudio.landed(self, _feedback_actor(), stream_override)

func support_node() -> Node2D:
	return _support.get_ref() as Node2D if _support != null else null

func presentation_snapshot(support_identity: Dictionary) -> Dictionary:
	# Only an actually landed final frame is a persistent corpse pose. An actor's
	# collision feet are deliberately not substituted for its fallen pixels.
	var support := support_node()
	if _disposed or not active or not settled or not _landed or frame_index != 7 or not visible or support_identity.is_empty(): return {}
	if not is_instance_valid(support) or support.is_queued_for_deletion(): return {}
	var stage := get_parent() as Node2D
	var location := stage.to_local(global_position)
	return {"version":1,"frame":7,"position":[location.x,location.y],"face":_face,"support":support_identity.duplicate(true),"support_anchor":[_support_anchor.x,_support_anchor.y]}

static func _finite_pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for coordinate: Variant in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)): return false
	return Vector2(value[0],value[1]).is_finite()

static func valid_presentation_snapshot(value: Variant) -> bool:
	if not value is Dictionary: return false
	# Godot JSON roundtrips integer-looking numbers as floats too.
	if not (value.get("version") is int or value.get("version") is float) or value.version != 1: return false
	if not (value.get("frame") is int or value.get("frame") is float) or value.frame != 7: return false
	if not _finite_pair(value.get("position")) or not _finite_pair(value.get("support_anchor")): return false
	if not (value.get("face") is int or value.get("face") is float) or (value.face != -1 and value.face != 1): return false
	var identity: Variant = value.get("support")
	if not identity is Dictionary: return false
	match identity.get("kind"):
		"module":
			for key: String in ["module","body"]:
				if not identity.get(key) is String or identity[key].is_empty() or identity[key].contains("@") or identity[key].validate_node_name() != identity[key]: return false
		"ground":
			var rect: Variant = identity.get("rect")
			if not rect is Array or rect.size() != 4 or not _finite_pair(rect.slice(0,2)) or not _finite_pair(rect.slice(2,4)) or rect[2] <= 0 or rect[3] <= 0: return false
		"shortcut":
			if not identity.get("id") is String or identity.id.is_empty(): return false
		_: return false
	return true

func restore_presentation(value: Variant, support: Node2D) -> bool:
	if _disposed or _health == null or not _health.terminal: return false
	_saved_presentation = value.duplicate(true) if valid_presentation_snapshot(value) else {}
	_saved_support = weakref(support) if is_instance_valid(support) and not support.is_queued_for_deletion() else null
	_restore_static()
	_restore_pending = true # Recheck only this contact after physics assembly sync.
	return not _saved_presentation.is_empty()

func _init() -> void:
	flash_material.shader = preload("res://game/enemies/presentation/enemy_feedback_01_flash.gdshader")
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
	_reset_death_feedback()
	var data: Dictionary = _view.call()
	_frames = data.frames as EnemyFeedback01Frames
	# Host supplies its actual world bottom-center and facing. The helper bounds
	# are already body-sized and bottom-centered; do not scale or turn a live PNG.
	var pose: Transform2D = data.transform
	global_position = pose.origin
	_saved_collision_foot = data.contact_foot
	global_rotation = 0.0
	global_scale = Vector2.ONE
	_face = float(data.face)
	flash_material.set_shader_parameter("readable_material", 1.0 if data.get("readable_material", false) else 0.0)
	flash_material.set_shader_parameter("copper_wings", 1.0 if _aerial else 0.0)
	flash_material.set_shader_parameter("lifeless", 0.0)
	_support = null
	_has_floor = false
	_landed = false
	_velocity_y = 0.0
	_fall_age = 0.0
	_fall_start_y = global_position.y
	_contact_age = 0.0
	_feet.clear()

func _set_frame(index: int) -> void:
	frame_index = index
	source = _frames.texture(index)
	bounds = _frames.bounds(index)
	var uv_rect := Vector4(0, 0, 1, 1)
	if source is AtlasTexture:
		var atlas := source as AtlasTexture
		var size := atlas.atlas.get_size()
		uv_rect = Vector4(atlas.region.position.x/size.x, atlas.region.position.y/size.y, atlas.region.size.x/size.x, atlas.region.size.y/size.y)
	flash_material.set_shader_parameter("frame_uv_rect", uv_rect)
	flash_material.set_shader_parameter("authored_palette", 1.0)
	if not _feet.has(index):
		var image := source.get_image()
		var bottom := 0.0
		for y: int in range(image.get_height() - 1, -1, -1):
			var found := false
			for x: int in image.get_width():
				if image.get_pixel(x, y).a >= .5:
					bottom = bounds.position.y + float(y + 1) / float(image.get_height()) * bounds.size.y
					found = true
					break
			if found: break
		_feet[index] = bottom
	_frame_foot = float(_feet[index])

func _find_support(reach: float = FLOOR_REACH, previous_foot_y: float = INF) -> Dictionary:
	# A single vertical center ray finds the first real standable surface below
	# this body. Side ledges, overhead floors and a departed ferry are no fallback.
	var foot := global_position + Vector2(0, _frame_foot)
	var from := foot - Vector2(0, CONTACT_SLOP)
	# Authored limb changes can move the pixel foot across a thin surface even
	# before gravity advances. Sweep from the previous foot as well as this one.
	if is_finite(previous_foot_y): from.y = minf(from.y, previous_foot_y-CONTACT_SLOP)
	var query := PhysicsRayQueryParameters2D.create(from, foot + Vector2(0, reach), 1)
	query.collide_with_areas = false
	if _motor is CollisionObject2D: query.exclude = [(_motor as CollisionObject2D).get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP) < .65: return {}
	return hit

func _attach_support(hit: Dictionary) -> void:
	_floor_point = hit.position
	_has_floor = true
	_landed = true
	_velocity_y = 0.0
	_contact_age = 0.0
	_support = null
	if hit.collider is Node2D:
		var support := hit.collider as Node2D
		_support = weakref(support)
		_support_anchor = support.to_local(_floor_point)
	global_position = _floor_point - Vector2(0, _frame_foot)

func _follow_support() -> void:
	if not _landed or _support == null: return
	var support := _support.get_ref() as Node2D
	if is_instance_valid(support) and not support.is_queued_for_deletion():
		_floor_point = support.to_global(_support_anchor)
		global_position = _floor_point - Vector2(0, _frame_foot)
		return
	# Support lifetime is not extended by the cosmetic leaf. A completed D4 can
	# fall from removed geometry, keeping D4 and its original accepted receipt.
	_support = null
	_has_floor = false
	_landed = false
	settled = false
	_velocity_y = 0.0
	_fall_age = 0.0
	_fall_start_y = global_position.y
	phase = &"falling"

func _committed(context: Dictionary) -> void:
	if _disposed or _begun or _sample == null or _health == null or not _health.terminal or not _sample.death_active: return
	if _epoch != _health.epoch or _sample.epoch() != _epoch: return
	if _sample.last_event_id != StringName(context.get("event_id", "")) or context.get("target_epoch", -1) != _epoch or _last_serial == _sample.impact_serial: return
	# EnemyFeedback01 records APPLIED damage only. The local damaged event must
	# match that exact lethal result; generic contact or a replay cannot start it.
	_last_serial = _sample.impact_serial
	_begun = true
	_capture()
	if PlainsEnemyAudio.supports(_feedback_actor()):
		var hold := _sample.tuning.plains_kill_hold_seconds
		_kill_hold_remaining = clampf(hold, 0.0, 0.06) if is_finite(hold) else 0.0
	_set_frame(4)
	# The legacy flyer art extends below its collision feet. When its drawn
	# lower edge already crosses a real floor, confirm that surface from the
	# actual Motor center before starting the visual fall; never miss the top
	# because the ray starts inside it. This is not used for saved-dead restore.
	var foot := global_position + Vector2(0, _frame_foot)
	if foot.y > _motor.global_position.y:
		var query := PhysicsRayQueryParameters2D.create(_motor.global_position, foot + Vector2(0, CONTACT_SLOP), 1)
		query.collide_with_areas = false
		if _motor is CollisionObject2D: query.exclude = [(_motor as CollisionObject2D).get_rid()]
		var contact := get_world_2d().direct_space_state.intersect_ray(query)
		if not contact.is_empty() and (contact.normal as Vector2).dot(Vector2.UP) >= .65 and foot.y >= (contact.position as Vector2).y:
			_attach_support(contact)
	_finished_death = false
	active = true
	visible = true
	restored = false
	restore_support_status = &"not_restored"
	restore_support_verified = false
	settled = false
	age = 0.0
	phase = &"falling"
	accepted_starts += 1
	flash_material.set_shader_parameter("hit_flash", _sample.flash_strength())
	queue_redraw()

func _initialized(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null or result.operation != &"initialize" or result.snapshot.epoch != _health.epoch: return
	_epoch = _health.epoch
	_begun = false
	active = false
	visible = false
	settled = false
	restored = false
	restore_support_status = &"not_restored"
	restore_support_verified = false
	age = 0.0
	phase = &"inactive"
	_support = null
	_saved_presentation.clear()
	_saved_support = null
	_frames = null
	_feet.clear()
	source = null
	bounds = Rect2()
	_landed = false
	_finished_death = false
	_restore_pending = false
	_reset_death_feedback()
	flash_material.set_shader_parameter("hit_flash", 0.0)
	flash_material.set_shader_parameter("authored_palette", 0.0)
	flash_material.set_shader_parameter("frame_uv_rect", Vector4(0, 0, 1, 1))
	if _health.terminal:
		_restore_static()
		_restore_pending = true
	queue_redraw()

func _restore_static() -> void:
	_capture()
	_set_frame(7)
	_finished_death = true
	_begun = true
	active = true
	restored = true
	settled = true
	age = 0.0
	phase = &"resting"
	if not _saved_presentation.is_empty():
		var location: Array = _saved_presentation.position
		global_position = (get_parent() as Node2D).to_global(Vector2(location[0],location[1]))
		_face = float(_saved_presentation.face)
		var support := _saved_support.get_ref() as Node2D if _saved_support != null else null
		var hit: Dictionary = {}
		if is_instance_valid(support) and not support.is_queued_for_deletion():
			var anchor: Array = _saved_presentation.support_anchor
			var foot := support.to_global(Vector2(anchor[0],anchor[1]))
			var query := PhysicsRayQueryParameters2D.create(foot-Vector2(0,CONTACT_SLOP),foot+Vector2(0,CONTACT_SLOP),1)
			query.collide_with_areas = false
			hit = get_world_2d().direct_space_state.intersect_ray(query)
			if hit.get("collider") != support or (not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP) < .65): hit = {}
		if not hit.is_empty():
			_attach_support(hit)
			restore_support_verified = true
			restore_support_status = &"saved_support_contact"
		else:
			# The saved support is gone/changed. Keep the recorded world pose and
			# original D4, then use the existing bounded fall, with no death replay.
			settled = false
			_fall_start_y = global_position.y
			phase = &"falling"
			restore_support_verified = false
			restore_support_status = &"saved_support_missing"
		visible = true
		flash_material.set_shader_parameter("hit_flash",0.0)
		queue_redraw()
		return
	# A dead save has no death trajectory/support-local pose. Only an existing
	# contact at its saved foot is defensible; a distant downward ray is not a
	# license to teleport D4 to a guessed floor. Missing support remains explicit.
	# Art may extend below the Motor's feet (legacy flyer). Saved collision
	# contact is an actual current-stage surface claim; visual atlas padding is
	# not. Verify only its +/-2wu band, never search a distant floor for restore.
	var query := PhysicsRayQueryParameters2D.create(_saved_collision_foot-Vector2(0, CONTACT_SLOP), _saved_collision_foot+Vector2(0, CONTACT_SLOP), 1)
	query.collide_with_areas = false
	if _motor is CollisionObject2D: query.exclude = [(_motor as CollisionObject2D).get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP) < .65: hit = {}
	if not hit.is_empty():
		_attach_support(hit)
		restore_support_verified = true
		restore_support_status = &"current_stage_contact"
	else:
		restore_support_verified = false
		restore_support_status = &"missing_saved_support"
	visible = _has_floor
	flash_material.set_shader_parameter("hit_flash", 0.0)
	flash_material.set_shader_parameter("lifeless", 0.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _disposed or not active or get_tree().paused or _epoch != _health.epoch: return
	if restored and _restore_pending:
		# Actor.restore initializes HP before Stage applies its saved position and
		# facing. Reconcile exactly once after assembly, still D4 with zero replay.
		_restore_pending = false
		_restore_static()
		return
	if not restored and _kill_hold_remaining > 0.0:
		delta = _advance_after_kill_hold(delta)
		if delta <= 0.0:
			queue_redraw()
			return
	_follow_support()
	if settled: return
	if not restored: age = minf(DEATH_SECONDS, age + delta)
	var previous_foot_y := global_position.y + _frame_foot
	var index := 7 if restored or _finished_death else 4 + mini(3, floori(age / FRAME_SECONDS))
	if not _landed and not _finished_death and not restored: index = mini(index, 6)
	_set_frame(index)
	if _landed: global_position = _floor_point - Vector2(0, _frame_foot)
	if not _landed:
		var hit := _find_support(FLOOR_REACH, previous_foot_y)
		_velocity_y += GRAVITY * delta
		var next_y := global_position.y + _velocity_y * delta
		if not hit.is_empty() and next_y + _frame_foot >= (hit.position as Vector2).y:
			_attach_support(hit)
		else:
			global_position.y = next_y
			_fall_age += delta
			if global_position.y > _fall_start_y + FLOOR_REACH or _fall_age >= VOID_SECONDS:
				visible = false
				active = false
				phase = &"void"
				flash_material.set_shader_parameter("hit_flash", 0.0)
				queue_redraw()
				return
	else:
		_contact_age += delta
	if _landed and _contact_age >= FRAME_SECONDS * .6:
		_play_landing_feedback()
	# D3 holds during a long airborne fall. Only genuine support contact enables
	# D4; authored frame pixels supply the collapse, with no sprite rotation.
	if _landed and age >= FRAME_SECONDS * 3.0:
		_set_frame(7)
		global_position = _floor_point - Vector2(0, _frame_foot)
	if frame_index == 7: _finished_death = true
	if _landed:
		phase = &"settling"
		if frame_index == 7 and _contact_age >= FRAME_SECONDS and (restored or age >= DEATH_SECONDS):
			settled = true
			phase = &"resting"
	else:
		phase = &"falling"
	flash_material.set_shader_parameter("hit_flash", 0.0 if restored else _sample.flash_strength())
	# Authored D1-D4 already carry their corpse palette/closed eyes. Never grey
	# or darken these new source pixels with the former whole-body material pass.
	flash_material.set_shader_parameter("lifeless", 0.0)
	queue_redraw()

func _draw() -> void:
	if not active or source == null: return
	# A real contact impulse: body rebounds once and comes fully to rest.
	# The authored final wing-tip pose follows the earlier body contact.
	var rebound := -.8*sin(PI*clampf(_contact_age/.18,0,1)) if _aerial and _landed and not settled and not restored and _contact_age<.18 else 0.0
	draw_set_transform(Vector2(0,rebound), 0.0, Vector2(_face, 1))
	draw_texture_rect(source, bounds, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func dispose() -> void:
	if _disposed: return
	_disposed = true
	# Stage-owned remains may outlive a removed host until stage teardown.
	# Stop only this body's contact tail even before the sibling leaves tree.
	GameAudio.stop_origin(self, false)
	if is_instance_valid(_receiver) and _receiver.damaged.is_connected(_committed): _receiver.damaged.disconnect(_committed)
	if _health != null and _health.changed.is_connected(_initialized): _health.changed.disconnect(_initialized)
	if is_instance_valid(_host) and _host.tree_exiting.is_connected(dispose): _host.tree_exiting.disconnect(dispose)
	_sample = null
	_receiver = null
	_health = null
	_motor = null
	_host = null
	_view = Callable()
	_frames = null
	_feet.clear()
	_support = null
	_saved_support = null
	_saved_presentation.clear()
	source = null
	active = false
	visible = false
	queue_free()

func _exit_tree() -> void:
	dispose()
