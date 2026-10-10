class_name ModuleMovingPlatform
extends AnimatableBody2D

var definition: ModuleMovingPlatformDefinition
var module: PlatformingModule

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -100
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	position = definition.at_time(module.clock)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = definition.size
	shape.shape = rectangle
	add_child(shape)
	queue_redraw()

func _physics_process(_delta: float) -> void:
	# CharacterBody2D consumes the engine's platform velocity in Motor.step.
	# Never translate the player or perform a second move_and_slide here.
	position = definition.at_time(module.clock)

func _draw() -> void:
	PlainsTerrainSkin.draw_moving_platform(self, Rect2(-definition.size / 2.0, definition.size))
