extends RefCounted
## Real App reward consumers; explicit damage and review positions, not traversal.
static func _check(r:Dictionary,ok:bool,label:String)->void:
 r.assertions+=1;r.checks.append({"label":label,"passed":ok})
 if not ok:r.failures.append(label);printerr("FAIL: "+label)
static func _frames(tree:SceneTree,n:int)->void:
 for _i:int in n:await tree.physics_frame
static func _isolate(node:Node)->void:
 if node is DemoContactEmitter:node.enabled=false
 if node is EnemyAttackBehavior:node.set_physics_process(false)
 for child:Node in node.get_children():_isolate(child)
static func _hit(tree:SceneTree,app:Node,id:StringName,health:HealthState,amount:float,serial:String)->bool:
 var request:=DamageRequest.new()
 request.target_id=id;request.source_id=&"explicit_loot_review_fixture";request.event_id=StringName(serial)
 request.token=app.lifetime.token();request.actor_epoch=app.lifetime.actor_epoch;request.health_epoch=health.epoch;request.amount=amount;request.hit_direction=Vector2.RIGHT
 var accepted:bool=app.policy.submit(request)
 await _frames(tree,3)
 return accepted
static func run(tree:SceneTree,app:Node)->Dictionary:
 var r:Dictionary={"assertions":0,"failures":[],"checks":[],"samples":[],"scope":"Actual DemoApp ordinary death/pickup/save consumers with explicit native damage and player positions; no Router combat or natural traversal claim"}
 _isolate(app)
 var stage:GeneratedDemoStage=app.stage as GeneratedDemoStage
 var enemy:EnemyMotor=stage.enemies[0]
 var actor:EnemyActor=enemy.get_node("Actor")
 var identity:String=stage.enemy_manifest[0].id
 var expected_coin:=0
 for reward:Dictionary in EnemyDropService.rewards_of(stage.generated.manifest.enemy_drops[identity]):
  if reward.kind=="coin":expected_coin+=int(reward.amount)
 var before:float=app.wallet.balance
 _check(r,await _hit(tree,app,StringName(identity),actor.health,actor.health.current,"loot-native-death"),"actual registered enemy receives the explicit native damage request")
 _check(r,actor.health.terminal,"native request commits terminal original enemy health")
 var units:Array[Dictionary]=[]
 for pickup:Dictionary in stage.pickups:
  if str(pickup.get("source",""))==identity:units.append(pickup)
 _check(r,not units.is_empty(),"actual App death creates stable denomination units")
 var total:=0
 for unit:Dictionary in units:
  if unit.kind=="coin":total+=int(unit.amount)
 _check(r,total==expected_coin,"actual spawned denominations sum to manifest-configured enemy coins")
 var count:=stage.pickups.size()
 app._settle_enemy_drops();app._settle_enemy_drops()
 _check(r,stage.pickups.size()==count,"repeat death scan does not create duplicate units or bonus rewards")
 if not units.is_empty():
  var first:Dictionary=units[0]
  app.player.reset_at(stage.to_global(first.position)+Vector2(0,-12))
  _check(r,not app._commit_pickup(stage.pickups.find(first)) and app.wallet.balance==before,"same-position early pickup is refused without money")
 app.player.reset_at(stage.spawn)
 var paused_positions:Array=[]
 for unit:Dictionary in units:paused_positions.append(unit.position)
 var clock_before:float=stage.clock
 tree.paused=true;await _frames(tree,5)
 var same:=true
 for i:int in units.size():same=same and units[i].position==paused_positions[i]
 _check(r,same and stage.clock==clock_before,"real App pause freezes pickup ballistics and eligibility clock")
 tree.paused=false
 await _frames(tree,150)
 var settled:=true
 for unit:Dictionary in units:settled=settled and bool(unit.loot_settled)
 _check(r,settled,"actual stage-owned units reach stable floor positions")
 var paid:=0
 for unit:Dictionary in units:
  if unit.kind!="coin":continue
  app.player.reset_at(stage.to_global(unit.position)+Vector2(0,-12))
  var pickup_index:=stage.pickups.find(unit)
  var old_balance:float=app.wallet.balance
  _check(r,app._commit_pickup(pickup_index),"real ready coin commits its original independent wallet receipt")
  paid+=int(unit.amount)
  _check(r,app.wallet.balance==old_balance+int(unit.amount),"wallet delta equals that physical denomination")
  _check(r,not app._commit_pickup(pickup_index),"same physical coin cannot be claimed twice")
 _check(r,paid==expected_coin and app.wallet.balance==before+expected_coin,"all physical coins pay exactly the configured total")
 stage.visual_layer._process(0.0)
 var collecting:=true
 for unit:Dictionary in units:
  if unit.kind=="coin":collecting=collecting and stage.visual_layer._pickup_by_id[unit.id].visible
 _check(r,collecting,"accepted coins remain visible for their short collection flight")
 await _frames(tree,20)
 stage.visual_layer._process(.3)
 var hidden:=true
 for unit:Dictionary in units:
  if unit.kind=="coin":hidden=hidden and not stage.visual_layer._pickup_by_id[unit.id].visible
 _check(r,hidden,"collection flight ends without retaining visible paid coins")
 var heart_index:=-1
 for i:int in stage.enemies.size():
  var id:String=stage.enemy_manifest[i].id
  var drop:Dictionary=stage.generated.manifest.enemy_drops[id]
  for reward:Dictionary in EnemyDropService.rewards_of(drop):
   if reward.kind=="heart" and id!=identity:heart_index=i
 _check(r,heart_index>=0,"declared seed naturally includes the original probability-selected healing bonus")
 if heart_index>=0:
  var health:HealthState=app.controller.actor_resources.health
  _check(r,await _hit(tree,app,&"player",health,2.0,"loot-native-player-injury"),"actual policy accepts the explicit wounded-player fixture")
  var wounded:float=health.current
  _check(r,wounded>0.0 and wounded<health.capacity,"healing fixture is genuinely missing current HP")
  var heart_enemy:EnemyMotor=stage.enemies[heart_index]
  var heart_actor:EnemyActor=heart_enemy.get_node("Actor")
  var heart_id:String=stage.enemy_manifest[heart_index].id
  _check(r,await _hit(tree,app,StringName(heart_id),heart_actor.health,heart_actor.health.current,"loot-native-heal-death"),"actual second enemy death produces its recorded probability bonus")
  app.player.reset_at(stage.spawn);await _frames(tree,180)
  var heart:Dictionary={}
  for pickup:Dictionary in stage.pickups:
   if str(pickup.get("source",""))==heart_id and pickup.kind=="heart":heart=pickup
  _check(r,not heart.is_empty(),"actual App materializes the separate life-orb entitlement")
  if not heart.is_empty():
   app.player.reset_at(stage.to_global(heart.position)+Vector2(0,-12))
   var old_hp:float=health.current
   _check(r,app._commit_pickup(stage.pickups.find(heart)),"real life orb commits HEAL_CURRENT")
   var actual_delta:float=health.current-old_hp
   _check(r,actual_delta>0.0 and actual_delta<=float(heart.amount) and health.current<=health.capacity,"actual healing changes current HP only and respects its cap")
   var feedback:PlayerFeedback=app.player.get_node("PlayerFeedback")
   _check(r,is_equal_approx(feedback.last_healed_amount,actual_delta),"player glow uses the committed healing amount")
   _check(r,not app._commit_pickup(stage.pickups.find(heart)),"life-orb receipt and healing cannot replay")
   r.samples.append({"wounded":wounded,"hp_before_collect":old_hp,"actual_healed":actual_delta,"hp_after_collect":health.current})
 # A second real death exercises the automatic App tick -> queue -> commit
 # counterpart. The per-unit direct tests above remain for receipt precision.
 var automatic_index:=-1
 for i:int in stage.enemies.size():
  var candidate_actor:EnemyActor=stage.enemies[i].get_node("Actor")
  if candidate_actor.health.terminal:continue
  var candidate_id:String=stage.enemy_manifest[i].id
  var has_heart:=false
  for reward:Dictionary in EnemyDropService.rewards_of(stage.generated.manifest.enemy_drops[candidate_id]):
   has_heart=has_heart or reward.kind=="heart"
  if not has_heart:automatic_index=i;break
 _check(r,automatic_index>=0,"automatic pickup fixture uses another genuinely alive non-healing enemy")
 if automatic_index>=0:
  var automatic_enemy:EnemyMotor=stage.enemies[automatic_index]
  var automatic_actor:EnemyActor=automatic_enemy.get_node("Actor")
  var automatic_id:String=stage.enemy_manifest[automatic_index].id
  app.player.reset_at(stage.to_global(stage.spawn))
  _check(r,await _hit(tree,app,StringName(automatic_id),automatic_actor.health,automatic_actor.health.current,"loot-native-automatic-death"),"automatic counterpart starts with another real accepted death")
  var automatic_units:Array[Dictionary]=[]
  var automatic_total:=0
  for pickup:Dictionary in stage.pickups:
   if str(pickup.get("source",""))==automatic_id and pickup.kind=="coin":automatic_units.append(pickup);automatic_total+=int(pickup.amount)
  _check(r,not automatic_units.is_empty(),"automatic counterpart produces actual independently receipted coins")
  if not automatic_units.is_empty():
   var automatic_before:float=app.wallet.balance
   app.player.reset_at(stage.to_global(automatic_units[0].position)+Vector2(0,-12))
   await _frames(tree,2)
   var early_unclaimed:=true
   for unit:Dictionary in automatic_units:early_unclaimed=early_unclaimed and not unit.claimed
   _check(r,early_unclaimed and app.wallet.balance==automatic_before,"real automatic proximity ticks cannot bypass the initial spray lock")
   app.player.reset_at(stage.to_global(stage.spawn));await _frames(tree,30)
   for unit:Dictionary in automatic_units:
    if unit.claimed:continue
    app.player.reset_at(stage.to_global(unit.position)+Vector2(0,-12))
    await _frames(tree,2)
    _check(r,unit.claimed,"actual App automatic tick queues and commits the approached ready coin")
   var automatically_claimed:=true
   for unit:Dictionary in automatic_units:automatically_claimed=automatically_claimed and bool(unit.claimed)
   _check(r,automatically_claimed and app.wallet.balance==automatic_before+automatic_total,"automatic queue and commit pay the full configured amount exactly once")
   for unit:Dictionary in automatic_units:_check(r,not app._commit_pickup(stage.pickups.find(unit)),"automatically collected receipt rejects subsequent manual replay")
   app.player.reset_at(stage.to_global(stage.spawn))
   r.samples.append({"automatic_enemy":automatic_id,"automatic_coin_total":automatic_total,"automatic_wallet_delta":app.wallet.balance-automatic_before,"scope":"Actual App tick/queue/commit with explicit player approach, not natural traversal"})
 # Translate the existing actual Stage, without changing any pickup's local
 # entitlement or granting a fake item. Local coordinates must not authorize
 # a distant world-space player; the real world position must authorize it.
 var translated_index:=-1
 for i:int in stage.pickups.size():
  if stage.pickups[i].kind=="coin" and not stage.pickups[i].claimed and not stage.pickups[i].has("source"):
   translated_index=i;break
 _check(r,translated_index>=0,"translated proximity fixture uses an existing unclaimed authored coin")
 if translated_index>=0:
  var translated_pickup:Dictionary=stage.pickups[translated_index]
  var old_stage_transform:Transform2D=stage.transform
  var old_player_position:Vector2=app.player.global_position
  stage.position+=Vector2(640,180)
  var translated_before:float=app.wallet.balance
  app.player.reset_at(translated_pickup.position)
  _check(r,not app._commit_pickup(translated_index) and not translated_pickup.claimed and app.wallet.balance==translated_before,"old apparent local proximity cannot claim a distant translated world pickup")
  app.player.reset_at(stage.to_global(translated_pickup.position))
  _check(r,app._commit_pickup(translated_index) and translated_pickup.claimed and app.wallet.balance==translated_before+int(translated_pickup.amount),"actual translated world proximity commits the original authored receipt")
  _check(r,not app._commit_pickup(translated_index),"translated world receipt cannot replay")
  r.samples.append({"translated_pickup":str(translated_pickup.id),"stage_offset":[640,180],"actual_amount":int(translated_pickup.amount),"wallet_delta":app.wallet.balance-translated_before,"scope":"Explicit rigid Stage translation; no entitlement or target position replacement"})
  stage.transform=old_stage_transform;app.player.reset_at(old_player_position)
 # Verify current saved physical entitlements, including claimed per-unit IDs.
 tree.paused=true;stage.capture_state()
 var snapshot:Dictionary=app.region_state.snapshot()
 var balances:float=app.wallet.balance
 app._load_stage();await tree.process_frame;await tree.process_frame
 stage=app.stage as GeneratedDemoStage;_isolate(app)
 var loaded_count:=0
 for pickup:Dictionary in stage.pickups:
  if str(pickup.get("source",""))==identity:
   loaded_count+=1
   _check(r,pickup.claimed,"same saved physical unit restores its claimed receipt")
 _check(r,loaded_count==units.size(),"reload restores exact unit count without new death spray")
 _check(r,app.wallet.balance==balances,"reload never pays previously claimed units again")
 _check(r,app.region_state.snapshot().drops.size()==snapshot.drops.size(),"reload retains per-enemy death ledger")
 tree.paused=false
 r.samples.append({"enemy":identity,"configured_coin_total":expected_coin,"physical_coin_total":total,"paid_coin_total":paid,"wallet_delta":balances-before,"saved_unit_count":units.size(),"restored_unit_count":loaded_count})
 return r
