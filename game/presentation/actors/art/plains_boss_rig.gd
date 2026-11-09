class_name PlainsBossRig
extends Node2D
## Rigid painted parts on a real editable bone hierarchy. No body-frame swap,
## optical flow or accumulated presentation time. Only view projection changes
## part width during a turn; attacks and phases retain their native dimensions.
@export_enum("bellstrider", "windkeeper") var family := "bellstrider"
@onready var skeleton: Skeleton2D = $Skeleton
@onready var animation: AnimationPlayer = $AnimationPlayer
var bones: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_collect(skeleton)

func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Bone2D: bones[String(child.name)] = child
		_collect(child)

func _place(key: String, target: Transform2D) -> void:
	var bone: Bone2D = bones[key]
	var parent := bone.get_parent() as Node2D
	bone.transform = (global_transform.affine_inverse() * parent.global_transform).affine_inverse() * target

func present(pose: Dictionary, flash: float = 0.0) -> void:
	if bones.is_empty(): return
	skeleton.scale = Vector2.ONE
	var body: Transform2D = pose.body_transform
	var face := float(pose.get("view_direction",pose.direction))
	var sway: float = animation.get_animation("cloth").value_track_interpolate(0, fposmod(float(pose.fight_age), 1.6))
	if family == "bellstrider":
		_place("Chassis", body)
		_place("Arch", pose.mast_transform)
		_place("Bell", pose.bell_transform)
		_place("Cannon", pose.launcher_transform)
		_place("RearWheel", pose.left_wheel)
		_place("FrontWheel", pose.right_wheel)
		_place("Cloth", body * Transform2D(float(pose.panel_angle)*.18+sway, Vector2(-67,-5)))
	else:
		_place("Torso", body)
		_place("Head", pose.head_transform)
		for i: int in 4:
			var upper: Vector2 = pose.knees[i]-pose.hips[i]
			var lower: Vector2 = pose.feet[i]-pose.knees[i]
			_place("Upper%d"%i, Transform2D(upper.angle()-PI*.5,Vector2(face,1),0,pose.hips[i]))
			_place("Lower%d"%i, Transform2D(lower.angle()-PI*.5,Vector2(face,1),0,pose.knees[i]))
		_place("Cape", body * Transform2D(sway+float(pose.bell_swing)*.30, Vector2(-35,-45)))
		_place("Banner", body * Transform2D(float(pose.bell_swing), Vector2(57,0)))
		_place("Tail", body * Transform2D(sway*.8, Vector2(-76,4)))
		var visible_mill := int(pose.phase)>=2
		bones.Pole.visible = visible_mill
		_place("Core",pose.core_transform)
		var pole:=PlainsBossViewPose.windmill_support(pose)
		_place("Pole",pole)
		var rotor:=pole*Transform2D(float(pose.fight_age)*7.0,Vector2.ZERO)
		rotor.origin=PlainsBossViewPose.windmill_origin(pose)
		_place("Rotor",rotor)
	var front:=float(pose.get("view_front",0.0))
	for key: String in bones:
		var sprite := bones[key].get_node_or_null("Art") as Sprite2D
		if sprite != null:
			var front_sprite:=bones[key].get_node_or_null("Front") as Sprite2D
			if front_sprite!=null:
				sprite.modulate.a=1.0-front
				front_sprite.modulate.a=front
				front_sprite.scale.x=1.0/maxf(.01,(bones[key] as Bone2D).global_transform.x.length())
			if key in ["Cape","Cloth","Tail","Banner","Cannon","Mount"]: sprite.modulate.a=1.0-front
			var surface := sprite.material as ShaderMaterial
			if surface != null: surface.set_shader_parameter("hit_flash",flash)

static func windmill_origin(pose: Dictionary) -> Vector2:
	return PlainsBossViewPose.windmill_origin(pose)
