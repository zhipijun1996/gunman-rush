class_name TraversalMechanismArt
extends RefCounted
## Shared, native-pixel movement hardware. Regional construction is drawn behind its action surfaces.
static var FUNGUS := load("res://assets/world_traversal/native/fungus_bumper.png") as Texture2D
static var BUBBLE := load("res://assets/world_traversal/native/bubble_membrane.png") as Texture2D
static var CAP := load("res://assets/world_traversal/native/portal_claw.png") as Texture2D
static var EMITTER := load("res://assets/world_traversal/native/pulse_diaphragm.png") as Texture2D
static var SPRING := load("res://assets/world_traversal/native/spring_plate.png") as Texture2D
static var WHEEL := load("res://assets/world_traversal/native/roller.png") as Texture2D
static var RESIN := load("res://assets/world_traversal/native/resin_edge.png") as Texture2D
static var ICE := load("res://assets/world_traversal/native/ice_edge.png") as Texture2D

static var FOAM := load("res://assets/world_traversal/native/water_foam.png") as Texture2D
static var GAS := load("res://assets/world_traversal/native/gas_wisp.png") as Texture2D
static var WIND := load("res://assets/world_traversal/native/wind_ribbon.png") as Texture2D
static var PHASE := load("res://assets/world_traversal/native/phase_thread.png") as Texture2D

static func sprite(canvas: CanvasItem, texture: Texture2D, center: Vector2, size: Vector2, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect(texture, Rect2((center-size*.5).round(),size.round().max(Vector2.ONE)),false,tint)

static func chain(canvas: CanvasItem, a: Vector2, b: Vector2, width := 3.0, tint := Color("b3a481")) -> void:
	var normal := (b-a).normalized().orthogonal()
	canvas.draw_line(a.round(),b.round(),Color("27282a"),width)
	canvas.draw_line((a+normal).round(),(b+normal).round(),tint.darkened(.28),1)
	var count := ceili(a.distance_to(b)/7)
	for i: int in count:
		var t := (i+.5)/maxf(1,count)
		var at := a.lerp(b,t)
		canvas.draw_line((at-normal).round(),(at+normal).round(),tint,2)

static func wheel(canvas: CanvasItem, center: Vector2, diameter: float, turn: float, tint := Color.WHITE) -> void:
	canvas.draw_set_transform(center.round(),turn)
	sprite(canvas,WHEEL,Vector2.ZERO,Vector2.ONE*diameter,tint)
	canvas.draw_set_transform(Vector2.ZERO,0)
