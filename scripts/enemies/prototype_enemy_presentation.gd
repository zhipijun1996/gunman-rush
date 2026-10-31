class_name PrototypeEnemyPresentation
extends EnemyPresentation
## Development candidates: one neutral master per species, never pose-sheet swaps.
const ATLAS: Texture2D = preload("res://assets/enemy_all_02/prototype_sheet.png")
const MANIFEST_PATH := "res://assets/enemy_all_02/prototype_manifest.json"
const GRID_COLUMNS := 6
const GRID_ROWS := 8
var moth := false
var _master_region := Rect2()
var _master_anchor := Vector2.ZERO
var _master_factor := 1.0
var _native_points := PackedVector2Array()
var _mesh := ArrayMesh.new()
var _prototype_epoch := -1
var _last_position := Vector2.ZERO
var _stride := 0.0
var _walking := 0.0
var _loading := 0.0
var _releasing := 0.0
var _recovering := 0.0
var _display_facing := 1.0
var _hurt_joint := 0.0

func _ready() -> void:
	super._ready()
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not manifest is Dictionary or not manifest.get("frames") is Dictionary:
		push_error("Prototype body master manifest is missing or invalid")
		return
	var frame: Dictionary = manifest.frames.get("moth" if moth else "guard", {})
	if not frame.get("region") is Array or not frame.get("anchor") is Array or not frame.get("basis_px") is Array:
		push_error("Prototype canonical master frame is missing")
		return
	var region: Array = frame.region
	var anchor: Array = frame.anchor
	var basis: Array = frame.basis_px
	_master_region = Rect2(region[0],region[1],region[2],region[3])
	_master_anchor = Vector2(anchor[0],anchor[1])
	# One uniform source-to-world ratio: guard visible42x45, moth38x47 approximately.
	_master_factor = (47.0 if moth else 45.0)/float(basis[1])
	_build_master_grid()

func _build_master_grid() -> void:
	var atlas_size := Vector2(ATLAS.get_size())
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for row: int in GRID_ROWS+1:
		for column: int in GRID_COLUMNS+1:
			var point := Vector2(float(column)/GRID_COLUMNS,float(row)/GRID_ROWS)*_master_region.size
			_native_points.append(point)
			vertices.append((point-_master_anchor)*_master_factor)
			uv.append((_master_region.position+point)/atlas_size)
	for row: int in GRID_ROWS:
		for column: int in GRID_COLUMNS:
			var first := row*(GRID_COLUMNS+1)+column
			indices.append_array(PackedInt32Array([first,first+1,first+GRID_COLUMNS+2,first,first+GRID_COLUMNS+2,first+GRID_COLUMNS+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)

func _presentation_profile() -> StringName:
	return &"prototype"

func _presentation_motion() -> RefCounted:
	# The prototype owns its canonical mesh. Parent legacy motion is not advanced.
	return null

func _presentation_initialized() -> void:
	super._presentation_initialized()
	_sync_prototype_epoch()

func synchronize_presentation() -> void:
	super.synchronize_presentation()
	var state := lifecycle.read_state()
	if not bool(state.get("valid",false)): return
	_last_position = state.position
	_display_facing = float(state.facing)

func _sync_prototype_epoch() -> void:
	if not is_instance_valid(actor) or actor.health == null: return
	if _prototype_epoch != actor.health.epoch:
		_prototype_epoch = actor.health.epoch
		_clock = 0.0
		var restored_terminal := actor.health.terminal and (hit_template == null or hit_template.sample.restored_terminal)
		_death_time = 0.6 if restored_terminal else 0.0
		_hurt_time = 0.0
		_stride = 0.0
		_walking = 0.0
		_loading = 0.0
		_releasing = 0.0
		_recovering = 0.0
		_display_facing = float(actor.brain.direction)
		_hurt_joint = 0.0
		_weight = Vector2.ONE
		_lean = 0.0
		_last_position = actor.motor.global_position

func _advance_body_pose(delta: float) -> void:
	var state := lifecycle.snapshot
	var phase: StringName = state.state
	var alive := not bool(state.terminal)
	var blend := 1.0-exp(-delta/0.065)
	_loading = lerpf(_loading,1.0 if alive and phase==&"telegraph" else 0.0,blend)
	_releasing = lerpf(_releasing,1.0 if alive and phase==&"attack" else 0.0,blend)
	_recovering = lerpf(_recovering,1.0 if alive and phase==&"recovery" else 0.0,blend)
	_display_facing = lerpf(_display_facing,float(state.facing),1.0-exp(-delta/0.045))
	var distance := (state.position as Vector2).distance_to(_last_position)
	_last_position = (state.position as Vector2)
	if alive and distance<32.0: _stride += distance*0.28
	_walking = lerpf(_walking,1.0 if alive and distance>0.05 else 0.0,blend)
	var accepted_pose := hit_template.pose() if hit_template != null else Vector2.ONE
	_hurt_joint = clampf(absf(1.0-accepted_pose.y)*5.0,0.0,0.6) if alive else lerpf(_hurt_joint,0.0,blend)

func _draw() -> void:
	if not lifecycle.is_bound(): return
	if not is_instance_valid(actor) or _native_points.is_empty(): return
	var tint := hit_template.tint() if hit_template != null else Color.WHITE
	if actor.health.terminal: tint.a = maxf(0.0,1.0-_death_time/0.6)
	if tint.a<=0.0: return
	var facing := _display_facing
	if absf(facing)<0.18: facing = 0.18 if facing>=0.0 else -0.18
	var foot := Vector2(0,actor.definition.collision_size.y*0.5)
	# Feet/hover anchor are stable. All animation occurs inside the same UV master.
	draw_set_transform_matrix(Transform2D(Vector2(facing,0),Vector2(0,1),foot))
	var destination := PackedVector2Array()
	destination.resize(_native_points.size())
	for index: int in _native_points.size():
		destination[index] = (_deform_master(_native_points[index])-_master_anchor)*_master_factor
	# One persistent connected mesh, with shared vertices and immutable UV/topology.
	_mesh.surface_update_vertex_region(0,0,destination.to_byte_array())
	draw_mesh(_mesh,ATLAS,Transform2D.IDENTITY,tint)
	draw_set_transform(Vector2.ZERO)

func _deform_master(point: Vector2) -> Vector2:
	var death := smoothstep(0.0,0.45,_death_time) if actor.health.terminal else 0.0
	var alive_weight := 1.0-death
	var p := point
	if moth:
		# Feather wings bend around the thorax; the abdomen and antenna have their own lag.
		var wing_weight := (1.0-smoothstep(150.0,265.0,point.y))*(1.0-smoothstep(140.0,290.0,point.x))
		var flap := sin(_clock*(18.0 if _releasing>0.4 else 14.0))*0.23*alive_weight
		var wing_angle := flap+_loading*0.10-_releasing*0.12+_hurt_joint*0.20+death*0.42
		p += ((point-Vector2(193,195)).rotated(wing_angle)+Vector2(193,195)-point)*wing_weight
		var abdomen_weight := smoothstep(190.0,270.0,point.y)*(1.0-smoothstep(145.0,220.0,point.x))
		var abdomen_angle := sin(_clock*3.0)*0.035*alive_weight-_releasing*0.10+_recovering*0.05+death*0.16
		p += ((point-Vector2(192,214)).rotated(abdomen_angle)+Vector2(192,214)-point)*abdomen_weight
		var feeler_weight := smoothstep(185.0,245.0,point.x)*(1.0-smoothstep(125.0,205.0,point.y))
		p += Vector2(sin(_clock*4.0)*4.0*alive_weight-_loading*9.0,_hurt_joint*14.0+death*18.0)*feeler_weight
	else:
		# Three planted leg zones carry a hinged upper carapace and flexible leaf shield.
		var upper_weight := 1.0-smoothstep(265.0,353.0,point.y)
		var upper_angle := -_loading*0.085+_releasing*0.11+_hurt_joint*0.12-death*0.24
		p += ((point-Vector2(168,327)).rotated(upper_angle)+Vector2(168,327)-point)*upper_weight
		var shield_weight := smoothstep(192.0,272.0,point.x)*(1.0-smoothstep(340.0,365.0,point.y))
		var shield_angle := -_loading*0.22+_releasing*0.16+_recovering*0.30+_hurt_joint*0.16+death*0.46
		p += ((point-Vector2(227,248)).rotated(shield_angle)+Vector2(227,248)-point)*shield_weight
		var leg_weight := smoothstep(278.0,327.0,point.y)*(1.0-smoothstep(220.0,265.0,point.x))
		var leg_phase := _stride+(0.0 if point.x<150.0 else PI)
		p.y -= maxf(0.0,sin(leg_phase))*11.0*_walking*alive_weight*leg_weight
		p.x += sin(leg_phase)*5.0*_walking*alive_weight*leg_weight
		var feeler_weight := (1.0-smoothstep(110.0,164.0,point.y))*smoothstep(100.0,195.0,point.x)
		p.x += (sin(_clock*3.0)*3.0*alive_weight+_loading*8.0-death*12.0)*feeler_weight
	# Bound joint displacement (not body scale) to keep every connected triangle positive.
	return point.lerp(p,0.50 if moth else 0.35)
