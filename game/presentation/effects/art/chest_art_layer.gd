class_name ChestArtLayer
extends Node2D
## Forest-only draw boundary: backgrounds/signals never inherit sprite shader.
## Retains the stage-owned rows by reference and reads actual claimed each draw.
var chests: Array[Dictionary] = []

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = ChestArtLibrary.world_material()

func configure(rows: Array[Dictionary]) -> void:
	chests = rows
	queue_redraw()

func _draw() -> void:
	ForestBiblePresentation.draw_chests(self,chests)
