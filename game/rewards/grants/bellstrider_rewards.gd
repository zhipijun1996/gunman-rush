class_name BellstriderRewards
extends RefCounted
## App calls this only for its accepted terminal win. This service creates
## durable physical entitlements; the existing App still owns every claim.
const CONTENT_VERSION := "bellstrider-rewards-v1"
const SOURCE_SUFFIX := "boss/plains_bellstrider"

static func source_id(stage: PlainsRegionStage) -> String:
	return PlainsRegionCampaign.prefix(stage.map_index) + SOURCE_SUFFIX

static func settle(stage: PlainsRegionStage, encounter: BellstriderEncounter) -> Dictionary:
	if not is_instance_valid(stage) or not stage.is_inside_tree() or not stage.assembly_ok or stage.region_state == null or stage.map_index != 1:
		return {}
	if not is_instance_valid(encounter) or not is_instance_valid(stage.boss) or encounter.motor != stage.boss or encounter.get_parent() != stage.boss or not encounter.health.terminal or encounter.mode != &"dead":
		return {}
	var identity := source_id(stage)
	if stage.region_state.drops.has(identity):
		return (stage.region_state.drops[identity] as Dictionary).duplicate(true)
	var definition := encounter.definition as BellstriderDefinition
	if definition == null or not definition.is_valid() or definition.reward_large_coin_value != 5:
		return {}
	var pose := encounter.rig_pose()
	if float(pose.get("death_age", 0.0)) < definition.reward_impact_seconds:
		return {}
	# Spray from inside the broken chassis, using the same death rig as its art.
	var body: Transform2D = pose.body_transform
	var origin := stage.to_local(encounter.motor.to_global(body * Vector2(0, 10)))
	var support := _safe_support(stage, origin)
	if support.is_empty():
		return {}
	var safe: Vector2 = support.position
	var amount := definition.reward_coin_total
	var output := {"enemy_id":identity, "boss_id":String(definition.stable_id), "kind":"coin" if amount > 0 else "none", "amount":amount,
		"rewards":[{"kind":"coin", "amount":amount}] if amount > 0 else [], "coin_total":amount, "configured_coin_total":amount,
		"content_version":CONTENT_VERSION, "position":[safe.x,safe.y], "spawn_origin":[origin.x,origin.y], "born_at":stage.clock,
		"pickup_lock_seconds":definition.reward_pickup_lock_seconds, "units":[]}
	var units := PlainsLootMotion.units(output, identity, origin, safe, stage.clock)
	for pickup: Dictionary in units:
		pickup.ready_at = stage.clock + definition.reward_pickup_lock_seconds
		stage.pickups.append(pickup)
		output.units.append(PlainsLootMotion.snapshot(pickup))
	stage.region_state.drops[identity] = output.duplicate(true)
	stage.queue_redraw()
	return output.duplicate(true)

static func _safe_support(stage: PlainsRegionStage, origin: Vector2) -> Dictionary:
	# Prefer the arena floor under the body. Every fallback is also checked
	# against real support; an absent floor never becomes a fabricated landing.
	var world := stage.get_world_2d().direct_space_state
	for offset: float in [0.0, -48.0, 48.0, -96.0, 96.0]:
		var x := origin.x + offset
		if stage.boss_arena.size.x > 48.0:
			x = clampf(x, stage.boss_arena.position.x + 24.0, stage.boss_arena.end.x - 24.0)
		var start := Vector2(x, origin.y - 64.0)
		var finish := Vector2(x, maxf(origin.y + 512.0, stage.boss_arena.end.y + 64.0))
		var query := PhysicsRayQueryParameters2D.create(stage.to_global(start), stage.to_global(finish), 1, [(stage.boss as BossMotor).get_rid()])
		query.collide_with_areas = false
		var hit := world.intersect_ray(query)
		if not hit.is_empty() and not (hit.collider is CharacterBody2D) and (hit.normal as Vector2).dot(Vector2.UP) > .65:
			return {"position":stage.to_local(hit.position)}
	return {}

static func restore_pickup_lock(stage: PlainsRegionStage, drop: Dictionary) -> void:
	# Generic restore keeps durable units/claims. The Boss's configured delay
	# can differ from the small-monster default, so restore its remaining part.
	var lock := float(drop.get("pickup_lock_seconds", PlainsLootMotion.PICKUP_DELAY))
	for pickup: Dictionary in stage.pickups:
		if str(pickup.get("source", "")) == source_id(stage):
			pickup.ready_at = stage.clock + maxf(0.0, lock - float(pickup.get("loot_age", 0.0)))
