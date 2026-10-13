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
static func draw_surface(node:CanvasItem,rect:Rect2,wood:bool=false)->void:
	var source:Rect2=WOOD if wood else GRASS
	var above:float=8 if wood else 9
	var height:float=minf(rect.size.y+above,source.size.y*SCALE)
	var target:=Rect2(rect.position-Vector2(0,above),Vector2(rect.size.x,height))
	for piece:Dictionary in PlainsTerrainSkin.clipped_strip_pieces(target,target,node.get_global_transform().origin,Rect2(source.position,Vector2(source.size.x,height/SCALE)),SCALE):
		node.draw_texture_rect_region(ATLAS,piece.destination,piece.source)
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
