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

func advance(actor: EnemyActor, delta: float) -> void:
	if not is_instance_valid(actor) or actor.health == null: return
	if _epoch != actor.health.epoch:
		_epoch = actor.health.epoch
		_last_position = actor.motor.global_position
		clock = 0.0
		stride = 0.0
		tension = 0.0
		release = 0.0
		recovery = 0.0
		travel = 0.0
	var current: Vector2 = actor.motor.global_position
	var distance := current.distance_to(_last_position)
	_last_position = current
	# Restored/accepted terminal images retain their existing owner and policy.
	if actor.health.terminal or delta <= 0.0: return
	clock += delta
	# Real displacement drives the feet; teleports do not produce a gait cycle.
	if distance < 48.0:
		stride += distance * TAU / 20.0
	var moving := clampf(distance / maxf(delta, 0.0001) / maxf(actor.definition.patrol_speed, 1.0), 0.0, 1.0) if distance < 48.0 else 0.0
	travel = lerpf(travel, moving, 1.0-exp(-delta/0.07))
	var state: StringName = actor.attack_behavior.state if actor.attack_behavior != null else &"idle"
	var state_time: float = actor.attack_behavior.state_time if actor.attack_behavior != null else 0.0
	var load := smoothstep(0.0, maxf(actor.definition.telegraph_duration, 0.001), state_time) if state == &"telegraph" else 0.0
	var strike := 1.0-smoothstep(0.0, maxf(actor.definition.attack_duration, 0.001), state_time) if state == &"attack" else 0.0
	var settle := 1.0-smoothstep(0.0, maxf(actor.definition.recovery_duration, 0.001), state_time) if state in [&"recovery", &"blocked"] else 0.0
	var blend := 1.0-exp(-delta/0.045)
	tension = lerpf(tension, load, blend)
	release = lerpf(release, strike, blend)
	recovery = lerpf(recovery, settle, blend)

func draw_body(canvas: Node2D, actor: EnemyActor, texture: Texture2D, bounds: Rect2, tint: Color) -> void:
	if texture == null or not bounds.has_area(): return
	# initialize can redraw a paused generic actor before its next process tick.
	# Only synchronize a changed epoch; sampling delta=0 every draw would consume
	# real displacement before advance() can turn it into a locomotion stride.
	if _epoch != actor.health.epoch:
		advance(actor, 0.0)
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
				p = _joint(p,Vector2(0.5,0.65),sin(clock*5.0)*0.035+release*0.12+recoil*0.08,smoothstep(0.62,0.90,uv.y))
			else:
				# The flying master has a diagonal dorsal wing fan and a bell
				# abdomen. Wing roots and abdomen use independent pivots.
				var wing := (1.0-smoothstep(0.48,0.69,uv.x))*(1.0-smoothstep(0.40,0.64,uv.y))
				p = _joint(p,Vector2(0.58,0.56),sin(clock*17.0)*(0.19+travel*0.10)-tension*0.18+release*0.20,wing)
				var abdomen := (1.0-smoothstep(0.36,0.58,uv.x))*smoothstep(0.59,0.82,uv.y)
				p = _joint(p,Vector2(0.53,0.62),-breath*2.0+tension*0.12-release*0.16+recoil*0.10,abdomen)
				p = _joint(p,Vector2(0.65,0.65),sin(clock*6.0)*0.06+release*0.14,smoothstep(0.70,0.94,uv.y)*smoothstep(0.48,0.70,uv.x))
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
