extends "res://tests/world/plains_region_routes.gd"
func cross_window(shutter: WorldShotLatch) -> Dictionary:
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(9)
 app.controller.router.request_action(&"shoot_release",(shutter.bell_position-app.player.position).normalized())
 var crossed_open:=false
 var furthest:=app.player.position.x
 for i: int in 120:
  await ticks(1)
  if i==15:app.controller.router.set_jump_held(&"keyboard_mouse",false)
  if app.player.position.x>1100 and app.player.position.y<1060:crossed_open=shutter.is_open
  if app.player.position.y<=942:furthest=maxf(furthest,app.player.position.x)
  if i>10 and app.player.is_on_floor():break
 app.controller.router.clear("grain_landed")
 print("GRAIN LAND ",app.player.position," opened=",shutter.open_count," far=",furthest)
 return {"crossed_open":crossed_open,"furthest":furthest}
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_grain_positive.json" if "--positive-only" in OS.get_cmdline_user_args() else "user://plains_grain.json"
 for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
 root.add_child(app);app.start_new();await settle();app.load_room("P-R29","");await settle()
 check(await walk(Vector2(352,654),"P-R29"),"approach from actual upper barn entrance")
 await hop(Vector2(768,942),Vector2(-1,.1))
 check(await walk(Vector2(880,942),"P-R29"),"grain-window broad preparation")
 var shutter:=app.room.mechanisms["P-R29:grain_shutter"] as WorldShotLatch
 var result:=await cross_window(shutter)
 check(shutter.open_count==1 and result.crossed_open,"one airborne shot opens and crosses actual shutter")
 check(app.player.is_on_floor() and app.player.position.x>1120 and absf(app.player.position.y-942)<8,"same recoil lands on right inspection storey")
 await ticks(85);check(not shutter.is_open,"grain shutter resets after the short crossing window")
 if not "--positive-only" in OS.get_cmdline_user_args():
  # Declared launch fixture: same live projectile, with recoil alone disabled.
  app.load_room("P-R29","");await settle();app.player.reset_at(Vector2(880,942));await ticks(4)
  app.controller.recoil_ability.enabled=false
  shutter=app.room.mechanisms["P-R29:grain_shutter"]
  result=await cross_window(shutter)
  check(shutter.open_count==1 and result.furthest+12<1120,"opening the shutter without recoil misses the higher right storey")
  app.controller.recoil_ability.enabled=true
  # Already-open geometry fixture permits a late edge/coyote jump, without a timer excuse.
  app.load_room("P-R29","");await settle();app.player.reset_at(Vector2(900,942));await ticks(2)
  shutter=app.room.mechanisms["P-R29:grain_shutter"]
  shutter.open_seconds=0;shutter.restore_region_opened(true);await ticks(2)
  result=await full_jump(Vector2(1248,942),1)
  check(result.furthest+12<1120,"late ordinary jump with an open gate still misses the right storey")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS GRAIN: ",failures," failures");quit(failures)
