class_name PlainsPlatformVisual
extends Node2D
var bounds := Rect2()

func _draw() -> void:
	PlainsTerrainSkin.draw_platform(self, bounds)
