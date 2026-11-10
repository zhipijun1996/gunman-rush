extends "res://tests/world/approved_exploration_rooms.gd"
## Real formal rooms. Local starts isolate each lesson; no H is granted for shooting paths.
func live_room(id:String,targets:Array[String])->void:
 await app.review.begin(id,"","base");await ticks(5)
 for key:String in app.room.enemies:
  if key in targets:continue
  var enemy:EnemyActor=app.room.enemies[key]
  enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)

func air_hit(id:String)->void:
 var enemy:EnemyActor=app.room.enemies[id]
 var before:=enemy.health.current
 app.controller.router.request_action(&"shoot_release",(enemy.motor.position-app.player.position-Vector2(0,-6)).normalized())
 await ticks(16)
 check(enemy.health.current<before and app.controller.action_resources.shot_charges==1 and not app.player.is_on_floor(),id+" actual air hit replenishes next shot "+str(app.player.position))

func land_at(target:Vector2,label:String)->void:
 for frame:int in 120:
  await ticks(1)
  app.controller.router.set_source_axis(&"keyboard_mouse",clampf((target.x-app.player.position.x)/35.0,-1,1))
  if app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-target.y)<5,label+" "+str(app.player.position))
 app.controller.router.clear("lesson completed")

func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 if selected("P-R10"):
  await live_room("P-R10",["P-R10:r9:teach_down"])
  await fixture(Vector2(896,2030));app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(18);app.controller.router.set_source_axis(&"keyboard_mouse",0)
  await air_hit("P-R10:r9:teach_down");app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  await land_at(Vector2(1056,1678),"P10 first two-shot lesson")
  await live_room("P-R10",["P-R10:r9:teach_diagonal"])
  await fixture(Vector2(1296,1678));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(22)
  await air_hit("P-R10:r9:teach_diagonal");app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  await land_at(Vector2(1120,1326),"P10 diagonal then down-shot lesson")
  await live_room("P-R10",["P-R10:r9:combo_left","P-R10:r9:combo_down","P-R10:r9:combo_right"])
  await fixture(Vector2(896,1326));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(22)
  await air_hit("P-R10:r9:combo_left");await air_hit("P-R10:r9:combo_down");await air_hit("P-R10:r9:combo_right")
  app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  await land_at(Vector2(960,718),"P10 four real shots cross 608-height space")
  await load_room("P-R10")
  await hop(Vector2(960,718),Vector2(896,430),Vector2.DOWN,"P10 final recoil to shared reward")
  await cache("open_P10_high_wind_cache",Vector2(832,430),20)
 if selected("P-R20"):
  await load_room("P-R20")
  await fixture(Vector2(2352,942));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
  for frame:int in 60:
   await ticks(1)
   if app.player.position.x<=2240 and app.player.position.y>=998:break
  app.controller.router.request_action(&"shoot_release",(Vector2(2360,1088)-app.player.position-Vector2(0,-6)).normalized())
  var opened:=false
  for frame:int in 100:
   await ticks(1)
   opened=opened or app.room.mechanisms["P-R20:r8:sluice"].is_open
   if app.player.position.x<2024:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(opened and app.player.is_on_floor() and app.player.position.x<2080,"P20 falling shot opens sluice and recoils through "+str(app.player.position))
  app.controller.router.clear("sluice complete")
  await fixture(Vector2(432,942));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
  app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  for frame:int in 90:
   await ticks(1)
   if app.player.position.y<680:app.controller.router.set_source_axis(&"keyboard_mouse",-1)
   if app.player.position.x<336:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-718)<5,"P20 vertical recoil clears solid shoulder before turning "+str(app.player.position))
  app.controller.router.clear("western shoulder")
  await hop(Vector2(288,718),Vector2(80,526),Vector2(.8,.6),"P20 recoil to seawall cache")
  await cache("open_P20_seawall_cache",Vector2(80,526),15)
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED FINAL ROOMS: ",failures," failures");quit(failures)
