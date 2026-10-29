class_name BossMotionPresentation
extends RefCounted
## A read-only pose sampler. No collision, motor, combat-clock or phase writes.
## Shared UV vertices keep the existing painted anatomy connected at joints.
var mode: StringName = &""
var mode_age := 0.0
var warning := 0.0
var action := 0.0
var recovery := 0.0
var hurt := 0.0
var death := 0.0
var gait := 0.0
var speed := 0.0
var phase := 1
var direction := 1.0
var _hurt_left := 0.0
var _shot_left := 0.0
var _last_position := Vector2.ZERO
var _position_seen := false
var _epoch := -1
var _meshes: Dictionary = {}

func bind(encounter: BossEncounter) -> void:
	_epoch = encounter.health.epoch
	_reset_epoch_pose(encounter.health.terminal)
	encounter.health.changed.connect(_health_changed)
	encounter.projectile_created.connect(_projectile_created)

func _reset_epoch_pose(terminal: bool) -> void:
	# A restored terminal resource already owns its settled pose, including
	# while paused. Only a newly accepted lethal transaction plays the fall.
	death = 1.0 if terminal else 0.0
	_hurt_left = 0.0
	_shot_left = 0.0
	action = 0.0
	recovery = 0.0
	warning = 0.0
	hurt = 0.0
	mode = &""
	mode_age = 0.0
	gait = 0.0
	speed = 0.0
	_position_seen = false

func _health_changed(result: ActorResourceResult) -> void:
	if result == null or result.snapshot == null: return
	if result.operation == &"initialize":
		_epoch = result.snapshot.epoch
		_reset_epoch_pose(result.snapshot.terminal)
	elif result.snapshot.epoch == _epoch and result.operation == &"damage" and result.status == ActorResourceResult.Status.APPLIED:
		_hurt_left = .24

func dispose(encounter: BossEncounter) -> void:
	_meshes.clear()
	if not is_instance_valid(encounter): return
	if encounter.health.changed.is_connected(_health_changed): encounter.health.changed.disconnect(_health_changed)
	if encounter.projectile_created.is_connected(_projectile_created): encounter.projectile_created.disconnect(_projectile_created)

func _projectile_created(_projectile: BossProjectile) -> void:
	# A committed projectile, including a real second volley, drives the kick.
	_shot_left = .22

func sample(encounter: BossEncounter, delta: float) -> void:
	if encounter == null or encounter.definition == null: return
	if _epoch != encounter.health.epoch:
		_epoch = encounter.health.epoch
		_reset_epoch_pose(encounter.health.terminal)
	var next: StringName = &"patrol"
	var remaining := 0.0
	var duration := encounter.definition.telegraph_duration
	phase = encounter.phases.phase
	direction = float(encounter.direction)
	if encounter is WindkeeperEncounter:
		var machine := encounter as WindkeeperEncounter
		next = machine.mode
		remaining = machine.clock
		phase = machine.stage_phase
		duration = (machine.definition as WindkeeperDefinition).warning_seconds
		if next == &"pier_warning": duration = (machine.definition as WindkeeperDefinition).pier_warning_seconds
		elif next == &"phase_transition": duration = (machine.definition as WindkeeperDefinition).phase_warning_seconds
	elif encounter is ThornForestEncounter:
		var forest := encounter as ThornForestEncounter
		next = forest.mode
		remaining = forest.clock
		phase = forest.stage_phase
		if next == &"phase_transition": duration = (forest.definition as ThornForestDefinition).phase_warning_seconds
		if forest is ThornQueenV2:
			next = StringName((forest as ThornQueenV2).motion_mode)
			remaining = (forest as ThornQueenV2).motion_clock
			duration = (forest.definition as ThornQueenWeaveDefinition).migration_preview_seconds
		elif forest is ThornQueenCanopyEncounter:
			next = StringName((forest as ThornQueenCanopyEncounter).motion_mode)
			remaining = (forest as ThornQueenCanopyEncounter).motion_clock
			duration = (forest.definition as ThornQueenCanopyDefinition).canopy_preview
		elif next == &"bell_warning" and forest.definition is BossDuelDefinition:
			duration = (forest.definition as BossDuelDefinition).bell_warning_seconds
	elif encounter.pattern.telegraphing:
		next = &"projectile_warning"
		remaining = duration * (1.0-encounter.pattern.warning_progress)
	if next != mode:
		mode = next
		mode_age = 0.0
	mode_age += delta
	var warning_mode := String(mode).ends_with("warning") or String(mode).ends_with("preview") or mode == &"phase_transition"
	warning = clampf(1.0-remaining/maxf(.01,duration),0.0,1.0) if warning_mode else 0.0
	var at := encounter.motor.global_position
	speed = at.distance_to(_last_position)/maxf(delta,.001) if _position_seen else 0.0
	_last_position = at
	_position_seen = true
	gait += minf(speed,700.0)*delta/22.0
	_hurt_left = maxf(0.0,_hurt_left-delta)
	_shot_left = maxf(0.0,_shot_left-delta)
	hurt = sin(PI*_hurt_left/.24) if _hurt_left > 0.0 else 0.0
	var releasing := mode in [&"stomp",&"pier_impact",&"seed_flight",&"rings",&"lob",&"bell_watch"]
	var travelling := mode in [&"charge",&"chase",&"roll",&"blades",&"pursuit_flight",&"flight",&"phase_flight"]
	var target := maxf(exp(-mode_age/.18) if releasing else 0.0, _shot_left/.22)
	if travelling: target = maxf(target,.65)
	action = lerpf(action,target,1.0-exp(-delta/.045))
	var recovering := mode in [&"neck",&"back",&"pier_open",&"final_hold",&"heart_open",&"landing_recovery",&"bell_stagger",&"perched"]
	recovery = lerpf(recovery,1.0 if recovering else 0.0,1.0-exp(-delta/.12))
	if encounter.health.terminal:
		death = minf(1.0,death+delta/.55)
		warning = 0.0
		action = 0.0
		hurt = 0.0
		recovery = 0.0

func limb_angle(side: float) -> float:
	# Opposed shoulder/forearm chain; hurt returns to the current live state.
	var intensity := 1.0+float(maxi(0,phase-1))*.12
	return side*(-warning*.22+action*.30+recovery*.10)*intensity+side*death*.38-direction*hurt*.11

func crown_angle() -> float:
	return direction*(warning*.07-action*.12+hurt*.09+death*.22)

func draw_body(canvas: Node2D, texture: Texture2D, bounds: Rect2, kind: StringName, tint := Color.WHITE, facing := 1.0) -> void:
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# One cached indexed mesh, one draw command. UVs/indices are immutable;
	# rebuilding its single surface updates vertices and its culling bounds.
	# AtlasTexture UVs are resolved onto the real source page explicitly.
	var divisions := 12 if kind in [&"windkeeper",&"bellstrider"] else 8
	var key := "%s/%s/%s/%s" % [texture.get_instance_id(),bounds,kind,facing]
	if not _meshes.has(key):
		var source := Rect2(Vector2.ZERO,texture.get_size())
		var page := texture
		if texture is AtlasTexture:
			source = (texture as AtlasTexture).region
			page = (texture as AtlasTexture).atlas
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for row: int in divisions+1:
			for column: int in divisions+1:
				var uv := Vector2(float(column)/divisions,float(row)/divisions)
				uvs.append((source.position+uv*source.size)/page.get_size())
		for row: int in divisions:
			for column: int in divisions:
				var a := row*(divisions+1)+column
				indices.append_array(PackedInt32Array([a,a+1,a+divisions+2,a,a+divisions+2,a+divisions+1]))
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		_meshes[key] = {"mesh":ArrayMesh.new(),"arrays":arrays,"page":page}
	var cached: Dictionary = _meshes[key]
	var vertices := PackedVector2Array()
	for row: int in divisions+1:
		for column: int in divisions+1:
			var uv := Vector2(float(column)/divisions,float(row)/divisions)
			var p := bounds.position+uv*bounds.size
			p += _joint_offset(uv,bounds.size,kind)
			p.x *= facing
			vertices.append(p)
	var arrays: Array = cached.arrays
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = cached.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	canvas.draw_mesh(mesh,cached.page,Transform2D.IDENTITY,tint)

func _joint_offset(uv: Vector2, size: Vector2, kind: StringName) -> Vector2:
	var offset := Vector2.ZERO
	var alive := 1.0-death
	if kind == &"bellstrider":
		# Painted wheel bearings stay on the real floor. Only the sprung chassis
		# and crown respond to load; the encounter-owned core is drawn separately.
		var sprung := 1.0-smoothstep(.53,.72,uv.y)
		offset.y += (warning*5.0-action*5.0+recovery*3.0+death*6.0)*sprung
		offset.x += direction*(-warning*3.0+action*5.0-hurt*4.0)*sprung
		var crown := 1.0-smoothstep(.1,.37,uv.y)
		offset.x += (uv.y-.37)*size.y*crown_angle()*crown
		var bell_lock := 1.0-smoothstep(.08,.19,uv.distance_to(Vector2(.5,.36)))
		return offset*(1.0-bell_lock)
	var queen := kind == &"queen"
	var crown_weight := 1.0-smoothstep(.15,.38,uv.y)
	offset.x += (uv.y-.38)*size.y*crown_angle()*crown_weight
	for side: int in [-1,1]:
		var shoulder := Vector2(.27 if side < 0 else .73,.39)
		var outer := 1.0-smoothstep(.24,.47,uv.x) if side < 0 else smoothstep(.53,.76,uv.x)
		var arm := smoothstep(.24,.40,uv.y)*(1.0-smoothstep(.67,.81,uv.y))*outer
		var arm_delta := (uv-shoulder)*size
		var angle := clampf(limb_angle(float(side)),-.42,.42)*(.95 if queen else 1.0)
		offset += (arm_delta.rotated(angle)-arm_delta)*arm
		# Forearm follows through around a separate elbow rather than scaling
		# the trunk. Its envelope is zero on the authored chest/heart pixels.
		var elbow := Vector2(.12 if side < 0 else .88,.58)
		var forearm := smoothstep(.48,.60,uv.y)*(1.0-smoothstep(.74,.84,uv.y))*outer
		var fore_delta := (uv-elbow)*size
		offset += (fore_delta.rotated(-angle*.65)-fore_delta)*forearm
	var leg_weight := smoothstep(.66,.86,uv.y)
	var leg := 0 if uv.x < .36 else 2 if uv.x > .66 else 1
	var cadence := gait+float(leg)*PI
	var swing := maxf(0.0,sin(cadence)) if speed > 2.0 else 0.0
	offset.y -= leg_weight*swing*minf(6.0,size.y*.04)*alive
	offset.x += leg_weight*sin(cadence)*minf(3.0,size.x*.02)*minf(1.0,speed/35.0)*alive
	# A grounded warning bends knees while the end of each foot stays planted.
	var knee := sin(clampf((uv.y-.65)/.35,0.0,1.0)*PI)
	offset.x += (uv.x-.5)*warning*knee*size.x*.07
	offset.y += smoothstep(.15,.65,uv.y)*(1.0-smoothstep(.82,1.0,uv.y))*death*size.y*.08
	# Real core anchors remain independent and visually registered to chest.
	var core := Vector2(.52,.43) if kind == &"guardian" else Vector2(.5,.5)
	var core_lock := 1.0-smoothstep(.08,.20,uv.distance_to(core))
	return offset*(1.0-core_lock)
