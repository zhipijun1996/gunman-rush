class_name UnderworldObjects
extends RefCounted
## Presentation helpers. Plates are declared native geometry; chest is a real
## generated open pose. No helper changes rewards, collision or switch state.
const OPEN_CHEST := preload("res://assets/underworld_plains/objects/opened_chest.png")
const CLOSED_CHEST := preload("res://assets/underworld_plains/actors/chest.png")

static func place_chest(sprite: Sprite2D, foot: Vector2, claimed: bool) -> void:
	sprite.texture = OPEN_CHEST if claimed else CLOSED_CHEST
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * 58.0 / sprite.texture.get_width()
	sprite.position = foot - Vector2(0, sprite.texture.get_height() * sprite.scale.y * .5)
	sprite.modulate = Color.WHITE
	sprite.set_meta("underworld_chest_open", claimed)

static func sequence_plate(canvas: Node2D, at: Vector2, step: int, active: bool) -> void:
	# Small aged-brass tally plate: one/two actual engraved notches, no floating
	# UI font. Order is mirrored in the target's family glyph, never randomized.
	var metal := Color("a38c51") if active else Color("665d3d")
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-11,-9),at+Vector2(9,-9),at+Vector2(12,-6),at+Vector2(12,7),at+Vector2(9,10),at+Vector2(-11,10)]),Color("1a231e"))
	canvas.draw_line(at+Vector2(-9,-8),at+Vector2(8,-8),metal,2)
	canvas.draw_line(at+Vector2(-9,8),at+Vector2(8,8),metal.darkened(.3),2)
	for index: int in clampi(step,1,2):
		var x := -3.0 if step == 1 else -6.0 + index * 6.0
		canvas.draw_line(at+Vector2(x,-4),at+Vector2(x,4),Color("101a16"),3)
		canvas.draw_line(at+Vector2(x+1,-4),at+Vector2(x+1,3),metal.lightened(.22),1)

static func link_sigil(canvas: Node2D, at: Vector2, index: int, size: float) -> void:
	# Same matching mechanism identity with restrained outline rather than a
	# bright floating number. Family glyph remains readable in native pixel art.
	var half := floorf(size*.4)
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-half),at+Vector2(half,0),at+Vector2(0,half),at+Vector2(-half,0)]),Color("17211b"))
	for side: int in 4:
		var a := at+Vector2.from_angle(side*PI*.5-PI*.5)*half
		var b := at+Vector2.from_angle((side+1)*PI*.5-PI*.5)*half
		canvas.draw_line(a,b,Color("76643b"),1)
	PixelFormalActors.sigil(canvas,at,index,size*.62)
