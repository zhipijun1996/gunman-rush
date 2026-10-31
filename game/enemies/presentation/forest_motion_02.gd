class_name ForestMotion02
extends RefCounted
## Body-only articulation of the existing transparent forest masters.
## Actor, attack deadlines, warnings, line endpoints and tether roots stay external.
const METADATA := &"forest_body_motion_02"
const DEATH_SECONDS := 0.38
const GRID := 16
const MOTION_GAIN := 0.35
var _mesh := ArrayMesh.new()
var _mesh_texture: Texture2D
var _mesh_bounds := Rect2()
var _mesh_points := PackedVector2Array()
var _joints: Array[Dictionary] = []
var _influence_layout: Array = []
var _influence_kind: StringName = &""
var _influence_foot_y := 0.0
var _influence_ready := false
var _influence_indices: Array[PackedInt32Array] = []
var _influence_weights: Array[PackedFloat64Array] = []
var _influence_totals := PackedFloat64Array()
var _influence_masks := PackedFloat64Array()
var _influence_clamp_y := PackedByteArray()
var _influence_has_mask := false
var _influence_pivots := PackedVector2Array()
var _influence_angles := PackedFloat64Array()
var clock := 0.0
var stride := 0.0
var tension := 0.0
var release := 0.0
var flight := 0.0
var death_elapsed := 0.0
var _feedback: EnemyFeedback01
var _epoch := -1
var _last_position := Vector2.ZERO
var _terminal := false
var _facing := 1.0
var _turn_from := 1.0
var _turn_to := 1.0
var _turn_elapsed := 0.12
var _last_body_pose := Vector2.ONE

static func install(canvas: Node2D) -> ForestMotion02:
	var motion := ForestMotion02.new()
	var hit := canvas.get_meta(EnemyHitTemplate.METADATA) as EnemyHitTemplate if canvas.has_meta(EnemyHitTemplate.METADATA) else null
	if is_instance_valid(hit): motion._feedback = hit.sample
	canvas.set_meta(METADATA, motion)
	return motion

func sync_epoch(actor: EnemyActor, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)) or _epoch == int(state.epoch): return
	_epoch = int(state.epoch)
	_last_position = state.position
	clock = 0.0
	stride = 0.0
	tension = 0.0
	release = 0.0
	flight = 0.0
	_terminal = bool(state.terminal)
	_facing = float(state.facing)
	_turn_to = _facing
	_turn_from = _facing
	_turn_elapsed = 0.12
	_last_body_pose = Vector2.ONE
	# Restored terminal is a pose, never a replay of the lethal event.
	death_elapsed = DEATH_SECONDS if _terminal and (_feedback == null or _feedback.restored_terminal) else 0.0

func synchronize(actor: EnemyActor, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)): return
	sync_epoch(actor,state)
	_last_position = state.position
	_facing = float(state.facing)
	_turn_to = _facing
	_turn_from = _facing
	_turn_elapsed = 0.12

func advance(actor: EnemyActor, delta: float, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)): return
	sync_epoch(actor,state)
	var position_now: Vector2 = state.position
	var distance := position_now.distance_to(_last_position)
	_last_position = position_now
	if bool(state.terminal):
		_terminal = true
		death_elapsed = minf(DEATH_SECONDS, death_elapsed + delta)
		tension = move_toward(tension, 0.0, delta/DEATH_SECONDS)
		release = move_toward(release, 0.0, delta/DEATH_SECONDS)
		flight = move_toward(flight, 0.0, delta/DEATH_SECONDS)
		_facing = lerpf(_facing, _turn_to, minf(1.0, delta/0.05))
		if death_elapsed >= DEATH_SECONDS: _facing = _turn_to
		return
	if delta <= 0.0: return
	clock += delta
	var target_facing := float(state.facing)
	if target_facing != _turn_to:
		_turn_from = _facing
		_turn_to = target_facing
		_turn_elapsed = 0.0
	_turn_elapsed = minf(0.12, _turn_elapsed+delta)
	_facing = lerpf(_turn_from, _turn_to, smoothstep(0.0, 0.12, _turn_elapsed))
	# Distance, not wall time, owns walking feet. Ignore restoration/teleport jumps.
	if distance < 32.0: stride += distance * 0.32
	var phase: StringName = state.state
	var blend := 1.0 - exp(-delta / 0.065)
	tension = lerpf(tension, 1.0 if phase in [&"telegraph", &"hold", &"turn"] else 0.0, blend)
	release = lerpf(release, 1.0 if phase in [&"attack", &"extend", &"travel", &"swing"] else 0.0, blend)
	flight = lerpf(flight, 1.0 if phase in [&"flight", &"cancelled_fall", &"recovery_fall"] else 0.0, blend)

static func draw_body(canvas: Node2D, actor: EnemyActor, texture: Texture2D, bounds: Rect2, facing: float, tint: Color) -> bool:
	var motion := canvas.get_meta(METADATA) as ForestMotion02 if canvas.has_meta(METADATA) else null
	if motion == null: return false
	motion._draw(canvas, actor, texture, bounds, facing, tint)
	return true

func _draw(canvas: Node2D, actor: EnemyActor, texture: Texture2D, bounds: Rect2, facing: float, tint: Color) -> void:
	_joints.clear()
	var hit_pose := EnemyHitTemplate.body_pose(canvas)
	if actor.health.terminal:
		hit_pose = _last_body_pose.lerp(Vector2.ONE, smoothstep(0.0,0.12,death_elapsed))
	else:
		_last_body_pose = hit_pose
	# Keep accepted pose bookkeeping before a pure body-math cull. The host
	# still draws warnings/HP/effects after this returns in identity coordinates.
	if not body_mesh_visible(canvas,bounds):
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var hit_origin := Vector2.ZERO if actor.definition.aerial else Vector2(0, actor.definition.collision_size.y * 0.5 * (1.0-hit_pose.y))
	if actor.definition.behavior_id == &"forest_swing_pod":
		hit_origin = Vector2(0,-13)*(Vector2.ONE-hit_pose)
	# A short side-on turn changes only the body; shield/aim remain committed.
	var body_facing := _facing if facing != 1.0 or actor.definition.behavior_id in [&"forest_lantern", &"forest_crossbranch", &"forest_bark_beetle"] else 1.0
	if absf(body_facing)<0.16: body_facing = 0.16 if body_facing>=0.0 else -0.16
	var body_transform := Transform2D(0.0, Vector2(body_facing*hit_pose.x, hit_pose.y), 0.0, hit_origin)
	var terminal := actor.health.terminal
	var death := smoothstep(0.0, DEATH_SECONDS, death_elapsed) if terminal else 0.0
	var recoil := clampf(absf(1.0-hit_pose.y)*4.0, 0.0, 0.45)
	var breath := sin(clock*3.0)*0.025 if not terminal else 0.0
	var kind: StringName = actor.definition.behavior_id
	var source_size := Vector2(texture.get_size())
	match kind:
		&"forest_lantern":
			# Thorax and lantern keep their original centers; each wing hinges at its root.
			_part(canvas,texture,bounds,Rect2(0,0,48,12),source_size,Vector2.ZERO,breath,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(16,12,16,12),source_size,Vector2.ZERO,0.0,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(0,24,48,16),source_size,Vector2(0,3),-breath+tension*0.08-release*0.06+death*0.24,body_transform,tint)
			for side: int in [-1,1]:
				var flap := sin(clock*(19.0 if release>0.4 else 14.0))*0.42
				var angle := float(side)*(flap*(1.0-death)-death*0.8-tension*0.18+recoil)
				_part(canvas,texture,bounds,Rect2(0 if side<0 else 32,12,16,12),source_size,Vector2(side*6,-1.5),angle,body_transform,tint)
		&"forest_seed_sentry":
			# Root/base stays planted; crown and seed chamber load then kick separately.
			_part(canvas,texture,bounds,Rect2(0,44,44,8),source_size,Vector2(0,17),0.0,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(0,16,44,28),source_size,Vector2(0,13.5),breath-tension*0.10+release*0.09+recoil*0.3+death*0.48,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(0,0,44,16),source_size,Vector2(0,-7.5),-breath+tension*0.13-release*0.16+death*0.65,body_transform,tint)
		&"forest_swing_pod":
			# Cap is the unmodified (-13wu) tether attachment. Only the pod below it lags.
			_part(canvas,texture,bounds,Rect2(0,0,36,8),source_size,Vector2(0,-13),0.0,body_transform,tint)
			var lag := clampf(actor.motor.velocity.x/800.0,-0.20,0.20)
			_part(canvas,texture,bounds,Rect2(0,8,36,36),source_size,Vector2(0,-10.5),lag+breath+recoil*0.3+death*0.36,body_transform,tint)
		&"forest_bark_beetle":
			# Three real leg strips alternate while the bark shell/shield remain rigid.
			for leg: int in 3:
				var gait := sin(stride+leg*PI)*0.17*(1.0-death)
				_part(canvas,texture,bounds,Rect2(leg*16,22,16,10),source_size,Vector2(-12+leg*12,6),gait+death*(0.42 if leg%2==0 else -0.42),body_transform,tint)
			_part(canvas,texture,bounds,Rect2(0,0,32,22),source_size,Vector2(-2,6),breath-tension*0.05+recoil*0.1+death*0.15,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(32,0,16,22),source_size,Vector2(6,3),tension*0.10-release*0.08+recoil*0.4+death*0.35,body_transform,tint)
		&"forest_crossbranch":
			# The central trunk/feet own contact; side branch limbs fold in flight.
			for side: int in [-1,1]:
				var angle := float(side)*(breath+tension*0.14-flight*0.38+recoil*0.5+death*0.55)
				_part(canvas,texture,bounds,Rect2(0 if side<0 else 32,0,16,48),source_size,Vector2(side*3,3),angle,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(16,16,16,32),source_size,Vector2(0,16),0.0,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(16,0,16,16),source_size,Vector2(0,-6.5),breath-tension*0.12+flight*0.13+death*0.5,body_transform,tint)
		&"forest_thread_spider", &"forest_bible_weaver":
			# Existing silk-bell body, with independent left/right leg fans and abdomen.
			var bell := kind == &"forest_bible_weaver"
			for side: int in [-1,1]:
				var tremor := sin(clock*(5.0 if bell else 4.0)+side)*0.025*(1.0-death)
				var angle := float(side)*(tremor+tension*(0.14 if bell else 0.22)-release*0.17+recoil*0.5+death*0.68)
				_part(canvas,texture,bounds,Rect2(0 if side<0 else 20,0,12,32),source_size,Vector2(side*5,0),angle,body_transform,tint)
			_part(canvas,texture,bounds,Rect2(12,0,8,32),source_size,Vector2(0,8),breath+release*(0.07 if bell else -0.06)+death*0.18,body_transform,tint)
	_draw_connected(canvas,actor,texture,bounds,body_transform,tint)
	canvas.draw_set_transform(Vector2.ZERO)

static func _part(canvas: Node2D, _texture: Texture2D, bounds: Rect2, source: Rect2, source_size: Vector2, pivot: Vector2, angle: float, _body_transform: Transform2D, _tint: Color) -> void:
	var motion := canvas.get_meta(METADATA) as ForestMotion02
	var ratio := bounds.size/source_size
	var destination := Rect2(bounds.position+source.position*ratio,source.size*ratio)
	# Regions describe joint influence only. The original full body remains one skin.
	motion._joints.append({"region":destination,"margin":ratio*6.0,"pivot":pivot,"angle":angle})

func _prepare_mesh(texture: Texture2D,bounds: Rect2) -> void:
	_influence_ready = false
	_mesh_texture = texture
	_mesh_bounds = bounds
	_mesh_points = PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y: int in GRID+1:
		for x: int in GRID+1:
			var uv := Vector2(float(x)/GRID,float(y)/GRID)
			_mesh_points.append(bounds.position+uv*bounds.size)
			uvs.append(uv)
	for y: int in GRID:
		for x: int in GRID:
			var first := y*(GRID+1)+x
			indices.append_array(PackedInt32Array([first,first+1,first+GRID+2,first,first+GRID+2,first+GRID+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _mesh_points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)

func _deform_connected(point: Vector2,kind: StringName,foot_y: float) -> Vector2:
	var delta_position := Vector2.ZERO
	var total := 0.0
	for joint: Dictionary in _joints:
		var region: Rect2 = joint.region
		var margin: Vector2 = joint.margin
		var wx := smoothstep(region.position.x-margin.x,region.position.x+margin.x,point.x)*(1.0-smoothstep(region.end.x-margin.x,region.end.x+margin.x,point.x))
		var wy := smoothstep(region.position.y-margin.y,region.position.y+margin.y,point.y)*(1.0-smoothstep(region.end.y-margin.y,region.end.y+margin.y,point.y))
		var weight := wx*wy
		var pivot: Vector2 = joint.pivot
		delta_position += ((point-pivot).rotated(float(joint.angle))+pivot-point)*weight
		total += weight
	if total>0.0: delta_position *= MOTION_GAIN/total
	var uv := (point-_mesh_bounds.position)/_mesh_bounds.size
	if kind==&"forest_seed_sentry":
		delta_position *= 1.0-smoothstep(0.88,0.97,uv.y)
	elif kind==&"forest_crossbranch":
		delta_position *= 1.0-smoothstep(0.65,0.95,uv.y)
	elif kind==&"forest_swing_pod":
		# The entire stem/cap neighborhood contains the real fixed tether point.
		delta_position *= smoothstep(0.15,0.60,uv.y)
	elif kind in [&"forest_thread_spider",&"forest_bible_weaver",&"forest_lantern"]:
		delta_position *= smoothstep(0.0,4.0,point.length())
	elif kind==&"forest_bark_beetle" and point.y>=foot_y-1.0:
		# A lifted foot is allowed; deformation never pushes a supported foot below soil.
		delta_position.y = minf(0.0,delta_position.y)
	return point+delta_position

func _prepare_influences(kind: StringName,foot_y: float) -> void:
	# Geometry is keyed by actual influence data, not species identity alone.
	# Angles stay dynamic and are read even on a cache hit.
	var layout: Array = []
	_influence_angles = PackedFloat64Array()
	for joint: Dictionary in _joints:
		layout.append(joint.region)
		layout.append(joint.margin)
		layout.append(joint.pivot)
		_influence_angles.append(float(joint.angle))
	if _influence_ready and layout==_influence_layout and kind==_influence_kind and foot_y==_influence_foot_y: return
	_influence_layout = layout
	_influence_kind = kind
	_influence_foot_y = foot_y
	_influence_indices.clear()
	_influence_weights.clear()
	_influence_totals = PackedFloat64Array()
	_influence_masks = PackedFloat64Array()
	_influence_clamp_y = PackedByteArray()
	_influence_pivots = PackedVector2Array()
	for joint: Dictionary in _joints: _influence_pivots.append(joint.pivot)
	_influence_has_mask = kind in [&"forest_seed_sentry",&"forest_crossbranch",&"forest_swing_pod",&"forest_thread_spider",&"forest_bible_weaver",&"forest_lantern"]
	for point: Vector2 in _mesh_points:
		var joint_indices := PackedInt32Array()
		var weights := PackedFloat64Array()
		var total := 0.0
		for joint_index: int in _joints.size():
			var joint: Dictionary = _joints[joint_index]
			var region: Rect2 = joint.region
			var margin: Vector2 = joint.margin
			var wx := smoothstep(region.position.x-margin.x,region.position.x+margin.x,point.x)*(1.0-smoothstep(region.end.x-margin.x,region.end.x+margin.x,point.x))
			var wy := smoothstep(region.position.y-margin.y,region.position.y+margin.y,point.y)*(1.0-smoothstep(region.end.y-margin.y,region.end.y+margin.y,point.y))
			var weight := wx*wy
			# Sum the same doubles in the same order as the reference consumer.
			total += weight
			if weight != 0.0:
				joint_indices.append(joint_index)
				weights.append(weight)
		_influence_indices.append(joint_indices)
		_influence_weights.append(weights)
		_influence_totals.append(total)
		var uv := (point-_mesh_bounds.position)/_mesh_bounds.size
		var mask := 1.0
		if kind==&"forest_seed_sentry": mask = 1.0-smoothstep(0.88,0.97,uv.y)
		elif kind==&"forest_crossbranch": mask = 1.0-smoothstep(0.65,0.95,uv.y)
		elif kind==&"forest_swing_pod": mask = smoothstep(0.15,0.60,uv.y)
		elif kind in [&"forest_thread_spider",&"forest_bible_weaver",&"forest_lantern"]: mask = smoothstep(0.0,4.0,point.length())
		_influence_masks.append(mask)
		_influence_clamp_y.append(1 if kind==&"forest_bark_beetle" and point.y>=foot_y-1.0 else 0)
	_influence_ready = true

func _deform_cached(index: int) -> Vector2:
	var point := _mesh_points[index]
	var delta_position := Vector2.ZERO
	var indices: PackedInt32Array = _influence_indices[index]
	var weights: PackedFloat64Array = _influence_weights[index]
	# Keep the reference Vector2 operations and nonzero-joint accumulation order.
	# No transform/sin/cos substitution or per-term pre-normalization is used.
	for influence: int in indices.size():
		var joint_index := indices[influence]
		var pivot := _influence_pivots[joint_index]
		delta_position += ((point-pivot).rotated(_influence_angles[joint_index])+pivot-point)*weights[influence]
	var total := _influence_totals[index]
	if total>0.0: delta_position *= MOTION_GAIN/total
	if _influence_has_mask: delta_position *= _influence_masks[index]
	elif _influence_clamp_y[index]!=0: delta_position.y = minf(0.0,delta_position.y)
	return point+delta_position

func _draw_connected(canvas: Node2D,actor: EnemyActor,texture: Texture2D,bounds: Rect2,body_transform: Transform2D,tint: Color) -> void:
	if not body_mesh_visible(canvas,bounds): return
	if _mesh_texture!=texture or _mesh_bounds!=bounds: _prepare_mesh(texture,bounds)
	_prepare_influences(actor.definition.behavior_id,actor.definition.collision_size.y*0.5)
	var vertices := PackedVector2Array()
	vertices.resize(_mesh_points.size())
	for index: int in _mesh_points.size():
		vertices[index] = _deform_cached(index)
	_mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())
	canvas.draw_set_transform_matrix(body_transform)
	canvas.draw_mesh(_mesh,texture,Transform2D.IDENTITY,tint)

static func body_mesh_visible(canvas: Node2D,bounds: Rect2) -> bool:
	# Cull only the pure body draw. State/epoch sampling, warnings and effects
	# remain with their existing hosts and keep advancing outside the viewport.
	var projected: Rect2 = canvas.get_global_transform_with_canvas()*bounds.grow(64.0)
	return canvas.get_viewport_rect().intersects(projected,true)

func dispose() -> void:
	_influence_ready = false
	_influence_layout.clear()
	_influence_indices.clear()
	_influence_weights.clear()
	_influence_totals = PackedFloat64Array()
	_influence_masks = PackedFloat64Array()
	_influence_clamp_y = PackedByteArray()
	_influence_pivots = PackedVector2Array()
	_influence_angles = PackedFloat64Array()
	_feedback = null
	_mesh_texture = null
	_mesh_points = PackedVector2Array()
	_joints.clear()
	_mesh.clear_surfaces()
	_epoch = -1
