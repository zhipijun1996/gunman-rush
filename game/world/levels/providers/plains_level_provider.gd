class_name PlainsLevelProvider
extends RefCounted

static func load_level(request: LevelRequest) -> LevelBuildResult:
	var generator := PlainsRegionGenerator.new()
	generator.root_bell_mode=request.root_bell_mode
	var seed_value := PlainsRegionCampaign.seed_for(request.root_seed,request.map_index)
	var difficulty := "intro" if request.map_index==1 else "advanced"
	var generated := generator.generate(seed_value,request.tuning,false,"",difficulty)
	if not request.expected_hash.is_empty() and generated.ok and request.expected_hash!=generated.manifest.manifest_hash:
		var matched := false
		for prior_mode: String in [request.root_bell_mode,"v2","legacy_v10"]:
			generator.root_bell_mode=prior_mode
			for historical_focus: bool in [false,true]:
				var prior := generator.generate_before_focus_15(seed_value,request.tuning,false,"",difficulty) if historical_focus else generator.generate(seed_value,request.tuning,false,"",difficulty)
				if prior.ok and prior.manifest.manifest_hash==request.expected_hash:
					generated=prior
					matched=true
					break
			if matched: break
		if not matched: generated={"ok":false,"error":"Recorded plains hash does not match a supported content/tuning version"}
	if not generated.ok:
		var rejected := LevelBuildResult.new()
		rejected.error=str(generated.error)
		return rejected
	return LegacyRegionPlanAdapter.generated(generated,request.tuning,request.map_index,false)
