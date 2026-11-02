class_name PlainsInteractiveArt
extends RefCounted
const ATLAS:=preload("res://assets/plains_v5/interactive_atlas.png")
const FORMS:=[Rect2(8,112,503,445),Rect2(515,0,510,558),Rect2(1025,62,510,497)]
const FEET:=[Vector2(245,440),Vector2(255,551),Vector2(250,490)]
const SIGILS:=[Rect2(1047,578,226,224),Rect2(1279,578,246,224),Rect2(1044,797,241,209)]
const AIM_DOWN:=Rect2(1286,793,241,231)
static func draw_sigil(node:CanvasItem,point:Vector2,index:int,size:float=34)->void:
	node.draw_texture_rect_region(ATLAS,Rect2(point-Vector2.ONE*size/2,Vector2.ONE*size),SIGILS[posmod(index,3)])
static func draw_thorns(node:CanvasItem,thorn:PlatformThornDefinition,platforms:Array[Rect2])->void:
	var danger:Rect2=thorn.danger(platforms)
	# Raw painted tile's thorn/root band; the stone host is already rendered.
	if thorn.face==PlatformThornDefinition.Face.TOP:
		node.draw_texture_rect_region(ATLAS,Rect2(danger.position, danger.size+Vector2(0,8)),Rect2(25,695,250,115))
	elif thorn.face==PlatformThornDefinition.Face.LEFT:
		node.draw_texture_rect_region(ATLAS,Rect2(danger.position, danger.size+Vector2(8,0)),Rect2(721,612,130,330))
	elif thorn.face==PlatformThornDefinition.Face.RIGHT:
		node.draw_set_transform(Vector2(danger.end.x,0),0,Vector2(-1,1))
		node.draw_texture_rect_region(ATLAS,Rect2(Vector2(0,danger.position.y),danger.size+Vector2(8,0)),Rect2(721,612,130,330))
		node.draw_set_transform(Vector2.ZERO)
	else:
		node.draw_set_transform(Vector2(0,danger.end.y),0,Vector2(1,-1))
		node.draw_texture_rect_region(ATLAS,Rect2(Vector2(danger.position.x,0),danger.size+Vector2(0,8)),Rect2(25,695,250,115))
		node.draw_set_transform(Vector2.ZERO)
static func draw_aim(node:CanvasItem,at:Vector2,size:float=54)->void:
	node.draw_texture_rect_region(ATLAS,Rect2(at-Vector2.ONE*size/2,Vector2.ONE*size),AIM_DOWN)
