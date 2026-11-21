class_name TerrainPaint
extends RefCounted
## Optional appearance protocol on schema-3 room documents.
static func validate(paint: Dictionary) -> String:
	if paint.is_empty(): return ""
	for key: String in paint:
		if key not in ["version", "seed", "regions", "surfaces"]: return "terrain_field_unknown:"+key
	if paint.get("version") != 1: return "terrain_version_unknown"
	if not WorldRoomValidation.number(paint.get("seed", 0)) or float(paint.get("seed", 0)) != floorf(float(paint.get("seed", 0))): return "terrain_seed_invalid"
	var ids: Dictionary = {}
	for field: String in ["regions", "surfaces"]:
		if not paint.get(field, []) is Array: return "terrain_array_required:"+field
		for row: Variant in paint.get(field, []):
			if not row is Dictionary: return "terrain_row_invalid"
			var id := str(row.get("id", ""))
			if id.is_empty() or ids.has(id): return "terrain_id_invalid"
			ids[id] = true
			if not WorldRoomValidation.rectangle(row.get("bounds")): return "terrain_bounds_invalid"
			for value: Variant in row.bounds:
				if float(value) != floorf(float(value)): return "terrain_pixel_alignment_required"
			if not WorldRoomValidation.number(row.get("priority", 0)) or float(row.get("priority", 0)) != floorf(float(row.get("priority", 0))): return "terrain_priority_invalid"
			var keys := ["id", "bounds", "priority", "material_id"] if field == "regions" else ["id", "bounds", "priority", "surface_id", "material_id", "facing"]
			for key: String in row:
				if key not in keys: return "terrain_row_field_unknown:"+key
			if field == "regions" or row.get("surface_id") == "material":
				if not TerrainMaterialRegistry.known(str(row.get("material_id", ""))): return "terrain_material_unknown"
			if field == "surfaces":
				if row.get("surface_id") not in ["bare", "material"]: return "terrain_surface_unknown"
				if row.get("facing") not in ["up", "down", "left", "right"]: return "terrain_surface_facing_invalid"
	return ""

static func ordered(rows: Array) -> Array:
	var result := rows.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("priority", 0)) == int(b.get("priority", 0)): return str(a.id) < str(b.id)
		return int(a.get("priority", 0)) < int(b.get("priority", 0)))
	return result

## Editing is transactional: the original document remains intact on refusal.
static func with_paint(document: Dictionary, paint: Dictionary) -> Dictionary:
	var error := validate(paint)
	if not error.is_empty(): return {"error":error}
	var result := document.duplicate(true)
	result.root.properties["terrain_paint"] = paint.duplicate(true)
	return {"document":result}
