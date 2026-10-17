extends Node2D
@export var encounter: ThornQueenV2
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if encounter==null: return
	var size := encounter.definition.collision_size
	draw_colored_polygon(PackedVector2Array([Vector2(-size.x*.5,0),Vector2(-16,-size.y*.5),Vector2(0,-size.y*.5-18),Vector2(16,-size.y*.5),Vector2(size.x*.5,0),Vector2(0,size.y*.5)]),Color("9c677e") if not encounter.health.terminal else Color("635866"))
	draw_circle(Vector2.ZERO,10,Color("efc591"))
	draw_arc(Vector2.ZERO,15,0,TAU,24,Color("fae4b4"),2)
	for side: int in [-1,1]:
		draw_line(Vector2(side*18,-3),Vector2(side*38,18),Color("b68ca3"),5)

	if encounter._weave_bound and encounter.motion_mode in ["migration_preview","phase_preview"]:
		var path := encounter.motion_path()
		for index: int in path.size()-1:
			draw_line(to_local(path[index]),to_local(path[index+1]),Color("dfb684"),2,true)
			draw_circle(to_local(path[index+1]),7,Color("efc591"))
