class_name LegacyRegionPlanAdapter
extends RefCounted
## Sole conversion of the existing region formats into runtime content.
## Old validation stays here, outside the common plan and world assembly.
static func geometry(recorded: Dictionary, tuning: PlayerTuning, forest_region: bool) -> LevelBuildResult:
	var result := LevelBuildResult.new()
	var valid := ThornForestRegionGenerator.new().validate(recorded,tuning) if forest_region else PlainsRegionGenerator.new().validate(recorded,tuning)
	if not valid:
		result.error="Invalid forest manifest or occupied assembler" if forest_region else "Invalid connected region manifest"
		return result
	var plan := LevelPlan.new()
	plan.region_id=&"thorn_forest" if forest_region else &"plains"
	plan.source_id=&"legacy_forest" if forest_region else &"legacy_plains"
	plan.source_version=str(recorded.version)
	plan.seed=str(recorded.seed)
	plan.map_hash=str(recorded.manifest_hash)
	plan.bounds=LevelContentValidation.rect(recorded.world_bounds)
	plan.spawn=Vector2(recorded.spawn[0],recorded.spawn[1])
	plan.anchors.append(plan.spawn)
	for area: Dictionary in recorded.areas:
		if area.role=="boss" or (forest_region and area.role=="challenge_reward"): continue
		plan.anchors.append(Vector2(area.position[0],area.position[1]))
	if forest_region:
		plan.map_index=int(recorded.map_index)
		var forest := ForestLevelGeometry.new()
		forest.platforms.assign(recorded.platforms.duplicate(true))
		forest.hook_anchors.assign(recorded.hook_anchors.duplicate(true))
		forest.training_bells.assign(recorded.get("training_bells",[]).duplicate(true))
		forest.vine_gate=recorded.vine_gate.duplicate(true)
		forest.reward_shortcuts.assign(recorded.get("forest_shortcuts",[]).duplicate(true))
		for shortcut: Dictionary in forest.reward_shortcuts:
			if shortcut.has("unlock_reward_id"):
				shortcut.reward_source_id="thorn_forest/map_%s/%s" % [recorded.map_index,shortcut.unlock_reward_id]
		for row: Array in recorded.dangers: forest.dangers.append(LevelContentValidation.rect(row))
		forest.danger_presentations=recorded.get("danger_presentations",[]).duplicate(true)
		if recorded.get("layout_version") in [ForestTargetHosts.LAYOUT,"forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"]:
			forest.target_hosts=ForestTargetHosts.build(recorded)
		forest.fruit_presentation=recorded.get("layout_version") in ["forest-fruit-routes-v14","forest-bible-world-v15","forest-branching-expedition-v16","forest-varied-bible-v17","forest-exploration-places-v18"]
		forest.bible_presentation=ForestBiblePresentation.enabled(recorded)
		forest.merge_solid_supports=recorded.get("scene_language_version")==ForestSceneLanguage.VERSION
		plan.forest=forest
	else:
		for node: Dictionary in recorded.nodes:
			var placement := LevelModulePlacement.new()
			placement.instance_id=str(node.id)
			placement.template_id=StringName(node.module_id)
			placement.definition=PlainsRegionGenerator.definition(node)
			placement.position=Vector2(node.offset[0],node.offset[1])
			placement.terrain_ownership=node.get("joint_recoil",{}).duplicate(true)
			plan.modules.append(placement)
		for row: Array in recorded.ground_supports: plan.ground_supports.append(LevelContentValidation.rect(row))
		plan.connections.assign(recorded.connections.duplicate(true))
	result.plan=plan
	return result

static func generated(data: Dictionary, tuning: PlayerTuning, map_index: int, forest_region: bool) -> LevelBuildResult:
	var result := geometry(data.manifest,tuning,forest_region)
	if not result.accepted(): return result
	var plan := result.plan
	var manifest: Dictionary=data.manifest
	plan.map_index=map_index
	plan.boss_arena=data.boss_arena
	plan.merchant_position=Vector2(manifest.merchant_position[0],manifest.merchant_position[1])
	for row: Dictionary in data.encounter_plan.enemies:
		var overrides := {&"patrol_half_width":float(row.patrol_radius)} if forest_region else {&"patrol_half_width":row.patrol_radius,&"aerial":row.aerial}
		if forest_region and row.behavior_id=="forest_bark_beetle" and row.has("initial_direction"):
			if not row.initial_direction is int or row.initial_direction not in [-1,1]:
				result.error="Recorded bark facing rejected"
				return result
			overrides[&"initial_direction"]=int(row.initial_direction)
		if not forest_region and row.has("dive_depth"): overrides[&"dive_depth"]=float(row.dive_depth)
		var placement := {"id":str(row.id),"behavior_id":StringName(row.behavior_id),"position":Vector2(row.position[0],row.position[1]),"overrides":overrides}
		if forest_region and manifest.get("layout_version")==ThornForestRegionGenerator.DEPTH_LAYOUT_EXPEDITION and row.behavior_id=="charger":
			if row.get("definition_path")!=EnemyBehaviorRegistry.definition_path(&"charger") or row.get("definition_sha256")!=EnemyBehaviorRegistry.CHARGER_V2_REVISION:
				result.error="Recorded v11 charger Definition identity rejected"
				return result
			placement.definition_revision=EnemyBehaviorRegistry.CHARGER_V2_REVISION
		plan.actors.append(placement)
	var boss_id: StringName=&"bellstrider" if map_index==1 else &"windkeeper_storm"
	var boss_position := Vector2(plan.boss_arena.get_center().x,plan.boss_arena.end.y-65)
	if forest_region:
		var path := ThornForestRegionGenerator.boss_scene_path(str(manifest.version),map_index,manifest)
		boss_id=&""
		for identity: StringName in BossFactory.RECORDS:
			if BossFactory.RECORDS[identity][0]==path:
				boss_id=identity
				break
		if boss_id.is_empty():
			result.error="Recorded forest Boss content is not in the version whitelist"
			return result
		var point: Array=manifest.get("boss_geometry",{}).get("boss_position",[plan.boss_arena.get_center().x,plan.boss_arena.end.y-100])
		boss_position=Vector2(point[0],point[1])
	plan.boss={"definition_id":boss_id,"position":boss_position}
	for row: Dictionary in manifest.pickups:
		plan.pickups.append({"id":str(row.id),"kind":row.kind,"amount":int(row.amount),"position":Vector2(row.position[0],row.position[1])})
	var prefix := "thorn_forest/map_%s/" % map_index if forest_region else PlainsRegionCampaign.prefix(map_index)
	for row: Dictionary in manifest.rewards:
		var cache := row.duplicate(true)
		cache.id=prefix+str(row.id)
		cache.position=Vector2(row.position[0],row.position[1])
		plan.caches.append(cache)
	result.error=plan.validation_error()
	result.legacy_generated=data
	return result
