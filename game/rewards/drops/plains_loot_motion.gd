class_name PlainsLootMotion
extends RefCounted
## Stage-owned cosmetic ballistics. Only the App may commit a pickup receipt.
const PICKUP_DELAY := 0.30
const GRAVITY := 620.0
const COLLECT_SECONDS := 0.18

static func units(output: Dictionary, enemy_id: String, origin: Vector2, safe: Vector2, now: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reward: Dictionary in EnemyDropService.rewards_of(output):
		var amount := int(reward.amount)
		var kind := str(reward.kind)
		var pieces: Array[int] = []
		if kind == "coin":
			for _i: int in amount / 5: pieces.append(5)
			for _i: int in amount % 5: pieces.append(1)
		else: pieces.append(amount)
		for value: int in pieces:
			var index := result.size()
			var identity := "drop_" + enemy_id + ("" if index == 0 else "/unit_%s" % index)
			# A dedicated presentation stream never advances reward/map streams.
			var rng := RunRandomStream.new(enemy_id,"loot_presentation",identity,"plains-loot-motion-v2")
			var side := -1.0 if index % 2 == 0 else 1.0
			var heavy: bool = kind == "coin" and value == 5
			var velocity := Vector2(side * (34.0 + rng.next_int(24)), -132.0 - rng.next_int(36))
			if heavy: velocity *= Vector2(0.84,0.90)
			result.append({"id":identity,"kind":kind,"amount":value,"position":origin,"claimed":false,"source":enemy_id,
				"spawn_origin":origin,"born_at":now,"ready_at":now+PICKUP_DELAY,"loot_motion":true,"loot_velocity":velocity,
				"loot_age":0.0,"loot_bounces":0,"loot_settled":false,"loot_safe":safe,"loot_rotation":0.0})
	return result

static func radius(pickup: Dictionary) -> float:
	return 12.0 if pickup.kind == "coin" and int(pickup.amount) == 5 else 8.0 if pickup.kind == "coin" else 9.5 if pickup.kind == "heart" else 10.5

static func advance(pickup: Dictionary, delta: float, stage: Node2D) -> void:
	if delta <= 0.0 or pickup.claimed or not pickup.get("loot_motion",false): return
	var world := stage.get_world_2d().direct_space_state
	var r := radius(pickup)
	if pickup.get("loot_settled",false):
		var foot: Vector2 = pickup.position + Vector2(0,r)
		var support_query := PhysicsRayQueryParameters2D.create(stage.to_global(foot-Vector2(0,1)),stage.to_global(foot+Vector2(0,3)),1)
		support_query.collide_with_areas = false
		var resting_support := world.intersect_ray(support_query)
		if not resting_support.is_empty() and (resting_support.normal as Vector2).dot(Vector2.UP) > 0.65: return
		pickup.loot_settled = false
		pickup.loot_velocity = Vector2.ZERO
	pickup.loot_age = float(pickup.loot_age) + delta
	var velocity: Vector2 = pickup.loot_velocity
	var previous: Vector2 = pickup.position
	velocity.y += GRAVITY * delta
	var next := previous + velocity * delta
	# Resolve the leading edge against the actual side/ceiling geometry too.
	# These sweeps only alter presentation motion, never the reward entitlement.
	if absf(velocity.x) > 0.01:
		var side := signf(velocity.x)
		var side_query := PhysicsRayQueryParameters2D.create(stage.to_global(previous+Vector2(side*(r-1.0),0)),stage.to_global(Vector2(next.x,previous.y)+Vector2(side*(r+1.0),0)),1)
		side_query.collide_with_areas = false
		var wall := world.intersect_ray(side_query)
		if not wall.is_empty() and (wall.normal as Vector2).dot(Vector2(-side,0)) > 0.65:
			next.x = stage.to_local(wall.position).x-side*r
			velocity.x *= -0.25
	if velocity.y < 0.0:
		var head_query := PhysicsRayQueryParameters2D.create(stage.to_global(previous-Vector2(0,r-1.0)),stage.to_global(Vector2(next.x,next.y)-Vector2(0,r+1.0)),1)
		head_query.collide_with_areas = false
		var ceiling := world.intersect_ray(head_query)
		if not ceiling.is_empty() and (ceiling.normal as Vector2).dot(Vector2.DOWN) > 0.65:
			next.y = stage.to_local(ceiling.position).y+r
			velocity.y *= -0.18
	var query := PhysicsRayQueryParameters2D.create(stage.to_global(previous + Vector2(0,r-1.0)),stage.to_global(next+Vector2(0,r+1.0)),1)
	query.collide_with_areas = false
	var hit := world.intersect_ray(query) if velocity.y > 0.0 else {}
	if not hit.is_empty() and (hit.normal as Vector2).dot(Vector2.UP) > 0.65:
		next.y = stage.to_local(hit.position).y-r
		pickup.loot_bounces = int(pickup.loot_bounces)+1
		var heavy: bool = pickup.kind == "coin" and int(pickup.amount) == 5
		if int(pickup.loot_bounces) >= (2 if heavy else 3) or velocity.y < 38.0:
			velocity = Vector2.ZERO
			pickup.loot_settled = true
		else:
			velocity.y *= -0.23 if heavy else -0.38
			velocity.x *= 0.48
	# Preserve the existing safe-landing guarantee for kills above genuine voids.
	# A returning item remains visible and unclaimed; never mint money offscreen.
	var safe: Vector2 = pickup.loot_safe
	if pickup.get("loot_returning",false) or (float(pickup.loot_age) > 1.25 and next.y > safe.y+96.0):
		var safe_query := PhysicsRayQueryParameters2D.create(stage.to_global(safe-Vector2(0,8)),stage.to_global(safe+Vector2(0,128)),1)
		safe_query.collide_with_areas = false
		var support := world.intersect_ray(safe_query)
		if not support.is_empty() and (support.normal as Vector2).dot(Vector2.UP)>.65:
			pickup.loot_returning=true
			var target := stage.to_local(support.position)-Vector2(0,r)
			next = previous.move_toward(target,260.0*delta)
			velocity = Vector2.ZERO
			if next.distance_to(target)<1.0:
				next=target;pickup.loot_settled=true
	pickup.position=next
	pickup.loot_velocity=velocity
	pickup.loot_rotation=float(pickup.loot_rotation)+velocity.x*delta*(0.012 if r>9.0 else 0.022)

static func snapshot(pickup: Dictionary) -> Dictionary:
	var velocity: Vector2=pickup.get("loot_velocity",Vector2.ZERO)
	var safe: Vector2=pickup.get("loot_safe",pickup.position)
	return {"id":str(pickup.id),"kind":str(pickup.kind),"amount":int(pickup.amount),"position":[pickup.position.x,pickup.position.y],"source":str(pickup.get("source","")),"claimed":bool(pickup.claimed),"velocity":[velocity.x,velocity.y],"safe":[safe.x,safe.y],"age":float(pickup.get("loot_age",0.0)),"bounces":int(pickup.get("loot_bounces",0)),"settled":bool(pickup.get("loot_settled",false)),"rotation":float(pickup.get("loot_rotation",0.0)),"returning":bool(pickup.get("loot_returning",false))}

static func restore(record: Dictionary, now: float) -> Dictionary:
	var at: Array = record.position
	var velocity: Array=record.get("velocity",[0.0,0.0])
	var safe: Array=record.get("safe",at)
	var age:=float(record.get("age",PICKUP_DELAY))
	return {"id":str(record.id),"kind":str(record.kind),"amount":int(record.amount),"position":Vector2(at[0],at[1]),"source":str(record.get("source","")),"claimed":bool(record.get("claimed",false)),"loot_motion":true,"loot_settled":bool(record.get("settled",true)),"loot_bounces":int(record.get("bounces",2)),"loot_velocity":Vector2(velocity[0],velocity[1]),"loot_rotation":float(record.get("rotation",0.0)),"loot_age":age,"loot_safe":Vector2(safe[0],safe[1]),"loot_returning":bool(record.get("returning",false)),"ready_at":now+maxf(0.0,PICKUP_DELAY-age)}
