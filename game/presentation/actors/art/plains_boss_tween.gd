class_name PlainsBossTween
extends RefCounted
## Pure continuous pose geometry, sampled from the encounter's accepted clocks.
const SHADER = preload("res://game/presentation/actors/art/plains_boss_tween.gdshader")
static var _textures: Dictionary = {}
static var _resources: Dictionary = {}
static func prepare(name: String) -> void:
	if _textures.has(name):return
	var root:="res://assets/plains_boss_motion_142/"+name
	_textures[name]={"vectors":load(root+"_vectors.png"),"body":load(root+"_body.png") if name.begins_with("bellstrider") else load("res://assets/plains_actors_142/atlases/"+name+".png")}
static func warm(family: String) -> void:
	for name: StringName in PlainsBossFrames.SHEETS:
		if String(name).begins_with(family) and (String(name).ends_with("_flow") or String(name).ends_with("_motion") or String(name).ends_with("_turn")):
			_resources[name]=load(PlainsBossFrames.SHEETS[name])
			prepare(String(name))

static func pair(frame: Dictionary) -> Dictionary:
	var animation: PlainsActorAnimation = frame.animation
	var row := maxi(0,animation.clips.find(String(frame.clip)))
	var loop: bool = frame.clip in [&"idle",&"move"]
	# Separate batches of generated in-betweens changed anatomy/materials.
	# Follow the original coherent key family; geometry fills the intervals.
	var stride:=2 if String(frame.sheet).ends_with("_flow") or String(frame.sheet).ends_with("_motion") else 1
	var count:=ceili(float(animation.columns)/stride)
	var time: float=clampf(frame.progress,0,1)*(count if loop else count-1)
	var key:=mini(floori(time),count-1)
	var column:=key*stride
	var following:=((key+1)%count)*stride if loop else mini(column+stride,animation.columns-1)
	return {"a":row*animation.columns+column,"b":row*animation.columns+following,"mix":time-floorf(time),"row":row,"column":column,"next_column":following}

static func anchor(frame: Dictionary, points: PackedVector2Array) -> Vector2:
	var p := pair(frame)
	return points[p.a].lerp(points[p.b],p.mix) if points.size()>maxi(p.a,p.b) else Vector2.ZERO

static func draw(canvas: Node2D, frame: Dictionary, tint: Color) -> void:
	var animation: PlainsActorAnimation=frame.animation
	var p:=pair(frame)
	var name:=String(frame.sheet)
	prepare(name)
	var textures: Dictionary=_textures[name]
	var surface:=canvas.material as ShaderMaterial
	var size:=Vector2(animation.frame_size)
	var atlas_size: Vector2=textures.body.get_size()
	var uv:=Vector2(p.column,p.row)*size/atlas_size
	surface.set_shader_parameter("motion_vectors",textures.vectors)
	surface.set_shader_parameter("frame_origin",uv)
	surface.set_shader_parameter("next_origin",Vector2(p.next_column,p.row)*size/atlas_size)
	surface.set_shader_parameter("frame_pixels",size)
	surface.set_shader_parameter("vector_size",Vector2(1.0/animation.columns,1.0/animation.clips.size()))
	surface.set_shader_parameter("vector_origin",Vector2(float(p.column)/animation.columns,float(p.row)/animation.clips.size()))
	surface.set_shader_parameter("pose_mix",p.mix)
	canvas.draw_set_transform(frame.origin,0,Vector2(frame.face,1))
	canvas.draw_texture_rect_region(textures.body,Rect2(-animation.pivot,size),Rect2(Vector2(p.column,p.row)*size,size),tint)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
