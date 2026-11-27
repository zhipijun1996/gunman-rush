extends RefCounted
# Sample the same local mask and opacity the foreground shader uses. A sparse
# tuft elsewhere in the frame does not cover the shaft or its return steps.
static func opacity(session: OrdinaryRoomSession, at: Vector2) -> float:
	var cover := session.room.element_runtime.nodes.get("grass_cutaway") as WorldForegroundCover
	if cover == null or not cover.bounds.has_point(at): return -1.0
	var offset := at - cover.bounds.position
	var pixel := Vector2i(offset)
	var texture := Image.new()
	if texture.load_png_from_buffer(FileAccess.get_file_as_bytes(cover.texture_path)) != OK: return -1.0
	if texture == null or texture.is_empty() or not Rect2i(Vector2i.ZERO,texture.get_size()).has_point(pixel): return -1.0
	var alpha := texture.get_pixelv(pixel).a
	var key := Vector2i((offset / WorldForegroundCover.CHUNK).floor())
	if not cover.chunks.has(key): return alpha
	var chunk: Dictionary = cover.chunks[key]
	var image: Image = chunk.image
	var area: Rect2 = chunk.area
	var uv := (at - area.position) / area.size
	var amount := image.get_pixelv(Vector2i(uv * Vector2(image.get_size()))).r
	return alpha * lerpf(1.0, cover.revealed_alpha, amount)
