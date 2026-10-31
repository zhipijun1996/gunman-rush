extends RefCounted
## Frozen Skin.deform from 2ce4ffa64ef65dd5fba892776eea019c9e2841d4.
const FrozenGround = preload("res://tests/fixtures/plains_revision_deform_2ce4ffa6/ground.gd")
const FrozenFlora = preload("res://tests/fixtures/plains_revision_deform_2ce4ffa6/flora.gd")
var kind: StringName
var bounds := Rect2()

func deform(point: Vector2, uv: Vector2, pose: Dictionary) -> Vector2:
	var master := point
	if kind==&"fan_sentry":
		# The new broad fan source devotes more area to wings. Fit its copper
		# abdomen to the previous body's ~13wu mass (+about 7.5%), independently
		# of the wing envelope's +15%. Stretching the entire source made it small.
		var body := (1.0-smoothstep(.12,.27,absf(uv.x-.42)))*smoothstep(.43,.59,uv.y)*(1.0-smoothstep(.87,.99,uv.y))
		var center := Vector2((.42-.5)*bounds.size.x,(.70-1.0)*bounds.size.y)
		master = point.lerp(center+(point-center)*1.55,body)
	var p := FrozenGround.deform(master,uv,bounds.size,pose,kind) if kind in [&"patrol",&"charger",&"hopper"] else FrozenFlora.deform(master,uv,bounds.size,pose,kind)
	# Contact impulse moves the mass, while the supporting feet retain the floor.
	if bool(pose.get("dead",false)):
		p.y -= float(pose.get("landing",0.0))*bounds.size.y*.025*(1.0-smoothstep(.77,1.0,uv.y))
	return p

