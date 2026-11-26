extends RefCounted
## Hardware is drawn behind the solid deck. All dimensions are world pixels.
const WHEEL := preload("res://assets/plains_v07/native/mill_gear.png")
const WINCH := preload("res://assets/plains_v07/native/pulley_switch.png")
const DECK := preload("res://assets/underworld_plains/mechanisms/carrier_fine.png")
const EDGE := Color("#252827")
const IRON := Color("#50514d")
const COPPER := Color("#876848")
const LIGHT := Color("#bb995d")

static func bearing(node: CanvasItem, at: Vector2) -> void:
	var rect := Rect2(at.round()-Vector2(8,8),Vector2(16,16))
	node.draw_texture_rect_region(WHEEL,rect,Rect2(27,27,16,16))

## Two rolled edges and diagonal ties frame a hollow iron arm. Ends use actual
## carrier deck pixels for the copper rivet straps.
static func girder(node: CanvasItem, start: Vector2, end: Vector2, height: float) -> void:
	var length := start.distance_to(end)
	if length < 1: return
	node.draw_set_transform(start.round(),start.angle_to_point(end),Vector2.ONE)
	var bottom := height*.5
	var bay_count := maxi(1,ceili(length/22.0))
	var bay := length/bay_count
	for i in bay_count:
		var a := Vector2(i*bay,-bottom+2)
		var b := Vector2((i+1)*bay,bottom-2)
		node.draw_line(a,b,EDGE,4)
		node.draw_line(a-Vector2(0,1),b-Vector2(0,1),COPPER,1)
	var cursor := 0.0
	while cursor<length:
		var width := minf(32,length-cursor)
		for y: float in [-bottom,bottom-3]:
			node.draw_texture_rect_region(DECK,Rect2(cursor,y,width,4),Rect2(80,0,width,4))
		cursor += width
	for i in range(bay_count+1):
		var x := minf(length-3,maxf(0,i*bay-1))
		node.draw_texture_rect_region(DECK,Rect2(x,-bottom,3,height),Rect2(5,4,3,height))
	node.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

## Closed rim around the wheel teeth identifies a captive sheave or flywheel.
static func sheave(node: CanvasItem, center: Vector2, radius: float, angle: float) -> void:
	center = center.round()
	node.draw_circle(center,radius+2,EDGE)
	node.draw_circle(center,radius,IRON)
	node.draw_arc(center,radius,-PI*.98,-PI*.32,32,Color("#92816a"),1)
	node.draw_circle(center,radius-3,Color("#343737"))
	node.draw_set_transform(center,angle,Vector2.ONE)
	var diameter := 2*(radius-3)
	node.draw_texture_rect(WHEEL,Rect2(-diameter*.5,-diameter*.5,diameter,diameter),false)
	node.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	bearing(node,center)

static func chain(node: CanvasItem, head: Vector2, shoe: Vector2) -> void:
	# A moving turn of the chain leaves the top wheel on the same vertical line.
	var x := roundf(shoe.x)
	var bottom := roundf(shoe.y)
	var top := roundf(head.y)
	if top>=bottom: return
	node.draw_rect(Rect2(x-2,top,4,bottom-top),EDGE)
	var y := bottom
	while y-7>=top:
		node.draw_rect(Rect2(x-3,y-7,5,4),IRON)
		node.draw_rect(Rect2(x-2,y-7,3,1),LIGHT)
		node.draw_rect(Rect2(x-3,y-6,1,2),COPPER)
		node.draw_rect(Rect2(x-1,y-4,2,4),COPPER)
		y-=7

static func orbit(node: Node2D, carriers: Array[WorldMovingPlatform], radius: float, angle: float) -> void:
	if carriers.is_empty(): return
	for deck in carriers:
		var end: Vector2 = node.to_local(deck.global_position)
		girder(node,Vector2.ZERO,end,12)
	var drum_radius := clampf(radius*.36,10,39)
	sheave(node,Vector2.ZERO,drum_radius,angle)

static func counterweight(node: Node2D, carriers: Array[WorldMovingPlatform], upper: Array[Vector2], progress: float, stroke: Vector2) -> void:
	if upper.size()!=2: return
	var decks: Array[Vector2] = [node.to_local(carriers[0].global_position),node.to_local(carriers[1].global_position)]
	var rail_y := minf(0,minf(upper[0].y,upper[1].y)-node.position.y-24)
	var left := minf(0,minf(decks[0].x,decks[1].x))
	var right := maxf(0,maxf(decks[0].x,decks[1].x))
	girder(node,Vector2(left,rail_y),Vector2(right,rail_y),14)
	for i in 2:
		var head := Vector2(decks[i].x,rail_y)
		chain(node,head,decks[i])
		var travel := progress*stroke.x if i==0 else (1-progress)*stroke.y
		sheave(node,head+Vector2(10 if i==0 else -10,0),12,travel/10)
	var frame := posmod(roundi(progress*stroke.x/7),6)
	node.draw_texture_rect_region(WINCH,Rect2(-32,rail_y-60,64,64),Rect2(frame*64,0,64,64))

static func deck_pin(node: CanvasItem, size: Vector2) -> void:
	if size.x<20 or size.y<10: return
	bearing(node,Vector2(0,minf(size.y*.2,3)))

class Track extends Node2D:
	var points: Array[Vector2] = []
	var call_points: Array[Vector2] = []

	func _draw() -> void:
		var previous := Vector2.ZERO
		for end in points:
			var length := previous.distance_to(end)
			var angle := previous.angle_to_point(end)
			draw_set_transform(previous.round(),angle,Vector2.ONE)
			draw_rect(Rect2(0,-2,length,5),EDGE)
			var x := 0.0
			while x<length:
				var width := minf(32,length-x)
				draw_texture_rect_region(DECK,Rect2(x,-2,width,3),Rect2(80,0,width,3))
				x+=width
			var ties := maxi(1,ceili(length/56.0))
			for i in ties:
				var at := roundf(i*length/ties)
				draw_texture_rect_region(DECK,Rect2(at-2,-4,5,9),Rect2(4,4,5,9))
			previous = end
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		for at in call_points:
			draw_texture_rect_region(WINCH,Rect2(at.round()-Vector2(32,60),Vector2(64,64)),Rect2(0,0,64,64))

static func bogie(node: CanvasItem, size: Vector2, distance: float) -> void:
	if size.x<30: return
	var inset := minf(size.x*.27,32)
	for x: float in [-inset,inset]:
		sheave(node,Vector2(x,size.y*.5),8,distance/8)
