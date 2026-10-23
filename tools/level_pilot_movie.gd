extends "res://tools/level_pilot_validate.gd"
## Continuous real Godot render of the same Router-driven pilot. Camera/HUD only.
var pilot_camera: Camera2D

func tick(n: int = 1) -> void:
	if not is_instance_valid(pilot_camera):
		pilot_camera = Camera2D.new()
		pilot_camera.position = Vector2(420, 128)
		pilot_camera.zoom = Vector2(1.25, 1.25)
		world.add_child(pilot_camera)
		var hud := CanvasLayer.new()
		world.add_child(hud)
		var label := Label.new()
		label.position = Vector2(24, 22)
		label.text = "AI LEVEL PILOT | %s | %s | v%d\nReal Godot / prototype geometry / reward location only / human fun unverified" % [candidate, strategy, variant]
		hud.add_child(label)
	await super.tick(n)
