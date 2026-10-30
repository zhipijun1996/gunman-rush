extends SceneTree
## Regression adapted from independent D082 round3 probe; explicit outcome fixtures.
var failures:=0
var assertions:=0
var app:DemoApp
func _initialize():run.call_deferred()
func check(ok,label):
 assertions+=1
 if not ok:failures+=1;printerr("FAIL "+label)
func frames(n):
 for i in n:await physics_frame
func isolate(node):
 if node is DemoContactEmitter:node.enabled=false
 if node is EnemyAttackBehavior:node.set_physics_process(false)
 for child in node.get_children():isolate(child)
func run():
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app);await frames(2)
 check(app.start_plains("d082-round3-drops"),"formal start");await frames(8);isolate(app)
 var stage:PlainsRegionStage=app.stage
 var idx:=-1
 for i in stage.enemies.size():
  if stage.generated.manifest.enemy_drops[stage.enemy_manifest[i].id].kind=="coin":idx=i;break
 check(idx>=0,"deterministic existing coin drop fixture found")
 if idx<0:quit(1);return
 var enemy:EnemyMotor=stage.enemies[idx]
 var actor:EnemyActor=enemy.get_node("Actor")
 var id:String=stage.enemy_manifest[idx].id
 var request:=DamageRequest.new();request.token=app.lifetime.token();request.actor_epoch=app.lifetime.actor_epoch;request.health_epoch=actor.health.epoch;request.target_id=StringName(id);request.source_id=&"explicit_review_fixture";request.event_id=&"kill_drop";request.amount=actor.health.current
 check(app.policy.submit(request),"real deterministic death request accepted")
 await frames(2)
 var pickup_idx:=-1
 for i in stage.pickups.size():
  if stage.pickups[i].id=="drop_"+id:pickup_idx=i;break
 check(pickup_idx>=0,"accepted death creates stable drop")
 var data:Dictionary=stage.pickups[pickup_idx]
 # The old single cosmetic token is now real individually receipted 1/5 units.
 # Keep the original seed, accepted death and every bounded observation below.
 var coin_indices:Array[int]=[]
 var coin_ids:Array[String]=[]
 var unit_total:=0
 var denominations_ok:=true
 for i in stage.pickups.size():
  var unit:Dictionary=stage.pickups[i]
  if str(unit.get("source",""))!=id or unit.kind!="coin":continue
  coin_indices.append(i);coin_ids.append(str(unit.id));unit_total+=int(unit.amount)
  denominations_ok=denominations_ok and int(unit.amount) in [1,5]
 var configured_coin_total:int=int(stage.generated.manifest.enemy_drops[id].configured_coin_total)
 check(not coin_indices.is_empty() and unit_total==configured_coin_total and denominations_ok,"all physical coin denominations sum to the independently recorded configured entitlement")
 var unique_ids:Dictionary={}
 for identity:String in coin_ids:unique_ids[identity]=true
 check(unique_ids.size()==coin_ids.size(),"every physical denomination has a distinct stable receipt identity")
 app.player.reset_at(data.position);var before:float=app.wallet.balance
 check(not app._commit_pickup(pickup_idx),"arrival blocks early grant")
 check(app.wallet.balance==before and not data.claimed,"early physical contact cannot change wallet or consume a unit")
 var visual:PlainsStageVisual=stage.visual_layer
 visual._process(0)
 var birth_position:Vector2=data.position
 var origin:Vector2=data.spawn_origin
 # Keep the original 42-frame interval. Stand at the original safe spawn to
 # observe flight; collection is then tested at each unit's actual position.
 app.player.reset_at(stage.spawn)
 await frames(42)
 visual._process(0)
 check(data.position.distance_to(origin)>1 and visual._pickup_by_id[data.id].position.is_equal_approx(data.position),"drop visibly in flight")
 check(data.position.distance_to(birth_position)>1 and bool(data.get("loot_motion",false)),"real position advances instead of an independent cosmetic arrival path")
 check(app.wallet.balance==before,"bounded spray observation at the safe spawn cannot silently collect the staged reward")
 var existing_count:int=stage.pickups.size()
 app._settle_enemy_drops();app._settle_enemy_drops()
 check(stage.pickups.size()==existing_count,"repeating death settlement cannot create another physical unit or entitlement")
 for unit_index:int in coin_indices:
  var unit:Dictionary=stage.pickups[unit_index]
  check(not unit.claimed and stage.clock>=float(unit.ready_at),"each denomination is unclaimed and pickup-ready after the original observation")
  app.player.reset_at(unit.position)
  var unit_before:float=app.wallet.balance
  check(app._commit_pickup(unit_index) and unit.claimed and app.wallet.balance==unit_before+int(unit.amount),"actual App commit credits exactly this ready denomination")
  check(not app._commit_pickup(unit_index) and app.wallet.balance==unit_before+int(unit.amount),"same physical receipt cannot be credited twice")
 var every_claimed:=true
 for unit_index:int in coin_indices:every_claimed=every_claimed and bool(stage.pickups[unit_index].claimed)
 check(every_claimed and app.wallet.balance==before+configured_coin_total,"arrival grants coin exactly once")
 check(not app._commit_pickup(pickup_idx),"repeat claim rejected")
 visual._process(0)
 var every_collecting:=true
 for identity:String in coin_ids:every_collecting=every_collecting and bool(visual._pickup_by_id[identity].visible)
 check(every_collecting,"claimed sprite remains for collection")
 app.player.reset_at(stage.spawn)
 await frames(18);visual._process(.3)
 var every_hidden:=true
 for identity:String in coin_ids:every_hidden=every_hidden and not bool(visual._pickup_by_id[identity].visible)
 check(every_hidden,"collection completes and disappears")
 paused=true;stage.capture_state();app._load_stage();await process_frame;await process_frame
 stage=app.stage;visual=stage.visual_layer;visual._process(0)
 var restored_idx:=-1
 var restored_ids:Dictionary={}
 var restored_total:=0
 var restored_all_claimed:=true
 for i in stage.pickups.size():
  var unit:Dictionary=stage.pickups[i]
  if unit.id=="drop_"+id:restored_idx=i
  if str(unit.id) not in coin_ids:continue
  restored_ids[str(unit.id)]=true;restored_total+=int(unit.amount)
  restored_all_claimed=restored_all_claimed and bool(unit.claimed)
 check(restored_idx>=0 and stage.pickups[restored_idx].claimed and restored_all_claimed,"reload restores consumed stable receipt")
 var restored_hidden:=true
 for identity:String in coin_ids:restored_hidden=restored_hidden and visual._pickup_by_id.has(identity) and not bool(visual._pickup_by_id[identity].visible)
 check(restored_hidden,"reload does not replay collected sprite")
 check(restored_ids.size()==coin_ids.size() and restored_total==configured_coin_total,"reload retains every denomination once and preserves the exact configured sum")
 check(app.wallet.balance==before+configured_coin_total,"reload does not pay twice")
 paused=false;await frames(8);isolate(app)
 app.player.reset_at(Vector2(stage.boss_arena.position.x+70,stage.boss_arena.end.y-18));await frames(48);isolate(app)
 check(stage.boss_seal.closed,"formal seal active")
 await frames(60)
 var health:HealthState=app.controller.actor_resources.health
 var hit:=DamageRequest.new();hit.token=app.lifetime.token();hit.actor_epoch=app.lifetime.actor_epoch;hit.health_epoch=health.epoch;hit.target_id=&"player";hit.source_id=&"explicit_environment_fixture";hit.event_id=&"sealed_environment";hit.kind=DamageRequest.Kind.ENVIRONMENT;hit.amount=1
 check(app.policy.submit(hit),"actual environment return request accepted")
 await frames(3)
 check(stage.boss_arena.encloses(Rect2(app.player.position-Vector2(12,18),Vector2(24,36))) and app.controller.active,"environment return leaves actor active inside seal")
 check(stage.boss_seal.closed and health.current>0,"environment return preserves closed gate and live health")
 if not await load("res://tests/audio_teardown.gd").drain_world(app):
  push_error("TEST AUDIO TEARDOWN: playback did not release within 1000ms");quit(1);return
 app.free();paused=false
 print("PLAINS COHESION DROPS: %s assertions, %s failures"%[assertions,failures]);quit(1 if failures else 0)
