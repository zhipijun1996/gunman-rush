class_name WindkeeperPressureRewards
extends RefCounted
## Stage-local physical units and original pickup receipts; no direct grants.
const SOURCE := "windkeeper_pressure/death_coins"

static func spawn(stage: PlainsRegionStage, encounter: WindkeeperPressureEncounter) -> bool:
	if not is_instance_valid(stage) or not is_instance_valid(encounter) or not encounter.health.terminal or not encounter.physical_reward_expected:
		return false
	if stage.region_state.drops.has(SOURCE): return false
	var definition := encounter.definition as WindkeeperPressureDefinition
	var safe_world := encounter.reward_stand_position()
	var excluded: Array[RID] = [encounter.motor.get_rid()]
	if encounter._target is CollisionObject2D: excluded.append((encounter._target as CollisionObject2D).get_rid())
	var query := PhysicsRayQueryParameters2D.create(safe_world-Vector2(0,24),safe_world+Vector2(0,160),1,excluded)
	# The nearest actual authored landing remains valid after the bridge breaks.
	var hit := stage.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.normal as Vector2).dot(Vector2.UP) < .7: return false
	var safe := stage.to_local(hit.position) - Vector2(0, 12)
	var pose := encounter.rig_pose()
	var origin_world := encounter.motor.to_global((pose.core_transform as Transform2D).origin)
	var origin := stage.to_local(origin_world)
	var output := {"kind":"coin", "amount":definition.reward_coin_total,
		"coin_total":definition.reward_coin_total, "content_version":"windkeeper-pressure-coins-v1",
		"position":[safe.x,safe.y], "spawn_origin":[origin.x,origin.y], "born_at":stage.clock, "units":[]}
	for pickup: Dictionary in PlainsLootMotion.units(output, SOURCE, origin, safe, stage.clock):
		stage.pickups.append(pickup)
		output.units.append(PlainsLootMotion.snapshot(pickup))
	stage.region_state.drops[SOURCE] = output
	stage.queue_redraw()
	return true
