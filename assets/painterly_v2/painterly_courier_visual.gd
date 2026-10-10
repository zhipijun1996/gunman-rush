class_name PainterlyCourierVisual
extends CourierVisual
## Painted atlas candidate. Cosmetic only; body sprites currently include the gun.
## Keep old vector visual as live-game fallback until visual/aim acceptance.
const CATALOG_PATH := "res://assets/painterly_v2/manifest.json"
var _painted: Sprite2D
var _frames: Array = []
var _textures: Dictionary = {}
var _source_scale: float = 1.0

func _ready() -> void:
	for old_layer: CanvasItem in [body, scarf, left_leg, right_leg, arm]:
		old_layer.visible = false
	var text: String = FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Invalid painterly catalog")
		return
	var data: Dictionary = parsed
	_frames = data.get("frames", [])
	_source_scale = 104.0 / float(data.get("source_character_height", 104.0))
	_painted = Sprite2D.new()
	_painted.name = "PaintedFrame"
	_painted.centered = false
	_painted.region_enabled = true
	add_child(_painted)
	for frame: Dictionary in _frames:
		var path: String = "res://" + str(frame.path)
		if not _textures.has(path):
			_textures[path] = load(path) as Texture2D
	_apply_frame()

func _process(delta: float) -> void:
	elapsed += delta
	_apply_frame()

func _apply_frame() -> void:
	if _painted == null:
		return
	var choices: Array[Dictionary] = []
	for frame: Dictionary in _frames:
		if str(frame.state) == str(state):
			choices.append(frame)
	if choices.is_empty():
		return
	var fps: float = 10.0 if state == &"run" else 5.0 if state == &"idle" else 7.0
	var index: int = int(elapsed * fps)
	if state in [&"idle", &"run"]:
		index %= choices.size()
	else:
		index = mini(index, choices.size() - 1)
	var selected: Dictionary = choices[index]
	var region: Array = selected.region
	var pivot: Array = selected.pivot_px
	_painted.texture = _textures["res://" + str(selected.path)]
	_painted.region_rect = Rect2(float(region[0]), float(region[1]), float(region[2]), float(region[3]))
	_painted.scale = Vector2(facing * _source_scale, _source_scale)
	_painted.position = Vector2(-float(pivot[0]) * facing, -float(pivot[1])) * _source_scale
