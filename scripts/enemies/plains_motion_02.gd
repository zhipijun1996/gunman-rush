class_name PlainsMotion02
extends RefCounted
## One connected UV skin per body. Only limbs, wings, necks and branches bend;
## AI movement, attack clocks, health, telegraphs and terminal policy stay external.
const GRID := 8
var skin: StringName
var clock := 0.0
var stride := 0.0
var tension := 0.0
var release := 0.0
var recovery := 0.0
var travel := 0.0
# Read-only mass response, derived from accepted displacement by this same
# locomotion clock. Drawing and repeated refresh(0) never integrate it again.
var drive := 0.0
var body_follow := 0.0
var appendage_follow := 0.0
var sample: EnemyFeedback01
var _epoch := -1
var _last_position := Vector2.ZERO
var _mesh := ArrayMesh.new()
var _source: Texture2D
var _texture: Texture2D
var _bounds := Rect2()
var _visible := Rect2()
var _points := PackedVector2Array()
var _units := PackedVector2Array()

func _init(style: StringName = &"underworld") -> void:
	skin = style

func sync_epoch(actor: EnemyActor, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)): return
	if _epoch == int(state.epoch): return
	_epoch = int(state.epoch)
	_last_position = state.position
	clock = 0.0
	stride = 0.0
	tension = 0.0
	release = 0.0
	recovery = 0.0
	travel = 0.0
	drive = 0.0
	body_follow = 0.0
	appendage_follow = 0.0

func synchronize(actor: EnemyActor, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)): return
	sync_epoch(actor,state)
	_last_position = state.position

func advance(actor: EnemyActor, delta: float, state: Dictionary = {}) -> void:
	if not is_instance_valid(actor): return
	if state.is_empty(): state = actor.presentation_state()
	if not bool(state.get("valid",false)): return
	sync_epoch(actor,state)
	var current: Vector2 = state.position
	var distance := current.distance_to(_last_position)
	_last_position = current
	# Restored/accepted terminal images retain their existing owner and policy.
	if bool(state.terminal) or delta <= 0.0: return
	clock += delta
	# Real displacement drives the feet; teleports do not produce a gait cycle.
	if distance < 48.0:
		stride += distance * TAU / 20.0
	var moving := clampf(distance / maxf(delta, 0.0001) / maxf(actor.definition.patrol_speed, 1.0), 0.0, 1.0) if distance < 48.0 else 0.0
	var previous_travel := travel
	travel = lerpf(travel, moving, 1.0-exp(-delta/0.07))
	if distance >= 48.0:
		# A restore/teleport is not an acceleration or a braking performance.
		drive = 0.0
		body_follow = travel
		appendage_follow = travel
	else:
		var acceleration := clampf((travel-previous_travel)/delta*0.11,-1.0,1.0)
		drive = lerpf(drive,acceleration,1.0-exp(-delta/0.10))
		body_follow = lerpf(body_follow,travel,1.0-exp(-delta/0.11))
		appendage_follow = lerpf(appendage_follow,body_follow,1.0-exp(-delta/0.12))
	var phase: StringName = state.state
	var state_time: float = state.state_time
	var durations: Dictionary = state.phase_durations
	var load := smoothstep(0.0, maxf(float(durations.telegraph), 0.001), state_time) if phase == &"telegraph" else 0.0
	var strike := 1.0-smoothstep(0.0, maxf(float(durations.attack), 0.001), state_time) if phase == &"attack" else 0.0
	var settle := 1.0-smoothstep(0.0, maxf(float(durations.recovery), 0.001), state_time) if phase in [&"recovery", &"blocked"] else 0.0
	var blend := 1.0-exp(-delta/0.045)
	tension = lerpf(tension, load, blend)
	release = lerpf(release, strike, blend)
	recovery = lerpf(recovery, settle, blend)

func body_bob(kind: StringName) -> float:
	# The diver's lift is now transmitted from wing roots through its thorax
	# and abdomen below. Other existing callers retain their old host offset.
	return 0.0 if kind == &"diver" else sin(clock*7.0)*1.2

func draw_body(canvas: Node2D, actor: EnemyActor, texture: Texture2D, bounds: Rect2, tint: Color) -> void:
	if texture == null or not bounds.has_area(): return
	# initialize can redraw a paused generic actor before its next process tick.
	# Only synchronize a changed epoch; sampling delta=0 every draw would consume
	# real displacement before advance() can turn it into a locomotion stride.
	if _epoch != actor.health.epoch:
		sync_epoch(actor)
	if not body_mesh_visible(canvas,bounds): return
	if _source != texture or _bounds != bounds:
		_prepare(texture, bounds)
	var vertices := PackedVector2Array()
	vertices.resize(_points.size())
	var hurt := 0.0
	if sample != null and not actor.health.terminal:
		hurt = sample.hurt_remaining/maxf(sample.tuning.hurt_seconds, 0.001)
	for index: int in _points.size():
		vertices[index] = _deform(_points[index], _units[index], actor.definition.behavior_id, actor.health.terminal, hurt)
	# Reuse one dynamic mesh. UVs and triangle topology remain fixed between
	# authored cells; adjacent triangles share the exact same deformed vertices.
	_mesh.surface_update_vertex_region(0, 0, vertices.to_byte_array())
	canvas.draw_mesh(_mesh, _texture, Transform2D.IDENTITY, tint)

func _prepare(texture: Texture2D, bounds: Rect2) -> void:
	_source = texture
	_bounds = bounds
	_visible = EnemyFeedback01Frames.visible_bounds(texture, bounds)
	_texture = texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		_texture = atlas.atlas
		region = atlas.region
	_points = PackedVector2Array()
	_units = PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y: int in GRID+1:
		for x: int in GRID+1:
			var unit := Vector2(float(x)/GRID, float(y)/GRID)
			var point := bounds.position+unit*bounds.size
			_points.append(point)
			_units.append((point-_visible.position)/_visible.size)
			uvs.append((region.position+unit*region.size)/_texture.get_size())
	for y: int in GRID:
		for x: int in GRID:
			var first := y*(GRID+1)+x
			indices.append_array(PackedInt32Array([first,first+1,first+GRID+2,first,first+GRID+2,first+GRID+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)

func _joint(point: Vector2, pivot: Vector2, angle: float, weight: float) -> Vector2:
	var root := _visible.position+pivot*_visible.size
	return point.lerp(root+(point-root).rotated(angle), clampf(weight,0.0,1.0))

func _deform(point: Vector2, uv: Vector2, kind: StringName, terminal: bool, hurt: float) -> Vector2:
	if terminal: return point
	var breath := sin(clock*3.0)*0.018
	var recoil := hurt*hurt
	var p := point
	match kind:
		&"diver":
			if skin == &"legacy":
				# This master is a rotor-bell: its two leaf blades articulate at
				# the crown hub, while the central brass lantern stays rigid.
				var blade := 1.0-smoothstep(0.20,0.36,uv.y)
				var side := -1.0 if uv.x < 0.5 else 1.0
				p = _joint(p,Vector2(0.5,0.16),side*(sin(clock*18.0)*0.15+tension*0.12-release*0.18),blade)
				var carried := 1.0-smoothstep(.73,.96,uv.y)
				p.y -= _visible.size.y*.016*sin(clock*18.0-.52)*(1.0-release*.8)*carried
				p = _joint(p,Vector2(.5,.36),-.032*drive,carried)
				p = _joint(p,Vector2(0.5,0.65),sin(clock*5.0)*0.035+release*0.12+recoil*0.08,smoothstep(0.62,0.90,uv.y))
			else:
				# The flying master has a diagonal dorsal wing fan and a bell
				# abdomen. Wing roots and abdomen use independent pivots.
				var wing := (1.0-smoothstep(0.48,0.69,uv.x))*(1.0-smoothstep(0.40,0.64,uv.y))
				# Lock tilts the trunk; the wings fold against the dive, then
				# spread well ahead of the abdomen to brake the real climb.
				var beat := clock*17.0
				var flap := sin(beat)*(0.19+travel*0.10)*(1.0-release*.85)
				p = _joint(p,Vector2(0.58,0.56),flap-tension*.12+release*.72-recovery*.30,wing)
				var thorax := smoothstep(0.31,0.52,uv.x)*(1.0-smoothstep(0.65,0.84,uv.y))
				var lift := sin(beat-0.52)*(1.0-release*.85)*(1.0-tension*.65)
				p.y -= _visible.size.y*0.018*lift*maxf(thorax,wing*.62)
				p = _joint(p,Vector2(.58,.56),-.045*drive+.022*sin(beat-.42)*(1.0-release),thorax)
				var abdomen := (1.0-smoothstep(0.36,0.58,uv.x))*smoothstep(0.59,0.82,uv.y)
				p = _joint(p,Vector2(0.53,0.62),-breath*2.0+.044*sin(beat-.95)*(1.0-release)-.065*drive+tension*.12-release*.13+recovery*.18+recoil*.10,abdomen)
				p = _joint(p,Vector2(0.65,0.65),sin(beat-1.25)*.065*(1.0-release)+release*.20-recovery*.13-.07*drive,smoothstep(.70,.94,uv.y)*smoothstep(.48,.70,uv.x))
		&"sentry", &"fan_sentry":
			# Planted feet carry recoil; the chamber and barrel move at the
			# neck, never the warning rays or the authoritative projectile.
			var upper := 1.0-smoothstep(0.48,0.82,uv.y)
			p = _joint(p,Vector2(0.52,0.74),breath-tension*0.07+release*0.11+recoil*0.045,upper)
			var barrel := smoothstep(0.55,0.76,uv.x)*(1.0-smoothstep(0.55,0.76,uv.y))
			p.x -= (release*2.0+recoil)*barrel
			if kind == &"fan_sentry":
				p = _joint(p,Vector2(0.57,0.42),sin(clock*7.0)*tension*0.07-release*0.045,barrel)
		&"root_bell":
			# Roots stay planted. The stalk bends from its root, then each
			# outer branch answers the pulse independently of the trunk.
			var upper := 1.0-smoothstep(0.55,0.96,uv.y)
			p = _joint(p,Vector2(0.5,0.94),breath+tension*0.07-release*0.11+recoil*0.06,upper)
			var side := -1.0 if uv.x < 0.5 else 1.0
			var branch := smoothstep(0.12,0.34,absf(uv.x-0.5))*(1.0-smoothstep(0.60,0.87,uv.y))
			p = _joint(p,Vector2(0.5,0.44),side*(sin(clock*4.0)*0.025+tension*0.13-release*0.22+recovery*0.045),branch)
		&"charger", &"hopper", &"patrol":
			# Alternating feet are weighted below the rigid shell. The
			# shell/head/antennae have their own joints, not whole-body squash.
			var leg := smoothstep(0.61,0.90,uv.y)
			var phase := stride+(PI if uv.x < 0.5 else 0.0)
			var gait := sin(phase)*travel
			p.x += gait*1.8*leg
			p.y -= maxf(0.0,gait)*1.5*leg
			var upper := 1.0-smoothstep(0.50,0.76,uv.y)
			if kind == &"hopper":
				var thigh := (1.0-smoothstep(0.35,0.58,uv.x))*smoothstep(0.51,0.78,uv.y)
				p = _joint(p,Vector2(0.36,0.62),tension*0.23-release*0.27+recovery*0.10+recoil*0.10,thigh)
				p = _joint(p,Vector2(0.51,0.70),-tension*0.065+release*0.10,upper)
			elif kind == &"charger":
				p = _joint(p,Vector2(0.49,0.72),-tension*0.075+release*0.09+recoil*0.045,upper)
				var head := smoothstep(0.62,0.83,uv.x)*(1.0-smoothstep(0.63,0.86,uv.y))
				p = _joint(p,Vector2(0.66,0.58),tension*0.13-release*0.16+recovery*0.045+recoil*0.08,head)
			else:
				var antenna := 1.0-smoothstep(0.17,0.39,uv.y)
				p = _joint(p,Vector2(0.52,0.37),sin(clock*4.5)*0.07+recoil*0.12,antenna)
				p = _joint(p,Vector2(0.5,0.72),gait*0.015+breath,upper)
	return p

static func body_mesh_visible(canvas: Node2D,bounds: Rect2) -> bool:
	# Cull only the pure body draw. State/epoch sampling, warnings and effects
	# remain with their existing hosts and keep advancing outside the viewport.
	var projected: Rect2 = canvas.get_global_transform_with_canvas()*bounds.grow(64.0)
	return canvas.get_viewport_rect().intersects(projected,true)

func dispose() -> void:
	sample = null
	_source = null
	_texture = null
	_points = PackedVector2Array()
	_units = PackedVector2Array()
	_mesh.clear_surfaces()
	_epoch = -1
