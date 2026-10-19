class_name PixelPlainsDecoration
extends WindchimeDecoration
## New original prop pixels; parent fields only retain the cosmetic interface.
const PIXELS := preload("res://assets/pixel_plains/props.svg")
var effects_enabled := true
var _wind_clock := 0.0

func configure(cells: Dictionary,keepouts: Array[Rect2],seed_text: String) -> void:
	placements.clear()
	var ordered: Array = cells.keys()
	ordered.sort_custom(func(a: Vector2i,b: Vector2i) -> bool:return a.x<b.x if a.x!=b.x else a.y<b.y)
	for cell: Vector2i in ordered:
		if cells.has(cell+Vector2i.UP) or not cells.has(cell+Vector2i.LEFT) or not cells.has(cell+Vector2i.RIGHT):continue
		var roll := posmod((seed_text+":pixel-plants:"+str(cell)).hash(),1000)
		if roll>430 or placements.size()>=17:continue
		var kind := 0 if roll<250 else 1 if roll<340 else 5 if roll<395 else 4
		var p := Vector2(cell*Blob47Rules.CELL)+Vector2(16,0)
		var r := Rect2(p-Vector2(16,64),Vector2(32,64))
		var valid := true
		for k: Rect2 in keepouts:
			if k.grow(6).intersects(r):valid=false
		for prev: Dictionary in placements:
			if p.distance_to(prev.position)<40:valid=false
		if valid: placements.append({"position":p,"kind":kind,"bounds":r})
	queue_redraw()

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	_wind_clock += delta
	if effects_enabled:queue_redraw()

func _draw() -> void:
	for item: Dictionary in placements:
		var p: Vector2 = item.position
		var sway := 2.0*roundf(sin(_wind_clock*1.4+p.x*.012)) if effects_enabled and int(item.kind) in [0,1,5] else 0.0
		# Roots stay fixed. Only the thin upper portion moves by one logical pixel.
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16,24),Vector2(32,24)),Rect2(int(item.kind)*64,80,64,48))
		draw_texture_rect_region(PIXELS,Rect2(p-Vector2(16-sway,64),Vector2(32,40)),Rect2(int(item.kind)*64,0,64,80))
