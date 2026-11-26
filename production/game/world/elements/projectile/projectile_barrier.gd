class_name ProjectileBarrier
extends ProjectileField
@export var element_id := ""
@export var section_id := "main"
@export var state_scope := "attempt"
@export var line_points: Array[Vector2] = [Vector2(0,-80),Vector2(0,80)]
@export var thickness := 12.0
@export var factions: Array[String] = ["player","enemy"]
@export var initial_active := true
var active := true
var spark := Vector2.ZERO
var flash := 0.0

func _ready() -> void:
	active = initial_active

func contact(at: Vector2, motion: Vector2, radius: float, faction: String, _elapsed: float, _step: float, _delta: float) -> Dictionary:
	if not active or faction not in factions: return {}
	var local := to_local(at)
	var vector := to_local(at+motion)-local
	var axis := line_points[0].direction_to(line_points[1])
	var size := line_points[0].distance_to(line_points[1])
	var relative := local-line_points[0]
	var p := Vector2(relative.dot(axis),relative.dot(axis.orthogonal()))
	var v := Vector2(vector.dot(axis),vector.dot(axis.orthogonal()))
	var rect := Rect2(0,-thickness/2,size,thickness)
	var t := INF
	# Minkowski sum of a disk and a rectangle, including the four round corners.
	for expanded: Rect2 in [rect.grow_individual(radius,0,radius,0),rect.grow_individual(0,radius,0,radius)]:
		var interval := ProjectileFlight.slab(p,v,expanded)
		if interval.y >= 0 and interval.y >= interval.x: t = minf(t,maxf(0,interval.x))
	for corner: Vector2 in [rect.position,rect.end,Vector2(0,rect.end.y),Vector2(size,rect.position.y)]:
		if p.distance_to(corner) <= radius: t = 0
		elif not v.is_zero_approx():
			var hit := Geometry2D.segment_intersects_circle(p,p+v,corner,radius)
			if hit >= 0: t = minf(t,hit)
	return {"t":t,"priority":0,"kind":"barrier"} if t<=1.0 else {}

func dissipate(point: Vector2) -> void:
	spark = to_local(point)
	flash = 0.12
	queue_redraw()

func _process(delta: float) -> void:
	if flash > 0:
		flash = maxf(0,flash-delta)
		queue_redraw()

func element_state() -> Dictionary: return {"active":active}
func element_can_receive(input: String, value: Variant) -> bool: return input=="set_active" and value is bool
func element_propose(_input: String, value: bool) -> Dictionary: return {"active":value}
func element_restore(data: Dictionary) -> void:
	var activating := not active and bool(data.active)
	active = data.active
	if activating and is_inside_tree():
		for faction: String in factions:
			for projectile: Node2D in get_tree().get_nodes_in_group("ordinary_flight_"+faction):
				if not projectile.spent and ProjectileField.domain_for(projectile)==domain:
					consume_inside(projectile,faction)
	queue_redraw()

func consume_inside(projectile: Node2D,faction: String) -> bool:
	if not contact(projectile.global_position,Vector2.ZERO,projectile.radius,faction,0,0,1).is_empty():
		dissipate(projectile.global_position)
		projectile.dispose()
		return true
	return false

func _draw() -> void:
	var normal := line_points[0].direction_to(line_points[1]).orthogonal()*thickness/2
	if active:
		draw_colored_polygon(PackedVector2Array([line_points[0]+normal,line_points[1]+normal,line_points[1]-normal,line_points[0]-normal]),Color("8fcfe790"))
	for d: float in [-1.,1.]:
		draw_line(line_points[0]+normal*d,line_points[1]+normal*d,Color("99c5cd") if active else Color("61747e"),1.5)
	if flash>0: draw_circle(spark,2+(0.12-flash)*65,Color.WHITE,false,1)
