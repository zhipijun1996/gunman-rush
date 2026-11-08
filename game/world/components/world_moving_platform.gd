class_name WorldMovingPlatform
extends ModuleMovingPlatform
## A real physics carrier. CharacterBody2D owns rider velocity and movement.
@export var endpoint := Vector2(384,0)
@export var platform_size := Vector2(128,24)
@export var period := 5.0
@export var phase_offset := 0.0
@export var one_way := false
## Optional ordered offsets for a guided cage; ordinary shuttles keep endpoint.
@export var route: Array[Vector2] = []
var origin := Vector2.ZERO
var route_length := 0.0
func _ready() -> void:
	origin=position;motion_clock=phase_offset
	var previous:=Vector2.ZERO
	for point: Vector2 in route:
		route_length+=previous.distance_to(point);previous=point
	if not route.is_empty():
		var points:=PackedVector2Array([Vector2.ZERO])
		points.append_array(route)
		for index: int in 2:
			var rail:=Line2D.new()
			rail.top_level=true;rail.points=points;rail.width=6 if index==0 else 2
			rail.default_color=Color("222d2b") if index==0 else Color("857349")
			rail.z_index=-3;add_child(rail);rail.global_position=global_position
	process_physics_priority=-100
	collision_layer=1;collision_mask=0
	var collision:=CollisionShape2D.new();collision.name="CollisionShape2D";var shape:=RectangleShape2D.new();shape.size=platform_size;collision.shape=shape;collision.one_way_collision=one_way;add_child(collision)
	if one_way:add_to_group("one_way_platform")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _physics_process(delta: float) -> void:
	if motion_running:motion_clock+=delta
	position=sample_position(motion_clock)
func sample_position(clock: float) -> Vector2:
	if route.is_empty() or route_length<=0:
		return origin+endpoint*(.5-.5*cos(TAU*clock/period))
	var phase:=fposmod(clock/period,1.0)
	var remaining: float=(phase*2 if phase<.5 else (1-phase)*2)*route_length
	var previous:=Vector2.ZERO
	for point: Vector2 in route:
		var length:=previous.distance_to(point)
		if remaining<=length and length>0:
			# Each corner comes to rest before changing axis, so riders do not
			# inherit an instantaneous sideways velocity from a vertical rail.
			return origin+previous.lerp(point,.5-.5*cos(PI*remaining/length))
		remaining-=length;previous=point
	return origin+route[-1]
func bind_bell_control() -> void:
	bell_controlled=true;motion_running=false
func restore_motion(clock: float,running: bool) -> void:
	motion_clock=clock;motion_running=running
	sync_to_physics=false
	position=sample_position(motion_clock)
	sync_to_physics=true
func _draw() -> void:
	UnderworldTerrain.draw_moving(self,Rect2(-platform_size/2,platform_size))
