class_name PlainsRevisionRemains
extends EnemyFeedback01Remains
## The existing accepted-death/support owner, rendered by the live body's rig.
## No collision or attack node is created. Actor owns damage and cancellation.
const HOLD_SECONDS := 0.75
const FADE_SECONDS := 0.55
var _rig: RefCounted
var _captured_pose: Dictionary = {}
var _persistent := false
var _death_seconds := 1.1
var _hold_age := 0.0
var _fade := 1.0
var _bell_played := false
const LOW_BELL: AudioStream = preload("res://assets/audio/plains_revision_01/root_bell_fall.wav")

func keeps_corpse() -> bool:
	return bool((_view.call() as Dictionary).get("persistent",false)) if _view.is_valid() else false

func _sync_material() -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("hit_flash",0.0 if restored or _sample==null else _sample.flash_strength())

func _committed(context: Dictionary) -> void:
	super._committed(context)
	_sync_material()

func _initialized(result: ActorResourceResult) -> void:
	super._initialized(result)
	if material is ShaderMaterial: (material as ShaderMaterial).set_shader_parameter("hit_flash",0.0)

func _capture() -> void:
	var packet: Dictionary = _view.call()
	_rig = packet.get("rig") as RefCounted
	var captured: Variant = packet.get("pose", {})
	_captured_pose = captured.duplicate(true) if captured is Dictionary else {}
	_persistent = bool(packet.get("persistent", false))
	_death_seconds = maxf(0.1, float(packet.get("death_seconds", 1.1)))
	var transform_value: Transform2D = packet.get("transform", Transform2D.IDENTITY)
	global_position = transform_value.origin
	_saved_collision_foot = packet.get("contact_foot", global_position)
	global_rotation = 0.0
	global_scale = Vector2.ONE
	_face = float(packet.get("face", 1.0))
	# Corpses retain the same 1wu sampling and material family as their live rig.
	if not material is ShaderMaterial or (material as ShaderMaterial).shader != preload("res://scripts/enemies/plains_revision_skin.gdshader"):
		var rig_material := ShaderMaterial.new()
		rig_material.shader = preload("res://scripts/enemies/plains_revision_skin.gdshader")
		material = rig_material
	_frames = null
	_support = null
	_has_floor = false
	_landed = false
	_velocity_y = 0.0
	_fall_age = 0.0
	_fall_start_y = global_position.y
	_contact_age = 0.0
	_frame_foot = 0.0
	_hold_age = 0.0
	_fade = 1.0
	_bell_played = false
	_feet.clear()

func _set_frame(index: int) -> void:
	# Retain the existing stage snapshot's terminal-frame contract. This is a
	# continuous rig pose, not a texture swap at these four reporting intervals.
	frame_index = clampi(index, 4, 7)
	source = _rig.get("texture") as Texture2D if _rig != null else null
	bounds = _rig.get("bounds") if _rig != null else Rect2()
	_frame_foot = 0.0

func _restore_static() -> void:
	_capture()
	if _persistent:
		# Reuse the exact support-local pose validation and bounded missing-
		# support semantics. The parent calls our capture/set_frame overrides.
		super._restore_static()
		return
	# A transient body's saved death must not start another collapse/fade.
	_set_frame(7)
	_begun = true
	_finished_death = true
	active = false
	visible = false
	restored = true
	settled = true
	age = 0.0
	phase = &"faded"
	_fade = 0.0
	restore_support_status = &"transient_restored_hidden"
	restore_support_verified = false
	queue_redraw()

func presentation_snapshot(support_identity: Dictionary) -> Dictionary:
	# Only the charger opts into the existing persistent corpse ledger.
	return super.presentation_snapshot(support_identity) if _persistent else {}

func _physics_process(delta: float) -> void:
	if _disposed or not active or _health == null or get_tree().paused or _epoch != _health.epoch or delta <= 0.0: return
	if restored and _restore_pending:
		_restore_pending = false
		_restore_static()
		return
	_sync_material()
	_follow_support()
	# With no recorded corpse pose, a restored collision foot that has no real
	# contact stays hidden just as the parent does; do not invent a distant floor.
	if restored and settled and not _landed: return
	if not restored: age += delta
	var was_finished := _finished_death
	if not _landed:
		var old_foot_y := global_position.y
		var hit := _find_support(FLOOR_REACH, old_foot_y)
		_velocity_y += GRAVITY * delta
		var next_y := global_position.y + _velocity_y * delta
		if not hit.is_empty() and next_y >= (hit.position as Vector2).y:
			_attach_support(hit)
		else:
			global_position.y = next_y
			_fall_age += delta
			if global_position.y > _fall_start_y + FLOOR_REACH or _fall_age >= VOID_SECONDS:
				visible = false
				active = false
				settled = false
				phase = &"void"
				queue_redraw()
				return
	if _landed:
		_contact_age += delta
		global_position = _floor_point
		var progress := 1.0 if _finished_death or restored else clampf(_contact_age / _death_seconds, 0.0, 1.0)
		if not restored and not _bell_played and _rig != null and _rig.get("kind")==&"root_bell" and progress>=.56:
			_bell_played = true
			var audio := get_tree().get_first_node_in_group(&"game_audio") as GameAudio
			if audio != null: audio.play(&"bell",LOW_BELL)
		_set_frame(4 + mini(3, floori(progress * 4.0)))
		if progress >= 1.0:
			_finished_death = true
			settled = true
			phase = &"resting"
			if not _persistent and not restored:
				if was_finished: _hold_age += delta
				if _hold_age > HOLD_SECONDS:
					phase = &"fading"
					_fade = clampf(1.0 - (_hold_age - HOLD_SECONDS) / FADE_SECONDS, 0.0, 1.0)
					if _fade <= 0.0:
						visible = false
						active = false
						phase = &"faded"
		else:
			settled = false
			phase = &"settling"
	else:
		settled = false
		phase = &"falling"
		_set_frame(7 if _finished_death or restored else 4)
	queue_redraw()

func _draw() -> void:
	if not active or _rig == null or source == null: return
	_sync_material()
	var pose := _captured_pose.duplicate(true)
	pose["dead"] = true
	pose["death"] = 1.0 if _finished_death or restored else clampf(_contact_age / _death_seconds, 0.0, 1.0) if _landed else 0.0
	pose["air"] = not _landed
	pose["death_clock"] = age
	# A separate contact impulse lets the body/wing joints recoil while their
	# actual support foot remains at zero; it never moves Actor or its collider.
	pose["landing"] = sin(PI * clampf(_contact_age / 0.22, 0.0, 1.0)) if _landed and not _finished_death and not restored and _contact_age < 0.22 else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_face, 1.0))
	_rig.call("draw_pose", self, pose, Color(1.0, 1.0, 1.0, _fade))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func dispose() -> void:
	_rig = null
	_captured_pose.clear()
	super.dispose()
