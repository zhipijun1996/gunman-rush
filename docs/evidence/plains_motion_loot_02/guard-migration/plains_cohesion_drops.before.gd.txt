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
 app.player.reset_at(data.position);var before:float=app.wallet.balance
 check(not app._commit_pickup(pickup_idx),"arrival blocks early grant")
 var visual:PlainsStageVisual=stage.visual_layer
 visual._process(0)
 check(visual._pickup_by_id[data.id].position.distance_to(data.position)>1,"drop visibly in flight")
 await frames(42)
 check(data.claimed and app.wallet.balance==before+data.amount,"arrival grants coin exactly once")
 check(not app._commit_pickup(pickup_idx),"repeat claim rejected")
 visual._process(0)
 check(visual._pickup_by_id[data.id].visible,"claimed sprite remains for collection")
 await frames(18);visual._process(.3)
 check(not visual._pickup_by_id[data.id].visible,"collection completes and disappears")
 paused=true;stage.capture_state();app._load_stage();await process_frame;await process_frame
 stage=app.stage;visual=stage.visual_layer;visual._process(0)
 var restored_idx:=-1
 for i in stage.pickups.size():
  if stage.pickups[i].id=="drop_"+id:restored_idx=i;break
 check(restored_idx>=0 and stage.pickups[restored_idx].claimed,"reload restores consumed stable receipt")
 check(not visual._pickup_by_id["drop_"+id].visible,"reload does not replay collected sprite")
 check(app.wallet.balance==before+data.amount,"reload does not pay twice")
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
