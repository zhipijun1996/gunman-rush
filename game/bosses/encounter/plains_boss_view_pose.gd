class_name PlainsBossViewPose
extends RefCounted
## Pure view articulation shared by damage anchors and painted bone placement.
## Front skins preserve depth during a turn; no edge-on whole-body collapse.
static func turn(pose: Dictionary, carriage: bool) -> Dictionary:
	var yaw := float(pose.get("turn_yaw",1.0))
	if is_equal_approx(yaw,1.0): return pose
	var facing := float(pose.direction)
	var side := absf(yaw)
	var front := 1.0-smoothstep(.15,.75,side)
	var result := pose.duplicate(true)
	var keys := ["body_transform","mast_transform","bell_transform","launcher_transform","left_wheel","right_wheel"] if carriage else ["body_transform","head_transform","core_transform"]
	for key: String in keys:
		var old: Transform2D=pose[key]
		var local:=Transform2D(Vector2(facing,0),Vector2(0,1),Vector2.ZERO)*old
		var width:=1.0
		if key=="body_transform":width=lerpf(130.0/(196.0 if carriage else 178.0),1.0,side)
		elif key=="head_transform":width=lerpf(78.0/104.0,1.0,side)
		elif key in ["left_wheel","right_wheel"]:width=lerpf(12.0/42.0,1.0,side)
		var face:=facing*(-1.0 if yaw<0 else 1.0)
		var basis:=Transform2D(Vector2(face,0),Vector2(0,1),Vector2.ZERO)*Transform2D(local.get_rotation()*side,Vector2(width,1),0,Vector2.ZERO)
		basis.origin=Vector2(old.origin.x*yaw,old.origin.y)
		if key in ["left_wheel","right_wheel"]:basis.origin.x+=(-26.0 if key=="left_wheel" else 26.0)*front
		if key=="core_transform":basis.origin.y=lerpf(old.origin.y,(result.body_transform as Transform2D).origin.y+27.0,front)
		result[key]=basis
	if not carriage:
		for key: String in ["hips","knees","feet"]:
			var points: Array[Vector2]=[]
			for i: int in 4:
				var old: Vector2=pose[key][i]
				var spread: float=(24.0 if key=="hips" else 32.0)*(1.0 if i<2 else .8)
				points.append(Vector2(old.x*yaw+(-spread if i%2==0 else spread)*front,old.y))
			result[key]=points
		for key: String in ["body_shape_points","head_shape_points"]:
			var outline: Array=WindkeeperPressureRig.BODY_OUTLINE if key=="body_shape_points" else WindkeeperPressureRig.HEAD_OUTLINE
			var transform: Transform2D=result.body_transform if key=="body_shape_points" else result.head_transform
			var points:=PackedVector2Array()
			for point: Vector2 in outline:points.append(transform*point)
			result[key]=points
		result.seed_origin=(result.head_transform as Transform2D)*Vector2(27*side,-4)
	result["view_front"]=front
	result["view_direction"]=facing*(-1.0 if yaw<0 else 1.0)
	return result

static func windmill_origin(pose: Dictionary) -> Vector2:
	return windmill_support(pose)*Vector2(8*absf(float(pose.get("turn_yaw",1.0))),-88)

static func windmill_support(pose: Dictionary) -> Transform2D:
	var opening:=smoothstep(0.0,.85,float(pose.progress)) if pose.mode==&"phase_transition" else 1.0
	return (pose.head_transform as Transform2D)*Transform2D((1.0-opening)*1.35,Vector2(-12*absf(float(pose.get("turn_yaw",1.0))),-42))
