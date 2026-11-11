extends SceneTree
## Authored collision volumes and their presentation share clean wall seams.
var failures:=0
func check(ok:bool,label:String)->void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
	var surfaces:Array[Rect2]=[Rect2(0,0,100,40)]
	var rock:Array[Rect2]=[Rect2(0,0,20,40),Rect2(10,0,20,40),Rect2(80,0,20,40)]
	var visible:=WorldRoomSpace.exposed_parts(surfaces,rock)
	var area:=0.0
	for part:Rect2 in visible:area+=part.get_area()
	check(area==2000,"overlapping rock is removed once; visible middle is retained")
	check(surfaces==[Rect2(0,0,100,40)],"source collision rectangles stay intact")
	check(WorldRoomSpace.exposed_parts(surfaces,[])==surfaces,"an unobstructed doorway keeps its full surface")
	var provider:=FixedWorldProvider.new();check(provider.open(),"formal world bundle")
	for id:String in ["P-R01","P-R03","P-R04","P-R06","P-R08","P-R13","P-R14","P-R15","P-R21","P-R22","P-R23","P-R24","P-R25","P-R26","P-R27","P-R31","P-R32","P-R33","Z-R01"]:
		var room:=load(str(provider.room(id).scene_ref)).instantiate() as FixedWorldRoom
		for placement:Dictionary in room.art_placements:
			if placement.has("motion_source"):check(room.get_node_or_null(NodePath(placement.motion_source)) is WorldMovingPlatform,id+" background drive references a real carrier")
		var geometry:Dictionary=provider.room(id).world_geometry
		var doors:Array=provider.room(id).doors.filter(func(d:Dictionary)->bool:return d.get("target_implemented",false))
		var blockers:=WorldRoomSpace.exterior_fill(geometry,doors)
		blockers.append_array(WorldRoomSpace.boundary_platforms(geometry,doors))
		for i:int in room.platforms.size():
			for j:int in range(i+1,room.platforms.size()):check(not room.platforms[i].intersects(room.platforms[j]),id+" authored platforms do not overlap")
			for wall:Rect2 in blockers:check(not room.platforms[i].intersects(wall),id+" authored platform stops at wall face")
		var parts:=WorldRoomSpace.exposed_parts(room.platforms,blockers)
		for part:Rect2 in parts:
			for wall:Rect2 in blockers:check(not part.intersects(wall),id+" visible platform never enters room rock")
		if id in ["P-R22","P-R23"]:check(room.masonry_platform_indices.is_empty(),id+" natural platforms retain the plains tile family")
		if id=="P-R01":
			check(room.masonry_platform_indices.is_empty(),"P01 approach stays pass-through and street stays plains")
			check(room.art_placements.any(func(p:Dictionary)->bool:return p.get("threshold_for","")=="L01:P-R01"),"P01 authored entrance suppresses duplicate automatic sill")
		if id=="P-R22":
			check(room.masonry_platform_indices.is_empty(),"canal receiving ledges and exit share the plains material")
			var entrance:Array[Rect2]=[room.platforms[0]]
			var cropped:=WorldRoomSpace.exposed_parts(entrance,blockers)
			check(cropped==entrance and entrance[0].position.x==608,"P22 entrance terminates at inner wall face")
		if id=="P-R25":
			var entrance:Array[Rect2]=[]
			for platform:Rect2 in room.platforms:
				if platform.position.y==960:entrance.append(platform)
			var cropped:=WorldRoomSpace.exposed_parts(entrance,blockers)
			check(cropped==entrance and cropped.size()==1 and cropped[0].end.x==352,"P25 timber terminates at bank face")
		room.free()
	print("PLATFORM ART SEAMS: ",failures," failures");quit(failures)
