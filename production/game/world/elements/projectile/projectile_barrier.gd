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
var field_age := 0.0

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
	field_age = fmod(field_age+delta,TAU)
	if active or flash>0:
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
	var axis := line_points[0].direction_to(line_points[1])
	var span := line_points[0].distance_to(line_points[1])
	var orientation := axis.angle()-PI/2
	draw_set_transform(line_points[0],orientation)
	if active:
		var light := Color("c4eaff").lerp(MechanismRegionArt.accent(self),.55)
		var tint := Color(light,.84+.1*sin(field_age*4))
		ProjectileMechanismArt.beam(self,Rect2(-thickness/2,0,thickness,span),ProjectileMechanismArt.VEIL,8,true,tint)
	for side: float in [-1.,1.]:
		var rim := side*thickness/2
		draw_dashed_line(Vector2(rim,2),Vector2(rim,maxf(2,span-2)),Color("9fcbd45c") if active else Color("78939453"),1,5)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for i: int in 2:
		var point := line_points[i]
		var inward := axis if i==0 else -axis
		MechanismRegionArt.stamp(self,"finial",point,Vector2(21,22),Color.WHITE if active else Color("89909a"))
		draw_set_transform(point,inward.angle())
		ProjectileMechanismArt.paint(self,Rect2(-11,-5,19,10),ProjectileMechanismArt.LENS,Color.WHITE if active else Color("616473"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if flash>0:
		PixelVfx.clip(self,&"spark",spark,1-flash/.12,orientation,Color("a6e6ff"),Vector2.ONE*.48)
