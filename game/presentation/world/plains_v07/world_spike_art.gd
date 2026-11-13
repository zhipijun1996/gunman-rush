class_name WorldSpikeArt
extends Node2D
## Static, continuous hazard skin. Physics remains owned by the room strips.
var bands: Array[Dictionary] = []
var hosts: Array[Rect2] = []

func setup(strips: Array[Dictionary], solids: Array[Rect2], room: FixedWorldRoom = null) -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=1
	hosts=solids.duplicate()
	bands.clear()
	for strip: Dictionary in strips:
		var face: String=str(strip.get("facing","up"))
		var rect:=FixedWorldProvider.rect(strip.bounds)
		var region := room.room_id.get_slice("-",0) if room != null else "P"
		var substrate := "windchime_plains"
		if room != null:
			substrate = room.region_preview if not room.region_preview.is_empty() else ("mill_masonry" if not room.interior_material().is_empty() else "windchime_plains")
			var root_point := rect.get_center()+Vector2(0,rect.size.y/2+1) if face=="up" else (rect.get_center()-Vector2(0,rect.size.y/2+1) if face=="down" else (rect.get_center()+Vector2(rect.size.x/2+1,0) if face=="left" else rect.get_center()-Vector2(rect.size.x/2+1,0)))
			var composer := room.get_node_or_null("TerrainComposer") as TerrainComposer
			if composer != null:
				for group: Dictionary in composer.groups:
					for solid: Rect2 in group.solids:
						if solid.has_point(root_point): substrate = str(group.material_id)
					for polygon: Dictionary in group.polygons:
						var vertices := PackedVector2Array()
						for point: Array in polygon.points: vertices.append(FixedWorldProvider.point(point))
						if Geometry2D.is_point_in_polygon(root_point,vertices): substrate = str(group.material_id)
		var style := WorldSurfaceStyles.choose(str(strip.get("appearance","")),region,substrate)
		# Adjacent authored strips share one run, without internal end caps.
		var changed:=true
		while changed:
			changed=false
			for i: int in bands.size():
				var other: Rect2=bands[i].rect
				var horizontal:=face in ["up","down"]
				var aligned: bool=(is_equal_approx(rect.position.y,other.position.y) and is_equal_approx(rect.size.y,other.size.y)) if horizontal else (is_equal_approx(rect.position.x,other.position.x) and is_equal_approx(rect.size.x,other.size.x))
				if bands[i].face==face and bands[i].style==style and aligned and rect.grow(.01).intersects(other):
					rect=rect.merge(other);bands.remove_at(i);changed=true;break
		bands.append({"face":face,"rect":rect,"style":style})
	queue_redraw()

func _draw() -> void:
	for band: Dictionary in bands:
		var face: int={"up":PlatformThornDefinition.Face.TOP,"down":PlatformThornDefinition.Face.BOTTOM,"left":PlatformThornDefinition.Face.LEFT,"right":PlatformThornDefinition.Face.RIGHT}[band.face]
		var drawn:=false
		for host: Rect2 in hosts:
			if not (band.rect as Rect2).grow(8).intersects(host): continue
			UnderworldHazardTiles.draw_band(self,band.rect,face,host,WorldSurfaceStyles.texture(band.style))
			drawn=true
		if not drawn: UnderworldHazardTiles.draw_band(self,band.rect,face,Rect2(),WorldSurfaceStyles.texture(band.style))
