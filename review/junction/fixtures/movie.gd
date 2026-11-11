extends "res://tests/world/approved_hub_actions.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 var clip:=OS.get_cmdline_user_args()[0]
 if clip=="encounter":
  await app.review.begin("P-R06","","base");await ticks(6)
  await fixture(Vector2(1216,1294));app.camera.reset_view();await ticks(50)
  for shot:int in 4:
   app.controller.router.request_action(&"shoot_release",Vector2(1,.07).normalized());await ticks(48)
  await ticks(50)
 else:
  await load_room("P-R06")
  var from:=Vector2(1152,1678) if clip=="rise" else Vector2(752,1134)
  var to:=Vector2(880,1454) if clip=="rise" else Vector2(448,942)
  var aim:=Vector2(.65,.76) if clip=="rise" else Vector2(.75,.66)
  await fixture(from);app.camera.reset_view();await ticks(45)
  await hop(from,to,aim,"P06 "+clip+" recoil")
  await ticks(80)
 await WorldAudioLifecycle.drain_world(app);quit(failures)
