class_name EnemyFeedback01Body
extends Node2D
## Body-only flash: health marks, telegraphs and debris retain their own palette.
var source: Texture2D
var destination := Rect2()
var body_tint := Color.WHITE
var flash_material := ShaderMaterial.new()
var body_motion: PlainsMotion02
var body_actor: EnemyActor

func _init() -> void:
	flash_material.shader = preload("res://scripts/enemies/enemy_feedback_01_flash.gdshader")
	material = flash_material
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func configure_underworld_palette(aerial: bool) -> void:
	flash_material.set_shader_parameter("readable_material", 1.0)
	flash_material.set_shader_parameter("copper_wings", 1.0 if aerial else 0.0)

func configure_motion(motion: PlainsMotion02, owner_actor: EnemyActor) -> void:
	body_motion = motion
	body_actor = owner_actor

func present(texture: Texture2D, bounds: Rect2, offset: Vector2, angle: float, pose: Vector2, tint: Color, flash: float) -> void:
	source = texture
	destination = bounds
	position = offset
	rotation = angle
	scale = pose
	body_tint = tint
	flash_material.set_shader_parameter("hit_flash", flash)
	# AtlasTexture uses UVs in the underlying complete atlas, not 0..1 per cell.
	var uv_rect := Vector4(0, 0, 1, 1)
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		var atlas_size := atlas.atlas.get_size()
		uv_rect = Vector4(atlas.region.position.x/atlas_size.x, atlas.region.position.y/atlas_size.y, atlas.region.size.x/atlas_size.x, atlas.region.size.y/atlas_size.y)
	flash_material.set_shader_parameter("frame_uv_rect", uv_rect)
	flash_material.set_shader_parameter("authored_palette", 1.0 if texture is AtlasTexture else 0.0)
	queue_redraw()

func _draw() -> void:
	if source == null: return
	if body_motion != null and is_instance_valid(body_actor):
		body_motion.draw_body(self, body_actor, source, destination, body_tint)
	else:
		draw_texture_rect(source, destination, false, body_tint)
