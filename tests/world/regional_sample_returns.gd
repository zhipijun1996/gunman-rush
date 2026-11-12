extends "res://tests/world/plains35_fixture.gd"
## Base jumps from the bottom of each narrow sample to its real plain-side exit.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for rid:String in ["M-R02","S-R01"]:
  var edge:="C03" if rid=="M-R02" else "C04"
  check(await app.review.begin(rid,edge+":"+rid,"base",true),rid+" declared arrival base stage")
  await fixture(Vector2(224,686))
  check(app.player.is_on_floor(),rid+" bottom floor")
  for target:Vector2 in [Vector2(128,574),Vector2(320,430),Vector2(128,286),Vector2(224,142)]:
   await hop(app.player.position,target,Vector2.ZERO,rid+" base jump "+str(target),8)
  app.controller.router.set_jump_held(&"keyboard_mouse",true)
  for i:int in 180:
   await ticks(1)
   if app.room.room_id=="P-R03" and not app.busy and app.player.is_on_floor():break
  check(app.room.room_id=="P-R03" and app.player.is_on_floor(),rid+" bottom-to-plains actual return")
  app.controller.router.clear("sample ascent complete")
  var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
  check(art.sky!=null and art.sky.texture!=null,rid+" cold-start return restores plains background")
 await WorldAudioLifecycle.drain_world(app);print("REGIONAL SAMPLE RETURNS: ",failures," failures");quit(failures)
