class_name BeamHardware
extends RefCounted
## Visible load-bearing surfaces follow their collision rectangles. Small shared
## fittings identify hinges, pressure-qualified loads, and shootable parts.
const GILLS := Rect2(0,0,25,11)
const BRAID := Rect2(32,0,27,15)
const SPORE := Rect2(64,0,12,21)
const SOCKET := Rect2(0,24,29,34)
const CLEAT := Rect2(36,24,16,11)
const BOSS := Rect2(62,24,18,18)
const SHADOW := Color("#292930")
const BRASS := Color("#b39467")
const SIGNAL := Color("#edc381")
const COOL := Color("#89ad9b")
static var workings: Texture2D

static func part(canvas: CanvasItem,frame: Rect2,center: Vector2,size: Vector2) -> void:
	if minf(size.x,size.y)<1: return
	if workings==null: workings=load("res://assets/mechanisms/beam_hardware/workings.png")
	canvas.draw_texture_rect_region(workings,Rect2((center-size*.5).round(),size),frame)

static func rivet(canvas: CanvasItem,at: Vector2) -> void:
	canvas.draw_rect(Rect2(at.round()-Vector2(2,2),Vector2(4,4)),SHADOW)
	canvas.draw_rect(Rect2(at.round()-Vector2(1,1),Vector2(2,2)),BRASS)

static func joint(canvas: CanvasItem,a: Vector2,b: Vector2,width: float) -> void:
	canvas.draw_line(a.round(),b.round(),SHADOW,width+2)
	canvas.draw_line(a.round(),b.round(),BRASS.darkened(.28),width)
	canvas.draw_line(a.round()-Vector2(0,1),b.round()-Vector2(0,1),BRASS,1)

static func beam(canvas: CanvasItem,rect: Rect2,style: String) -> void:
	if rect.size.y < 9 or rect.size.x<24:
		MechanismRegionArt.panel(canvas,rect)
		return
	var cap := clampf(roundf(rect.size.y*.28),3,8)
	var upper := rect.position.y+cap
	var lower := rect.end.y-cap
	canvas.draw_rect(rect,SHADOW)
	var bays := maxi(1,roundi(rect.size.x/32))
	var span := rect.size.x/bays
	for i: int in bays:
		var x := rect.position.x+i*span
		var middle := Vector2(x+span*.5,lower)
		match style:
			"woven":
				part(canvas,BRAID,Vector2(x+span*.5,rect.get_center().y),Vector2(span,rect.size.y))
				MechanismRegionArt.stamp(canvas,"finial",Vector2(x+span*.5,lower-1),Vector2(span*.55,rect.size.y-3))
			"vaulted":
				MechanismRegionArt.panel(canvas,Rect2(x,upper,span,lower-upper))
				var knee := minf((lower-upper)*.65,span*.18)
				var inset := PackedVector2Array([Vector2(x+3,lower),Vector2(x+3,upper+knee),Vector2(x+3+knee,upper+1),Vector2(x+span-3-knee,upper+1),Vector2(x+span-3,upper+knee),Vector2(x+span-3,lower)])
				canvas.draw_colored_polygon(inset,SHADOW)
			"rigged":
				joint(canvas,Vector2(x,upper),Vector2(x+span,lower),2)
				joint(canvas,Vector2(x,lower),Vector2(x+span,upper),1)
			_:
				joint(canvas,Vector2(x,upper),middle,2)
				joint(canvas,middle,Vector2(x+span,upper),2)
		if i>0: rivet(canvas,Vector2(x,upper))
	MechanismRegionArt.panel(canvas,Rect2(rect.position,Vector2(rect.size.x,cap)))
	MechanismRegionArt.panel(canvas,Rect2(rect.position.x,lower,rect.size.x,cap),Color("#bbb9ac"))
	for x: float in [rect.position.x+4,rect.end.x-4]:
		MechanismRegionArt.stamp(canvas,"mount",Vector2(x,rect.get_center().y),Vector2(9,rect.size.y))

static func bearing(canvas: CanvasItem,diameter: float,warning: bool) -> void:
	var size := Vector2.ONE*diameter
	MechanismRegionArt.stamp(canvas,"mount",Vector2.ZERO,size+Vector2(6,6))
	BellGateArt.stamp_scaled_wheel(canvas,Vector2.ZERO,size)
	var r := clampf(diameter*.13,1,4)
	canvas.draw_rect(Rect2(-Vector2.ONE*r,Vector2.ONE*r*2),SIGNAL if warning else BRASS)
	canvas.draw_line(Vector2(r,0),Vector2(diameter*.43,0),Color("#dfc18d"),2)

static func teeth(canvas: CanvasItem,edge: Vector2,width: float,depth: float) -> void:
	var count := maxi(1,roundi(width/12))
	var pitch := width/count
	for i: int in count:
		var start := edge+Vector2.RIGHT*(i*pitch)
		var tip := start+Vector2(pitch*.5,depth)
		canvas.draw_colored_polygon(PackedVector2Array([start,start+Vector2.RIGHT*pitch,tip]),Color("#a79b84"))
		canvas.draw_line(start+Vector2(pitch-1,0),tip,SHADOW,1)
		canvas.draw_line(start+Vector2(1,0),tip,Color("#dfc69b"),1)
	MechanismRegionArt.stamp(canvas,"hazard",edge+Vector2(width*.5,-2),Vector2(minf(width,24),7))

static func tie(canvas: CanvasItem,rect: Rect2,style: String) -> void:
	if rect.size.x<18 or rect.size.y<18: return
	var inset := rect.grow(-4)
	var tl := inset.position
	var br := inset.end
	var tr := Vector2(br.x,tl.y)
	var bl := Vector2(tl.x,br.y)
	match style:
		"woven":
			for y: float in [.27,.72]:
				part(canvas,BRAID,Vector2(rect.get_center().x,rect.position.y+rect.size.y*y),Vector2(rect.size.x-3,minf(18,rect.size.y*.34)))
		"vaulted":
			for fraction: float in [.30,.70]:
				var x := rect.position.x+rect.size.x*fraction
				MechanismRegionArt.panel(canvas,Rect2(x-3,tl.y,6,inset.size.y),Color("#bdbbad"))
		"rigged":
			joint(canvas,tl,br,2)
			joint(canvas,tr,bl,2)
		_:
			joint(canvas,bl,tr,4)
			for point: Vector2 in [tl,tr,bl,br]: part(canvas,CLEAT,point,Vector2(9,7))

static func ballast(canvas: CanvasItem,rect: Rect2,marked: bool,crate: bool) -> void:
	MechanismRegionArt.panel(canvas,rect)
	var style := BellGateArt.structure(canvas)
	if not crate:
		var shoulder := minf(12,rect.size.x*.2)
		for x: float in [rect.position.x,rect.end.x-shoulder]:
			MechanismRegionArt.panel(canvas,Rect2(x,rect.position.y,shoulder,rect.size.y),Color("#918a7d"))
		for y: float in [.31,.71]:
			var h := minf(4,rect.size.y*.1)
			MechanismRegionArt.panel(canvas,Rect2(rect.position.x,rect.position.y+rect.size.y*y,rect.size.x,h))
	else:
		var h := minf(7,rect.size.y*.18)
		for y: float in [rect.position.y,rect.end.y-h]:
			MechanismRegionArt.panel(canvas,Rect2(rect.position.x,y,rect.size.x,h),Color("#d4c7a6"))
	tie(canvas,rect,style)
	if marked:
		var d := minf(21,minf(rect.size.x,rect.size.y)*.4)
		MechanismRegionArt.stamp(canvas,"mount",rect.get_center(),Vector2.ONE*d)
		var p := rect.get_center()
		var mark := PackedVector2Array([p+Vector2(-4,-3),p+Vector2(4,-3),p+Vector2(6,4),p+Vector2(-6,4)])
		canvas.draw_colored_polygon(mark,BRASS)
		canvas.draw_arc(p+Vector2(0,-4),2,PI,TAU,5,SIGNAL,1)

static func press(canvas: CanvasItem,rect: Rect2,origin: Vector2,depth: float,warning: bool) -> void:
	var top := rect.position.y
	var mid := rect.get_center().x
	var span := minf(22,rect.size.x*.26)
	if top>origin.y:
		MechanismRegionArt.panel(canvas,Rect2(mid-span/2,origin.y,span,top-origin.y),Color("#c6c4b9"))
		for y: int in range(roundi(origin.y+4),roundi(top),12):
			canvas.draw_line(Vector2(mid-span/2,y),Vector2(mid+span/2,y),SHADOW,2)
	MechanismRegionArt.stamp(canvas,"mount",origin,Vector2(36,26))
	part(canvas,SOCKET,origin,Vector2(21,26))
	MechanismRegionArt.panel(canvas,rect)
	var side := minf(20,rect.size.x*.22)
	for x: float in [rect.position.x+side/2,rect.end.x-side/2]:
		MechanismRegionArt.stamp(canvas,"finial",Vector2(x,rect.get_center().y),Vector2(side,rect.size.y))
	MechanismRegionArt.panel(canvas,Rect2(rect.position.x,rect.end.y-4,rect.size.x,4),Color("#c5b99a"))
	MechanismRegionArt.stamp(canvas,"lamp",rect.get_center(),Vector2(19,24),Color.WHITE if warning else Color("#a5a6a0"))
	teeth(canvas,Vector2(rect.position.x,rect.end.y),rect.size.x,depth)

static func growth(canvas: CanvasItem,length_now: float,thickness: float,rooted: bool) -> void:
	var rect := Rect2(-Vector2(length_now,thickness)*.5,Vector2(length_now,thickness))
	var sections := maxi(1,ceili(length_now/24))
	var span := length_now/sections
	if rooted:
		MechanismRegionArt.panel(canvas,rect)
		for i: int in sections:
			var center := rect.position.x+(i+.5)*span
			part(canvas,BRAID,Vector2(center,0),Vector2(span,minf(16,thickness)))
			MechanismRegionArt.stamp(canvas,"finial",Vector2(center+span*.30,0),Vector2(minf(12,span),thickness))
		MechanismRegionArt.stamp(canvas,"mount",Vector2(rect.end.x-minf(6,span*.23),0),Vector2(minf(13,span),thickness))
	else:
		var upper := maxf(2,thickness*.58)
		MechanismRegionArt.panel(canvas,Rect2(rect.position,Vector2(length_now,upper)))
		for i: int in sections:
			var x := rect.position.x+(i+.5)*span
			part(canvas,GILLS,Vector2(x,rect.end.y-thickness*.31),Vector2(span,thickness*.62))
		MechanismRegionArt.stamp(canvas,"finial",Vector2(rect.position.x+span*.33,-1),Vector2(span*.66,thickness))
		MechanismRegionArt.stamp(canvas,"finial",Vector2(rect.end.x-span*.33,-1),Vector2(span*.66,thickness))

static func growth_bud(canvas: CanvasItem,at: Vector2,blocked: bool) -> void:
	MechanismRegionArt.stamp(canvas,"mount",at,Vector2(23,23))
	part(canvas,SPORE,at,Vector2(13,18))
	var color := Color("#dd9561") if blocked else Color("#e0db9a")
	canvas.draw_rect(Rect2(at.round()-Vector2(2,0),Vector2(4,3)),color)

static func signal_dial(canvas: CanvasItem,active: bool,blocked: bool,wave: bool) -> void:
	MechanismRegionArt.stamp(canvas,"mount",Vector2.ZERO,Vector2(42,32))
	part(canvas,BOSS,Vector2(-7,0),Vector2(18,18))
	var origin := Vector2(10,0)
	if wave:
		for i: int in 3:
			canvas.draw_rect(Rect2(origin+Vector2(i*3-3,-3+i),Vector2(2,5)),SIGNAL if active else BRASS)
	else:
		joint(canvas,Vector2.ZERO,Vector2(8,-6 if active else 6),2)
		for y: float in [-6,6]:
			canvas.draw_rect(Rect2(origin+Vector2(-1,y-1),Vector2(4,3)),SIGNAL if (y<0)==active else SHADOW)
	if blocked: canvas.draw_arc(Vector2.ZERO,16,-PI*.8,-PI*.2,10,Color("#e69260"),2)
