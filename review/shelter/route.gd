extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R27","WEST-P26-P27:P-R27","base"),"P27 actual lower entry")
 await ticks(20);mark("entry")
 check(app.player.is_on_floor() and absf(app.player.position.y-718)<5,"lower entrance supported")
 await walk_to(704)
 await jump_to(Vector2(864,558),Vector2.DOWN,"continuous entry recoil onto rest bank")
 await walk_to(960)
 check(app.context_target().get("kind")=="rest","rest station reached naturally")
 var cycle:int=app.state.value.cycle
 app._interact();await ticks(6)
 check(is_instance_valid(app.rest_sequence) and app.rest_sequence.active,"actual rest starts")
 for i:int in 360:
  await ticks(1)
  if not is_instance_valid(app.rest_sequence) or not app.rest_sequence.active:break
 check(app.controller.active and app.state.value.cycle==cycle+1,"rest completes and returns input")
 mark("east")
 await walk_to(1730);await ticks(45)
 check(app.room.room_id=="P-R05","continuous east exit reaches P05")
 if app.room.room_id=="P-R05":
  await walk_to(-50);await ticks(45)
  check(app.room.room_id=="P-R27","P05 doorway returns to rest courtyard")
 mark("ascent")
 await walk_to(820)
 await jump_to(Vector2(584,430),Vector2(.8,.6),"rest bank to first ascent deck")
 await jump_to(Vector2(624,270),Vector2.DOWN,"second ascent deck")
 await jump_to(Vector2(768,142),Vector2.ZERO,"upper bell deck")
 mark("north")
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
 app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(65)
 app.controller.router.clear("north entry")
 check(app.room.room_id=="P-R14","upper exit reaches Windkeeper approach")
 if app.room.room_id=="P-R14":
  for door:Dictionary in app.room.doors:
   if door.target_room=="P-R27":
    var at:=FixedWorldProvider.point(door.position_candidate.local_world_units)
    print("P14 RETURN ",at," player ",app.player.position)
    await walk_to(at.x)
    well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false);await ticks(95)
    break
  check(app.room.room_id=="P-R27","upper doorway supports return")
 mark("shaft")
 if app.room.room_id=="P-R27":
  await walk_to(700)
  well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false);await ticks(50)
  await walk_to(600)
  well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false);await ticks(55)
  well_key(KEY_S,true);well_key(KEY_SPACE,true);await ticks(8);well_key(KEY_SPACE,false);well_key(KEY_S,false);await ticks(60)
  check(app.player.is_on_floor() and absf(app.player.position.y-718)<5,"continuous descent to lower bank")
  await walk_to(512);await ticks(60)
  check(app.room.room_id=="P-R26","open lower shaft reaches windmill interior")
  if app.room.room_id=="P-R26":
   for door:Dictionary in app.room.doors:
    if door.target_room=="P-R27":
     var at:=FixedWorldProvider.point(door.position_candidate.local_world_units)
     await walk_to(at.x)
     app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
     app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(90)
     app.controller.router.clear("return up shaft")
     break
   check(app.room.room_id=="P-R27" and app.player.is_on_floor(),"shaft returns onto actual receiving bank")
 await ticks(30)
 await WorldAudioLifecycle.drain_world(app);quit(failures)

func mark(label:String)->void:print("MOVIE_MARK ",label," ",Engine.get_frames_drawn()," physics ",Engine.get_physics_frames())
func walk_to(x:float)->void:
 var id:=app.room.room_id
 for i:int in 600:
  if app.room.room_id!=id or absf(app.player.position.x-x)<5:break
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(x-app.player.position.x));await ticks(1)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(3)
func jump_to(target:Vector2,aim:Vector2,label:String)->void:
 var axis:=signf(target.x-app.player.position.x)
 app.controller.router.set_source_axis(&"keyboard_mouse",axis);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(16)
 if aim!=Vector2.ZERO:app.controller.router.request_action(&"shoot_release",aim)
 var reached:=false
 for i:int in 120:
  await ticks(1)
  if (app.player.position.x-target.x)*axis>=0 or absf(app.player.position.x-target.x)<5:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.player.is_on_floor():
   reached=absf(app.player.position.y-target.y)<5;break
 check(reached,label+" "+str(app.player.position));app.controller.router.clear("jump complete")
 await ticks(12)
