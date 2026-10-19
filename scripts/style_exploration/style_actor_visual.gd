class_name StyleActorVisual
extends Node2D
## Presentation only. PlayerMotor retains all movement, collisions and accepted actions.
const ROOT := "res://assets/style_exploration/"
var motor: PlayerMotor
var controller: PlayerController
var style_id := "retro"
var _body: Sprite2D
var _hand: Sprite2D
var _gun: Sprite2D
var _atlas: AtlasTexture
var _clock := 0.0
var _facing := 1.0
var _generated := false
var _native_size := Vector2.ONE * 16
var _foot := Vector2(8, 16)
var _height := 34.0
var _temporary := false

func configure(value: String) -> void:
	style_id = value
	for child: Node in get_children(): child.free()
	_hand = null
	_gun = null
	_atlas = null
	_generated = false
	_temporary = false
	_height = 34
	_native_size = Vector2.ONE * 16
	_foot = Vector2(8, 16)
	_body = Sprite2D.new()
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if value != "scribble" else CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_body)
	if _load_generated(): return
	var file := ""
	var region := Rect2()
	match value:
		"retro": file = "Player.png"; region = Rect2(0, 32, 16, 16)
		"basic":
			# Reference-pack mushroom mascot, not a claim of final protagonist design.
			file = "sTileset.png"; region = Rect2(0, 128, 16, 16)
		"scribble":
			file = "character_roundPurple.png"; _native_size = Vector2(64, 64); _foot = Vector2(32, 62)
		_:
			# Explicit temporary neutral courier while new style-specific art is pending.
			_temporary = true
			set_meta("visual_status", "temporary_silhouette_missing_pack_player")
			_body.hide()
			queue_redraw()
			return
	var source := load(ROOT + value + "/original/" + file) as Texture2D
	if region.size != Vector2.ZERO:
		_atlas = AtlasTexture.new()
		_atlas.atlas = source
		_atlas.region = region
		_atlas.filter_clip = true
		_body.texture = _atlas
	else: _body.texture = source
	set_meta("visual_status", "native_reference_pack_mascot")
	if value == "scribble":
		_hand = Sprite2D.new()
		_hand.texture = load(ROOT + value + "/original/character_handPurple.png") as Texture2D
		_hand.scale = Vector2.ONE * 0.2
		add_child(_hand)
	_apply_frame(false)
	queue_redraw()

func _load_generated() -> bool:
	var path := ROOT + style_id + "/player.png"
	if not ResourceLoader.exists(path): return false
	var texture := load(path) as Texture2D
	_native_size = texture.get_size()
	_foot = Vector2(_native_size.x * 0.5, _native_size.y)
	var metadata_path := ROOT + style_id + "/player.json"
	if FileAccess.file_exists(metadata_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if data is Dictionary:
			if data.has("region"):
				var r: Array = data.region
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(r[0], r[1], r[2], r[3])
				atlas.filter_clip = true
				texture = atlas
				_native_size = Vector2(r[2], r[3])
			if data.has("foot"): _foot = Vector2(data.foot[0], data.foot[1])
			_height = float(data.get("world_height", 38))
	_body.texture = texture
	_generated = true
	set_meta("visual_status", "generated_experimental_player")
	_apply_frame(false)
	return true

func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(motor): return
	var walking := absf(motor.velocity.x) > 12.0 and motor.is_on_floor()
	if absf(motor.velocity.x) > 4.0: _facing = signf(motor.velocity.x)
	if is_instance_valid(controller) and controller.router.aim_engaged and absf(controller.router.aim_direction.x) > 0.15:
		_facing = signf(controller.router.aim_direction.x)
	if _temporary:
		queue_redraw()
		return
	if style_id == "retro" and _atlas != null:
		var frame := int(_clock * 10) % 4 if walking else 0
		var row := 16 if walking else 32
		if not motor.is_on_floor(): row = 64; frame = 0
		_atlas.region = Rect2(frame * 16, row, 16, 16)
	_apply_frame(walking)

func _apply_frame(walking: bool) -> void:
	if not is_instance_valid(_body): return
	var ratio := _height / _native_size.y
	var bounce := sin(_clock * 13) * 0.8 if walking else sin(_clock * 2) * 0.3
	_body.scale = Vector2(_facing * ratio, ratio)
	_body.position = Vector2(-_foot.x * ratio * _facing, 20 - _foot.y * ratio + bounce)
	if _hand != null:
		_hand.position = Vector2(13 * _facing, 4 + bounce)
		_hand.rotation = sin(_clock * 11) * 0.12 if walking else 0.0

func _draw() -> void:
	if not _temporary: return
	# Limited, explicitly labelled fallback. It does not stand in for finished source art.
	var ink := Color("c9e4c3") if style_id == "underworld" else Color("e2cee1")
	draw_circle(Vector2(0, -9), 8, ink)
	draw_style_box(_fallback_coat(ink.darkened(0.22)), Rect2(-9, -2, 18, 20))
	draw_line(Vector2(-5, 17), Vector2(-6, 20), ink, 4)
	draw_line(Vector2(5, 17), Vector2(6, 20), ink, 4)
	draw_circle(Vector2(_facing * 3, -10), 1.7, Color("283239"))

func _fallback_coat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	return box
