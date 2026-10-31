class_name PlainsRevisionSkin
extends RefCounted
## One authored body and continuous joints through live, hurt and death.
## Coordinates are in world units; source resolution never sets pixel size.
const GRID := 24
const TEXTURES := {
	&"patrol": preload("res://assets/plains_revision_01/patrol.png"),
	&"charger": preload("res://assets/plains_revision_01/charger.png"),
	&"hopper": preload("res://assets/plains_revision_01/hopper.png"),
	&"sentry": preload("res://assets/plains_revision_01/sentry.png"),
	&"fan_sentry": preload("res://assets/plains_revision_01/fan_sentry.png"),
	&"root_bell": preload("res://assets/plains_revision_01/root_bell.png")
}
# Relative to the measured visible bodies, not the source PNG dimensions.
const SIZES := {&"patrol":Vector2(41.4,39.33),&"charger":Vector2(40.5,30.375),&"hopper":Vector2(41.4,33.12),&"sentry":Vector2(41.4,42.46),&"fan_sentry":Vector2(41.4,30),&"root_bell":Vector2(49.5,60)}
var texture: Texture2D
var bounds := Rect2()
var kind: StringName
var _mesh := ArrayMesh.new()
var _points := PackedVector2Array()
var _units := PackedVector2Array()
var _weights: Array[PlainsRevisionWeights] = []
var _weights_kind: StringName
# A settled body's local vertices are independent of its continuing corpse age.
# Keep every draw/shader/tint and world-support transform with its existing host.
var _rest_cached := false
var _rest_kind: StringName
var _rest_bounds := Rect2()
var _rest_texture: Texture2D
var _rest_pose: Dictionary = {}

static func supports(definition: EnemyDefinition) -> bool:
	return definition != null and definition.stable_id in [&"patrol_drone",&"graybox_patrol_drone",&"plains_charger",&"plains_hopper",&"plains_sentry",&"plains_fan_sentry",&"plains_root_bell"]

func _init(behavior: StringName = &"patrol") -> void:
	kind = behavior
	texture = TEXTURES.get(kind)
	var size: Vector2 = SIZES.get(kind,Vector2(36,36))
	bounds = Rect2(Vector2(-size.x*.5,-size.y),size)
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y: int in GRID+1:
		for x: int in GRID+1:
			var uv := Vector2(float(x)/GRID,float(y)/GRID)
			_units.append(uv)
			_points.append(bounds.position+uv*size)
			uvs.append(uv)
	for y: int in GRID:
		for x: int in GRID:
			var i := y*(GRID+1)+x
			indices.append_array(PackedInt32Array([i,i+1,i+GRID+2,i,i+GRID+2,i+GRID+1]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES|Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)

func deform(point: Vector2, uv: Vector2, pose: Dictionary) -> Vector2:
	return deform_prepared(point, uv, PlainsRevisionPose.prepare(pose), PlainsRevisionWeights.new(uv, kind))

func deform_prepared(point: Vector2, uv: Vector2, pose: PlainsRevisionPose, weights: PlainsRevisionWeights) -> Vector2:
	var master := point
	if kind==&"fan_sentry":
		# The new broad fan source devotes more area to wings. Fit its copper
		# abdomen to the previous body's ~13wu mass (+about 7.5%), independently
		# of the wing envelope's +15%. Stretching the entire source made it small.
		var body := weights.fan_body_fit
		var center := Vector2((.42-.5)*bounds.size.x,(.70-1.0)*bounds.size.y)
		master = point.lerp(center+(point-center)*1.55,body)
	var p := PlainsRevisionGround.deform_prepared(master,uv,bounds.size,pose,kind,weights) if kind in [&"patrol",&"charger",&"hopper"] else PlainsRevisionFlora.deform_prepared(master,uv,bounds.size,pose,kind,weights)
	# Contact impulse moves the mass, while the supporting feet retain the floor.
	if pose.dead:
		p.y -= pose.landing*bounds.size.y*.025*weights.landing
	return p

func draw_pose(canvas: Node2D, pose: Dictionary, tint: Color = Color.WHITE) -> void:
	if texture == null: return
	if not PlainsMotion02.body_mesh_visible(canvas,bounds): return
	var at_rest := bool(pose.get("dead",false)) and float(pose.get("death",0.0)) >= 1.0 and float(pose.get("landing",0.0)) == 0.0
	var rest_pose: Dictionary = pose.duplicate(true) if at_rest else {}
	rest_pose.erase("death_clock")
	if not (at_rest and _rest_cached and _rest_kind == kind and _rest_bounds == bounds and _rest_texture == texture and _rest_pose == rest_pose):
		var vertices := PackedVector2Array()
		vertices.resize(_points.size())
		# Only UV and kind determine these masks. Bounds and texture remain live
		# inputs to the unchanged kernel and existing settled-mesh invalidation.
		if _weights.size() != _units.size() or _weights_kind != kind:
			_weights.clear()
			for uv: Vector2 in _units: _weights.append(PlainsRevisionWeights.new(uv, kind))
			_weights_kind = kind
		var prepared := PlainsRevisionPose.prepare(pose)
		for i: int in _points.size(): vertices[i] = deform_prepared(_points[i],_units[i],prepared,_weights[i])
		_mesh.surface_update_vertex_region(0,0,vertices.to_byte_array())
		_rest_cached = at_rest
		_rest_pose = rest_pose
		_rest_kind = kind
		_rest_bounds = bounds
		_rest_texture = texture if at_rest else null
	if canvas.material is ShaderMaterial:
		canvas.material.set_shader_parameter("death_progress",float(pose.get("death",0.0)) if bool(pose.get("dead",false)) else 0.0)
		canvas.material.set_shader_parameter("eye_center",Vector2(.86,.39) if kind==&"patrol" else Vector2(.87,.52) if kind==&"hopper" else Vector2(.79,.46))
		canvas.material.set_shader_parameter("plant_body",kind in [&"root_bell",&"sentry"])
		canvas.material.set_shader_parameter("kind_code",1 if kind==&"fan_sentry" else 2 if kind==&"root_bell" else 0)
	canvas.draw_mesh(_mesh,texture,Transform2D.IDENTITY,tint)
