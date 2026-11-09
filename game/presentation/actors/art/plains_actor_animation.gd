class_name PlainsActorAnimation
extends Resource
## Authored frames only. Combat and accepted-hit owners supply every clock.
@export var atlas: Texture2D
@export var frame_size := Vector2i.ZERO
@export var pivot := Vector2.ZERO
@export var columns := 4
@export var clips: Array[String] = []
@export var core_points := PackedVector2Array()
@export var muzzle_points := PackedVector2Array()
@export var barrel_pivots := PackedVector2Array()
@export var barrel_regions: Array[Rect2] = []

func frame_index(clip: StringName, progress: float) -> int:
	var row := maxi(0, clips.find(String(clip)))
	return row * columns + clampi(floori(progress * columns), 0, columns - 1)

func core_point(clip: StringName, progress: float) -> Vector2:
	var index := frame_index(clip, progress)
	return core_points[index] if index < core_points.size() else Vector2.ZERO

func region(clip: StringName, progress: float) -> Rect2:
	var row := clips.find(String(clip))
	if row < 0: row = 0
	var column := clampi(floori(progress * columns), 0, columns - 1)
	return Rect2(Vector2(column * frame_size.x, row * frame_size.y), Vector2(frame_size))

func draw_frame(canvas: CanvasItem, clip: StringName, progress: float, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect_region(atlas, Rect2(-pivot, Vector2(frame_size)), region(clip, progress), tint)
