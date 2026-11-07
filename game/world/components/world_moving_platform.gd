class_name WorldMovingPlatform
extends ModuleMovingPlatform
## A real physics carrier. CharacterBody2D owns rider velocity and movement.
@export var endpoint := Vector2(384,0)
@export var platform_size := Vector2(128,24)
@export var period := 5.0
@export var phase_offset := 0.0
@export var one_way := false
var origin := Vector2.ZERO
func _ready() -> void:
	origin=position;motion_clock=phase_offset
	process_physics_priority=-100
	collision_layer=1;collision_mask=0
	var collision:=CollisionShape2D.new();collision.name="CollisionShape2D";var shape:=RectangleShape2D.new();shape.size=platform_size;collision.shape=shape;collision.one_way_collision=one_way;add_child(collision)
	if one_way:add_to_group("one_way_platform")
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _physics_process(delta: float) -> void:
	if motion_running:motion_clock+=delta
	var t:=.5-.5*cos(TAU*motion_clock/period)
	position=origin+endpoint*t
func bind_bell_control() -> void:
	bell_controlled=true;motion_running=false
func restore_motion(clock: float,running: bool) -> void:
	motion_clock=clock;motion_running=running
	sync_to_physics=false
	position=origin+endpoint*(.5-.5*cos(TAU*motion_clock/period))
	sync_to_physics=true
func _draw() -> void:
	UnderworldTerrain.draw_moving(self,Rect2(-platform_size/2,platform_size))
