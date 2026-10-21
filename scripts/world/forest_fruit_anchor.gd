class_name ForestFruitAnchor
extends GrappleAnchor
## V14-only authored visual candidate. GrappleAnchor owns all target physics.
var fruit_role := "recommended"
var stem_root := Vector2.ZERO
var bible_presentation := false

func _draw() -> void:
	_draw_rooted_stem()
	if bible_presentation:
		ForestBiblePresentation.draw_fruit(self, fruit_role, hang_enabled)
		return
	# Crisp stepped silhouette at the existing target's scale. No moving
	# collision, enlarged halo, screen-space glow, or decorative false ring.
	var body := Color("d5a75c")
	var shade := Color("8c623e")
	var light := Color("f1d193")
	if fruit_role == "optional":
		body = Color("92915e"); shade = Color("596442"); light = Color("bcb77a")
	elif fruit_role == "recovery":
		body = Color("7ba998"); shade = Color("477267"); light = Color("c1ded0")
	elif fruit_role == "gate":
		body = Color("d1bb70"); shade = Color("8b7945"); light = Color("f4e3aa")
	elif fruit_role == "boss":
		body = Color("b79d6c"); shade = Color("796248"); light = Color("dfcca0")
	draw_rect(Rect2(-7, -11, 14, 3), shade)
	draw_rect(Rect2(-11, -8, 22, 16), shade)
	draw_rect(Rect2(-7, 8, 14, 4), shade)
	draw_rect(Rect2(-8, -8, 16, 15), body)
	draw_rect(Rect2(-5, 7, 10, 3), body)
	draw_rect(Rect2(-6, -6, 4, 5), light)
	draw_rect(Rect2(-4, -14, 3, 4), Color("83925a"))
	draw_colored_polygon(PackedVector2Array([Vector2(-2, -12), Vector2(3, -19), Vector2(11, -18), Vector2(6, -12)]), Color("8f9d65"))
	if hang_enabled:
		# The paired pale seeds retain a shape cue for a held target.
		draw_rect(Rect2(-6, 0, 3, 6), Color("d4eee0"))
		draw_rect(Rect2(3, 0, 3, 6), Color("d4eee0"))

func _draw_rooted_stem() -> void:
	var tip := Vector2(-2, -13)
	var points := PackedVector2Array()
	var shoulder := Vector2(tip.x + (18.0 if stem_root.x >= 0 else -18.0), minf(stem_root.y, tip.y) - 10.0)
	for index: int in 13:
		var t := float(index) / 12.0
		var at := (1.0 - t) * (1.0 - t) * stem_root + 2.0 * (1.0 - t) * t * shoulder + t * t * tip
		points.append(at.round())
	draw_polyline(points, Color("435d42"), 3.0, false)
	draw_polyline(points, Color("7a8652"), 1.0, false)
