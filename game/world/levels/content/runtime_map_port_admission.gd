class_name RuntimeMapPortAdmission
extends RefCounted
## v2 Ports are geometric apertures. Native ports/anchors are supported player
## body centres. Resolve the latter from unchanged materialized source geometry;
## authored entry/exit helpers remain provenance, never admission requirements.
const PLAYER := preload("res://game/player/player.tscn")
const POLICY := "runtime-map-used-port-banks/1"

static func resolve(definition: PlatformingModuleDefinition, content: Dictionary, instance: Dictionary, instances: Dictionary, connections: Array, request: LevelRequest, world_spawn: Vector2) -> Dictionary:
	var half := _formal_body_half()
	if half == Vector2.ZERO: return _reject("formal player rectangle is unavailable")
	if request.capabilities.has("collision_half_extents"):
		var raw: Variant = request.capabilities.collision_half_extents
		if not LevelContentValidation.point(raw) or Vector2(raw[0],raw[1]) != half:
			return _reject("actual host body differs from native module standing validation")
	var banks: Array[Dictionary] = []
	var anchors: Array[Vector2] = []
	var ids: Array[String] = []
	for value: Variant in instance.connected_port_ids: ids.append(str(value))
	ids.sort()
	for id: String in ids:
		var port := _port(instance,id)
		var link_error := _link_error(instance,port,instances,connections)
		if not link_error.is_empty(): return _reject(link_error)
		if port.permission != "INOUT": return _reject("ports."+id+".permission: host capability unsupported for legal "+str(port.permission)+"; used ports require INOUT")
		var bank := _bank(definition,content,port,half)
		if not bank.ok: return _reject("ports."+id+"."+str(bank.error))
		banks.append({"port_id":id,"face":port.face,"surface":port.surface,"body_center_pixels":[bank.point.x,bank.point.y],"support_platform_index":bank.platform_index,"scope":"static_body_clearance_and_owned_landing_only"})
		if bank.point not in anchors: anchors.append(bank.point)
	if anchors.is_empty(): return _reject("no used port has an admitted bank")
	# A terminal with one used geometric port still needs an actual interior
	# body witness for the native two-canonical-port contract. Prefer its real
	# requested spawn; only retained, independently valid source helpers follow.
	var origin := Vector2(instance.origin_blocks[0],instance.origin_blocks[1])*128.0
	var local_spawn := world_spawn-origin
	if definition.world_bounds.has_point(local_spawn) and _clear_standing(definition,content,local_spawn,half) and local_spawn not in anchors:
		if anchors.size()==1: anchors.push_front(local_spawn)
		else: anchors.append(local_spawn)
	if anchors.size() == 1:
		for key: String in ["entry_port","exit_port"]:
			var raw: Array = content[key]
			var point := Vector2(raw[0],raw[1])
			if point not in anchors and _clear_standing(definition,content,point,half): anchors.append(point)
	if anchors.size() < 2: return _reject("used port has no distinct supported interior body witness")
	var entry := PlatformingModulePort.new()
	entry.port_id = &"admitted_body_entry"
	entry.position = anchors[0]
	var finish := PlatformingModulePort.new()
	finish.port_id = &"admitted_body_exit"
	finish.position = anchors[1]
	entry.direction = (finish.position-entry.position).normalized()
	finish.direction = entry.direction
	definition.entry_port = entry
	definition.exit_port = finish
	definition.anchors.assign(anchors)
	definition.set_meta("runtime_map_v2_port_admission",{"policy":POLICY,"body_half_extents":[half.x,half.y],"used_ports":banks,"neighbor_traversal":"NOT_CERTIFIED_BY_STATIC_ADMISSION"})
	return {"ok":true,"error":""}

static func _bank(definition: PlatformingModuleDefinition, content: Dictionary, port: Dictionary, half: Vector2) -> Dictionary:
	var horizontal: bool = port.face in ["LEFT","RIGHT"] and port.surface == "ROCK"
	var upper: bool = port.face == "TOP" and port.surface == "ONE_WAY_PLATFORM"
	if not horizontal and not upper: return _reject("host capability unsupported for used face/surface "+str(port.face)+"/"+str(port.surface))
	var aperture := Vector2(port.local_position_pixels[0],port.local_position_pixels[1])
	var candidates: Array[Dictionary] = []
	for index: int in content.platforms.size():
		var raw: Array = content.platforms[index]
		var platform := Rect2(raw[0],raw[1],raw[2],raw[3])
		if (index in content.one_way_platform_indices) != upper: continue
		if platform.size.x < half.x*2.0: continue
		var point := Vector2(clampf(aperture.x,platform.position.x+half.x,platform.end.x-half.x),platform.position.y-half.y)
		if horizontal:
			if port.face == "LEFT" and not is_zero_approx(platform.position.x): continue
			if port.face == "RIGHT" and not is_equal_approx(platform.end.x,definition.world_bounds.end.x): continue
			point.x = platform.position.x+half.x if port.face == "LEFT" else platform.end.x-half.x
			# The output locates an aperture on one actual 128-pixel boundary
			# cell. This bounds the search; geometry supplies the floor height.
			if point.y-half.y < aperture.y-64.0 or point.y+half.y > aperture.y+64.0: continue
		else:
			if point.x-half.x < aperture.x-64.0 or point.x+half.x > aperture.x+64.0 or point.y < half.y or point.y+half.y > 128.0: continue
		if not _clear_standing(definition,content,point,half): continue
		if not _approach_clear(definition,content,point,port,half): continue
		# Prefer a retained authored helper only after it independently passes
		# this exact used aperture and unchanged native collision validation.
		for key: String in ["entry_port","exit_port"]:
			var authored: Array = content[key]
			var helper := Vector2(authored[0],authored[1])
			var near := absf(helper.x-aperture.x)<=128.0 and absf(helper.y-aperture.y)<=64.0 if horizontal else absf(helper.x-aperture.x)<=64.0 and helper.y<=128.0
			if near and is_equal_approx(helper.y,point.y) and _clear_standing(definition,content,helper,half) and _approach_clear(definition,content,helper,port,half): point = helper
		candidates.append({"point":point,"platform_index":index,"distance":point.distance_squared_to(aperture)})
	if candidates.is_empty(): return _reject("no clear supported body landing at actual used aperture")
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance<b.distance if a.distance!=b.distance else a.platform_index<b.platform_index)
	return {"ok":true,"error":"","point":candidates[0].point,"platform_index":candidates[0].platform_index}

static func _clear_standing(definition: PlatformingModuleDefinition, content: Dictionary, point: Vector2, half: Vector2) -> bool:
	# Reuse the authoritative original module standing/body/danger/envelope
	# checks. This does not redefine native geometry or player physics.
	return definition._standing_point(point) and _gate_clear(Rect2(point-half,half*2.0),content)

static func _approach_clear(definition: PlatformingModuleDefinition, content: Dictionary, point: Vector2, port: Dictionary, half: Vector2) -> bool:
	var at := point
	match str(port.face):
		"LEFT": at.x = half.x
		"RIGHT": at.x = definition.world_bounds.end.x-half.x
		"TOP": at.y = half.y
		_: return false
	var sweep := Rect2(point-half,half*2.0).merge(Rect2(at-half,half*2.0))
	for platform: Rect2 in definition.platforms:
		if platform.intersects(sweep): return false
	for danger: Rect2 in definition.static_dangers():
		if danger.intersects(sweep.grow(8.0)): return false
	for saw: ModuleSawDefinition in definition.saws:
		if saw.envelope().intersects(sweep.grow(8.0)): return false
	for ferry: ModuleMovingPlatformDefinition in definition.ferries:
		if ferry.envelope().intersects(sweep.grow(8.0)): return false
	return _gate_clear(sweep,content)

static func _gate_clear(body: Rect2, content: Dictionary) -> bool:
	for latch: Dictionary in content.latches:
		var raw: Array = latch.gate
		if Rect2(raw[0],raw[1],raw[2],raw[3]).intersects(body): return false
	return true

static func _link_error(instance: Dictionary, port: Dictionary, instances: Dictionary, connections: Array) -> String:
	var matches: Array[Dictionary] = []
	for raw: Variant in connections:
		if not raw is Dictionary or not raw.get("a") is Dictionary or not raw.get("b") is Dictionary: return "connections: malformed endpoint"
		if (raw.a.get("instance_id")==instance.id and raw.a.get("port_id")==port.id) or (raw.b.get("instance_id")==instance.id and raw.b.get("port_id")==port.id): matches.append(raw)
	if matches.size()!=1: return "ports."+str(port.id)+".connections: expected one actual used-port connection"
	var edge: Dictionary = matches[0]
	if not LevelContentValidation.point(edge.get("position_pixels")) or edge.get("surface")!=port.surface or edge.get("condition","open")!="open": return "ports."+str(port.id)+".connections: surface/position/condition mismatch"
	var world := Vector2(instance.origin_blocks[0],instance.origin_blocks[1])*128.0+Vector2(port.local_position_pixels[0],port.local_position_pixels[1])
	if world!=Vector2(edge.position_pixels[0],edge.position_pixels[1]): return "ports."+str(port.id)+".connections: actual seam position differs"
	var peer: Dictionary = edge.b if edge.a.instance_id==instance.id else edge.a
	if not instances.get(peer.get("instance_id")) is Dictionary: return "ports."+str(port.id)+".connections: peer missing"
	var other: Dictionary = instances[peer.instance_id]
	if not other.get("ports") is Array or not LevelContentValidation.point(other.get("origin_blocks")): return "ports."+str(port.id)+".connections: malformed peer"
	var other_port := _port(other,str(peer.get("port_id","")))
	var opposite := {"LEFT":"RIGHT","RIGHT":"LEFT","TOP":"BOTTOM","BOTTOM":"TOP"}
	if other_port.is_empty() or other_port.get("face")!=opposite[port.face] or other_port.get("surface")!=port.surface or not LevelContentValidation.point(other_port.get("local_position_pixels")): return "ports."+str(port.id)+".connections: peer face/surface/aperture mismatch"
	if other_port.get("permission") not in ["INPUT","OUTPUT","INOUT"]: return "ports."+str(port.id)+".connections: peer permission invalid protocol value"
	if other_port.permission!="INOUT": return "ports."+str(port.id)+".connections: host capability unsupported for legal "+str(other_port.permission)+" peer permission"
	if not other.get("connected_port_ids") is Array or other_port.id not in other.connected_port_ids: return "ports."+str(port.id)+".connections: peer port is not connected"
	if Vector2(other.origin_blocks[0],other.origin_blocks[1])*128.0+Vector2(other_port.local_position_pixels[0],other_port.local_position_pixels[1])!=world: return "ports."+str(port.id)+".connections: peer world position differs"
	return ""

static func _port(instance: Dictionary, id: String) -> Dictionary:
	for raw: Variant in instance.ports:
		if raw is Dictionary and raw.get("id")==id: return raw
	return {}

static func _formal_body_half() -> Vector2:
	var state := PLAYER.get_state()
	for node: int in state.get_node_count():
		if state.get_node_name(node)!=&"CollisionShape2D" or str(state.get_node_path(node)).trim_prefix("./")!="CollisionShape2D": continue
		for property: int in state.get_node_property_count(node):
			if state.get_node_property_name(node,property)!=&"shape": continue
			var shape: Variant = state.get_node_property_value(node,property)
			if shape is RectangleShape2D: return shape.size*0.5
	return Vector2.ZERO

static func _reject(error: String) -> Dictionary:
	return {"ok":false,"error":error}
