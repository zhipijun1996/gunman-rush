extends "res://tests/world/plains35_fixture.gd"
## Actual H-only climb; no mid-route teleports or altered ability parameters.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R01","","h",true),"H-stage return-state fixture")
 await app.load_room("P-R03","");await ticks(5)
 if is_instance_valid(app.story) and app.story.active:app.story.finish()
 await fixture(Vector2(144,1774))
 for point:Vector2 in [Vector2(208,1584),Vector2(272,1408),Vector2(336,1232),Vector2(352,1056)]:
  var aim:=(point-app.player.global_position-Vector2(0,-6)).normalized()
  app.controller.router.request_action(&"grapple",aim)
  for i:int in 150:
   await ticks(1)
   if app.controller.traversal.state==&"hook_hang":break
  check(app.controller.traversal.state==&"hook_hang" and app.player.global_position.distance_to(point)<80,"real hook reaches "+str(point)+" actual "+str(app.player.position))
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(5);app.controller.router.set_jump_held(&"keyboard_mouse",false)
 for i:int in 100:
  if app.player.position.x<248:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  await ticks(1)
  if app.player.is_on_floor():break
 check(app.player.is_on_floor() and absf(app.player.position.y-1102)<5,"H chain ends on upper receiving deck")
 # Align on the real deck before jumping; rising under the closed part of
 # the ceiling must correctly stop a premature diagonal jump.
 for i:int in 90:
  app.controller.router.set_source_axis(&"keyboard_mouse",clampf((192-app.player.position.x)/48,-1,1))
  await ticks(1)
  if absf(app.player.position.x-192)<5:break
 # Final ordinary jump is the real threshold crossing after the H climb.
 app.controller.router.set_source_axis(&"keyboard_mouse",0)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 180:
  if app.room.room_id=="P-R03":app.controller.router.set_source_axis(&"keyboard_mouse",clampf((192-app.player.position.x)/64,-1,1))
  await ticks(1)
  if app.room.room_id=="M-R02" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="M-R02" and not app.busy and app.player.is_on_floor(),"actual upper-left exit enters mushroom sample actual="+app.room.room_id+" "+str(app.player.position)+" "+app.status)
 if OS.get_cmdline_user_args().has("capture"):
  await WorldAudioLifecycle.drain_world(app)
  print("OPENING HOOK EXIT CAPTURE: ",failures," failures");quit(failures);return
 # Missing H cannot use anchors. The nearest valid floor is >600wu below
 # the receiving deck; no ordinary platforms bridge that climb.
 check(await app.review.begin("P-R01","","base",true),"base-stage negative climb fixture")
 await app.load_room("P-R03","");await ticks(5)
 if is_instance_valid(app.story) and app.story.active:app.story.finish()
 await fixture(Vector2(144,1774))
 app.controller.router.request_action(&"grapple",Vector2(96,-190).normalized());await ticks(2)
 check(app.controller.traversal.state==&"free","unearned H cannot latch onto the visible anchors")
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(12)
 app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
 var min_y:=app.player.position.y
 for i:int in 110:
  await ticks(1);min_y=minf(min_y,app.player.position.y)
  if app.player.is_on_floor():break
 check(app.room.room_id=="P-R03" and min_y>1180,"base jump plus upward recoil cannot reach H-only receiving deck")
 await WorldAudioLifecycle.drain_world(app);print("OPENING HOOK EXIT: ",failures," failures");quit(failures)
