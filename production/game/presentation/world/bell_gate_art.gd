class_name BellGateArt
extends RefCounted
## The same brass bell and winding gear identify the two ends of the signal.
static var sheet: Texture2D

static func texture() -> Texture2D:
	if sheet == null: sheet = load("res://assets/mechanisms/bell_gate/bell_gate.png")
	return sheet
const BELL := Rect2(0,0,28,34)
const BRACKET := Rect2(32,0,42,48)
const WHEEL := Rect2(80,0,26,26)
const CASE := Rect2(0,50,64,23)
const GUIDE := Rect2(66,50,5,19)
const CLEAT := Rect2(78,50,27,10)
const SILL := Rect2(0,76,39,10)
const WEIGHT := Rect2(48,76,7,12)
const INK := Color("#322b31")
const BRONZE := Color("#88704f")
const AMBER := Color("#f1ca7d")

## Bound spars for growth-based regions, long spars and lashings for open-air
## rigging, stepped masonry arches for stonework, pinned trusses for machinery.
static func structure(canvas: CanvasItem) -> String:
	match MechanismRegionArt.region_id(canvas):
		"thorn_forest","root_sanctuary","mushroom_caverns","firefly_marsh": return "woven"
		"windchime_plains","windswept_canyon","shattered_isles": return "rigged"
		"frostmirror_glacier","sunken_ruins","moonshadow_cemetery","moon_crown_castle","starbridge_gate": return "vaulted"
	return "riveted"

static func stamp(canvas: CanvasItem,part: Rect2,position: Vector2,tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture(),Rect2(position.round(),part.size),part,tint)

static func stamp_scaled_wheel(canvas: CanvasItem,center: Vector2,size: Vector2) -> void:
	canvas.draw_texture_rect_region(texture(),Rect2((center-size*.5).round(),size),WHEEL)

static func chain(canvas: CanvasItem,x: float,top: float,bottom: float) -> void:
	canvas.draw_line(Vector2(x,top),Vector2(x,bottom),INK,3)
	for y: int in range(roundi(top),roundi(bottom)-1,5):
		canvas.draw_rect(Rect2(x-1,y,2,3),BRONZE)
		canvas.draw_rect(Rect2(x+1,y+2,1,2),Color("#665747"))

static func bell(canvas: CanvasItem,at: Vector2,age: float,open: bool) -> void:
	at = at.round()
	# Keep the striking bell and its clear swing common. Each construction
	# carries the load back from the same hook into its own wall attachment.
	match structure(canvas):
		"woven":
			MechanismRegionArt.stamp(canvas,"finial",at+Vector2(-12,-45),Vector2(51,49))
			canvas.draw_line(at+Vector2(-5,-48),at+Vector2(0,-39),BRONZE,3)
		"vaulted":
			MechanismRegionArt.panel(canvas,Rect2(at+Vector2(-31,-57),Vector2(36,9)))
			MechanismRegionArt.stamp(canvas,"mount",at+Vector2(-23,-44),Vector2(23,29))
			chain(canvas,at.x,at.y-49,at.y-39)
		"rigged":
			MechanismRegionArt.panel(canvas,Rect2(at+Vector2(-34,-52),Vector2(40,6)))
			canvas.draw_line(at+Vector2(-28,-31),at+Vector2(-6,-48),BRONZE,3)
			MechanismRegionArt.stamp(canvas,"finial",at+Vector2(-27,-41),Vector2(17,26))
			chain(canvas,at.x,at.y-46,at.y-39)
		_:
			MechanismRegionArt.stamp(canvas,"finial",at+Vector2(-14,-50),Vector2(43,40))
			stamp(canvas,BRACKET,at+Vector2(-29,-65),Color("#c5bdab"))
			MechanismRegionArt.stamp(canvas,"mount",at+Vector2(-21,-31),Vector2(21,25))
	var pivot := at+Vector2(0,-39)
	var strike := sin(age*24)*.22*maxf(0,1-age/.65)
	canvas.draw_set_transform(pivot,strike)
	chain(canvas,0,0,23)
	stamp(canvas,BELL,Vector2(-14,22),Color(1.12,1.10,1.03) if open else Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
	if age < .46:
		for i: int in 2:
			var t := age-float(i)*.09
			if t < 0 or t > .36: continue
			var radius := roundf(18+t*70)
			var color := Color(1,.81,.50,1-t/.36)
			for side: float in [0.0,PI]:
				canvas.draw_arc(at,radius,side-.56,side+.56,8,color,1)

static func cropped_center(canvas: CanvasItem,part: Rect2,center: Vector2,width: float) -> void:
	var piece := part
	piece.size.x = clampf(roundf(width),0,part.size.x)
	if piece.size.x <= 0: return
	piece.position.x += floorf((part.size.x-piece.size.x)*.5)
	stamp(canvas,piece,center-Vector2(piece.size.x*.5,0))

static func gate(canvas: CanvasItem,box: Rect2,open: bool,turn: float) -> void:
	var left := roundf(box.position.x)
	var right := roundf(box.end.x)
	var top := roundf(box.position.y)
	var bottom := roundf(box.end.y)
	var mid := roundf(box.get_center().x)
	# Guides, winding drum and sill stay outside the clear passage.
	for x: float in [left-4,right]:
		for y: int in range(roundi(top),roundi(bottom),int(GUIDE.size.y)):
			var piece := GUIDE
			piece.size.y = minf(piece.size.y,bottom-y)
			stamp(canvas,piece,Vector2(x,y),Color("#beb5a6"))
	var style := structure(canvas)
	for x: float in [left-3,right+2]:
		match style:
			"woven":
				for y: int in range(roundi(top+9),roundi(bottom-4),24):
					MechanismRegionArt.stamp(canvas,"finial",Vector2(x,y),Vector2(11,24))
			"vaulted":
				for y: int in range(roundi(top+5),roundi(bottom-4),25):
					MechanismRegionArt.panel(canvas,Rect2(x-3,y,6,minf(23,bottom-y)),Color("#b6b5aa"))
			"rigged":
				chain(canvas,x,top,bottom-2)
	if not open:
		# Alternate the solid's masonry with thinner bands of the local door material.
		for y: int in range(roundi(top+9),roundi(bottom-5),24):
			var height := minf(9,bottom-y)
			MechanismRegionArt.panel(canvas,Rect2(left,y,box.size.x,height))
		for y: int in range(roundi(top+14),roundi(bottom-8),24):
			cropped_center(canvas,CLEAT,Vector2(mid,y),box.size.x-1)
	elif turn < 1:
		# Lift the side catches into the drum. The center clears immediately
		# with the authoritative leaf, including when the player stands here.
		var rise := roundf(turn*box.size.y)
		for y: int in range(roundi(top+14),roundi(bottom-8),24):
			if y-rise < top: continue
			stamp(canvas,Rect2(CLEAT.position,Vector2(5,8)),Vector2(left-2,y-rise))
			stamp(canvas,Rect2(CLEAT.end-Vector2(5,8),Vector2(5,8)),Vector2(right-3,y-rise))
	cropped_center(canvas,SILL,Vector2(mid,bottom-2),box.size.x+12)
	var head_width := maxf(48.0,box.size.x+18.0)
	for x: int in range(roundi(mid-head_width*.5+16),roundi(mid+head_width*.5-16),16):
		var width := minf(16,mid+head_width*.5-16-x)
		canvas.draw_texture_rect_region(texture(),Rect2(x,top-16,width,16),Rect2(25,54,width,16))
	stamp(canvas,Rect2(CASE.position,Vector2(32,CASE.size.y)),Vector2(mid-head_width*.5,top-20))
	stamp(canvas,Rect2(CASE.position+Vector2(32,0),Vector2(32,CASE.size.y)),Vector2(mid+head_width*.5-32,top-20))
	MechanismRegionArt.panel(canvas,Rect2(mid-head_width*.5+7,top-15,head_width-14,12))
	MechanismRegionArt.stamp(canvas,"finial",Vector2(mid+head_width*.5-6,top-13),Vector2(24,23))
	var axle := Vector2(mid-head_width*.5+13,top-9)
	canvas.draw_set_transform(axle,turn*PI*.80)
	stamp(canvas,WHEEL,-WHEEL.size*.5)
	canvas.draw_set_transform(Vector2.ZERO)
	var weight_y := top+5+roundf(turn*minf(29,box.size.y*.25))
	chain(canvas,left-9,top-7,weight_y)
	stamp(canvas,WEIGHT,Vector2(left-12,weight_y))
	canvas.draw_rect(Rect2(right+1,top-10,4,3),AMBER if open else Color("#7e6349"))

static func countdown(canvas: CanvasItem,gate_corner: Vector2,remaining: float) -> void:
	var x := roundf(gate_corner.x+7)
	var y := roundf(gate_corner.y+6)
	canvas.draw_rect(Rect2(x-2,y-2,8,42),INK)
	canvas.draw_rect(Rect2(x-1,y-1,6,40),Color("#68584c"))
	for i: int in 6:
		var lamp := Rect2(x,y+7*i,4,4)
		canvas.draw_rect(lamp,AMBER if remaining>float(i)/6 else Color("#3e3637"))
		if remaining>float(i)/6: canvas.draw_rect(Rect2(lamp.position,Vector2(3,1)),Color("#ffedbd"))
