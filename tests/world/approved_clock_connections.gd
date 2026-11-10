extends "res://tests/world/approved_draft_connections.gd"
## Local starts, real portals/switches; terminal Boss health isolates progression.
func drop_to(target:String,start:Vector2,threshold:float)->void:
 await fixture(start);app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for frame:int in 360:
  await ticks(1)
  if app.player.position.x<threshold:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.room.room_id==target and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id==target and app.player.is_on_floor(),"real downward passage to "+target+" "+str(app.player.position))
 app.controller.router.clear("crossing finished")
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await cross("P-R16","P-R11",Vector2(1392,686),1)
 await cross("P-R11","P-R16",Vector2(144,1198),-1)
 await cross("P-R27","P-R14",Vector2(768,142),0,true)
 await load_room("P-R14");await drop_to("P-R27",Vector2(512,1230),390)
 await load_room("P-R14");await drop_to("P-R15",Vector2(4736,398),4614)
 await cross("P-R15","P-R14",Vector2(192,142),0,true)
 await load_room("P-R14")
 await fixture(Vector2(3712,974));app._interact();await ticks(3)
 check(not app.state.has("shortcut_p03"),"side gate rejects use before Boss victory")
 await fixture(app.room.battle_entry_anchor);await ticks(5)
 var health:=app.room.encounter.health
 health.apply_damage(ActorResourceRequest.new(&"crossing_victory_fixture",health.epoch,health.current+1,health.get_instance_id()));await ticks(12)
 await fixture(Vector2(3712,974));app._interact();await ticks(5)
 check(app.state.has("shortcut_p03"),"actual side gate switch opens return")
 await drop_to("P-R06",Vector2(3840,1102),3718)
 # Keep that earned switch while approaching the paired upper portal.
 await fixture(Vector2(704,142));app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 300:
  await ticks(1)
  if app.room.room_id=="P-R14" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R14" and app.player.is_on_floor(),"P06 returns through the opened side gate")
 await load_room("P-R15","h")
 await fixture(Vector2(1952,3918));app._interact();await ticks(365);app.story.finish();await ticks(5)
 await fixture(Vector2(2112,3918));app._interact();await ticks(5)
 await drop_to("P-R32",Vector2(2304,4686),2182)
 await fixture(Vector2(960,142));app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 300:
  await ticks(1)
  if app.room.room_id=="P-R15" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R15" and app.player.is_on_floor(),"P32 returns through the repaired clock shortcut")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(4)
 print("APPROVED CLOCK CONNECTIONS: ",failures," failures");quit(failures)
