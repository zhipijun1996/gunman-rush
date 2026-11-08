extends "res://tests/world/plains_region_routes.gd"
## Qualified cluster approaches; subsequent crossings use only controller input.
func grain_circuit() -> bool:
 await app.review.begin("P-R28","","base")
 if not await path([Vector2(448,622),Vector2(592,526)],"P-R28"):return false
 await clear_enemies()
 if not await walk(Vector2(688,526),"P-R28"):return false
 await hop(Vector2(1088,462),Vector2.LEFT,15)
 if not await walk(Vector2(1088,462),"P-R28"):return false
 await clear_enemies()
 if not await walk(Vector2(1280,526),"P-R28"):return false
 await full_jump(Vector2(1568,526))
 await hop(Vector2(1696,398),Vector2(-.4,1))
 if not await walk(Vector2(1696,398),"P-R28"):return false
 await rise_then_cross(Vector2(1888,174),true)
 if not await route([Vector2(2042,174)],"P-R28","P-R29"):return false
 if not await walk(Vector2(352,654),"P-R29"):return false
 await hop(Vector2(768,942),Vector2(-1,.1))
 if not await path([Vector2(832,942),Vector2(920,1518),Vector2(1120,1518),Vector2(1248,1518)],"P-R29"):return false
 await clear_enemies()
 if not await path([Vector2(1440,1518),Vector2(1104,1518)],"P-R29"):return false
 if not await route([Vector2(896,1518),Vector2(768,1646)],"P-R29","P-R09"):return false
 if not await walk(Vector2(1800,622),"P-R09"):return false
 await clear_enemies();return true
func market_water() -> bool:
 var entry:=str(app.content.room("P-R34").doors.filter(func(d: Dictionary) -> bool:return d.target_room=="P-R31")[0].id)
 await app.review.begin("P-R34",entry,"base")
 if not await path([Vector2(432,270),Vector2(656,398),Vector2(480,526),Vector2(736,782),Vector2(784,1038)],"P-R34"):return false
 await rise_then_cross(Vector2(976,942),true)
 return await route([Vector2(1146,942)],"P-R34","P-R20")
func underground() -> bool:
 var entry:=""
 for door: Dictionary in app.content.room("P-R35").doors:
  if door.target_room=="P-R34":entry=door.id
 await app.review.begin("P-R35",entry,"base")
 if not await walk(Vector2(720,2446),"P-R35"):return false
 await hop(Vector2(1024,2446),Vector2(-1,.2))
 if not await route([Vector2(1408,2446),Vector2(1408,2286)],"P-R35","P-R33"):return false
 check(app.room.enemies.is_empty(),"clock forecourt retains a quiet landmark")
 if not await route([Vector2(1152,1006)],"P-R33","P-R35"):return false
 if not await walk(Vector2(1680,2446),"P-R35"):return false
 await hop(Vector2(2080,2542),Vector2(-1,.1))
 await hop(Vector2(2208,2670),Vector2(-1,.1))
 if not await walk(Vector2(2208,2670),"P-R35"):return false
 if not await route([Vector2(2336,2798)],"P-R35","P-R19"):return false
 if not await path([Vector2(1008,414),Vector2(1120,558),Vector2(1008,702),Vector2(1120,846),Vector2(1008,990),Vector2(1120,1134)],"P-R19"):return false
 await clear_enemies(160)
 if not await route([Vector2(1504,1134),Vector2(2042,1134)],"P-R19","P-R12"):return false
 if not await walk(Vector2(320,2702),"P-R12"):return false
 var cage:=app.room.get_node("DrainCage") as WorldMovingPlatform
 for i: int in 1300:
  await ticks(1)
  if cage.position.y>2632:break
 if not await board_carrier(cage):return false
 for i: int in 1200:
  await ticks(1)
  var dx:=cage.position.x-app.player.position.x
  app.controller.router.set_source_axis(&"keyboard_mouse",signf(dx) if absf(dx)>3 else 0)
  if cage.position.y<970 and app.player.is_on_floor():break
 app.controller.router.clear("drain_upper_stop")
 await full_jump(Vector2(656,878));await clear_enemies(160)
 if not await walk(Vector2(688,878),"P-R12"):return false
 await full_jump(Vector2(752,750))
 if not await path([Vector2(864,878),Vector2(944,878)],"P-R12"):return false
 await hop(Vector2(1200,878),Vector2(-1,.2))
 if not await route([Vector2(1530,878)],"P-R12","P-R18"):return false
 if not await walk(Vector2(2144,1902),"P-R18"):return false
 check(await ride_up("IrrigationCage","P-R18:IrrigationCage",Vector2(2160,1848),830),"culvert lift joins the real field floor")
 await full_jump(Vector2(2120,718))
 return app.room.room_id=="P-R18" and absf(app.player.position.y-718)<8 and app.player.is_on_floor()
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_lower_routes.json";root.add_child(app)
 var selected:=""
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--route="):selected=arg.trim_prefix("--route=")
 if selected.is_empty() or selected=="grain":check(await grain_circuit(),"field, grain shaft and mine actual circuit")
 if selected.is_empty() or selected=="water":check(await market_water(),"market drain enters water chamber")
 if selected.is_empty() or selected=="underground":check(await underground(),"junction, clock, root well, cellar and irrigation continuous route")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS LOWER ROUTES: ",failures," failures");quit(failures)
