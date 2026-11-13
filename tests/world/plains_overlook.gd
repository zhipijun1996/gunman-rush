extends "res://tests/world/plains_next_batch.gd"
## Local P24 fixtures exercise authored arena state, actual carrier and durable chest.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://overlook_round3.json";root.add_child(app)
 await load_room("P-R24")
 var zoom_before:=app.camera.zoom
 await fixture(Vector2(1984,1102));await ticks(75)
 for index:int in 3:
  var encounter:=app.wave_encounter
  check(encounter.wave==index and encounter.active_ids.size()==[3,4,5][index],"P24 wave population "+str(index))
  check((app.camera as WorldCamera).zones.active_id=="arena" and app.camera.zoom==zoom_before,"P24 stable arena composition without zoom")
  for id:String in encounter.active_ids:
   var enemy:=app.room.enemies[id] as EnemyActor
   check(enemy.health.capacity in [9.0,14.0],"P24 authored health "+id)
   enemy.damageable.receive_damage({"amount":1000.0,"source_actor_id":app.player.get_instance_id(),"event_id":StringName(id+":test"),"source_faction":&"player","target_actor_id":enemy.damageable.actor_id,"target_epoch":enemy.damageable.damage_epoch})
  await ticks(80)
 check(app.state.has("intro_arena_cleared") and app.wave_encounter.finished,"P24 three waves open gates")
 await fixture(Vector2(1344,1102))
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(38);app.controller.router.clear("boarded")
 check(app.player.is_on_floor() and absf(app.player.position.y-1044)<3,"P24 boards shifted lift")
 app.controller.router.request_action(&"shoot_release",Vector2.UP);await ticks(15)
 var lift:=app.room.get_node("OverlookLift") as WorldMovingPlatform
 check(lift.motion_running,"P24 onboard bell starts lift")
 for i:int in 650:
  await ticks(1)
  if lift.position.y<=208.1:break
 check(app.player.is_on_floor() and absf(app.player.position.y-180)<3,"P24 full ascent has headroom")
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 70:
  await ticks(1)
  if app.player.position.x<1180:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if i>15 and app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-142)<3,"P24 jumps left onto upper landing")
 await fixture(Vector2(1136,1102));await ticks(45)
 check(app.room.camera_concealers.secret.visible,"P24 hidden chamber concealed from main route")
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 120:
  await ticks(1)
  if app.player.position.x<690:break
 app.controller.router.clear("inside hidden chamber");await ticks(30)
 check(app.player.is_on_floor() and app.player.position.x<690 and not app.room.camera_concealers.secret.visible,"P24 walks through plant entrance into hidden room")
 var before_gold:int=app.services.ledger().gold
 app._interact();await ticks(3)
 var total:=0
 for drop:Dictionary in app.services.ledger().drops.values():
  if str(drop.source)=="chest:open_P24_hidden_chest":total+=int(drop.amount)
 total+=int(app.services.ledger().gold)-before_gold
 check(app.state.value.receipts.has("open_P24_hidden_chest") and total==20,"P24 chest commits exactly twenty scattered coins")
 
 app._interact();await ticks(2)
 check(app.state.value.receipts.has("income:chest:open_P24_hidden_chest"),"P24 chest payout idempotency receipt")
 var snapshot:Dictionary=app._snapshot()
 check(WorldServices.valid_ledger(snapshot.services),"P24 persisted chest coin ledger validates")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("OVERLOOK: ",failures," failures");quit(failures)
