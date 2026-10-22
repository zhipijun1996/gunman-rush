class_name ForestBibleThornSurfaces
extends RefCounted
## V15-only growth on real solid faces. No new support or damage rectangle.
## Retires one isolated prototype strip; recorded v13/v14 factories stay intact.
const VERSION := "forest-bible-thorn-covered-platforms-v1"
const RETIRED_LOCAL := [82.0, 100.0, 790.0, 18.0]
const RETIRE_REASON := "unhosted_prototype_strip_210wu_below_broken_arch"

static func install(m: Dictionary) -> bool:
	var instance: Dictionary = {}
	for row: Dictionary in m.get("geometry_instances", []):
		if row.id == "broken_arch": instance = row; break
	if instance.is_empty() or instance.get("local_geometry", {}).get("dangers") != [RETIRED_LOCAL]: return false
	var indices: Array = instance.get("danger_indices", [])
	if indices.size() != 1 or int(indices[0]) != m.dangers.size()-1: return false
	var index := int(indices[0])
	var offset: Array = instance.translation
	var expected := [float(offset[0])+82.0, float(offset[1])+100.0, 790.0, 18.0]
	if m.dangers[index] != expected or m.danger_presentations.size() != m.dangers.size(): return false
	# Keep the original factory and all its platform/anchor/action data. The
	# deliberate v15 delta is serialized, not hidden in presentation or a reader.
	var retired := {"instance_id":"broken_arch", "reason":RETIRE_REASON,
		"source_local_dangers":[RETIRED_LOCAL.duplicate()],
		"source_global_dangers":[expected], "source_danger_indices":[index]}
	m.dangers.remove_at(index)
	m.danger_presentations.remove_at(index)
	instance.local_geometry.dangers = []
	instance.danger_indices = []
	instance.thorn_surface_derivation = retired.duplicate(true)
	m.thorn_surface_contract = {"version":VERSION, "retired_prototype":retired,
		"physical_delta":"remove_exact_unhosted_prototype_strip_only",
		"existing_supports_unchanged":true}
	m.thorn_surfaces = _surfaces(m)
	return validate(m)

static func validate(m: Dictionary) -> bool:
	var contract: Variant = m.get("thorn_surface_contract")
	if not contract is Dictionary or contract.get("version") != VERSION: return false
	if contract.get("physical_delta") != "remove_exact_unhosted_prototype_strip_only" or contract.get("existing_supports_unchanged") != true: return false
	var surfaces: Variant = m.get("thorn_surfaces")
	if not surfaces is Array or surfaces.size() != m.get("dangers", []).size() or surfaces.is_empty(): return false
	var expected := _surfaces(m)
	return expected.size() == surfaces.size() and RandomStageGenerator.new()._same_data(expected,surfaces)

static func _surfaces(m: Dictionary) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index: int in m.get("dangers", []).size():
		var hazard := _rect(m.dangers[index])
		var display: Dictionary = m.danger_presentations[index]
		var structure := str(display.get("host_structure_id", ""))
		var face := str(display.get("facing", ""))
		var segments: Array[Dictionary] = []
		if structure == "hollow" and face in ["up", "down"]:
			# Actual adjacent union, including the 40wu elbow lips and cap.
			# Each segment is tied to its own real solid, not the nearest label.
			var seam := hazard.position.y if face == "down" else hazard.end.y
			for row: Dictionary in m.platforms:
				if row.get("structure_id") != "hollow" or bool(row.one_way): continue
				var support := _rect(row.rect)
				var edge := support.end.y if face == "down" else support.position.y
				if not is_equal_approx(edge, seam): continue
				var left := maxf(support.position.x, hazard.position.x)
				var right := minf(support.end.x, hazard.end.x)
				if right > left: segments.append({"support_id":str(row.id), "start":[left,seam], "end":[right,seam]})
			segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.start[0]) < float(b.start[0]))
			var cursor := hazard.position.x
			for segment: Dictionary in segments:
				if not is_equal_approx(float(segment.start[0]), cursor): return []
				cursor = float(segment.end[0])
			if not is_equal_approx(cursor, hazard.end.x): return []
		elif structure == "thorn_mouth":
			var host_id := str(display.get("host_support_id", ""))
			var host := _support(m, host_id)
			if not host.has_area(): return []
			if host_id == "thorn_mouth__root_arch":
				face = "down"
				if hazard.position.x < host.position.x or hazard.end.x > host.end.x or hazard.position.y > host.end.y or hazard.end.y <= host.end.y: return []
				segments.append({"support_id":host_id, "start":[hazard.position.x,host.end.y], "end":[hazard.end.x,host.end.y]})
			elif host_id == "thorn_mouth__crown":
				face = "left"
				if hazard.position.y < host.position.y or hazard.end.y > host.end.y or hazard.position.x >= host.position.x or hazard.end.x < host.position.x: return []
				segments.append({"support_id":host_id, "start":[host.position.x,hazard.position.y], "end":[host.position.x,hazard.end.y]})
			else: return []
		else: return []
		if segments.is_empty(): return []
		output.append({"danger_index":index, "face":face, "hazard_rect":m.dangers[index].duplicate(), "segments":segments})
	return output

static func _support(m: Dictionary, id: String) -> Rect2:
	for row: Dictionary in m.platforms:
		if row.id == id and not bool(row.one_way): return _rect(row.rect)
	return Rect2()

static func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
