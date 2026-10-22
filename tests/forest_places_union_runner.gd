extends SceneTree
## New contour source contract only. Does not alter the shared union algorithm.
var output := "res://build/forest-v18/union.json"
var failures: Array[String] = []
var assertions := 0
# Actual v18.4 native contour signatures, round08/union.json. V18.5 only
# removes colliders wholly covered by the named window lip; its solid union
# must remain exactly the same. This does not pin future geometry versions.
const V18_4_CONTOURS := ["caf3679fb27adc26fd2d9bb060bf9bcf203e0c9dab0a9b15490a747e0a13699a","d27d71fb85308c3c93068916832a7b8e4c2aae6f409171d7cf3374cbbaf0b9a9"]
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	assertions += 1
	if not ok: failures.append(message)
func run() -> void:
	var rows: Array = []
	var candidates: Array[Dictionary] = []
	for variant: int in [0,1]:
		candidates.append(ForestExplorationPlaces.build("seven_bough_reveal",variant))
		candidates.append(ForestExplorationPlaces.build("z_descending_return",variant))
		candidates.append(ForestExplorationFallenTrunk.build(variant))
		candidates.append(ForestExplorationFruitCrossing.build(variant))
	for m: Dictionary in candidates:
		var variant := int(m.variant)
		var solids: Array[Rect2] = []
		for body: Dictionary in m.platforms:
			if bool(body.one_way): continue
			var r := Rect2(body.rect[0],body.rect[1],body.rect[2],body.rect[3])
			solids.append(r)
			for coordinate: float in [r.position.x,r.position.y,r.end.x,r.end.y]:
				check(is_equal_approx(coordinate,snappedf(coordinate,2.0)),"new contour endpoints must share the 2wu pixel lattice/"+str(body.id))
		var plan := UnderworldTerrain.geometry_plan(solids)
		if m.id == "seven_bough_reveal":
			check(edge_signature(plan.edges)==V18_4_CONTOURS[variant],"removing redundant window colliders preserves actual v18.4 solid union/"+str(variant))
		var interior: Array = []
		for edge: Vector4 in plan.edges:
			var a := Vector2(edge.x,edge.y)
			var b := Vector2(edge.z,edge.w)
			if a.distance_to(b)<0.1: continue
			var middle := (a+b)*0.5
			var normal := Vector2(0.0,0.05) if a.y==b.y else Vector2(0.05,0.0)
			if occupied(solids,middle+normal) and occupied(solids,middle-normal): interior.append([edge.x,edge.y,edge.z,edge.w])
		check(interior.is_empty(),"new union cannot contain internal exposed edges/variant"+str(variant))
		var divided: Array[Rect2] = []
		for r: Rect2 in solids:
			var half := r.size.x*0.5
			divided.append(Rect2(r.position,Vector2(half,r.size.y)))
			divided.append(Rect2(r.position+Vector2(half,0),Vector2(r.size.x-half,r.size.y)))
		divided.reverse()
		divided.append(divided[0])
		var split_plan := UnderworldTerrain.geometry_plan(divided)
		check(edge_signature(plan.edges)==edge_signature(split_plan.edges),"equivalent split/order/duplicate keeps canonical contour/"+str(variant))
		rows.append({"module_id":str(m.id),"variant":variant,"solid_count":solids.size(),"edge_count":plan.edges.size(),"internal_edges":interior,"canonical_signature":edge_signature(plan.edges)})
	# A known bad internal face is rejected by the actual predicate.
	var filled: Array[Rect2] = [Rect2(0,0,64,64)]
	check(occupied(filled,Vector2(32,32.05)) and occupied(filled,Vector2(32,31.95)),"negative control detects a face drawn inside a filled body")
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"assertions":assertions,"failures":failures,"rows":rows.filter(func(row: Dictionary) -> bool: return row.module_id=="seven_bough_reveal"),"expansion_rows":rows.filter(func(row: Dictionary) -> bool: return row.module_id!="seven_bough_reveal"),"scope":"new_contour_source_lattice_and_canonical_union_not_art_acceptance"}))
	print("FOREST PLACES UNION: %s assertions, %s failures" % [assertions,failures.size()])
	quit(0 if failures.is_empty() else 1)
func occupied(solids: Array[Rect2],at: Vector2) -> bool:
	for r: Rect2 in solids:
		if r.has_point(at): return true
	return false
func edge_signature(edges: PackedVector4Array) -> String:
	var keys: Array[String] = []
	for edge: Vector4 in edges: keys.append(JSON.stringify([edge.x,edge.y,edge.z,edge.w]))
	keys.sort()
	return JSON.stringify(keys).sha256_text()
