class_name RouteSignpost
extends Node2D
## World-space presentation of committed route offers. Never chooses or claims.
var routes: Array[Dictionary] = []

func configure(offers: Array, directions: Array[Vector2], profiles: Array = []) -> void:
	routes.clear()
	for index: int in mini(offers.size(), directions.size()):
		var offer: ExitOffer = offers[index]
		routes.append({"exit_id": offer.exit_id, "type_id": offer.next_stage_type_id,
			"icon_id": offer.icon_id, "label": offer.label, "direction": directions[index],
			"risk_label": _risk_label(profiles[index]) if index < profiles.size() else ""})
	queue_redraw()

func _draw() -> void:
	# Muted timber, pale lettering and explicit arrows stay legible against the
	# painted meadow without introducing an interactive HUD or blocking terrain.
	draw_line(Vector2(0, 0), Vector2(0, -152), Color("302f25"), 13)
	draw_line(Vector2(-2, -2), Vector2(-2, -150), Color("827452"), 7)
	for index: int in routes.size():
		var center := Vector2(0, -128 + index * 62)
		var board := Rect2(center + Vector2(-72, -19), Vector2(182, 54))
		draw_style_box(_board_style(), board)
		draw_line(board.position + Vector2(8, 7), board.position + Vector2(170, 7), Color("716442"), 1)
		draw_circle(center + Vector2(-64, 0), 2, Color("c5ba8e"))
		_draw_icon(center + Vector2(-46, 0), routes[index].icon_id)
		draw_string(ThemeDB.fallback_font, center + Vector2(-29, 5), str(routes[index].label), HORIZONTAL_ALIGNMENT_LEFT, 85, 16, Color("f4e9bb"))
		draw_string(ThemeDB.fallback_font, center + Vector2(-60, 25), str(routes[index].risk_label), HORIZONTAL_ALIGNMENT_LEFT, 160, 12, Color("d9c58e"))
		var direction: Vector2 = routes[index].direction
		var arrow := center + Vector2(94, 0)
		draw_line(arrow - direction * 8, arrow + direction * 8, Color("ead9a4"), 2.5, true)
		draw_line(arrow + direction * 8, arrow + direction * 2 + direction.orthogonal() * 5, Color("ead9a4"), 2.5, true)
		draw_line(arrow + direction * 8, arrow + direction * 2 - direction.orthogonal() * 5, Color("ead9a4"), 2.5, true)

func _board_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("4b4932")
	style.border_color = Color("9a8858")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.05, 0.06, 0.04, 0.4)
	style.shadow_size = 3
	return style

func _draw_icon(point: Vector2, kind: StringName) -> void:
	var painted := PlainsV3Assets.stage_icon(kind)
	if painted != null:
		draw_texture_rect(painted, Rect2(point - Vector2(11, 11), Vector2(22, 22)), false)
		return
	if kind in [&"coin_reward", &"health_reward"]:
		var texture := PlainsRefreshAssets.object_texture(&"coin" if kind == &"coin_reward" else &"heart")
		draw_texture_rect(texture, Rect2(point - Vector2(10, 10), Vector2(20, 20)), false)
	elif kind == &"item_reward":
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -10), point + Vector2(8, 0), point + Vector2(0, 10), point + Vector2(-8, 0)]), Color("c5a2e0"))
	elif kind == &"shop":
		draw_rect(Rect2(point - Vector2(8, 3), Vector2(16, 12)), Color("c1cf9e"), false, 2)
		draw_line(point + Vector2(-10, -6), point + Vector2(10, -6), Color("d3b57b"), 5)
	elif kind == &"boss":
		draw_colored_polygon(PackedVector2Array([point + Vector2(-10, -6), point + Vector2(-4, -1), point + Vector2(0, -10), point + Vector2(4, -1), point + Vector2(10, -6), point + Vector2(7, 8), point + Vector2(-7, 8)]), Color("e4b166"))
	else:
		draw_line(point + Vector2(-7, -8), point + Vector2(7, 8), Color("dcad94"), 3)
		draw_line(point + Vector2(7, -8), point + Vector2(-7, 8), Color("dcad94"), 3)

func _risk_label(profile: Dictionary) -> String:
	if profile.get("risk", "steady") != "challenge":
		return "STEADY PATH"
	return "CHALLENGE + LOOT" if int(profile.get("bonus_coins", 0)) + int(profile.get("bonus_notes", 0)) > 0 else "CHALLENGE"
