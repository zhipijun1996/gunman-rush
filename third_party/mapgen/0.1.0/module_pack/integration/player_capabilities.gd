extends RefCounted
## Binding layer only. No motion parameters or resource grants are changed here.
const SUPPORTED := ["move","jump","shot_recoil","double_jump","grapple","wall_climb"]

static func validate(values: Variant) -> Dictionary:
	if not values is Array:
		return {"ok":false,"reason":"capabilities_must_be_array"}
	var seen: Dictionary={}
	for value: Variant in values:
		if not value is String or value not in SUPPORTED:
			return {"ok":false,"reason":"unsupported_capability/"+str(value)}
		if seen.has(value):return {"ok":false,"reason":"duplicate_capability/"+str(value)}
		seen[value]=true
	if seen.has("double_jump") and not seen.has("jump"):
		return {"ok":false,"reason":"missing_dependency/double_jump/jump"}
	if seen.has("wall_climb") and not seen.has("move"):
		return {"ok":false,"reason":"missing_dependency/wall_climb/move"}
	var canonical: Array=[]
	for id: String in SUPPORTED:
		if seen.has(id):canonical.append(id)
	return {"ok":true,"capabilities":canonical}

static func apply(actor: PlayerController, values: Array) -> Dictionary:
	var validation:=validate(values)
	if not validation.ok:return validation
	# Explicitly revoke legacy profile grants before applying this exact snapshot.
	actor.traversal.grant(&"double_jump",false)
	actor.traversal.grant(&"grapple",false)
	actor.traversal.grant(&"wall_climb",false)
	actor.jump_ability.enabled="jump" in values
	actor.shoot_ability.enabled="shot_recoil" in values
	if "double_jump" in values:actor.traversal.grant(&"double_jump")
	if "grapple" in values:actor.traversal.grant(&"grapple")
	if "wall_climb" in values:actor.traversal.grant(&"wall_climb")
	return {"ok":true,"snapshot":snapshot(actor,values)}

static func snapshot(actor: PlayerController, values: Array) -> Dictionary:
	return {"declared":values.duplicate(),"move_enabled":"move" in values,
		"jump_enabled":actor.jump_ability.enabled,"shoot_enabled":actor.shoot_ability.enabled,
		"maximum_jumps":actor.jump_ability.maximum_jumps(),"double_enabled":actor.traversal.double_enabled,
		"grapple_enabled":actor.traversal.hook_enabled,"wall_enabled":actor.traversal.wall_enabled,
		"base_max_air_shots":actor.motor.tuning.max_air_shots,"hook_range":actor.traversal.definition.hook_range}

static func indices(raw: Variant, count: int) -> Dictionary:
	if not raw is Array:return {"ok":false,"reason":"indices_must_be_array"}
	var result: Dictionary={}
	for value: Variant in raw:
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)):
			return {"ok":false,"reason":"index_must_be_finite_integer"}
		var index:=int(value)
		if index<0 or index>=count:return {"ok":false,"reason":"index_out_of_bounds"}
		result[index]=true
	return {"ok":true,"indices":result}
