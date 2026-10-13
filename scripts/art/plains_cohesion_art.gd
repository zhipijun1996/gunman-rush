class_name PlainsCohesionArt
extends RefCounted
const ATLAS:=preload("res://assets/plains_v6/cohesion_atlas.png")
# Actual measured regions, not the requested grid (which the generator did not follow).
const GRASS:=Rect2(24,180,656,320)
const FILL:=Rect2(735,95,365,355)
const EDGE:=Rect2(1170,115,350,385)
const WOOD:=Rect2(20,710,578,195)
const MINI_BURST:=Rect2(617,532,477,481)
const WIND_BURST:=Rect2(1098,528,428,490)
const SCALE:=.2
const MODULAR := preload("res://assets/plains_v7/modular_terrain.png")
# Separate terminal silhouettes and a straight middle. No cap is repeated inside a slab.
static func surface_pieces(rect: Rect2, wood: bool, joined_left: bool = false, joined_right: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not rect.has_area(): return result
	var top := 145.0 if wood else 570.0
	var standing := 217.0 if wood else 640.0
	var bottom := 489.0 if wood else 910.0
	var scale := minf(.20, rect.size.y / (bottom-standing))
	var above := (standing-top)*scale
	var height := (bottom-top)*scale
	var cap_width := minf(458*scale, rect.size.x/2)
	var left := 0.0 if joined_left else cap_width
	var right := 0.0 if joined_right else cap_width
	var y := rect.position.y-above
	if left>0:
		result.append({"kind":"left", "destination":Rect2(rect.position.x,y,left,height), "source":Rect2(29,top,left/scale,bottom-top)})
	var x := rect.position.x+left
	var finish := rect.end.x-right
	while x<finish-.001:
		var width := minf(450*scale,finish-x)
		result.append({"kind":"middle", "destination":Rect2(x,y,width,height), "source":Rect2(540,top,width/scale,bottom-top)})
		x+=width
	if right>0:
		result.append({"kind":"right", "destination":Rect2(finish,y,right,height), "source":Rect2(1508-right/scale,top,right/scale,bottom-top)})
	return result

static func draw_surface(node:CanvasItem,rect:Rect2,wood:bool=false,joined_left:bool=false,joined_right:bool=false)->void:
	for piece:Dictionary in surface_pieces(rect,wood,joined_left,joined_right):
		node.draw_texture_rect_region(MODULAR,piece.destination,piece.source)
static func draw_fill(node:CanvasItem,rect:Rect2)->void:
	node.draw_rect(rect,Color("344c3b"))
	var tile:=FILL.size*.55
	var origin:Vector2=node.get_global_transform().origin
	var world:=Rect2(rect.position+origin,rect.size)
	for row:int in range(floori(world.position.y/tile.y),ceili(world.end.y/tile.y)):
		for col:int in range(floori(world.position.x/tile.x),ceili(world.end.x/tile.x)):
			var cell:=Rect2(Vector2(col,row)*tile,tile);var part:=world.intersection(cell)
			if not part.has_area():continue
			var src:=Rect2(FILL.position+(part.position-cell.position)/.55,part.size/.55)
			node.draw_texture_rect_region(ATLAS,Rect2(part.position-origin,part.size),src,Color(.89,.96,.89))
static func draw_outer_edges(node:CanvasItem,rect:Rect2,edges:Array)->void:
	for e:Dictionary in edges:
		var part:Rect2=e.rect
		# Side root fringes use real exposed faces, never each module's internal seam.
		var width:float=minf(15,rect.size.x*.25)
		if e.side=="bottom":
			var target:=Rect2(part.position-Vector2(0,4),Vector2(part.size.x,10))
			for piece:Dictionary in PlainsTerrainSkin.clipped_strip_pieces(target,target,node.get_global_transform().origin,Rect2(35,345,610,50),SCALE):node.draw_texture_rect_region(ATLAS,piece.destination,piece.source,Color(.75,.86,.76))
			continue
		var base:=Rect2(EDGE.position+Vector2(EDGE.size.x-80,80),Vector2(80,200))
		var top:float=part.position.y;var finish:float=part.end.y
		while top<finish-.001:
			var height:=minf(40,finish-top)
			var src:=Rect2(base.position,Vector2(80,height/SCALE))
			if e.side=="right":node.draw_texture_rect_region(ATLAS,Rect2(part.position.x-8,top,width,height),src,Color(.82,.93,.85))
			else:
				node.draw_set_transform(Vector2(part.position.x+8,0),0,Vector2(-1,1))
				node.draw_texture_rect_region(ATLAS,Rect2(0,top,width,height),src,Color(.82,.93,.85));node.draw_set_transform(Vector2.ZERO)
			top+=height

static func arrival(origin:Vector2,target:Vector2,age:float,duration:float)->Vector2:
	var t:=clampf(age/maxf(duration,.01),0,1)
	return origin.lerp(target,t)+Vector2(0,-sin(t*PI)*minf(90,20+origin.distance_to(target)*.12))
