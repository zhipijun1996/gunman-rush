extends "res://tests/world/plains35_fixture.gd"
## Declared sample positions exercise the real new paired exits and cold backgrounds.
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("M-R02","C03:M-R02","base",true),"mushroom bottom entry with base actions")
 await fixture(Vector2(224,142))
 for i:int in 440:
  app.controller.router.set_look_axis(&"keyboard_mouse",1)
  app.controller.router.set_jump_held(&"keyboard_mouse",app.player.is_on_floor())
  await ticks(1)
  if app.room.room_id=="P-R03" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R03" and not app.busy and app.player.is_on_floor() and absf(app.player.position.y-1102)<5,"mushroom descent returns to the real upper-left plains receiving deck")
 app.controller.router.clear("sample descent complete")
 var art:=app.room.get_node("RegionalArt") as PlainsRoomArt
 check(art.sky!=null and art.sky.texture!=null,"cold-start mushroom return restores plains background")
 check(await app.review.begin("S-R01","C04:S-R01","base",true),"marsh declared base arrival")
 await fixture(Vector2(224,686))
 check(app.player.is_on_floor(),"marsh bottom floor")
 for target:Vector2 in [Vector2(128,574),Vector2(320,430),Vector2(128,286),Vector2(224,142)]:
  await hop(app.player.position,target,Vector2.ZERO,"marsh base return jump "+str(target),8)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for i:int in 180:
  await ticks(1)
  if app.room.room_id=="P-R20" and not app.busy and app.player.is_on_floor():break
 check(app.room.room_id=="P-R20" and not app.busy and app.player.is_on_floor(),"marsh return now enters P20 instead of P03")
 app.controller.router.clear("sample ascent complete")
 await hop(Vector2(560,1134),Vector2(736,1038),Vector2.ZERO,"P20 lower receiving deck to middle shore",8)
 await hop(Vector2(736,1038),Vector2(784,910),Vector2.ZERO,"P20 middle to upper shore",8)
 await hop(Vector2(784,910),Vector2(960,814),Vector2.ZERO,"P20 upper shore returns to main route",8)
 await WorldAudioLifecycle.drain_world(app);print("REGIONAL SAMPLE RETURNS: ",failures," failures");quit(failures)
