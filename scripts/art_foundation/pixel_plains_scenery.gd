class_name PixelPlainsScenery
extends WindchimeScenery
## Pixel bell-harp and grounded accents; the structure is a decorative socket.
var effects_enabled := true
var light_enabled := true
var _phase := 0.0

func _ready() -> void:
	z_index=0

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	var ink := Color("111e2b")
	var stone := Color("365a59")
	var brass := Color("a66d45")
	var light := Color("ead39a")
	# The focal wind instrument is grounded on the right ledge at y480.
	draw_rect(Rect2(944,200,12,280),ink)
	draw_rect(Rect2(948,204,4,276),stone)
	draw_rect(Rect2(932,196,196,10),ink)
	draw_rect(Rect2(936,196,188,2),Color("6e9180"))
	# Weathered timber joints and one lit side; no clean uniform pole silhouette.
	draw_rect(Rect2(944,206,2,270),Color("6e9180"))
	for p: Vector2 in [Vector2(948,218),Vector2(950,252),Vector2(946,306),Vector2(950,344),Vector2(948,414)]:
		draw_rect(Rect2(p,Vector2(2,16)),Color("a66d45"))
		draw_rect(Rect2(p+Vector2(2,4),Vector2(2,6)),Color("203b46"))
	for y: int in [210,218,438,446]:
		draw_rect(Rect2(942,y,16,4),brass)
		draw_rect(Rect2(946,y,4,2),light)
	for x: int in [956,984,1028,1064,1108]:
		draw_rect(Rect2(x,200,12,2),Color("365a59"))
		draw_rect(Rect2(x+4,204,6,2),Color("6e9180"))
	draw_rect(Rect2(946,198,14,14),brass)
	draw_rect(Rect2(950,200,4,4),light)
	draw_rect(Rect2(1118,198,6,6),Color("365a59"))
	for i: int in 20:
		draw_rect(Rect2(950+i*2,242-i*2,4,4),stone)
	# A restrained woven cloth and engraved ring, not a row of repeated flags.
	draw_rect(Rect2(916,208,22,92),Color("6e9180"))
	draw_rect(Rect2(920,212,14,78),Color("b0b97b"))
	draw_rect(Rect2(922,222,10,2),light)
	draw_rect(Rect2(926,218,2,30),Color("a66d45"))
	for i: int in 3:
		var x := 1008.0+i*38
		var shift := 2.0*roundf(sin(_phase*1.3+i*.5)) if effects_enabled else 0.0
		var length: float = [100.0,142.0,116.0][i]
		draw_rect(Rect2(x,206,2,38),brass)
		draw_rect(Rect2(x-4+shift,244,10,length-38),brass)
		draw_rect(Rect2(x-2+shift,246,2,length-44),light)
		draw_rect(Rect2(x-6+shift,242,14,4),Color("b47c64"))
		draw_rect(Rect2(x+2+shift,248,2,length-46),Color("6e9180"))
		draw_rect(Rect2(x-4+shift,244+length-42,10,4),Color("203b46"))
		for y: float in [268,294,316]:
			if y<244+length-46:draw_rect(Rect2(x+shift,y,4,4),Color("365a59"))
	var ring := Vector2(1046,386)
	for i: int in 32:
		var p := (ring+Vector2(cos(i*TAU/32),sin(i*TAU/32))*14).snapped(Vector2(2,2))
		draw_rect(Rect2(p,Vector2(4,4)),brass)
		if i>16 and i<28:draw_rect(Rect2(p+Vector2(0,-2),Vector2(2,2)),light)
	draw_rect(Rect2(1046,206,2,166),brass)
	# Small local halo, deliberately confined to the focal instrument.
	if light_enabled:
		for i: int in range(4,0,-1):
			var r := float(i*8)
			draw_rect(Rect2(ring-Vector2(r,r),Vector2(r*2,r*2)),Color(.91,.75,.42,.013))
	# Short stone incision. Its rhythm is authored across cells, not tiled.
	for p: Vector2 in [Vector2(42,544),Vector2(68,548),Vector2(96,546),Vector2(128,548),Vector2(158,542),Vector2(194,542),Vector2(226,538),Vector2(250,540)]:
		draw_rect(Rect2(p,Vector2(22,2)),Color("365a59"))
	for x: int in range(452,704,36):
		draw_rect(Rect2(x,566+(x/36)%3*2,24,2),Color("365a59"))
	# A few mineral/lichen clusters follow the lower face, below walkable edges.
	for p: Vector2 in [Vector2(30,592),Vector2(250,630),Vector2(428,564),Vector2(752,588),Vector2(1170,548),Vector2(1224,642)]:
		draw_rect(Rect2(p,Vector2(8,4)),Color("6e9180"))
		draw_rect(Rect2(p+Vector2(6,-4),Vector2(4,4)),Color("365a59"))
	if effects_enabled:
		for i: int in 12:
			var p := Vector2(fposmod(i*109+_phase*9,1280),170+i%5*39+sin(_phase*.6+i)*6).snapped(Vector2(2,2))
			draw_rect(Rect2(p,Vector2(2,2)),Color(.79,.77,.52,.35))
