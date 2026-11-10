extends "res://tests/world/plains35_fixture.gd"
func run() -> void:
 root.size=Vector2i(1280,720)
 app=load("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_feedback5.json";root.add_child(app);app.workbench.enabled=true
 await load_room("P-R24");await fixture(Vector2(1984,1102));await ticks(75)
 var attacking:Dictionary={}
 for i:int in 150:
  await ticks(1)
  for id:String in app.wave_encounter.active_ids:
   var enemy:EnemyActor=app.room.enemies[id]
   if enemy.attack_behavior!=null and enemy.attack_behavior.state==&"attack":attacking[id]=true
 check(attacking.size()>=2,"P24 multiple active threats commit attacks without being approached")
 app._commit_action("intro_clear_waves");await ticks(90)
 check((app.camera as WorldCamera).zones.active_id=="hall","P24 clear returns to horizontal hall")
 check(absf(app.camera.global_position.y-960)<45,"P24 clear keeps the next route and floor in view")
 await fixture(Vector2(1136,1102));await ticks(25)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(95);app.controller.router.clear("secret traverse");await ticks(40)
 check((app.camera as WorldCamera).zones.active_id=="secret" and absf(app.camera.global_position.y-976)<40,"P24 secret horizontal entry keeps a stable floor composition")
 await load_room("P-R31")
 await hop(Vector2(928,878),Vector2(1216,878),Vector2.LEFT,"P31 culvert recoil")
 await hop(Vector2(1552,510),Vector2(1840,526),Vector2.LEFT,"P31 hoist-bank recoil connection")
 await load_room("P-R32")
 await hop(Vector2(736,1006),Vector2(1056,942),Vector2(-.9,.4),"P32 first broken bridge")
 await hop(Vector2(1440,942),Vector2(1696,814),Vector2(-.8,.6),"P32 second pier rise")
 await load_room("P-R32","h")
 await fixture(Vector2(1184,942));app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(12)
 app.controller.router.request_action(&"grapple",(Vector2(1200,680)-app.player.position-Vector2(0,-6)).normalized())
 for i:int in 90:
  await ticks(1)
  if app.controller.traversal.state==&"hook_hang":break
 check(app.controller.traversal.state==&"hook_hang","P32 lower stop anchor")
 app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 90:
  await ticks(1)
  if app.player.position.x<1104:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if i>10 and app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-622)<5,"P32 held anchor jumps onto broad upper bank "+str(app.player.position))
 await hook(Vector2(1104,622),Vector2(960,416),"P32 upper anchor after bank",12)
 app.controller.router.request_action(&"grapple",(Vector2(960,224)-app.player.position-Vector2(0,-6)).normalized());await ticks(60)
 check(app.controller.traversal.state==&"hook_hang" and app.player.position.distance_to(Vector2(960,224))<65,"P32 final anchor reaches top doorway")
 exercise_story=true
 await load_room("P-R01")
 await fixture((app.room.get_node("StationLift") as WorldMovingPlatform).position-Vector2(0,28))
 for i:int in 650:
  await ticks(1)
  if app.room.room_id!="P-R01":check(false,"station carrier unexpectedly left room at "+str(app.player.position));quit(1);return
  if app.story.active:break
 check(app.story.active and app.player.position.y<=1264,"first lift delivers the player to station before briefing")
 app.story.finish();await ticks(5)
 await fixture(Vector2(1392,1262));app.controller.router.request_action(&"shoot_release",Vector2.UP);await ticks(15)
 var upper:=app.room.get_node("UpperStationLift") as WorldMovingPlatform
 check(upper.motion_running,"safe bank shot rings upper lift bell")
 await hop(Vector2(1392,1262),Vector2(1536,1204),Vector2.ZERO,"board upper carrier from safe station bank")
 for i:int in 850:
  await ticks(1)
  if upper.position.y<=384.1:break
 check(app.player.is_on_floor() and absf(app.player.position.y-356)<5,"upper lift carries player with clear headroom "+str(app.player.position))
 var first:=app.room.get_node("StationLift") as WorldMovingPlatform
 check(first.endpoint.x==0 and first.endpoint.y==-464,"P01 first carrier ends at station rather than upper gate")
 check(app.room.mechanisms.has("P01:upper_station_lift"),"P01 second lift is bound to a real bell")
 await fixture(Vector2(1984,366));await ticks(3)
 check(app.story.active and app.story.guarding,"P01 NPC intercepts without yellow wall")
 app.story.finish();await ticks(120)
 check(not app.paused and app.player.position.x<1940,"NPC refusal walks player back onto safe bank")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(3)
 print("PLAINS FEEDBACK5: ",failures," failures");quit(failures)
