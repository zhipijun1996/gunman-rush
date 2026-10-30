extends RefCounted
## Focused reward/ballistic boundaries. Explicit floor and scripted observer
## ticks are fixtures, not formal App traversal, player input or visual approval.

static func run(tree: SceneTree) -> Dictionary:
	var report := {"assertions":0,"failures":[],"checks":[],"samples":[],"scope":"Configured reward receipts and actual ray/terrain ballistics in an explicit translated floor fixture; no natural route, App transaction or art/audio approval"}
	_configuration(report)
	_denominations(report)
	_reward_streams(report)
	await _ballistics(tree,report)
	await _obstacles(tree,report)
	return report

static func _check(report: Dictionary, ok: bool, label: String) -> void:
	report.assertions+=1
	report.checks.append({"label":label,"passed":ok})
	if not ok:
		report.failures.append(label)
		printerr("FAIL: ",label)

static func _config() -> Dictionary:
	return {"version":1,"weights":{"coin":55,"note":25,"heart":10,"none":10},"amounts":{"coin":1,"note":1,"heart":1},"guaranteed_coins":true,"coin_totals":{"patrol":1,"charger":2,"diver":2,"hopper":2,"sentry":3,"fan_sentry":5,"root_bell":7}}

static func _configuration(report: Dictionary) -> void:
	var service:=EnemyDropService.new()
	_check(report,service.configure("loot-native-boundaries","explicit-floor"),"real tracked JSON configuration loads with JSON number semantics")
	var legacy_version := service.settle(&"version_legacy")
	var guaranteed_version := service.settle(&"version_guaranteed",&"root_bell")
	_check(report,legacy_version.content_version==EnemyDropService.CONTENT_VERSION and not legacy_version.has("rewards"),"default drop result retains the public legacy version consumed by the real Forest validator")
	_check(report,guaranteed_version.content_version==EnemyDropService.GUARANTEED_CONTENT_VERSION and guaranteed_version.content_version!=EnemyDropService.CONTENT_VERSION and guaranteed_version.has("rewards"),"guaranteed plains bundle declares its distinct version without changing the legacy API")
	_check(report,EnemyDropService.valid_configuration(_config()),"explicit seven-species guaranteed configuration is valid")
	var integral_float:=_config()
	integral_float.coin_totals.root_bell=7.0
	_check(report,EnemyDropService.valid_configuration(integral_float),"integral JSON float coin amounts remain valid")
	var invalid_values: Array = [0,-1,1.5,true,false,NAN,INF,-INF,"7",100001,null,[],{}]
	for index: int in invalid_values.size():
		var invalid:=_config()
		invalid.coin_totals.root_bell=invalid_values[index]
		_check(report,not EnemyDropService.valid_configuration(invalid),"invalid configured coin amount refused / %s"%index)
	for invalid_container: Variant in [[],"totals",null,7]:
		var invalid:=_config()
		invalid.coin_totals=invalid_container
		_check(report,not EnemyDropService.valid_configuration(invalid),"malformed coin table refused / %s"%str(invalid_container))
	var invalid_key:=_config()
	invalid_key.coin_totals={1:7}
	_check(report,not EnemyDropService.valid_configuration(invalid_key),"non-string configured species key refused")
	var invalid_flag:=_config()
	invalid_flag.guaranteed_coins=1
	_check(report,not EnemyDropService.valid_configuration(invalid_flag),"nonboolean guarantee policy refused")
	_check(report,not service.configure("","explicit-floor",_config()),"empty reward root seed refused")
	_check(report,not service.configure("loot-native-boundaries","",_config()),"empty stable stage identity refused")
	_check(report,service.configure("loot-native-boundaries","explicit-floor",_config()) and service.settle(&"").is_empty(),"empty enemy identity never settles")

static func _denominations(report: Dictionary) -> void:
	var origin:=Vector2(21,-19)
	var safe:=Vector2(6,280)
	for amount: int in range(1,32):
		var output: Dictionary={"kind":"coin","amount":amount}
		var pieces:=PlainsLootMotion.units(output,"amount_%s"%amount,origin,safe,9.0)
		var paid:=0
		var small:=0
		var identities: Dictionary={}
		var admissible:=not pieces.is_empty()
		for piece: Dictionary in pieces:
			paid+=int(piece.amount)
			if int(piece.amount)==1:small+=1
			identities[str(piece.id)]=true
			var velocity:Vector2=piece.loot_velocity
			admissible=admissible and int(piece.amount) in [1,5] and piece.position==origin and piece.spawn_origin==origin and not piece.claimed and piece.ready_at>piece.born_at and velocity.is_finite() and velocity.y<0.0 and absf(velocity.x)>0.0 and velocity.length()<240.0
		_check(report,paid==amount and identities.size()==pieces.size() and small<5 and admissible,"exact finite independent 1/5 denomination entitlement / %s"%amount)
		_check(report,pieces==PlainsLootMotion.units(output,"amount_%s"%amount,origin,safe,9.0),"same drop identity has reproducible cosmetic spray / %s"%amount)
	var seven:=PlainsLootMotion.units({"kind":"coin","amount":7},"seven",origin,safe,9.0)
	_check(report,seven.size()==3 and seven.map(func(piece:Dictionary)->int:return int(piece.amount))==[5,1,1],"seven coins is precisely one five and two ones")
	_check(report,seven[0].loot_velocity.x*seven[1].loot_velocity.x<0.0 and seven[1].loot_velocity!=seven[2].loot_velocity,"multi-unit spray uses both sides and varies velocity")
	_check(report,PlainsLootMotion.radius(seven[0])>PlainsLootMotion.radius(seven[1]),"five denomination has larger physical footprint")
	var bonuses:=PlainsLootMotion.units({"rewards":[{"kind":"coin","amount":7},{"kind":"note","amount":1},{"kind":"heart","amount":2}]},"multi-entitlement",origin,safe,0.0)
	var kinds:Dictionary={}
	var unique:Dictionary={}
	for piece:Dictionary in bonuses:
		kinds[piece.kind]=int(kinds.get(piece.kind,0))+int(piece.amount)
		unique[piece.id]=true
	_check(report,bonuses.size()==5 and unique.size()==5 and kinds=={"coin":7,"note":1,"heart":2},"coin note and healing entitlements coexist without aliasing receipts or values")
	_check(report,PlainsLootMotion.units({"kind":"none","amount":0},"empty",origin,safe,0.0).is_empty(),"no reward cannot create decorative collectible value")
	report.samples.append({"id":"seven-denominations","amounts":seven.map(func(piece:Dictionary)->int:return int(piece.amount)),"ids":seven.map(func(piece:Dictionary)->String:return str(piece.id)),"origin":[origin.x,origin.y],"velocities":seven.map(func(piece:Dictionary)->Array:return [piece.loot_velocity.x,piece.loot_velocity.y])})

static func _reward_streams(report: Dictionary) -> void:
	var legacy:=EnemyDropService.new()
	var current:=EnemyDropService.new()
	_check(report,legacy.configure("bonus-interval-boundaries","stage",_config()) and current.configure("bonus-interval-boundaries","stage",_config()),"paired old/current reward streams initialize")
	var same_intervals:=true
	var all_paid:=true
	var draws:Dictionary={"coin":0,"note":0,"heart":0,"none":0}
	for index: int in 256:
		var identity:=StringName("actor_%s"%index)
		var old:=legacy.settle(identity)
		var actual:=current.settle(identity,&"root_bell")
		draws[old.kind]=int(draws[old.kind])+1
		var bonus: Array[Dictionary]=[]
		var coin_amount:=0
		for reward:Dictionary in EnemyDropService.rewards_of(actual):
			if reward.kind=="coin":coin_amount+=int(reward.amount)
			else:bonus.append(reward)
		var expected: Array[Dictionary]=[]
		if old.kind in ["note","heart"]:expected.append({"kind":old.kind,"amount":int(old.amount)})
		same_intervals=same_intervals and actual.roll==old.roll and actual.stream_position==old.stream_position and actual.bonus_roll_kind==old.kind and bonus==expected
		all_paid=all_paid and coin_amount==7 and int(actual.configured_coin_total)==7
	_check(report,same_intervals,"256 same identities preserve original draw and exact note/heart result, with no additional reward RNG")
	_check(report,all_paid,"all 256 configured enemies guarantee their exact coin amount regardless of original roll kind")
	_check(report,int(draws.note)>0 and int(draws.heart)>0 and int(draws.none)>0 and int(draws.coin)>0,"paired cohort actually exercises both bonuses and both no-bonus outcomes")
	_check(report,current.settle(&"actor_0",&"root_bell").is_empty(),"second death settlement for same enemy returns no entitlement")
	var forward:=EnemyDropService.new()
	var reverse:=EnemyDropService.new()
	forward.configure("kill-order-boundaries","stage",_config())
	reverse.configure("kill-order-boundaries","stage",_config())
	var rows:Dictionary={}
	for index:int in 32:rows[index]=forward.settle(StringName("order_%s"%index),&"fan_sentry")
	var order_equal:=true
	for index:int in range(31,-1,-1):order_equal=order_equal and rows[index]==reverse.settle(StringName("order_%s"%index),&"fan_sentry")
	_check(report,order_equal,"reversing actual kill order cannot change any enemy reward record")
	var observer:=EnemyDropService.new()
	observer.configure("presentation-isolation","stage",_config())
	var baseline:=EnemyDropService.new()
	baseline.configure("presentation-isolation","stage",_config())
	var before:=observer.settle(&"a",&"patrol")
	for index:int in 20:PlainsLootMotion.units(before,"unrelated_spray_%s"%index,Vector2.ZERO,Vector2.ZERO,0.0)
	_check(report,observer.settle(&"b",&"patrol")==baseline.settle(&"b",&"patrol"),"twenty cosmetic sprays cannot advance the reward stream")
	var unknown:=EnemyDropService.new()
	var old_unknown:=EnemyDropService.new()
	unknown.configure("unknown-species","stage",_config());old_unknown.configure("unknown-species","stage",_config())
	_check(report,unknown.settle(&"unknown",&"unconfigured")==old_unknown.settle(&"unknown"),"unconfigured species retains the explicit old single-reward contract")
	var off_config:=_config();off_config.guaranteed_coins=false
	var off:=EnemyDropService.new();off.configure("guarantee-off","stage",off_config)
	var off_old:=EnemyDropService.new();off_old.configure("guarantee-off","stage",off_config)
	_check(report,off.settle(&"off",&"root_bell")==off_old.settle(&"off"),"explicit probability-policy switch preserves old contract")
	report.samples.append({"id":"paired-bonus-observations","identities":256,"original_kind_counts":draws,"scope":"Exact paired outcomes, not a statistical probability estimate"})

static func _ballistics(tree: SceneTree, report: Dictionary) -> void:
	_check(report,not tree.paused,"ballistic fixture begins in an unpaused tree")
	if tree.paused:return
	var arena:=Node2D.new()
	arena.name="ExplicitTranslatedLootFloor"
	arena.position=Vector2(12000,-5000)
	arena.process_mode=Node.PROCESS_MODE_PAUSABLE
	var floor_body:=StaticBody2D.new()
	floor_body.position=Vector2(0,310)
	floor_body.collision_layer=1
	var collision:=CollisionShape2D.new()
	var shape:=RectangleShape2D.new()
	shape.size=Vector2(1400,20)
	collision.shape=shape
	floor_body.add_child(collision);arena.add_child(floor_body);tree.root.add_child(arena)
	var reference:WeakRef=weakref(arena)
	await tree.physics_frame
	await tree.physics_frame
	var pieces:=PlainsLootMotion.units({"kind":"coin","amount":7},"actual-wide-floor",Vector2(0,220),Vector2(0,280),0.0)
	var min_y: Array[float]=[220.0,220.0,220.0]
	var rebound_counts: Array[int]=[0,0,0]
	var rebound_heights: Array[float]=[0.0,0.0,0.0]
	var did_not_penetrate:=true
	var receipts_unchanged:=true
	var initial_ids:=pieces.map(func(piece:Dictionary)->String:return str(piece.id))
	for frame:int in 240:
		await tree.physics_frame
		for index:int in pieces.size():
			var piece:Dictionary=pieces[index]
			var old_velocity:Vector2=piece.loot_velocity
			PlainsLootMotion.advance(piece,1.0/60.0,arena)
			var velocity:Vector2=piece.loot_velocity
			if old_velocity.y>0.0 and velocity.y<0.0:rebound_counts[index]+=1
			min_y[index]=minf(min_y[index],piece.position.y)
			if int(piece.loot_bounces)>0:rebound_heights[index]=maxf(rebound_heights[index],300.0-PlainsLootMotion.radius(piece)-piece.position.y)
			did_not_penetrate=did_not_penetrate and piece.position.y+PlainsLootMotion.radius(piece)<=301.1
			receipts_unchanged=receipts_unchanged and not piece.claimed and str(piece.id)==initial_ids[index]
	_check(report,min_y.all(func(value:float)->bool:return value<214.0),"actual gravity trajectory first ejects all denominations upward")
	_check(report,did_not_penetrate,"all swept contacts keep translated real floor beneath item footprint")
	_check(report,pieces.all(func(piece:Dictionary)->bool:return bool(piece.loot_settled)),"all real wide-floor items settle within bounded four seconds")
	_check(report,rebound_counts.all(func(count:int)->bool:return count>=1 and count<=2),"each denomination rebounds once or twice before rest")
	_check(report,rebound_counts[0]<=maxi(rebound_counts[1],rebound_counts[2]) and rebound_heights[0]<maxf(rebound_heights[1],rebound_heights[2]),"large coin has less bounce energy than the small denominations")
	_check(report,receipts_unchanged and pieces.map(func(piece:Dictionary)->int:return int(piece.amount))==[5,1,1],"ballistics cannot claim, rename or change the seven-coin entitlement")
	var floor_contacts:=true
	for piece:Dictionary in pieces:
		var foot:Vector2=arena.to_global(piece.position+Vector2(0,PlainsLootMotion.radius(piece)))
		var query:=PhysicsRayQueryParameters2D.create(foot-Vector2(0,1),foot+Vector2(0,1),1)
		query.collide_with_areas=false
		var actual:Dictionary=arena.get_world_2d().direct_space_state.intersect_ray(query)
		floor_contacts=floor_contacts and actual.get("collider")==floor_body
	_check(report,floor_contacts,"settled translated footprints independently intersect actual authored floor")
	var snapshot:Dictionary=PlainsLootMotion.snapshot(pieces[1])
	var restored:Dictionary=PlainsLootMotion.restore(snapshot,31.0)
	var frozen:=restored.duplicate(true)
	for _frame:int in 10:PlainsLootMotion.advance(restored,1.0/60.0,arena)
	_check(report,restored==frozen and restored.id==pieces[1].id and restored.amount==pieces[1].amount and restored.loot_settled,"reload restores the exact entitlement at rest without replaying spray")
	var claimed:Dictionary=pieces[2].duplicate(true);claimed.claimed=true
	var claimed_before:=claimed.duplicate(true)
	PlainsLootMotion.advance(claimed,1.0,arena)
	_check(report,claimed==claimed_before,"claimed item cannot resume physics or create another value")
	var zero:Dictionary=PlainsLootMotion.units({"kind":"heart","amount":1},"zero-tick",Vector2(0,220),Vector2(0,280),0.0)[0]
	var zero_before:=zero.duplicate(true);PlainsLootMotion.advance(zero,0.0,arena)
	_check(report,zero==zero_before,"zero-delta observation does not advance loot clocks or coordinates")
	report.samples.append({"id":"translated-real-floor","world_offset":[arena.position.x,arena.position.y],"amounts":[5,1,1],"rebounds":rebound_counts,"rebound_heights":rebound_heights,"end_positions":pieces.map(func(piece:Dictionary)->Array:return [piece.position.x,piece.position.y])})
	shape.size=Vector2(180,20)
	await tree.physics_frame
	await tree.physics_frame
	var returned:Dictionary=PlainsLootMotion.units({"kind":"coin","amount":1},"void-return",Vector2(300,210),Vector2(0,280),0.0)[0]
	var returning_seen:=false
	var never_claimed:=true
	for _frame:int in 360:
		await tree.physics_frame
		PlainsLootMotion.advance(returned,1.0/60.0,arena)
		returning_seen=returning_seen or bool(returned.get("loot_returning",false))
		never_claimed=never_claimed and not returned.claimed
	_check(report,returning_seen and returned.loot_settled and absf(returned.position.x)<1.0 and absf(returned.position.y+PlainsLootMotion.radius(returned)-300.0)<1.0,"genuine void item returns to the supplied real safe floor and settles")
	_check(report,never_claimed and returned.amount==1 and returned.id=="drop_void-return","void recovery is visible entitlement movement, never an offscreen auto-grant")
	floor_body.queue_free()
	await tree.physics_frame
	await tree.physics_frame
	var released:Dictionary=pieces[0].duplicate(true)
	var released_before:Vector2=released.position
	for _frame:int in 60:
		await tree.physics_frame
		PlainsLootMotion.advance(released,1.0/60.0,arena)
	_check(report,not released.loot_settled and not released.claimed and released.position.y>released_before.y+40.0,"removing the actual floor releases a previously settled entitlement into a fall")
	_check(report,released.id==pieces[0].id and released.amount==pieces[0].amount,"support loss cannot rename or repay the settled coin")
	var unsupported:Dictionary=PlainsLootMotion.units({"kind":"heart","amount":1},"no-invented-floor",Vector2(0,210),Vector2(0,280),0.0)[0]
	for _frame:int in 120:
		await tree.physics_frame
		PlainsLootMotion.advance(unsupported,1.0/60.0,arena)
	_check(report,not unsupported.loot_settled and not unsupported.claimed and unsupported.position.y>376.0,"missing safe geometry never produces a floating resting item or automatic heal")
	report.samples.append({"id":"real-void-and-missing-floor","returned":[returned.position.x,returned.position.y],"returned_amount":int(returned.amount),"unsupported_y":unsupported.position.y,"scope":"Explicit floor deletion and safe-anchor fixtures, not natural route"})
	arena.queue_free();arena=null
	await tree.process_frame
	await tree.physics_frame
	_check(report,reference.get_ref()==null,"ballistic fixture and its geometric support unload without strong-owner residue")

static func _obstacles(tree: SceneTree, report: Dictionary) -> void:
	var arena:=Node2D.new();arena.position=Vector2(15000,-5000)
	arena.name="ExplicitLootRoofAndWall"
	var floor_body:=StaticBody2D.new();floor_body.position=Vector2(0,370)
	var floor_shape:=RectangleShape2D.new();floor_shape.size=Vector2(900,20)
	var floor_collision:=CollisionShape2D.new();floor_collision.shape=floor_shape;floor_body.add_child(floor_collision)
	var ceiling:=StaticBody2D.new();ceiling.position=Vector2(0,193)
	var ceiling_shape:=RectangleShape2D.new();ceiling_shape.size=Vector2(380,12)
	var ceiling_collision:=CollisionShape2D.new();ceiling_collision.shape=ceiling_shape;ceiling.add_child(ceiling_collision)
	var wall:=StaticBody2D.new();wall.position=Vector2(44,280)
	var wall_shape:=RectangleShape2D.new();wall_shape.size=Vector2(12,260)
	var wall_collision:=CollisionShape2D.new();wall_collision.shape=wall_shape;wall.add_child(wall_collision)
	arena.add_child(floor_body);arena.add_child(ceiling);arena.add_child(wall);tree.root.add_child(arena)
	var reference:WeakRef=weakref(arena)
	await tree.physics_frame;await tree.physics_frame
	var roof_coin:Dictionary=PlainsLootMotion.units({"kind":"coin","amount":5},"real-low-roof",Vector2(-120,220),Vector2(-120,340),0.0)[0]
	var roof_min:=220.0
	var roof_turned:=false
	var roof_no_penetration:=true
	for _frame:int in 32:
		await tree.physics_frame
		var old_velocity:Vector2=roof_coin.loot_velocity
		PlainsLootMotion.advance(roof_coin,1.0/60.0,arena)
		var velocity:Vector2=roof_coin.loot_velocity
		roof_turned=roof_turned or (old_velocity.y<0.0 and velocity.y>=0.0)
		roof_min=minf(roof_min,roof_coin.position.y)
		roof_no_penetration=roof_no_penetration and roof_coin.position.y-PlainsLootMotion.radius(roof_coin)>=198.0
	_check(report,roof_turned and roof_no_penetration,"upward ejection strikes the real low roof without its visual footprint crossing the underside")
	_check(report,not roof_coin.claimed and roof_coin.amount==5,"roof contact does not claim or alter the denomination")
	var side_coin:Dictionary=PlainsLootMotion.units({"kind":"coin","amount":7},"real-side-wall",Vector2(0,270),Vector2(0,340),0.0)[1]
	var wall_max:=0.0
	var wall_reflected:=false
	for _frame:int in 60:
		await tree.physics_frame
		var old_velocity:Vector2=side_coin.loot_velocity
		PlainsLootMotion.advance(side_coin,1.0/60.0,arena)
		var velocity:Vector2=side_coin.loot_velocity
		wall_max=maxf(wall_max,side_coin.position.x)
		wall_reflected=wall_reflected or (old_velocity.x>0.0 and velocity.x<0.0)
	_check(report,wall_reflected and wall_max+PlainsLootMotion.radius(side_coin)<=39.0,"lateral spray reflects off actual side wall without crossing its left face")
	_check(report,not side_coin.claimed and side_coin.amount==1,"side-wall response keeps the same unclaimed one-coin entitlement")
	report.samples.append({"id":"actual-low-roof-and-side-wall","roof_underside":199,"roof_min_center_y":roof_min,"wall_left":38,"wall_max_center_x":wall_max,"scope":"Explicit translated solid fixtures; actual physics sweeps, no Sprite-only collision claim"})
	arena.queue_free();arena=null
	await tree.process_frame;await tree.physics_frame
	_check(report,reference.get_ref()==null,"roof and wall fixture releases its owned geometry")
