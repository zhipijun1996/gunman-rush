extends "res://tests/world/approved_clock_connections.gd"
## Local doorway approaches, actual crossings and arrivals in the formal catalog.
func paired(source:String,dest:String)->void:
 await load_room(source)
 var matches:=app.room.doors.filter(func(d:Dictionary)->bool:return d.target_room==dest)
 check(matches.size()==1,source+" unique doorway to "+dest)
 if matches.is_empty():return
 var door:Dictionary=matches[0]
 var start:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
 var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
 if door.direction=="down":
  await drop_to(dest,start,portal.x+6)
  return
 await fixture(start)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1 if door.direction=="left" else (1 if door.direction=="right" else 0))
 if door.direction=="up":app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 360:
  await ticks(1)
  if app.room.room_id==dest and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id==dest and not app.busy and app.player.is_on_floor(),source+" -> "+dest+" real doorway and safe arrival "+str(app.player.position))
 app.controller.router.clear("paired crossing done")

func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for pair:Array in [["P-R18","P-R12"],["P-R13","P-R04"],["P-R18","P-R35"],["P-R25","P-R26"],["P-R34","P-R31"],["P-R34","P-R35"]]:
  await paired(pair[0],pair[1]);await paired(pair[1],pair[0])
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED EXPLORATION CONNECTIONS: ",failures," failures");quit(failures)
