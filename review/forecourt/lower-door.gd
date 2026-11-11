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
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R35","HUB-P33-P35:P-R35","base"),"actual lower neighbor arrival")
 await ticks(20)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 90:
  await ticks(1)
  if app.room.room_id=="P-R33":break
 app.controller.router.clear("returned through ceiling");await ticks(45)
 check(app.room.room_id=="P-R33" and app.player.is_on_floor() and absf(app.player.position.y-910)<6,"P35 ordinary jump arrives on actual P33 safe bank "+str(app.player.position))
 await walk(1024);await ticks(70)
 check(app.room.room_id=="P-R35" and app.player.is_on_floor(),"P33 lower mouth returns to P35 landing")
 await WorldAudioLifecycle.drain_world(app);quit(failures)
