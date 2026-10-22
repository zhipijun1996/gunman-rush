class_name EnemyFeedback01Body
extends Node2D
## Body-only flash: health marks, telegraphs and debris retain their own palette.
var source: Texture2D
var destination := Rect2()
var body_tint := Color.WHITE
var flash_material := ShaderMaterial.new()

func _init() -> void:
	flash_material.shader = preload("res://scripts/enemies/enemy_feedback_01_flash.gdshader")
	material = flash_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func configure_underworld_palette(aerial: bool) -> void:
	flash_material.set_shader_parameter("readable_material", 1.0)
	flash_material.set_shader_parameter("copper_wings", 1.0 if aerial else 0.0)

func present(texture: Texture2D, bounds: Rect2, offset: Vector2, angle: float, pose: Vector2, tint: Color, flash: float) -> void:
	source = texture
	destination = bounds
	position = offset
	rotation = angle
	scale = pose
	body_tint = tint
	flash_material.set_shader_parameter("hit_flash", flash)
	queue_redraw()

func _draw() -> void:
	if source != null: draw_texture_rect(source, destination, false, body_tint)
