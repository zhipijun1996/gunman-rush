extends CanvasLayer
const MAX_PROTECTION := 64
const WIND_MARGIN := 3.0
var _protect: Array[Rect2] = []
var _dynamic_protect: Array[Rect2] = []
var _static_protect: Array[Rect2] = []
var _source_counts: Dictionary = {}
var _overflow := false
var _protection_viewport := Rect2()
var _protection_canvas := Transform2D.IDENTITY
func set_masks(masks: Array) -> void:
	_static_protect.clear()
	_static_protect.append_array(masks)
func state() -> Dictionary:
	return {"protect":_protect.duplicate(),"dynamic":_dynamic_protect.duplicate(),"static":_static_protect.duplicate(),"counts":_source_counts.duplicate(),"overflow":_overflow}

func begin_pass() -> void:
	_protect.clear();_dynamic_protect.clear();_static_protect.clear();_source_counts.clear();_overflow=false

func _add(rect: Rect2,source: String) -> void:
	if not rect.has_area() or not rect.intersects(get_viewport().get_visible_rect()):return
	_source_counts[source]=int(_source_counts.get(source,0))+1
	var next:=rect.intersection(get_viewport().get_visible_rect())
	# Preserve source semantics before union merging: a permanent UI or terrain
	# border must not turn a small local mask into permanent whole-object fading.
	if source in ["player","muzzle","aim_ray","actual_grapple_guide","actual_grapple_rope","actual_actor_or_danger","enemy_and_warning","actual_attack_goal_path","actual_attack_goal_warning","actual_sentry_warning_ray","projectile_and_actual_trail"] or source.begins_with("actual_moving_"):
		_dynamic_protect.append(next)
	else:_static_protect.append(next)
	for i: int in range(_protect.size()-1,-1,-1):
		var existing:=_protect[i]
		if existing.encloses(next):return
		if next.encloses(existing):_protect.remove_at(i);continue
		if existing.intersects(next):
			var merged:=existing.merge(next)
			if merged.get_area()<1.25*(existing.get_area()+next.get_area()):next=merged;_protect.remove_at(i)
	_protect.append(next)
	if _protect.size()>MAX_PROTECTION:_overflow=true

func _world_rect(rect: Rect2,source: String) -> void:
	_add(get_viewport().get_canvas_transform()*rect,source)

func _exposed_regions(bounds: Rect2,size: Vector2) -> Array[Rect2]:
	# Geometry estimate only, not a claim about painted-alpha pixel coverage.
	# Permanent masks carve local regions instead of suppressing the whole reed.
	var regions: Array[Rect2]=[]
	var clipped:=bounds.intersection(Rect2(Vector2.ZERO,size))
	if clipped.has_area():regions.append(clipped)
	for mask_rect: Rect2 in _static_protect:
		var strict:=mask_rect.grow(WIND_MARGIN)
		var next: Array[Rect2]=[]
		for part: Rect2 in regions:
			var cut:=part.intersection(strict)
			if not cut.has_area():next.append(part);continue
			var strips: Array[Rect2]=[
				Rect2(part.position,Vector2(part.size.x,cut.position.y-part.position.y)),
				Rect2(Vector2(part.position.x,cut.end.y),Vector2(part.size.x,part.end.y-cut.end.y)),
				Rect2(Vector2(part.position.x,cut.position.y),Vector2(cut.position.x-part.position.x,cut.size.y)),
				Rect2(Vector2(cut.end.x,cut.position.y),Vector2(part.end.x-cut.end.x,cut.size.y))]
			for strip: Rect2 in strips:
				if strip.has_area():next.append(strip)
		# A complex static mask can over-estimate exposed area if fragmented.
		# Bound CPU work; the exact GPU masks remain authoritative and unchanged.
		if next.size()>64:return regions
		regions=next
		if regions.is_empty():break
	return regions

