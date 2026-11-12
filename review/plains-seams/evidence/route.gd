extends "res://tests/world/plains35_fixture.gd"
func run()->void:
 root.size=Vector2i(1280,720);root.content_scale_size=root.size
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R31","HUB-P31-P34:P-R31","base",true),"formal lower bank start")
 await ticks(45)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for frame:int in 360:
  await ticks(1)
  if app.room.room_id=="P-R31" and app.player.position.x<1858:app.controller.router.set_source_axis(&"keyboard_mouse",0)
  if app.room.room_id=="P-R34" and not app.busy and app.player.is_on_floor():break
 app.controller.router.clear("arrival at old market")
 check(app.room.room_id=="P-R34" and app.player.is_on_floor(),"continuous P31 to outdoor P34")
 await ticks(60)
 app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 300:
  await ticks(1)
  if app.room.room_id=="P-R31" and not app.busy and app.player.is_on_floor():break
 app.controller.router.clear("return to outdoor canal")
 check(app.room.room_id=="P-R31" and app.player.is_on_floor(),"continuous return to P31")
 await ticks(45)
 await WorldAudioLifecycle.drain_world(app);quit(failures)
