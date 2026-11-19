class_name WorldProps
extends RefCounted
## Existing authored textures, uniformly scaled; gameplay owns every trigger.
static func draw_icon(canvas: Node2D,texture: Texture2D,foot: Vector2,height: float) -> void:
	var size:=texture.get_size()*height/texture.get_height()
	canvas.draw_texture_rect(texture,Rect2(foot+Vector2(-size.x/2,18-size.y),size),false)
static var _props: Dictionary={}
static func prop(id: String) -> Texture2D:
	if not _props.has(id):
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world_interactions/manifest.json"))
		var atlas:=AtlasTexture.new()
		atlas.atlas=load("res://"+str(data.source))
		atlas.region=FixedWorldProvider.rect(data.regions[id])
		atlas.filter_clip=true
		_props[id]=atlas
	return _props[id]
static func draw_thorns(canvas: Node2D,bounds: Rect2) -> void:
	var texture:=preload("res://assets/forest_bible_v2/native/fine_32/thorn_briar_atlas.png")
	# Native up-facing strip, clipped horizontally rather than stretched.
	var x:=bounds.position.x
	while x<bounds.end.x:
		var width:=minf(128,bounds.end.x-x)
		canvas.draw_texture_rect_region(texture,Rect2(x,bounds.position.y,width,24),Rect2(0,0,width,24))
		x+=width
