class_name WorldSpikeArt
extends Node2D
## Static, continuous hazard skin. Physics remains owned by the room strips.
var bands: Array[Dictionary] = []
var hosts: Array[Rect2] = []

func setup(room: FixedWorldRoom) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 1
	hosts = room.platforms.duplicate()
	bands.clear()
	var composer := room.get_node("TerrainComposer") as TerrainComposer
	var inward := {"up": Vector2.DOWN, "down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT}
	for strip: Dictionary in room.spike_strips:
		var face := str(strip.get("facing", "up"))
		var rect := FixedWorldProvider.rect(strip.bounds)
		var normal: Vector2 = inward[face]
		var root_point := rect.get_center() + normal * (rect.size * 0.5 + Vector2.ONE)
		var material_id := composer.material_at(root_point, room.terrain_material)
		var style := WorldSurfaceStyles.choose(str(strip.get("appearance", "")), material_id)
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
			for part: Dictionary in UnderworldHazardTiles.surface_plan(band.rect,face,host):
				var foot: Rect2 = part.root_world
				if not foot.has_area(): continue
				# Hardware stays wholly inside the supporting wall, even on shallow strips.
				var join := Vector2(minf(14,foot.size.x),minf(6,foot.size.y)) if band.face in ["up","down"] else Vector2(minf(6,foot.size.x),minf(14,foot.size.y))
				MechanismRegionArt.stamp(self,"mount",foot.get_center(),join)
			drawn=true
		if not drawn: UnderworldHazardTiles.draw_band(self,band.rect,face,Rect2(),WorldSurfaceStyles.texture(band.style))
