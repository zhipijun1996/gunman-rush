extends FixedWorldRoom
## Presentation-only greybox skin. Geometry and every hazard stay in the normal room fields.
const TRIAL_INK := Color("90b7ca")
const TRIAL_STONE := Color("253b50")

func _ready() -> void:
	super._ready()
	# The regional plains renderer is not the art direction of this unfinished region.
	# Keep the exact normal physics nodes and replace only their visible skin.
	for node: Node in find_children("*", "UnderworldTerrain", true, false):
		(node as CanvasItem).hide()
	var plains := get_node_or_null("RegionalArt") as PlainsRoomArt
	if plains != null:
		plains.hide()
		plains.set_process(false)
		plains.ambient.color = Color.WHITE
		if plains.daylight != null: plains.daylight.enabled = false
	var sky := Polygon2D.new()
	var bounds := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units)
	sky.polygon = PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)])
	sky.color = Color("0b1426")
	sky.z_index = -100
	add_child(sky)
	queue_redraw()

func _draw() -> void:
	if contract.is_empty(): return
	# Faint large rings establish depth without disguising collision edges.
	for center: Vector2 in hook_points:
		draw_arc(center,240,-2.9,2.2,64,Color("23324a"),2)
		draw_arc(center,218,-1.8,1.5,48,Color("192c42"),1)
	var bounds := FixedWorldProvider.rect(contract.world_geometry.bounds_world_units)
	for i: int in 90:
		var point := bounds.position+Vector2(24+fposmod(i*173,maxf(1,bounds.size.x-48)),24+fposmod(i*317,maxf(1,bounds.size.y-48)))
		draw_rect(Rect2(point,Vector2(2,2)),Color("536f8e"))
	for platform: Rect2 in platforms:
		draw_rect(platform,TRIAL_STONE)
		draw_rect(platform,TRIAL_INK,false,2)
		draw_line(platform.position+Vector2(0,5),Vector2(platform.end.x,platform.position.y+5),Color("496077"),2)
		for x: int in range(int(platform.position.x)+32,int(platform.end.x),64):
			draw_line(Vector2(x,platform.position.y+12),Vector2(x,minf(platform.end.y-6,platform.position.y+40)),Color("344b62"),1)
	for wall: Rect2 in climbable_walls:
		draw_rect(wall,Color("254a55"))
		draw_rect(wall,Color("81e0ce"),false,3)
		for y: int in range(int(wall.position.y)+8,int(wall.end.y)-4,16):
			draw_line(Vector2(wall.position.x+5,y),Vector2(wall.end.x-5,y),Color("81e0ce"),2)
	for strip: Dictionary in spike_strips:
		var rect := FixedWorldProvider.rect(strip.bounds)
		var facing := str(strip.get("facing","up"))
		var span := rect.size.x if facing in ["up","down"] else rect.size.y
		for offset: int in range(0,int(span)-8,12):
			var triangle := PackedVector2Array()
			if facing=="down": triangle=PackedVector2Array([rect.position+Vector2(offset,0),rect.position+Vector2(offset+6,rect.size.y),rect.position+Vector2(offset+12,0)])
			elif facing=="left": triangle=PackedVector2Array([rect.position+Vector2(rect.size.x,offset),rect.position+Vector2(0,offset+6),rect.position+Vector2(rect.size.x,offset+12)])
			elif facing=="right": triangle=PackedVector2Array([rect.position+Vector2(0,offset),rect.position+Vector2(rect.size.x,offset+6),rect.position+Vector2(0,offset+12)])
			else: triangle=PackedVector2Array([rect.position+Vector2(offset,rect.size.y),rect.position+Vector2(offset+6,0),rect.position+Vector2(offset+12,rect.size.y)])
			draw_colored_polygon(triangle,Color("d7848c"))
	# Landing trim marks actual ground recovery; hanging rings have no such trim.
	for retry: Dictionary in retry_anchors:
		var point := FixedWorldProvider.point(retry.point)
		for platform: Rect2 in platforms:
			if point.x>platform.position.x and point.x<platform.end.x and absf(platform.position.y-point.y-18)<2:
				draw_rect(Rect2(platform.position+Vector2(16,0),Vector2(maxf(1,platform.size.x-32),4)),Color("81e0ce"))
	var finish := get_node_or_null("FinishReturn") as WorldReturnLatch
	if finish!=null:
		var emblem := finish.position+Vector2(32,-62)
		draw_arc(emblem,36,0,TAU,48,Color("e2c77e"),3)
		draw_line(emblem+Vector2(-16,0),emblem+Vector2(-4,12),Color("e2c77e"),4)
		draw_line(emblem+Vector2(-4,12),emblem+Vector2(18,-15),Color("e2c77e"),4)
	super._draw()
