class_name WorldNpc
extends Node2D
## A stable placement and visual only. Services own dialogue conditions and results.
@export var npc_id := ""
@export var visual_kind := "artisan"
@export var display_name := ""
func _ready() -> void:
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UnderworldHomeWorld.BUILD_PATH))
	var asset: Dictionary=spec.assets[visual_kind]
	var sprite:=Sprite2D.new()
	var atlas:=AtlasTexture.new()
	atlas.atlas=load(str(asset.image)) as Texture2D
	atlas.region=FixedWorldProvider.rect(asset.region)
	sprite.texture=atlas
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.centered=false
	sprite.scale=Vector2.ONE*UnderworldActors.HUMANOID_HEIGHT/float(asset.opaque_height)
	sprite.position=Vector2(0,18)-FixedWorldProvider.point(asset.foot)*sprite.scale
var highlighted:=false:
	set(value):
		if highlighted==value: return
		highlighted=value;queue_redraw()
func _draw() -> void:
	if highlighted:
		draw_line(Vector2(-5,-55),Vector2(0,-61),DemoClockworkTheme.TEAL,2)
		draw_line(Vector2(0,-61),Vector2(5,-55),DemoClockworkTheme.TEAL,2)
