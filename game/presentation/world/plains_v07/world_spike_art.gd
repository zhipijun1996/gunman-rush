class_name WorldSpikeArt
extends Node2D
## Static, continuous hazard skin. Physics remains owned by the room strips.
var bands: Array[Dictionary] = []
var hosts: Array[Rect2] = []

func setup(strips: Array[Dictionary], solids: Array[Rect2]) -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	z_index=1
	hosts=solids.duplicate()
	for strip: Dictionary in strips:
		var face: String=str(strip.get("facing","up"))
		var rect:=FixedWorldProvider.rect(strip.bounds)
		# Adjacent authored strips share one run, without internal end caps.
		var changed:=true
		while changed:
			changed=false
			for i: int in bands.size():
				var other: Rect2=bands[i].rect
				var horizontal:=face in ["up","down"]
				var aligned: bool=(is_equal_approx(rect.position.y,other.position.y) and is_equal_approx(rect.size.y,other.size.y)) if horizontal else (is_equal_approx(rect.position.x,other.position.x) and is_equal_approx(rect.size.x,other.size.x))
				if bands[i].face==face and aligned and rect.grow(.01).intersects(other):
					rect=rect.merge(other);bands.remove_at(i);changed=true;break
		bands.append({"face":face,"rect":rect})
	queue_redraw()

func _draw() -> void:
	for band: Dictionary in bands:
		var face: int={"up":PlatformThornDefinition.Face.TOP,"down":PlatformThornDefinition.Face.BOTTOM,"left":PlatformThornDefinition.Face.LEFT,"right":PlatformThornDefinition.Face.RIGHT}[band.face]
		var drawn:=false
		for host: Rect2 in hosts:
			if not (band.rect as Rect2).grow(8).intersects(host): continue
			UnderworldHazardTiles.draw_band(self,band.rect,face,host)
			drawn=true
		if not drawn: UnderworldHazardTiles.draw_band(self,band.rect,face,Rect2())
