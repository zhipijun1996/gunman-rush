class_name PlatformThornDefinition
extends Resource
## A hazardous surface belongs to a real solid, not decorative terrain.
enum Face { TOP, LEFT, RIGHT, BOTTOM }
@export var surface_id: StringName = &"thorns"
@export var platform_index := 0
@export var face: Face = Face.TOP
@export var start_offset := 0.0
@export var length := 128.0
@export var depth := 24.0
func is_valid(platforms: Array[Rect2]) -> bool:
	if surface_id.is_empty() or platform_index<0 or platform_index>=platforms.size() or face<0 or face>3:return false
	for value:float in [start_offset,length,depth]:
		if not is_finite(value):return false
	var extent:float=platforms[platform_index].size.x if face in [Face.TOP,Face.BOTTOM] else platforms[platform_index].size.y
	return start_offset>=0 and length>0 and depth>0 and start_offset+length<=extent+.001
func danger(platforms: Array[Rect2])->Rect2:
	var p:Rect2=platforms[platform_index]
	if face==Face.TOP:return Rect2(p.position+Vector2(start_offset,-depth),Vector2(length,depth))
	if face==Face.BOTTOM:return Rect2(Vector2(p.position.x+start_offset,p.end.y),Vector2(length,depth))
	if face==Face.LEFT:return Rect2(p.position+Vector2(-depth,start_offset),Vector2(depth,length))
	return Rect2(Vector2(p.end.x,p.position.y+start_offset),Vector2(depth,length))
