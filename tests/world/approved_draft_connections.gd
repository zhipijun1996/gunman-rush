extends "res://tests/world/approved_draft_actions.gd"
## Six actual crossings, including the vertical pair; local doorway approaches.
func cross(source:String,dest:String,start:Vector2,axis:float,jump:bool=false)->void:
 await load_room(source)
 await fixture(start)
 app.controller.router.set_source_axis(&"keyboard_mouse",axis)
 if jump:app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 360:
  await ticks(1)
  if app.room.room_id==dest and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id==dest and not app.busy and app.player.is_on_floor(),source+" -> "+dest+" real crossing "+str(app.player.position))
 app.controller.router.clear("crossing check")
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await cross("P-R28","P-R29",Vector2(2032,1262),1)
 await cross("P-R29","P-R28",Vector2(144,622),-1)
 await load_room("P-R29");await fixture(Vector2(1216,1358));app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i:int in 360:
  await ticks(1)
  if app.room.room_id=="P-R29" and app.player.position.x<1092:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.room.room_id=="P-R09" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R09" and app.player.is_on_floor(),"P29 -> P09 down opening and receiving bank "+str(app.player.position));app.controller.router.clear("drop entry")
 await cross("P-R09","P-R29",Vector2(1344,142),0,true)
 await cross("P-R01","P-R31",Vector2(2032,1198),1)
 await cross("P-R31","P-R01",Vector2(144,878),-1)
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED CONNECTIONS: ",failures," failures");quit(failures)
