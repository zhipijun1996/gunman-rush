extends "res://tests/world/approved_exploration_connections.gd"
func paired(source:String,dest:String)->void:
 await load_room(source)
 var matches:=app.room.doors.filter(func(d:Dictionary)->bool:return d.target_room==dest)
 if matches.is_empty():check(false,"missing passage "+source+" -> "+dest);return
 var door:Dictionary=matches[0]
 var start:=FixedWorldProvider.point(door.landing_contract.safe_standing_position_world_units)
 var portal:=FixedWorldProvider.point(door.position_candidate.local_world_units)
 await fixture(start)
 var axis:=signf(portal.x-start.x) if door.direction=="down" else (-1.0 if door.direction=="left" else (1.0 if door.direction=="right" else 0.0))
 app.controller.router.set_source_axis(&"keyboard_mouse",axis)
 if door.direction=="up":app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 360:
  await ticks(1)
  if door.direction=="down" and app.room.room_id==source and (app.player.position.x-portal.x)*axis>=-6:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.room.room_id==dest and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id==dest and not app.busy and app.player.is_on_floor(),source+" -> "+dest+" actual passage "+str(app.player.position))
 app.controller.router.clear("doorway finished")

func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for pair:Array in [["P-R02","P-R10"],["P-R10","P-R16"],["P-R10","P-R17"],["P-R19","P-R20"],["P-R20","P-R34"]]:
  await paired(pair[0],pair[1]);await paired(pair[1],pair[0])
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED FINAL CONNECTIONS: ",failures," failures");quit(failures)
