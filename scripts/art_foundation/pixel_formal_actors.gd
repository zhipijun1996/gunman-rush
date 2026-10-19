@static_unload
class_name PixelFormalActors
extends RefCounted
## Original two-world-unit pixel clusters. Cosmetic adapters never own gameplay.
const INK := Color("111e2b")
const SHADE := Color("314b50")
const MOSS := Color("6e9180")
const BRASS := Color("a66d45")
const CREAM := Color("ead39a")
const ROSE := Color("c77f68")
static var _textures: Dictionary = {}

static func install(stage: Node2D) -> Dictionary:
	# Lazy orchestration avoids a strong script dependency back to consumers.
	return load("res://scripts/art_foundation/pixel_formal_style_installer.gd").install(stage)

static func pixel_line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) / 2))
	for i: int in steps + 1:
		var p := a.lerp(b, float(i) / steps).snapped(Vector2(2,2))
		canvas.draw_rect(Rect2(p-Vector2.ONE*width*.5,Vector2.ONE*width),color)

static func disc(canvas: CanvasItem, at: Vector2, radius: float, color: Color) -> void:
	for y: int in range(-ceili(radius/2), ceili(radius/2)):
		var py := float(y*2+1)
		var half := floorf(sqrt(maxf(0,radius*radius-py*py))/2)*2
		if half > 0: canvas.draw_rect(Rect2(at+Vector2(-half,y*2),Vector2(half*2,2)),color)

static func bell(canvas: CanvasItem, at: Vector2, open: bool, flash: bool = false) -> void:
	canvas.draw_rect(Rect2(at+Vector2(-8,-14),Vector2(16,24)),INK)
	canvas.draw_rect(Rect2(at+Vector2(-6,-12),Vector2(12,20)),CREAM if flash or open else BRASS)
	canvas.draw_rect(Rect2(at+Vector2(-10,6),Vector2(20,4)),CREAM)
	canvas.draw_rect(Rect2(at+Vector2(-2,-8),Vector2(4,14)),INK)
	canvas.draw_rect(Rect2(at+Vector2(-2,10),Vector2(4,4)),CREAM)

static func draw_bellstrider(canvas: Node2D, encounter: Node, clock: float, spring: float, wheel_angle: float, flash: bool) -> void:
	# Same axle centers and floor as original presentation: origin + (±40,40).
	for side: int in [-1,1]:
		var p := Vector2(side*40,40)
		disc(canvas,p,24,INK)
		disc(canvas,p,18,BRASS)
		disc(canvas,p,10,SHADE)
		for spoke: int in 4:
			var axis := Vector2.from_angle(wheel_angle+spoke*PI*.5)
			pixel_line(canvas,p+axis*6,p+axis*18,CREAM)
	var bob := 2*roundf((spring+sin(clock*3))/2)
	canvas.draw_set_transform(Vector2(0,bob))
	canvas.draw_rect(Rect2(-70,-4,140,22),INK)
	canvas.draw_rect(Rect2(-62,-8,124,16),BRASS)
	canvas.draw_rect(Rect2(-50,-62,100,56),INK)
	canvas.draw_rect(Rect2(-42,-58,84,46),CREAM if flash else SHADE)
	canvas.draw_rect(Rect2(-34,-72,68,12),BRASS)
	canvas.draw_rect(Rect2(-24,-80,48,8),CREAM)
	for x: int in [-30,30]:
		canvas.draw_rect(Rect2(x-4,-54,8,42),BRASS)
		canvas.draw_rect(Rect2(x-2,-52,2,36),CREAM)
	canvas.draw_rect(Rect2(-14,-56,28,44),INK)
	bell(canvas,Vector2(0,-34),false,flash)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_windkeeper(canvas: Node2D, encounter: Node, stride: float, speed: float, hurt: bool, old_phase: int = 1, form_blend: float = 1.0) -> void:
	var phase: int = encounter.stage_phase
	var raised := (encounter.definition as WindkeeperDefinition).platform_trials
	var old_top := -152.0 if raised and old_phase==3 else -106.0
	var new_top := -152.0 if raised and phase==3 else -106.0
	var top := 2*roundf(lerpf(old_top,new_top,smoothstep(0,1,form_blend))/2)
	var body_color := CREAM if hurt else MOSS
	# Four planted/swing legs, anchored at real standing floor y=65.
	for leg: int in 4:
		var phase_angle: float = stride+(PI if leg%2==0 else 0)
		var lift := 2*roundf(maxf(0,sin(phase_angle))*4) if absf(speed)>2 else 0.0
		var x := -60+leg*38
		canvas.draw_rect(Rect2(x-8,12,16,48-lift),INK)
		canvas.draw_rect(Rect2(x-4,14,6,36-lift),BRASS)
		canvas.draw_rect(Rect2(x-12,58-lift,28,8),INK)
		canvas.draw_rect(Rect2(x-12,58-lift,24,2),CREAM)
	var crouch := 4.0 if encounter.mode in [&"stomp_warning",&"charge_warning",&"pier_warning"] else 0.0
	canvas.draw_set_transform(Vector2(0,crouch))
	canvas.draw_rect(Rect2(-76,-60,152,80),INK)
	canvas.draw_rect(Rect2(-68,-56,136,62),body_color)
	canvas.draw_rect(Rect2(-62,-52,124,6),CREAM)
	canvas.draw_rect(Rect2(-62,-22,124,26),SHADE)
	for x: int in [-48,0,48]:
		canvas.draw_rect(Rect2(x-8,-50,16,48),INK)
		canvas.draw_rect(Rect2(x-4,-46,6,38),BRASS)
	# Distinct wind-bell tower head/neck instead of reused generic beetle.
	var face := float(encounter.direction)
	canvas.draw_rect(Rect2(face*48-14,top+18,28,-top-58),INK)
	canvas.draw_rect(Rect2(face*48-8,top+22,16,-top-64),BRASS)
	canvas.draw_rect(Rect2(face*48-28,top-6,56,32),INK)
	canvas.draw_rect(Rect2(face*48-22,top-2,44,24),body_color)
	canvas.draw_rect(Rect2(face*48+face*10-4,top+4,8,6),CREAM)
	canvas.draw_rect(Rect2(face*48-36,top+20,72,8),BRASS)
	canvas.draw_rect(Rect2(face*48-20,top-16,8,12),BRASS)
	canvas.draw_rect(Rect2(face*48+12,top-16,8,12),BRASS)
	canvas.draw_set_transform(Vector2.ZERO)
	# Core position is computed by encounter, never guessed from the silhouette.
	if not encounter.core_open:
		bell(canvas,encounter.core_offset(),false,hurt)

static func draw_rotor(canvas: Node2D, at: Vector2, angle: float) -> void:
	for i: int in 4:
		var axis := Vector2.from_angle(angle+i*PI*.5)
		pixel_line(canvas,at+axis*16,at+axis*94,INK,8)
		pixel_line(canvas,at+axis*24,at+axis*90,BRASS,4)
		pixel_line(canvas,at+axis*66,at+axis*90,CREAM,4)
	disc(canvas,at,14,INK)
	disc(canvas,at,8,CREAM)

static func icon_texture(kind: StringName) -> Texture2D:
	if _textures.has(kind): return _textures[kind]
	var rows: PackedStringArray
	match kind:
		&"coin": rows = ["..cccc..",".cbbbbc.","cbccbbbc","cbcbbcbc","cbcbbcbc","cbbccbbc",".cbbbbc.","..cccc.."]
		&"heart": rows = ["..rr...rr..",".rccr.rccr.","rccccrccccr","rcccccccccr",".rcccccccr.","..rcccccr..","...rcccr...","....rcr....",".....r....."]
		&"chest": rows = ["..bbbbbbbbbbbb..",".bccbbbbbbbbccb.","bccccccccccccccb","bsssssbbsssssccb","bsssssccsssssssb","bbbbbbccbbbbbbbb","bssssssssssssssb","bssssssssssssssb","bccccccccccccccb",".bbbbbbbbbbbbbb."]
		&"door": rows = ["......bbbbbb......","....bbccccccbb....","...bccssssssccb...","..bcissssssssicb..",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssccssssicb.",".bcissssbbssssicb.",".bcissssccssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.",".bcissssssssssicb.","bbbbbbbbbbbbbbbbbb","cccccccccccccccccc"]
		&"bell": rows = ["...bb...","..bccb..","..bccb..",".bccccb.",".bciicb.",".bciicb.",".bciicb.","bccccccb","bbbbbbbb","...cc..."]
		&"merchant": rows = ["........bbbb........","......bbccccbb......",".....bccccccccb.....","....bssssssssssb....","...bbbbbbbbbbbbbb...","......iiccii........","......iiccii........",".......brrb.........","....rrrbbbbrrrr......","...rrrsssssssrrr....","...rrsssssssssrr....","...rbsssssssssbrr...","....bcccccccccb.....","....bbbbbbbbbbb.....","...bbssbbsssssbb....","...bbssbbsssssbb....","...bbccbbcccccbb....","....bbbbbbbbbbb.....",".....ii...ii........","....iiii.iiii......."]
		_: rows = ["....cc..","....cb..","....cb..","....cb..","....cb..","....cb..",".ccccb..","cccccb..","ccccb...",".bbb...."]
	var width := 0
	for row: String in rows: width = maxi(width,row.length())
	var image := Image.create(width,rows.size(),false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors := {"i":INK,"s":SHADE,"m":MOSS,"b":BRASS,"c":CREAM,"r":ROSE}
	for y: int in rows.size():
		for x: int in rows[y].length():
			var key := rows[y].substr(x,1)
			if colors.has(key): image.set_pixel(x,y,colors[key])
	var texture := ImageTexture.create_from_image(image)
	_textures[kind] = texture
	return texture

static func pixel_context(node: Node) -> bool:
	var parent: Node = node
	while parent != null:
		if parent.get_meta("pixel_formal_style",false): return true
		parent = parent.get_parent()
	return false

static func projectile(canvas: Node2D, radius: float, direction: Vector2, lob: bool = false) -> void:
	# Pixel disc covers the real damaging circle, including its extreme tips.
	var extent := maxf(4,ceilf(radius/2)*2)
	disc(canvas,Vector2.ZERO,extent,INK)
	disc(canvas,Vector2.ZERO,maxf(2,extent-2),ROSE)
	canvas.draw_rect(Rect2(-2,-extent,4,extent*2),CREAM)
	canvas.draw_rect(Rect2(-extent,-2,extent*2,4),CREAM)
	if lob: bell(canvas,Vector2.ZERO,true)
	else: pixel_line(canvas,-direction*(extent+4),-direction*(extent+12),Color(ROSE,.6))


static func gate(canvas: Node2D, rect: Rect2, opacity: float) -> void:
	canvas.draw_rect(rect,Color(INK,opacity))
	var inset := minf(4,rect.size.x*.25)
	canvas.draw_rect(Rect2(rect.position+Vector2(inset,0),rect.size-Vector2(inset*2,0)),Color(BRASS,opacity))
	canvas.draw_rect(Rect2(rect.position+Vector2(inset,0),Vector2(2,rect.size.y)),Color(CREAM,opacity))
	for y: float in [rect.position.y,rect.end.y-minf(6,rect.size.y*.5)]:
		canvas.draw_rect(Rect2(rect.position.x,y,rect.size.x,minf(6,rect.size.y*.5)),Color(CREAM,opacity))

static func sigil(canvas: Node2D, at: Vector2, index: int, size: float) -> void:
	var radius := floorf(size*.3/2)*2
	var color := CREAM
	match posmod(index,4):
		0:
			for i: int in 4:
				var a := Vector2.from_angle(i*PI*.5)*radius
				var b := Vector2.from_angle((i+1)*PI*.5)*radius
				pixel_line(canvas,at+a,at+b,color)
		1:
			pixel_line(canvas,at-Vector2(radius,radius),at+Vector2(radius,radius),color)
			pixel_line(canvas,at+Vector2(radius,-radius),at+Vector2(-radius,radius),color)
		2:
			for x: int in [-1,0,1]: pixel_line(canvas,at+Vector2(x*6,-radius),at+Vector2(x*6,radius),color)
		3:
			pixel_line(canvas,at-Vector2(radius,0),at-Vector2(0,radius),color)
			pixel_line(canvas,at-Vector2(0,radius),at+Vector2(radius,0),color)
			pixel_line(canvas,at+Vector2(radius,0),at-Vector2(radius,0),color)
