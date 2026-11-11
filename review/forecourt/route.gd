extends "res://tests/world/approved_hub_actions.gd"
func mark(label:String)->void:print("MOVIE_MARK ",label," ",Engine.get_frames_drawn()," position ",app.player.position)
func walk(x:float)->void:
 var id:=app.room.room_id
 for i:int in 300:
  if app.room.room_id!=id or absf(app.player.position.x-x)<5:break
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(x-app.player.position.x));await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(8)
func jump_to(target:Vector2,aim:Vector2=Vector2.ZERO,delay:int=16)->void:
 var axis:=signf(target.x-app.player.position.x)
 app.controller.router.set_source_axis(&"keyboard_mouse",axis)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(delay)
 if aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim)
 for i:int in 110:
  await ticks(1)
  if (target.x-app.player.position.x)*axis<8:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():break
 app.controller.router.clear("landing")
 check(app.player.is_on_floor() and absf(app.player.position.y-target.y)<6,"continuous landing "+str(target)+" actual "+str(app.player.position));await ticks(12)
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R33","HUB-P32-P33:P-R33","base"),"actual west entry; base review stage")
 await ticks(30);mark("entry")
 await walk(768);await ticks(30);mark("approach")
 await walk(1536);await ticks(60);mark("portal")
 app._interact();await ticks(100)
 check(app.room.room_id=="Z-R01","continuous enters interior");mark("interior")
 await walk(640);await ticks(30)
 check(app.story.active,"actual interior investigation starts")
 app.story.finish();await ticks(25)
 check(app.state.has("clockheart_briefed"),"actual investigation receipt")
 await walk(256);app._interact();await ticks(100)
 check(app.room.room_id=="P-R33","continuous return from interior");mark("front_return")
 await walk(1024);await ticks(12)
 well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false)
 await ticks(90)
 check(app.player.is_on_floor() and absf(app.player.position.y-814)<6,"down+jump reaches lower step "+str(app.player.position));mark("middle_step")
 await walk(1152);await ticks(30)
 check(app.player.is_on_floor() and absf(app.player.position.y-910)<6,"continuous lower bank "+str(app.player.position));mark("foundation")
 await jump_to(Vector2(1024,814))
 await jump_to(Vector2(1024,558),Vector2.DOWN)
 mark("recoil_return")
 await walk(800);await ticks(30)
 await walk(-40);await ticks(100)
 check(app.room.room_id=="P-R32","west doorway return");mark("west_return")
 await walk(3100);await ticks(100)
 check(app.room.room_id=="P-R33","west doorway reentry")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
