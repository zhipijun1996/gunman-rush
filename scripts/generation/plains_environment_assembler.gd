class_name PlainsEnvironmentAssembler
extends PlainsRegionAssembler

func build(recorded: Dictionary, tuning: PlayerTuning) -> Dictionary:
	var replay_ok := PlainsPlacePlan.validate_recorded(recorded,tuning) if recorded.get("version") == PlainsPlacePlan.VERSION else PlainsEnvironmentPlan.validate_recorded(recorded,tuning)
	if not is_inside_tree() or not modules.is_empty() or not replay_ok:
		return {"ok": false, "error": "Environment candidate failed exact source replay"}
	manifest = recorded.duplicate(true)
	var plan: Dictionary = manifest.environment_plan
	var b: Array = plan.bounds
	bounds = Rect2(b[0],b[1],b[2],b[3])
	for place: Dictionary in plan.places:
		var module := PlainsEnvironmentModule.new()
		module.name = str(place.id)
		module.authoring_debug = false
		module.definition = PlatformingModuleDefinition.new()
		var d := module.definition
		d.module_id = StringName("environment/"+str(place.id))
		d.world_bounds = Rect2(place.bounds[0],place.bounds[1],place.bounds[2],place.bounds[3])
		d.entry_port = _port(place.entry_port)
		d.exit_port = _port(place.exit_port)
		for stand: Dictionary in place.safe_stands: d.anchors.append(Vector2(stand.position[0],stand.position[1]))
		for solid: Dictionary in plan.solid_polygons:
			if str(solid.place_id)==str(place.id): module.solids.append(solid)
		for mechanism: Dictionary in plan.mechanisms:
			if str(mechanism.place_id)!=str(place.id): continue
			var saw := ModuleSawDefinition.new()
			saw.source_id = StringName(mechanism.id)
			saw.origin = Vector2(mechanism.origin[0],mechanism.origin[1])
			saw.travel = Vector2(mechanism.travel[0],mechanism.travel[1])
			saw.radius = float(mechanism.radius)
			saw.period = float(mechanism.period)
			saw.initial_phase = float(mechanism.initial_phase)
			d.saws.append(saw)
		if region_state != null: module.clock = float(region_state.clocks.get("environment/"+str(place.id),0.0))
		modules.append(module)
		add_child(module)
	return {"ok": true}

func _port(data: Dictionary) -> PlatformingModulePort:
	var port := PlatformingModulePort.new()
	port.port_id = StringName(data.id)
	port.position = Vector2(data.position[0],data.position[1])
	return port

func world_exits() -> Array[Dictionary]: return []

func world_anchors() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for module: PlatformingModule in modules: result.append_array(module.world_anchors())
	return result

func _draw() -> void: pass
