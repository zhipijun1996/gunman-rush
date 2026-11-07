extends Node2D
## Seeded pixel light cores and short tails; same motion data as Canvas.

@export var region_id := "plains"

var particles: Array[Dictionary] = []
var random_state := 93

func _random() -> float:
	random_state = (random_state * 1664525 + 1013904223) & 0xffffffff
	return float(random_state) / 4294967296.0

func _prepare(data: Dictionary, region: Dictionary) -> void:
	var settings: Dictionary = region.get("particles", {})
	var width := float(data["viewport"]["width"])
	var height := float(data["viewport"]["height"])
	random_state = int(data.get("motion", {}).get("seed", 93)) & 0xffffffff
	for ch in region_id:
		random_state = (random_state * 31 + ch.unicode_at(0)) & 0xffffffff
	for i in int(settings.get("count", 24)):
		var r1 := _random()
		var r2 := _random()
		var r3 := _random()
		var r4 := _random()
		var r5 := _random()
		particles.append({"id": i, "start_x": -16 + r1 * (width + 32), "start_y": 38 + r2 * (height - 80), "speed_factor": 0.65 + r3 * 0.7, "phase": r4 * TAU, "amplitude": 2 + r5 * 4, "depth": "near" if i % 5 == 0 else "mid"})

func _point_in_polygon(x: float, y: float, points: Array) -> bool:
	var inside := false
	var previous := points.size() - 1
	for i in points.size():
		var a: Array = points[i]
		var b: Array = points[previous]
		if (float(a[1]) > y) != (float(b[1]) > y):
			if x < (float(b[0]) - float(a[0])) * (y - float(a[1])) / (float(b[1]) - float(a[1])) + float(a[0]):
				inside = not inside
		previous = i
	return inside

func snapshot(at_time: float = -1.0) -> Array[Dictionary]:
	var study := get_tree().current_scene
	var result: Array[Dictionary] = []
	if study == null or study.data.is_empty():
		return result
	var region: Dictionary = study.region_spec(region_id)
	if region.is_empty():
		return result
	if particles.is_empty():
		_prepare(study.data, region)
	var spec: Dictionary = region.get("particles", {})
	var width := float(study.data["viewport"]["width"])
	var height := float(study.data["viewport"]["height"])
	var speed := float(spec.get("speed", 19))
	var vertical := float(spec.get("vertical", -3))
	var t: float = study.ambient_time if at_time < 0 else at_time
	var hero: Sprite2D = study.get_node("Traveler/Visual/Sprite2D")
	var hero_bounds: Rect2 = hero.get_global_transform() * hero.get_rect()
	for particle in particles:
		var x := floorf(-16 + fposmod(float(particle["start_x"]) + 16 + t * speed * float(particle["speed_factor"]), width + 32) + 0.5)
		var y := floorf(28 + fposmod(float(particle["start_y"]) - 28 + t * vertical + sin(t * 0.85 + float(particle["phase"])) * float(particle["amplitude"]), height - 56) + 0.5)
		var alpha := clampf(minf(x + 16, width + 16 - x) / 18, 0, 1) * (0.64 + 0.2 * sin(t * 1.2 + float(particle["phase"])))
		var blocked := x > hero_bounds.position.x - 4 and x < hero_bounds.end.x + 4 and y > hero_bounds.position.y - 3 and y < hero_bounds.end.y + 3
		if not blocked:
			for terrain in study.terrain_bodies(region_id):
				if _point_in_polygon(x, y, terrain["points"]):
					blocked = true
					break
		result.append({"id": particle["id"], "x": x, "y": y, "alpha": 0.0 if blocked else alpha, "depth": particle["depth"], "speed": speed, "vertical": vertical})
	return result

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	var study := get_tree().current_scene
	if study == null or study.data.is_empty():
		return
	var spec: Dictionary = study.region_spec(region_id).get("particles", {})
	var rgb: Array = spec.get("color", [1.0, 0.91, 0.65])
	var kind := str(spec.get("kind", "dust"))
	var tail_length := 5 if kind == "embers" else 3 if kind == "spores" else 6
	for particle in snapshot():
		var alpha := float(particle["alpha"])
		if alpha <= 0:
			continue
		var x := float(particle["x"])
		var y := float(particle["y"])
		var dx := signf(float(particle["speed"]))
		if dx == 0:
			dx = 1
		var dy := 1.0 if kind == "embers" else signf(-float(particle["vertical"]))
		for k in range(tail_length, 0, -1):
			var tail_color := Color(float(rgb[0]), float(rgb[1]), float(rgb[2]), alpha * (1.0 - float(k) / (tail_length + 1)) * 0.32)
			draw_rect(Rect2(x - dx * k, y + floorf(dy * k * 0.25 + 0.5), 1, 1), tail_color)
		var core_color := Color(0.55 + float(rgb[0]) * 0.45, 0.55 + float(rgb[1]) * 0.45, 0.55 + float(rgb[2]) * 0.45, alpha)
		draw_rect(Rect2(x, y, 1 if kind == "embers" else 2, 2), core_color)
		if particle["depth"] == "near":
			draw_rect(Rect2(x - 1, y - 1, 4, 4), Color(float(rgb[0]), float(rgb[1]), float(rgb[2]), 0.12 * alpha))
