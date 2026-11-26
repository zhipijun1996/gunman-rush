class_name RoomWaymarker
extends Node2D
## Grounded scenery for authored notices and safe returns. The room owns all
## interaction ranges and recovery decisions.
var notice := false
var selected := false

func _draw() -> void:
	if notice:
		MechanismRegionArt.panel(self,Rect2(-3,-20,6,20))
		MechanismRegionArt.panel(self,Rect2(-16,-39,32,23))
		var parchment := PackedVector2Array([Vector2(-11,-35),Vector2(11,-35),Vector2(10,-21),Vector2(4,-22),Vector2(1,-20),Vector2(-10,-21)])
		draw_colored_polygon(parchment,Color("d2bb88"))
		for line: Rect2 in [Rect2(-7,-31,13,2),Rect2(-7,-27,9,1),Rect2(-7,-24,12,1)]:
			draw_rect(line,Color("67513f"))
		MechanismRegionArt.stamp(self,"finial",Vector2(0,-43),Vector2(18,14))
	else:
		MechanismRegionArt.panel(self,Rect2(-11,-5,22,5))
		MechanismRegionArt.stamp(self,"mount",Vector2(0,-8),Vector2(16,16))
		var light := MechanismRegionArt.accent(self)
		if not selected: light = light.darkened(.4)
		draw_polyline(PackedVector2Array([Vector2(-4,-8),Vector2(0,-12),Vector2(4,-8),Vector2(0,-5),Vector2(-4,-8)]),light,1)
		if selected: draw_rect(Rect2(-1,-10,3,3),light)
