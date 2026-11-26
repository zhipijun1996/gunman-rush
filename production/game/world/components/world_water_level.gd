class_name WorldWaterLevel
extends Node2D

@export var element_id := ""
@export_enum("attempt") var state_scope := "attempt"
@export var section_id := "main"
@export var bounds := Rect2(0,0,320,192)
@export var low_surface_y := 160.0
@export var high_surface_y := 32.0
@export var surface_speed := 48.0
@export_enum("low","high") var initial_level := "low"
var high := false
var level := 160.0
var actual_surface_y: float:
	get: return bounds.position.y+level
var volume: WorldEnvironmentZone

func _ready() -> void:
	position = bounds.position
	high = initial_level == "high"
	level = high_surface_y if high else low_surface_y
	process_physics_priority = -150

func element_bind(context: Dictionary) -> void:
	volume = WorldEnvironmentZone.new()
	volume.mode = "water"
	volume.show_behind_parent = true
	volume.services = context.room.services
	volume.controller = context.controller
	volume.policy = context.policy
	volume.lifetime = context.lifetime
	add_child(volume)
	# The environment consumer expects coordinates in the room frame.
	volume.position = -position
	refresh_volume()

func refresh_volume() -> void:
	if volume == null: return
	volume.bounds = Rect2(bounds.position.x,actual_surface_y,bounds.size.x,bounds.size.y-level)
	volume.visible = volume.bounds.has_area()
	volume.set_physics_process(volume.visible)
	volume.queue_redraw()
	queue_redraw()

func _draw() -> void:
	# Wet masonry and the level gauge are fixed to the basin, behind the water.
	var size := bounds.size
	var rim := minf(8.0,size.x*.08)
	for x: float in [0.0,size.x-rim]:
		MechanismRegionArt.panel(self,Rect2(x,0,rim,size.y))
	MechanismRegionArt.panel(self,Rect2(0,size.y-minf(7.0,size.y),size.x,minf(7.0,size.y)))
	if size.x<36: return
	var gauge := Vector2(size.x-rim-11,0)
	draw_rect(Rect2(gauge,Vector2(5,size.y)),Color("#444747"))
	for y: int in range(3,int(size.y),8):
		var width := 7 if (y-3)%32==0 else 4
		draw_rect(Rect2(gauge+Vector2(0,y),Vector2(width,1)),Color("#b6af88"))
	var marker := gauge+Vector2(0,level)
	draw_colored_polygon(PackedVector2Array([marker,marker+Vector2(-6,-3),marker+Vector2(-6,3)]),MechanismRegionArt.accent(self))


func _physics_process(delta: float) -> void:
	var next := move_toward(level,high_surface_y if high else low_surface_y,surface_speed*delta)
	if next != level:
		level = next
		refresh_volume()

func element_state() -> Dictionary:
	return {"high":high,"level":level}

func element_can_receive(input: String,value: Variant) -> bool:
	return input == "set_active" and value is bool

func element_propose(_input: String,value: bool) -> Dictionary:
	return {"high":value,"level":level}

func element_restore(data: Dictionary) -> void:
	high = data.high
	level = clampf(data.level,high_surface_y,low_surface_y)
	refresh_volume()
