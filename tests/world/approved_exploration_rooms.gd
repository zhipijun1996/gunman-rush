extends "res://tests/world/approved_clock_rooms.gd"
## Local approaches exercise the actual formal controller, not a full room run.
func cache(id:String,at:Vector2,amount:int)->void:
 await super.cache(id,at,amount);await ticks(30)

func pickup_return(pickup:String,latch:String,at:Vector2,switch_at:Vector2)->void:
 if pickup=="pickup_HP01":check(not app.state.holds(app.content.action(latch).requires),pickup+" return locked before reward")
 await fixture(at);app._interact();await ticks(4)
 check(app.state.value.receipts.has(pickup),pickup+" actual pickup")
 await fixture(switch_at);app._interact();await ticks(4)
 check(app.state.value.receipts.has(latch),pickup+" actual reward-qualified return")

func clock_shutter()->void:
 var lift:=app.room.get_node("DrainCage") as WorldMovingPlatform
 lift.restore_motion(13.6,true)
 await fixture(Vector2(879,674))
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(12)
 app.controller.router.request_action(&"shoot_release",(Vector2(816,624)-app.player.position-Vector2(0,-6)).normalized())
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 var opened:=false
 for frame:int in 100:
  await ticks(1)
  opened=opened or app.room.mechanisms["P-R12:air_shutter"].is_open
  if app.player.position.x>1053:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 check(opened and app.player.is_on_floor() and app.player.position.x>992 and absf(app.player.position.y-462)<5,"P12 moving-cage jump fires bell and recoils through timed roof shutter "+str(app.player.position))
 app.controller.router.clear("clock shutter complete")

func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 if selected("P-R12"):
  await load_room("P-R12")
  await clock_shutter()
  await cache("open_P12_cellar_cache",Vector2(160,1326),20)
  await pickup_return("pickup_EQ_MAP_P01","reward_return_EQ_MAP_P01_open",Vector2(1104,462),Vector2(1152,462))
  await hop(Vector2(1016,462),Vector2(816,302),Vector2(.8,.6),"P12 reward return upper shoulder")
 if selected("P-R13"):
  await load_room("P-R13")
  await hop(Vector2(5032,2062),Vector2(4672,1902),Vector2(.8,.6),"P13 rising thorn gap")
  await hop(Vector2(4368,1902),Vector2(4080,2062),Vector2(.8,-.6),"P13 falling thorn gap",10)
  await hop(Vector2(3744,2062),Vector2(3440,2030),Vector2.RIGHT,"P13 middle transition below hanging teeth")
  await fixture(Vector2(2960,2030));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
  for frame:int in 60:
   await ticks(1)
   if app.player.position.y>=2140:break
  app.controller.router.request_action(&"shoot_release",Vector2.RIGHT)
  for frame:int in 100:
   await ticks(1)
   if app.player.position.x<2624:app.controller.router.set_source_axis(&"keyboard_mouse",0)
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and app.player.position.x<2680 and absf(app.player.position.y-2222)<5,"P13 drop then horizontal recoil below final narrow roof "+str(app.player.position))
  app.controller.router.clear("narrow gap complete")
  await hop(Vector2(5024,2478),Vector2(4768,2478),Vector2.ZERO,"P13 lower road gap remains ordinary jump")
  await pickup_return("pickup_HP01","reward_return_HP01_open",Vector2(384,2222),Vector2(448,2222))
 if selected("P-R18"):
  await load_room("P-R18")
  await ride("P18","IrrigationCage",Vector2(2048,1376),Vector2(2080,1422))
  await ride("P18","CliffCarrier")
  await cache("open_P18_irrigation_cache",Vector2(672,1454),20)
  await hop(Vector2(1032,1454),Vector2(1376,1422),Vector2(-.8,.6),"P18 cellar return across ditch beside open well")
 if selected("P-R25"):
  await app.review.begin("P-R25","","base");await ticks(5)
  for key:String in app.room.enemies:
   if key=="P-R25:r7:air_fan_refill":continue
   var enemy:EnemyActor=app.room.enemies[key]
   enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)
  var target:EnemyActor=app.room.enemies["P-R25:r7:air_fan_refill"]
  await fixture(Vector2(1416,718))
  app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(22)
  app.controller.router.request_action(&"shoot_release",(target.motor.position-app.player.position-Vector2(0,-6)).normalized())
  await ticks(16)
  check(target.health.current<9 and not app.player.is_on_floor(),"P25 actual airborne projectile connects")
  check(app.controller.action_resources.shot_charges==1,"P25 committed hit replenishes the spent air shot")
  app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
  for frame:int in 100:
   await ticks(1)
   app.controller.router.set_source_axis(&"keyboard_mouse",clampf((1488-app.player.position.x)/30.0,-1,1))
   if app.player.is_on_floor():break
  check(app.player.is_on_floor() and absf(app.player.position.y-334)<5,"P25 hit-refill and second air recoil reaches reward "+str(app.player.position))
  app.controller.router.clear("reward approach complete");app._interact();await ticks(4)
  check(app.state.value.receipts.has("pickup_TG01"),"P25 actual high reward pickup")
 if selected("P-R34"):
  await load_room("P-R34")
  await cache("open_P34_eaves_cache",Vector2(96,430),15)
  await hop(Vector2(1136,1038),Vector2(1344,910),Vector2.DOWN,"P34 rise onto memorial cover",9)
  await hop(Vector2(1648,1038),Vector2(1944,1038),Vector2(-.8,.6),"P34 plaza crossing to east building")
  await hop(Vector2(2096,1038),Vector2(2224,846),Vector2.DOWN,"P34 eastern building first rise")
  await hop(Vector2(2304,846),Vector2(2496,590),Vector2.DOWN,"P34 eastern building second rise")
  await hop(Vector2(2528,590),Vector2(2656,366),Vector2.DOWN,"P34 eastern building final rise")
  await hop(Vector2(1648,1422),Vector2(1760,1230),Vector2.DOWN,"P34 lower well recovers through wide one-way shoulder")
  await hop(Vector2(1840,1230),Vector2(1984,1038),Vector2.DOWN,"P34 lower well recovers to plaza")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED EXPLORATION ROOMS: ",failures," failures");quit(failures)
