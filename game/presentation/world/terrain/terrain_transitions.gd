class_name TerrainTransitions
extends Node2D
## Batched native texture patches clipped to real occupied polygons.
var patches: Array[Dictionary] = []

func setup(seams: Array[Dictionary], geometry: Dictionary) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var lit := ShaderMaterial.new(); lit.shader = UnderworldTerrain.CORE_SHADER; material = lit
	for seam: Dictionary in seams:
		var y := float(seam.start)
		var open_top := not UnderworldPolygonTerrain.inside(geometry.shapes, Vector2(seam.x,y-.1))
		while y < float(seam.end):
			var height := minf(32, float(seam.end)-y)
			var box := Rect2(float(seam.x)-16,y,32,height)
			var row := 0 if y == float(seam.start) and open_top else 1
			var variant := posmod(floori(y/32),3)
			var source := Rect2(variant*32,row*32,32,height)
			for shape: PackedVector2Array in seam.shapes:
				for clip: PackedVector2Array in Geometry2D.intersect_polygons(shape, UnderworldPolygonTerrain.rectangle_points(box)):
					var uv := PackedVector2Array()
					var texture := TerrainMaterialRegistry.texture(seam.texture)
					for point: Vector2 in clip:
						var relative := point-box.position
						if seam.stone_on_right: relative.x = 32-relative.x
						uv.append((source.position+relative)/Vector2(texture.get_size()))
					patches.append({"points":clip,"uv":uv,"texture":texture})
			y += height
	queue_redraw()

func _draw() -> void:
	for patch: Dictionary in patches: draw_polygon(patch.points,PackedColorArray([Color.WHITE]),patch.uv,patch.texture)
