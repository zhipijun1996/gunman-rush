class_name ForestBibleThorns
extends RefCounted
## Authored native sprites only. No procedural stem, needles, physics or RNG.
const ATLAS: Texture2D = preload("res://assets/forest_bible_v2/native/thorn_briar_atlas_v2.png")
# Byte-equivalent region data is embedded so exported builds need no JSON filter.
const REGIONS: Dictionary = {
	"up12_a": {"atlas_rect":[0,0,64,20],"size":[64,20],"face":"up","seam_native":12,"outer_rect":[0,0,64,12],"root_rect":[0,12,64,8],"port":[0,17],"root_anchor_y_by_x":[17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],"safe_tail_columns":[1,2,3,4,5,6,10,11,12,13,14,15,16,17,18,19,20,23,24,25,26,27,28,29,30,31,32,33,34,37,38,39,40,41,42,43,44,45,46,47,51,52,53,54,55,56,57,60,61,62,63,64]},
	"down10_a": {"atlas_rect":[66,0,64,18],"size":[64,18],"face":"down","seam_native":8,"outer_rect":[0,8,64,10],"root_rect":[0,0,64,8],"port":[0,3],"root_anchor_y_by_x":[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],"safe_tail_columns":[1,2,3,4,5,6,10,11,12,13,14,15,16,17,18,19,20,23,24,25,26,27,28,29,30,31,32,33,34,35,37,38,39,40,41,42,43,44,45,46,47,51,52,53,54,55,56,57,60,61,62,63,64]},
	"down8_a": {"atlas_rect":[132,0,64,16],"size":[64,16],"face":"down","seam_native":8,"outer_rect":[0,8,64,8],"root_rect":[0,0,64,8],"port":[0,3],"root_anchor_y_by_x":[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],"safe_tail_columns":[1,2,3,4,5,6,10,11,12,13,14,15,16,17,18,19,20,21,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,51,52,53,54,55,56,57,58,59,60,61,62,63,64]},
	"up12_b": {"atlas_rect":[198,0,48,20],"size":[48,20],"face":"up","seam_native":12,"outer_rect":[0,0,48,12],"root_rect":[0,12,48,8],"port":[0,17],"root_anchor_y_by_x":[17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],"safe_tail_columns":[1,2,3,4,5,10,11,12,13,14,15,16,17,18,20,21,22,23,24,25,26,27,28,29,35,36,37,38,39,40,41,44,45,46,47,48]},
	"down10_b": {"atlas_rect":[0,22,48,18],"size":[48,18],"face":"down","seam_native":8,"outer_rect":[0,8,48,10],"root_rect":[0,0,48,8],"port":[0,3],"root_anchor_y_by_x":[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],"safe_tail_columns":[1,2,3,4,5,10,11,12,13,14,15,16,17,18,20,21,22,23,24,25,26,27,28,29,35,36,37,38,39,40,41,44,45,46,47,48]},
	"down8_b": {"atlas_rect":[50,22,48,16],"size":[48,16],"face":"down","seam_native":8,"outer_rect":[0,8,48,8],"root_rect":[0,0,48,8],"port":[0,3],"root_anchor_y_by_x":[3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3],"safe_tail_columns":[1,2,3,4,5,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,35,36,37,38,39,40,41,42,43,44,45,46,47,48]},
	"left20": {"atlas_rect":[100,22,28,26],"size":[28,26],"face":"left","seam_native":20,"outer_rect":[0,0,20,26],"root_rect":[20,0,8,26],"port":[23,0],"root_anchor_y_by_x":[],"safe_tail_columns":[]},
	"bare_short": {"atlas_rect":[130,22,16,8],"size":[16,8],"face":"bare","seam_native":0,"outer_rect":[0,0,0,0],"root_rect":[0,0,16,8],"port":[0,4],"root_anchor_y_by_x":[],"safe_tail_columns":[]},
	"elbow_up90": {"atlas_rect":[148,22,80,56],"size":[80,56],"face":"bare","seam_native":0,"outer_rect":[0,0,0,0],"root_rect":[0,0,80,56],"port":[0,4],"root_anchor_y_by_x":[],"safe_tail_columns":[]},
	"elbow_down40": {"atlas_rect":[230,22,24,30],"size":[24,30],"face":"bare","seam_native":0,"outer_rect":[0,0,0,0],"root_rect":[0,0,24,30],"port":[0,4],"root_anchor_y_by_x":[],"safe_tail_columns":[]},
}
const PIXEL: float = 2.0
const VARIANTS: Array[int] = [0,1,1,0,0,1,0,1]

static func draw(canvas: Node2D, m: Dictionary) -> void:
	if m.get("layout_version") not in ["forest-bible-world-v15", "forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"]: return
	var hosts: Dictionary = {}
	var hollow: Array[Rect2] = []
	var hollow_ids: Dictionary = {}
	for row: Dictionary in m.get("platforms", []):
		if bool(row.get("one_way",false)) or not row.has("rect"): continue
		hosts[str(row.id)] = _rect(row.rect)
		if row.get("structure_id") == "hollow":
			hollow.append(_rect(row.rect)); hollow_ids[str(row.id)] = true
	var joins: Array[Dictionary] = []
	for surface: Dictionary in m.get("thorn_surfaces", []):
		var face: String = str(surface.get("face", ""))
		if face not in ["up","down","left"]: continue
		var hazard: Rect2 = _rect(surface.hazard_rect)
		var segments: Array = surface.get("segments", [])
		if segments.is_empty() or not hazard.has_area(): continue
		var solids: Array[Rect2] = []
		var valid: bool = true
		for segment: Dictionary in segments:
			var id: String = str(segment.support_id)
			if not hosts.has(id): valid = false; break
			solids.append(hosts[id])
		if not valid: continue
		var seam: Vector2 = _point(segments[0].start)
		var reach: float = seam.x-hazard.position.x if face == "left" else hazard.end.y-seam.y if face == "down" else seam.y-hazard.position.y
		var depth: int = roundi(reach/PIXEL)
		if not is_equal_approx(reach,float(depth)*PIXEL): continue
		if face == "left":
			if depth != 20 or not is_equal_approx(hazard.size.y,52.0): continue
			_stamp(canvas,"left20",Vector2(seam.x-40.0,hazard.position.y),hazard,solids)
			continue
		if (face == "up" and depth != 12) or (face == "down" and depth not in [8,10]): continue
		var family: String = ("up" if face == "up" else "down")+str(depth)
		# One sprite run for the actual hazard union: shared support boundaries
		# do not restart phase, emit another cap, or duplicate external thorns.
		var origin_y: float = seam.y-reach if face == "up" else seam.y-16.0
		var layout: Array[Dictionary] = _layout(family,hazard.size.x)
		for piece: Dictionary in layout:
			_stamp(canvas,str(piece.name),Vector2(hazard.position.x+float(piece.offset),origin_y),hazard,solids)
		for segment: Dictionary in segments:
			if hollow_ids.has(str(segment.support_id)):
				joins.append({"first":_point(segment.start),"last":_point(segment.end),"face":face,
					"family":family,"run_left":hazard.position.x,"run_right":hazard.end.x,"origin_y":origin_y,"layout":layout,"host":hosts[str(segment.support_id)]})
	_draw_connections(canvas,joins,hollow)

static func _layout(family: String, width: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total: int = roundi(width/PIXEL)
	if not is_equal_approx(width,float(total)*PIXEL): return result
	var at: int = 0
	while at < total:
		var preferred: int = VARIANTS[result.size()%VARIANTS.size()]
		var remaining: int = total-at
		var selected: String = ""
		for choice: int in [preferred,1-preferred]:
			var name: String = family+("_a" if choice == 0 else "_b")
			var region: Dictionary = REGIONS[name]
			if remaining >= int(region.size[0]) or remaining in region.safe_tail_columns:
				selected = name; break
		if selected.is_empty(): return []
		var used: int = mini(remaining,int(REGIONS[selected].size[0]))
		result.append({"name":selected,"offset":float(at)*PIXEL,"width":float(used)*PIXEL})
		at += used
	return result

static func _stamp(canvas: Node2D, name: String, origin: Vector2, hazard: Rect2, solids: Array[Rect2]) -> void:
	var region: Dictionary = REGIONS[name]
	_blit(canvas,region,origin,_rect(region.outer_rect),hazard)
	var root: Rect2 = _rect(region.root_rect)
	var run_clip: Rect2 = Rect2(Vector2(origin.x-10000.0,hazard.position.y),Vector2(20000.0,hazard.size.y)) if region.face == "left" else Rect2(Vector2(hazard.position.x,origin.y-10000.0),Vector2(hazard.size.x,20000.0))
	for solid: Rect2 in solids: _blit(canvas,region,origin,root,solid.intersection(run_clip))

static func _blit(canvas: Node2D, region: Dictionary, origin: Vector2, native: Rect2, clip: Rect2) -> void:
	if not native.has_area(): return
	var target := Rect2(origin+native.position*PIXEL,native.size*PIXEL)
	var visible: Rect2 = target.intersection(clip)
	if not visible.has_area(): return
	var source := Rect2(_point(region.atlas_rect)+native.position+(visible.position-target.position)/PIXEL,visible.size/PIXEL)
	canvas.draw_texture_rect_region(ATLAS,visible,source)

static func _root_anchor(row: Dictionary, at_end: bool) -> Vector2:
	var x: float = float(row.last.x)-4.0 if at_end else float(row.first.x)+4.0
	for piece: Dictionary in row.layout:
		var left: float = float(row.run_left)+float(piece.offset)
		if x < left or x >= left+float(piece.width): continue
		var region: Dictionary = REGIONS[str(piece.name)]
		var column: int = clampi(floori((x-left)/PIXEL),0,int(region.size[0])-1)
		return Vector2(x,float(row.origin_y)+float(region.root_anchor_y_by_x[column])*PIXEL)
	return Vector2(x,float(row.first.y))

static func _draw_connections(canvas: Node2D, joins: Array[Dictionary], solids: Array[Rect2]) -> void:
	for a: Dictionary in joins:
		for b: Dictionary in joins:
			if a == b or a.face != b.face: continue
			var gap: Vector2 = b.first-a.last
			if gap.x < 0.0 or gap.x > 160.0 or absf(gap.y) > 96.0 or gap.length() < PIXEL: continue
			var interrupted: bool = false
			for c: Dictionary in joins:
				if c.face == a.face and c.first.x > a.last.x and c.first.x < b.first.x:
					interrupted = true; break
			if interrupted: continue
			var host_a: Rect2 = a.host
			var host_b: Rect2 = b.host
			# Two explicit native elbow profiles are bound to the actual exposed
			# step of these real solids. Thorn endpoints inside a safe bay do
			# not define a corner. No arbitrary +12 bend or nearest-host search.
			var step_x: float = host_a.end.x
			if is_zero_approx(gap.y) and is_equal_approx(gap.x,130.0) and host_a == host_b:
				_bare_level(canvas,_root_anchor(a,true),_root_anchor(b,false),solids)
				continue
			if not is_equal_approx(step_x,host_b.position.x): continue
			if a.face == "up" and is_equal_approx(gap.x,130.0) and is_equal_approx(gap.y,90.0):
				if not is_equal_approx(host_a.end.y,host_b.end.y): continue
				if not is_equal_approx(host_a.position.y,float(a.last.y)) or not is_equal_approx(host_b.position.y,float(b.first.y)): continue
				if not is_equal_approx(float(a.last.x),step_x-130.0) or not is_equal_approx(float(b.first.x),step_x): continue
				_bare(canvas,"elbow_up90",Vector2(step_x-140.0,float(a.last.y)),solids)
			elif a.face == "down" and is_zero_approx(gap.x) and is_equal_approx(gap.y,40.0):
				# Both original upper solids share a top; their exposed bottoms
				# differ by40wu. The lip width is the real40wu solid.
				if not is_equal_approx(host_a.end.y,float(a.last.y)) or not is_equal_approx(host_b.end.y,float(b.first.y)): continue
				if not is_equal_approx(host_a.position.y,host_b.position.y) or not is_equal_approx(host_b.size.x,40.0): continue
				_bare(canvas,"elbow_down40",Vector2(step_x-16.0,float(a.last.y)-16.0),solids)

static func _bare(canvas: Node2D, name: String, origin: Vector2, solids: Array[Rect2]) -> void:
	var region: Dictionary = REGIONS[name]
	for solid: Rect2 in solids: _blit(canvas,region,origin,_rect(region.root_rect),solid)

static func _bare_level(canvas: Node2D, first: Vector2, last: Vector2, solids: Array[Rect2]) -> void:
	var length: float = last.x-first.x
	if length <= 0.0: return
	var count: int = ceili(length/24.0)
	var limit := Rect2(Vector2(first.x,minf(first.y,last.y)-16.0),Vector2(length,absf(last.y-first.y)+32.0))
	var region: Dictionary = REGIONS.bare_short
	for i: int in count:
		var point: Vector2 = first.lerp(last,float(i)/float(count)).snapped(Vector2.ONE*PIXEL)
		for solid: Rect2 in solids: _blit(canvas,region,point-Vector2(0,8),_rect(region.root_rect),solid.intersection(limit))

static func _point(raw: Array) -> Vector2:
	return Vector2(float(raw[0]),float(raw[1]))

static func _rect(raw: Array) -> Rect2:
	return Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
