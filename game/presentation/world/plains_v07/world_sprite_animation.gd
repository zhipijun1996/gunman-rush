class_name WorldSpriteAnimation
extends Sprite2D
## Native atlas playback. Observes events; never submits gameplay or save changes.
@export var asset_id := "time_gear"
var phase := 0.0
var event_seconds := 0.0
var spec: Dictionary
var disposable := false
var activated := false
static var catalog: Dictionary = {}
func _ready() -> void:
	if catalog.is_empty(): catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/plains_v07/manifest.json")).assets
	spec = catalog[asset_id]
	texture = load("res://" + str(spec.image)) as Texture2D
	hframes = int(spec.frames)
	centered = false
	offset = -FixedWorldProvider.point(spec.anchor)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if spec.kind=="npc":
		var readable:=CanvasItemMaterial.new();readable.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material=readable
	process_mode = Node.PROCESS_MODE_PAUSABLE
func play_event() -> void:
	event_seconds = .75
	phase = 0
func _process(delta: float) -> void:
	phase += delta
	event_seconds = maxf(0,event_seconds-delta)
	if spec.kind == "npc": frame = 4 + mini(1,int(phase*4)) if event_seconds>0 else int(phase*3)%4
	elif spec.kind == "mechanism": frame = mini(5,int(phase*8)) if event_seconds>0 else (5 if activated else 0)
	elif spec.kind == "burst":
		frame = mini(5,int(phase*15))
		if phase>.45 and disposable: queue_free()
	else: frame = int(phase*float(spec.fps))%int(spec.frames)
