class_name ModuleMovingPlatform
extends AnimatableBody2D

var definition: ModuleMovingPlatformDefinition
var module: PlatformingModule
var bell_controlled := false
var motion_running := true
var motion_clock := 0.0
var painted_art: Node2D
var pixel_art_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -100
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = false
	position = definition.at_time(module.clock)
	sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = definition.size
	shape.shape = rectangle
	add_child(shape)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# CharacterBody2D consumes the engine's platform velocity in Motor.step.
	# Never translate the player or perform a second move_and_slide here.
	if bell_controlled:
		if motion_running: motion_clock += _delta
		position = definition.at_time(motion_clock)
	else: position = definition.at_time(module.clock)

func _draw() -> void:
	if pixel_art_enabled and (not is_instance_valid(painted_art) or not painted_art.visible):
		if UnderworldActors.enabled(self): UnderworldTerrain.draw_moving(self, Rect2(-definition.size / 2.0, definition.size))
		else: PixelFormalTerrain.draw_moving(self, Rect2(-definition.size / 2.0, definition.size))
	elif not pixel_art_enabled and (not is_instance_valid(painted_art) or not painted_art.visible):
		PlainsTerrainSkin.draw_moving_platform(self, Rect2(-definition.size / 2.0, definition.size))

func bind_bell_control() -> void:
	bell_controlled=true
	motion_clock=module.clock
	motion_running=false
func set_motion_running(value:bool)->void:
	motion_running=value

func restore_motion(clock:float,running:bool)->void:
	motion_clock=clock
	motion_running=running
	# Loading a saved platform while paused must show its true phase immediately.
	sync_to_physics=false
	position=definition.at_time(motion_clock)
	sync_to_physics=true

# Style toggles do not create bodies, move carriers, or alter animation phases.
func set_painted_enabled(value: bool) -> void:
	pixel_art_enabled = value
	# Existing presentation instances can survive style installation or reload.
	# A current Underworld carrier must never keep an old painted material overlay.
	if value and UnderworldActors.enabled(self) and is_instance_valid(painted_art) and not painted_art is UnderworldCarrierPaint:
		remove_child(painted_art)
		painted_art.queue_free()
		painted_art = null
	if value and not is_instance_valid(painted_art):
		painted_art = UnderworldCarrierPaint.new() if UnderworldActors.enabled(self) else PixelFormalTerrain.build_moving(Rect2(-definition.size / 2.0, definition.size))
		if painted_art is UnderworldCarrierPaint:
			(painted_art as UnderworldCarrierPaint).bounds=Rect2(-definition.size / 2.0, definition.size)
			painted_art.name="UnderworldCarrierMaterial"
			painted_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			painted_art.set_meta("material_source","res://assets/underworld_plains/mechanisms/carrier.png")
		add_child(painted_art)
	if is_instance_valid(painted_art): painted_art.visible = value
	queue_redraw()

class UnderworldCarrierPaint extends Node2D:
	var bounds: Rect2
	func _draw() -> void:
		UnderworldTerrain.draw_moving(self,bounds)
