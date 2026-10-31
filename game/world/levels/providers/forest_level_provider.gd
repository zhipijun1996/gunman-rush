class_name ForestLevelProvider
extends RefCounted

static func load_level(request: LevelRequest) -> LevelBuildResult:
	var seed_value := request.root_seed+"/thorn_forest/map_%s" % request.map_index
	var capabilities := request.capabilities.duplicate(true)
	var generated := ThornForestRegionGenerator.new().generate(seed_value,request.tuning,request.map_index,capabilities)
	if not request.expected_hash.is_empty() and generated.ok and request.expected_hash!=generated.manifest.manifest_hash:
		var recorded_version := ""
		for recorded: Dictionary in ThornForestRegionGenerator.recorded_variants():
			var prior_capability := capabilities.duplicate(true)
			prior_capability.forest_layout_version=recorded.layout
			prior_capability.forest_v9_north_return=recorded.get("north_return",true)
			var prior := ThornForestRegionGenerator.new().generate_version(recorded.version,seed_value,request.tuning,request.map_index,prior_capability)
			if prior.ok and prior.manifest.manifest_hash==request.expected_hash:
				generated=prior
				recorded_version=recorded.version
				capabilities.forest_layout_version=str(prior.manifest.get("layout_version",ThornForestRegionGenerator.CURRENT_DEPTH_LAYOUT))
				capabilities.forest_v9_north_return=bool(prior_capability.forest_v9_north_return)
				break
		if recorded_version.is_empty(): generated={"ok":false,"error":"Recorded forest hash does not match a supported content version"}
		else: capabilities.forest_content_version=recorded_version
	if not generated.ok:
		var rejected := LevelBuildResult.new()
		rejected.error=str(generated.error)
		return rejected
	var result := LegacyRegionPlanAdapter.generated(generated,request.tuning,request.map_index,true)
	result.resolved_capabilities=capabilities
	return result
