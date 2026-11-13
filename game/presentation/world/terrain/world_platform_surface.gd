class_name WorldPlatformSurface
extends Node2D
## Structural platform skin; the host remains the sole collision owner.
var bounds: Rect2
var appearance := "carrier"
var one_way := false
func _draw() -> void:
	if appearance=="timber" and one_way: PlainsTimberSurface.draw_surface(self,bounds)
	elif one_way: UnderworldTerrain.draw_one_way(self,bounds)
	else: UnderworldTerrain.draw_moving(self,bounds)
