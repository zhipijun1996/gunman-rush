class_name PlainsPlacePlan
extends RefCounted
## Three measured whole-body places; only translations are applied at assembly.
const VERSION := "plains-places-candidate-v1"
const CONTRACT_PATH := "res://resources/generation/environment_grammar/places_v1.json"
const ATTEMPTS := 4
const ORDERS := [["wind_meadow","postal_valley","lee_court"],["wind_meadow","lee_court","postal_valley"],["postal_valley","wind_meadow","lee_court"],["postal_valley","lee_court","wind_meadow"],["lee_court","wind_meadow","postal_valley"],["lee_court","postal_valley","wind_meadow"]]
const MUTATIONS := ["", "missing-body-art", "invalid-scale", "break-port", "overlap-places", "source-sha-mismatch"]

static func generate(seed_value: String, tuning: PlayerTuning, variant: String = "seeded", mutation: String = "") -> Dictionary:
	if seed_value.is_empty() or tuning == null or tuning.max_jumps < 1 or tuning.max_air_shots < 2:
		return {"ok":false,"error":"Measured places require the actual base jump/two native shots","attempts":0,"rejections":[]}
	if mutation not in MUTATIONS or variant not in ["seeded", "A"]:
		return {"ok":false,"error":"Unknown place variant or mutation","attempts":0,"rejections":[]}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		return {"ok":false,"error":"Invalid measured place catalog","attempts":0,"rejections":[]}
	var catalog: Dictionary = parsed
	var errors := _catalog_errors(catalog)
	if not errors.is_empty(): return {"ok":false,"error":"; ".join(errors),"attempts":0,"rejections":errors}
	var order_rng := RunRandomStream.new(seed_value,"plains_places_order","layout",VERSION)
	var connection_rng := RunRandomStream.new(seed_value,"plains_places_connections","layout",VERSION)
	var first_order := order_rng.next_int(ORDERS.size())
	var recipes: Array = catalog.connection_recipes
	var first_connections := connection_rng.next_int(recipes.size()*recipes.size())
	var rejections: Array = []
	for attempt: int in ATTEMPTS:
		var code := first_connections + attempt
		var order: Array = ORDERS[(first_order + floori(float(code) / float(recipes.size()*recipes.size()))) % ORDERS.size()]
		var connection_code := code % (recipes.size()*recipes.size())
		var chosen: Array = [recipes[connection_code % recipes.size()],recipes[floori(float(connection_code) / float(recipes.size()))]]
		var result := _compile(catalog,seed_value,order,chosen,attempt,mutation)
		if not result.ok:
			rejections.append({"attempt":attempt,"prototype_order":order,"connection_recipes":[chosen[0].id,chosen[1].id],"reason":result.error})
			continue
		var manifest: Dictionary = result.manifest
		manifest.environment_plan.generation = {"attempt":attempt,"attempt_limit":ATTEMPTS,"rejections":rejections.duplicate(true),"fallback_id":"","order_stream_position":order_rng.position(),"connection_stream_position":connection_rng.position()}
		manifest.manifest_hash = PlainsEnvironmentPlan._hash(manifest)
		result.environment_plan = manifest.environment_plan
		result["attempts"] = attempt+1
		result["rejections"] = rejections
		return result
	return {"ok":false,"error":"No admitted measured place combination within bounded attempts; no unverified fallback","attempts":ATTEMPTS,"rejections":rejections}

static func validate_recorded(recorded: Dictionary, tuning: PlayerTuning) -> bool:
	if recorded.get("version") != VERSION or not recorded.get("environment_plan") is Dictionary: return false
	var plan: Dictionary = recorded.environment_plan
	var replay := generate(str(recorded.get("seed","")),tuning,"seeded",str(plan.get("mutation","")))
	return replay.get("ok",false) and recorded.get("manifest_hash") == PlainsEnvironmentPlan._hash(recorded) and replay.manifest.manifest_hash == recorded.manifest_hash

static func create_stage() -> PlainsRegionStage:
	return PlainsEnvironmentPlan.create_stage()

static func _catalog_errors(catalog: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not catalog.get("prototypes") is Dictionary or not catalog.get("connection_recipes") is Array or catalog.connection_recipes.is_empty():
		errors.append("Missing prototypes or connection recipes")
		return errors
	for id: String in ORDERS[0]:
		var prototype: Dictionary = catalog.prototypes.get(id,{})
		if not prototype.get("measurement") is Dictionary:
			errors.append(id+": actual source measurement unavailable")
			continue
		var m: Dictionary = prototype.measurement
		for field: String in ["solid_polygons","surfaces","safe_stands","terrain_instances","route_waypoints","route_forward","route_return"]:
			if not m.get(field) is Array or m[field].is_empty(): errors.append(id+": missing measured "+field)
		for key: String in ["entry_port","exit_port"]:
			if not m.get(key) is Dictionary or not _pair_ok(m[key].get("position")) or _line(m,str(m[key].get("surface_id",""))).size()<2:
				errors.append(id+": invalid measured "+key)
		for body: Dictionary in m.get("terrain_instances",[]):
			errors.append_array(_body_errors(body,m.get("solid_polygons",[])))
			if not _pair_ok(body.get("source_anchor_px")) or not _pair_ok(body.get("world_anchor")) or float(body.get("uniform_scale",0))<=0 or float(body.get("uniform_scale",0))>1:
				errors.append(id+": invalid whole-body scale or anchor")
			if not FileAccess.file_exists(str(body.get("texture",""))): errors.append(id+": whole-body art missing")
	for recipe: Dictionary in catalog.connection_recipes:
		if float(recipe.get("gap_world",0)) not in [160.0,200.0] or float(recipe.get("rise_world",0)) not in [0.0,40.0]: errors.append("Unadmitted connection dimensions")
	return errors

static func _compile(catalog: Dictionary, seed_value: String, order: Array, recipes: Array, attempt: int, mutation: String) -> Dictionary:
	var plan := {"schema_version":1,"version":VERSION,"seed":seed_value,"mutation":mutation,"task_id":"PLAINS-PLACES-01","production_pool":false,"structure_variant":"seeded","contract_sha256":FileAccess.get_sha256(CONTRACT_PATH),"assets_catalog":str(catalog.assets_catalog),"places":[],"place_instances":[],"place_order":[],"prototype_order":order.duplicate(),"solid_polygons":[],"surfaces":[],"attachments":[],"mechanisms":[],"enemies":[],"terrain_instances":[],"layer_instances":[],"route_waypoints":[],"route_forward":[],"route_return":[],"keep_clear":[],"connections":[],"camera":{"zoom":1.25}}
	var offset := Vector2.ZERO
	var previous: Dictionary = {}
	var previous_offset := Vector2.ZERO
	var phase_rng := RunRandomStream.new(seed_value,"plains_places_phases","mechanisms",VERSION)
	var local_measurements: Array[Dictionary] = []
	var extent := Rect2()
	for index: int in order.size():
		var prototype_id: String = order[index]
		var measurement: Dictionary = catalog.prototypes[prototype_id].measurement.duplicate(true)
		var instance_id := "place_%d_%s" % [index,prototype_id]
		if index>0:
			var exit_line := _line(previous,str(previous.exit_port.surface_id))
			var entry_line := _line(measurement,str(measurement.entry_port.surface_id))
			var recipe: Dictionary = recipes[index-1]
			offset = previous_offset + exit_line[-1] - entry_line[0] + Vector2(float(recipe.gap_world),-float(recipe.rise_world))
			if mutation=="overlap-places": offset.x -= float(recipe.gap_world)+400.0
		var prefix := instance_id+"/"
		plan.place_instances.append({"id":instance_id,"prototype_id":prototype_id,"translation":[offset.x,offset.y],"source_measurement_sha256":JSON.stringify(measurement,"",true).sha256_text()})
		plan.place_order.append(instance_id)
		var place := {"id":instance_id,"prototype_id":prototype_id,"label":str(catalog.prototypes[prototype_id].label),"bounds":_rect_move(measurement.bounds,offset),"entry_port":{"id":prefix+"entry","position":_move(measurement.entry_port.position,offset)},"exit_port":{"id":prefix+"exit","position":_move(measurement.exit_port.position,offset)},"safe_stands":[],"focal_anchors":[],"layer_anchors":[],"composition":measurement.get("composition",{}).duplicate(true)}
		for solid: Dictionary in measurement.solid_polygons:
			var item := solid.duplicate(true)
			item.id = prefix+str(solid.id)
			item.place_id = instance_id
			item.points = []
			for point: Array in solid.points: item.points.append(_move(point,offset))
			if item.has("presentation_owner_surface_id"): item.presentation_owner_surface_id = prefix+str(item.presentation_owner_surface_id)
			plan.solid_polygons.append(item)
		for surface: Dictionary in measurement.surfaces:
			var item := surface.duplicate(true)
			item.id = prefix+str(surface.id)
			item.solid_id = prefix+str(surface.solid_id)
			plan.surfaces.append(item)
		for stand: Dictionary in measurement.safe_stands:
			var item := stand.duplicate(true)
			item.id = prefix+str(stand.id)
			item.surface_id = prefix+str(stand.surface_id)
			item.position = _move(stand.position,offset)
			place.safe_stands.append(item)
		for key: String in ["focal_anchors","layer_anchors"]:
			for anchor: Dictionary in measurement.get(key,[]):
				var item := anchor.duplicate(true)
				item.id = prefix+str(anchor.id)
				item.position = _move(anchor.position,offset)
				place[key].append(item)
		for body: Dictionary in measurement.terrain_instances:
			var item := body.duplicate(true)
			item.id = prefix+str(body.id)
			item.place_id = instance_id
			item.solid_id = prefix+str(body.solid_id)
			item.world_anchor = _move(body.world_anchor,offset)
			if mutation=="missing-body-art": item.texture = "res://missing-place-body.png"
			if mutation=="invalid-scale": item.uniform_scale = -1.0
			if mutation=="source-sha-mismatch": item.source_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
			plan.terrain_instances.append(item)
		for key: String in ["attachments","mechanisms","enemies"]:
			for source: Dictionary in measurement.get(key,[]):
				var item := source.duplicate(true)
				item.id = prefix+str(source.id)
				item.place_id = instance_id
				if item.has("area"): item.area = instance_id
				if item.has("surface_id"): item.surface_id = prefix+str(item.surface_id)
				for point_key: String in ["position","origin"]:
					if item.has(point_key): item[point_key] = _move(item[point_key],offset)
				if key=="mechanisms": item.initial_phase = float(phase_rng.next_int(4))/4.0
				plan[key].append(item)
		for waypoint: Dictionary in measurement.route_waypoints:
			var item := waypoint.duplicate(true)
			item.id = prefix+str(waypoint.id)
			item.position = _move(waypoint.position,offset)
			plan.route_waypoints.append(item)
		for clear: Dictionary in measurement.get("keep_clear",[]):
			plan.keep_clear.append({"id":prefix+str(clear.id),"bounds":_rect_move(clear.bounds,offset)})
		plan.places.append(place)
		var r: Array = place.bounds
		var bounds := Rect2(r[0],r[1],r[2],r[3])
		extent = bounds if index==0 else extent.merge(bounds)
		local_measurements.append(measurement)
		previous = measurement
		previous_offset = offset
	# Actual safe standing anchor is distinct from a sloping arrival port.
	plan.spawn = plan.places[0].safe_stands[0].position.duplicate()
	for index: int in order.size():
		var id: String = plan.place_order[index]
		for point_id: String in local_measurements[index].route_forward: plan.route_forward.append(id+"/"+point_id)
		if index<order.size()-1:
			var next_id: String = plan.place_order[index+1]
			var edge_id := "edge_%d" % index
			var recipe: Dictionary = recipes[index]
			var a: Dictionary = plan.places[index]
			var b: Dictionary = plan.places[index+1]
			plan.route_waypoints.append(_waypoint(edge_id+"/forward",b.entry_port.position,"jump_recoil",1))
			plan.route_forward.append(edge_id+"/forward")
			plan.route_waypoints.append(_waypoint(edge_id+"/return",a.exit_port.position,"jump_recoil",-1))
			plan.connections.append({"id":edge_id,"a":a.id,"b":b.id,"condition":"open","kind":"horizontal","bidirectional":true,"path":[a.exit_port.position,b.entry_port.position],"modules":[index,index+1],"recipe_id":recipe.id,"gap_world":recipe.gap_world,"rise_world":recipe.rise_world})
	for index: int in range(order.size()-1,-1,-1):
		for point_id: String in local_measurements[index].route_return: plan.route_return.append(str(plan.place_order[index])+"/"+point_id)
		if index>0: plan.route_return.append("edge_%d/return" % (index-1))
	plan.route_waypoints.append(_waypoint(str(plan.place_order[0])+"/return_spawn",plan.spawn,"arrive",1))
	plan.route_return.append(str(plan.place_order[0])+"/return_spawn")
	if mutation=="break-port": plan.places[1].entry_port.position[1] += 300
	PlainsEnvironmentPlan._resolve_surfaces(plan)
	var errors := _resolved_errors(plan)
	if not errors.is_empty(): return {"ok":false,"error":"; ".join(errors)}
	plan.bounds = [extent.position.x-80,extent.position.y-200,extent.size.x+160,extent.size.y+400]
	plan.route_failure_y = extent.end.y+100
	var reference := Vector2(extent.get_center().x,700)
	plan.layer_instances.append({"id":"shared_far_world","texture":str(catalog.far_layer.texture),"pivot_px":catalog.far_layer.pivot_px,"world_anchor":[reference.x,420],"uniform_scale":1.7,"depth_factor":0.1,"z_index":-80,"camera_reference":[reference.x,reference.y]})
	for index: int in order.size():
		var translation: Array = plan.place_instances[index].translation
		var delta := Vector2(translation[0],translation[1])
		for source: Dictionary in local_measurements[index].get("layer_instances",[]):
			var item := source.duplicate(true)
			item.id = str(plan.place_order[index])+"/"+str(source.id)
			var desired := Vector2(source.world_anchor[0],source.world_anchor[1])+delta
			var camera := Vector2(local_measurements[index].composition.camera_center[0],local_measurements[index].composition.camera_center[1])+delta
			var anchor := desired-(camera-reference)*(1.0-float(source.depth_factor))
			item.world_anchor = [anchor.x,anchor.y]
			item.camera_reference = [reference.x,reference.y]
			plan.layer_instances.append(item)
	var m := {"version":VERSION,"seed":seed_value,"region":"plains","layout_id":"measured_place_grammar_candidate","family":"places_seeded","production_pool":false,"world_bounds":plan.bounds,"spawn":plan.spawn,"areas":[],"nodes":[],"connections":plan.connections,"ground_supports":[],"terminal_exits":[],"rewards":[],"pickups":[],"enemies":plan.enemies,"enemy_drops":{},"merchant_id":"","merchant_position":[1000000,1000000],"boss_arena":[-2000,-2000,1,1],"shot_latch_plan":{"version":"places_no_latches_v1","latches":[]},"environment_plan":plan,"streams":{"order":"plains_places_order","connections":"plains_places_connections","phases":"plains_places_phases","phase_position":phase_rng.position(),"algorithm":RunRandomStream.ALGORITHM}}
	var placement_points: Array[Vector2] = []
	for place: Dictionary in plan.places:
		m.areas.append({"id":place.id,"position":place.entry_port.position,"role":"junction","identity":place.prototype_id,"label":place.label})
		m.nodes.append({"id":"environment/"+str(place.id),"place_id":place.id,"module_id":"environment_polygon","offset":[0,0],"mirrored":false})
		for stand: Dictionary in place.safe_stands: placement_points.append(Vector2(stand.position[0],stand.position[1]))
	var drops := EnemyDropService.new()
	if not drops.configure(seed_value,"plains_region"): return {"ok":false,"error":"Original drop service rejected seed"}
	for enemy: Dictionary in plan.enemies: m.enemy_drops[enemy.id] = drops.settle(StringName(enemy.id))
	return {"ok":true,"manifest":m,"environment_plan":plan,"placement_points":placement_points,"boss_arena":Rect2(-2000,-2000,1,1),"stage_generator_version":VERSION,"encounter_plan":{"version":VERSION,"enemies":plan.enemies},"shot_latch_plan":m.shot_latch_plan}

static func _resolved_errors(plan: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var ids: Dictionary = {}
	for solid: Dictionary in plan.solid_polygons:
		if ids.has(solid.id): errors.append("Duplicate resolved collision id")
		ids[solid.id] = true
		var points := PackedVector2Array()
		for point: Array in solid.points: points.append(Vector2(point[0],point[1]))
		if Geometry2D.triangulate_polygon(points).is_empty(): errors.append("Non-simple measured collision: "+str(solid.id))
	for body: Dictionary in plan.terrain_instances:
		errors.append_array(_body_errors(body,plan.solid_polygons))
		if float(body.uniform_scale)<=0 or float(body.uniform_scale)>1: errors.append("invalid-scale")
		if not FileAccess.file_exists(str(body.texture)): errors.append("missing-body-art")
		if not ids.has(body.solid_id): errors.append("Body art references missing collision")
	for index: int in plan.places.size()-1:
		var a: Dictionary = plan.places[index]
		var b: Dictionary = plan.places[index+1]
		var recipe: Dictionary = plan.connections[index]
		var dx := float(b.entry_port.position[0])-float(a.exit_port.position[0])
		var dy := absf(float(b.entry_port.position[1])-float(a.exit_port.position[1]))
		if dx<=float(recipe.gap_world) or dx>400 or dy>90: errors.append("Incompatible measured departure/receiver ports")
	for a: Dictionary in plan.solid_polygons:
		for b: Dictionary in plan.solid_polygons:
			if str(a.place_id)>=str(b.place_id): continue
			var pa := PackedVector2Array()
			var pb := PackedVector2Array()
			for p: Array in a.points: pa.append(Vector2(p[0],p[1]))
			for p: Array in b.points: pb.append(Vector2(p[0],p[1]))
			if not Geometry2D.intersect_polygons(pa,pb).is_empty(): errors.append("Measured place collision overlap")
	return errors

static func _body_errors(body: Dictionary, solids: Array) -> Array[String]:
	var errors: Array[String] = []
	var scale := float(body.get("uniform_scale",0))
	var admitted: Variant = body.get("admitted_scales")
	var admitted_scale := false
	if admitted is Array:
		for value: Variant in admitted:
			if not (value is int or value is float) or float(value) not in [0.3,0.4,0.6]:
				errors.append("invalid-scale: unmeasured admitted scale")
			elif absf(scale-float(value))<0.00000001: admitted_scale = true
	if not admitted_scale or not is_finite(scale): errors.append("invalid-scale: outside finite measured scales")
	var path := str(body.get("texture",""))
	if not FileAccess.file_exists(path):
		errors.append("missing-body-art")
	elif str(body.get("source_sha256","")) != FileAccess.get_sha256(path):
		errors.append("source-sha-mismatch: actual whole-body source differs")
	var profile: Variant = body.get("source_profile_px")
	if not profile is Array or profile.size()<2 or not _pair_ok(body.get("source_anchor_px")) or not _pair_ok(body.get("world_anchor")):
		errors.append("Source standing profile/anchors unavailable")
		return errors
	var solid: Dictionary = {}
	for candidate: Dictionary in solids:
		if str(candidate.get("id",""))==str(body.get("solid_id","")): solid = candidate
	if solid.is_empty() or not solid.get("points") is Array or solid.points.size()<profile.size():
		errors.append("Measured standing profile has no actual collision")
		return errors
	var source_anchor := Vector2(body.source_anchor_px[0],body.source_anchor_px[1])
	var world_anchor := Vector2(body.world_anchor[0],body.world_anchor[1])
	for index: int in profile.size():
		if not _pair_ok(profile[index]) or not _pair_ok(solid.points[index]):
			errors.append("Non-finite measured standing point")
			continue
		var source := Vector2(profile[index][0],profile[index][1])
		var expected := world_anchor+(source-source_anchor)*scale
		var actual := Vector2(solid.points[index][0],solid.points[index][1])
		if actual.distance_to(expected)>maxf(0.0001,absf(scale)):
			errors.append("source-profile-mismatch: collision drift exceeds one source pixel")
	return errors

static func _line(m: Dictionary, id: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	for surface: Dictionary in m.get("surfaces",[]):
		if str(surface.id)!=id: continue
		for solid: Dictionary in m.get("solid_polygons",[]):
			if str(solid.id)!=str(surface.solid_id): continue
			for raw: Variant in surface.edge_indices:
				var index := int(raw)
				if index<0 or index>=solid.points.size(): return PackedVector2Array()
				if result.is_empty(): result.append(Vector2(solid.points[index][0],solid.points[index][1]))
				var next: int = (index+1)%solid.points.size()
				result.append(Vector2(solid.points[next][0],solid.points[next][1]))
	return result

static func _pair_ok(value: Variant) -> bool:
	return value is Array and value.size()==2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and is_finite(float(value[0])) and is_finite(float(value[1]))

static func _move(point: Array, delta: Vector2) -> Array: return [float(point[0])+delta.x,float(point[1])+delta.y]
static func _rect_move(rect: Array, delta: Vector2) -> Array: return [float(rect[0])+delta.x,float(rect[1])+delta.y,rect[2],rect[3]]
static func _waypoint(id: String, position: Array, intent: String, direction: int) -> Dictionary:
	return {"id":id,"position":position.duplicate(),"intent":intent,"direction":direction,"tolerance":22,"require_grounded":true}
