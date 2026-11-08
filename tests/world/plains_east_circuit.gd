extends "res://tests/world/plains_region_routes.gd"
## H revisit starts at the long bridge side; the circuit has no subsequent placement.
func eastern_circuit() -> bool:
 if not await walk(Vector2(704,1134),"P-R35"):return false
 await clear_enemies(128)
 if not await walk(Vector2(1152,1134),"P-R35"):return false
 await rise_then_cross(Vector2(1344,1006),true)
 if not await path([Vector2(1568,1006),Vector2(1840,1134)],"P-R35"):return false
 await hop(Vector2(2032,974),Vector2(-.5,1))
 await hop(Vector2(2352,1134),Vector2(-1,.1))
 if not await walk(Vector2(2352,1134),"P-R35"):return false
 await clear_enemies(128)
 if not await walk(Vector2(2352,1134),"P-R35"):return false
 await rise_then_cross(Vector2(2528,1022))
 if not await walk(Vector2(2608,1022),"P-R35"):return false
 await full_jump(Vector2(2752,910))
 if not await route([Vector2(2938,910)],"P-R35","P-R18"):return false
 if not await path([Vector2(400,782),Vector2(608,878),Vector2(736,782),Vector2(880,782)],"P-R18"):return false
 await clear_enemies(128)
 if not await walk(Vector2(1056,878),"P-R18"):return false
 await hop(Vector2(1328,718),Vector2(-1,.7),15)
 if not await walk(Vector2(1328,718),"P-R18"):return false
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 for anchor: Vector2 in app.room.hook_points:
  if not await hook(anchor):return false
  app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(12)
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 if not await walk(Vector2(1568,206),"P-R18"):return false
 check(app.room.section_at(app.player.position)=="access:H","independent H forest preview remains behind the stone spine")
 # Drop west of the preview shelf to rejoin the broad field, then choose the eastern cliff.
 await full_jump(Vector2(1408,142))
 if not await walk(Vector2(1248,878),"P-R18"):return false
 await hop(Vector2(1456,718),Vector2(-.6,1))
 if not await walk(Vector2(1664,878),"P-R18"):return false
 await clear_enemies(128)
 if not await walk(Vector2(1824,782),"P-R18"):return false
 if not await walk(Vector2(1904,878),"P-R18"):return false
 await hop(Vector2(2208,878),Vector2(-1,.1))
 if not await walk(Vector2(2208,878),"P-R18"):return false
 await rise_then_cross(Vector2(2080,718),true)
 await clear_enemies(280)
 if not await walk(Vector2(2144,718),"P-R18"):return false
 await hop(Vector2(2384,654),Vector2(-1,.4))
 if not await walk(Vector2(2288,654),"P-R18"):return false
 await hop(Vector2(2080,430),Vector2(.5,1))
 if not await walk(Vector2(2144,430),"P-R18"):return false
 await hop(Vector2(2384,286),Vector2(-.6,1))
 if not await walk(Vector2(2288,286),"P-R18"):return false
 await hop(Vector2(2080,142),Vector2(.6,1))
 if not await walk(Vector2(2144,142),"P-R18"):return false
 await hop(Vector2(2304,142),Vector2(-1,.1))
 if not await route([Vector2(2554,142)],"P-R18","P-R07"):return false
 if not await path([Vector2(432,622),Vector2(600,526),Vector2(688,526)],"P-R07"):return false
 await clear_enemies(128)
 if not await walk(Vector2(688,526),"P-R07"):return false
 await hop(Vector2(1040,462),Vector2(-1,.3))
 if not await walk(Vector2(1392,622),"P-R07"):return false
 await full_jump(Vector2(1536,526))
 if not await path([Vector2(1568,526),Vector2(1632,622),Vector2(1808,622)],"P-R07"):return false
 await clear_enemies(128)
 if not await walk(Vector2(1872,622),"P-R07"):return false
 await full_jump(Vector2(2032,622))
 return await route([Vector2(2128,622),Vector2(2208,750)],"P-R07","P-R02")
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_east_circuit.json"
 root.add_child(app)
 check(await app.review.begin("P-R35","","h"),"declared H junction approach")
 check(await eastern_circuit(),"junction terrain, separate H preview, cliff and lookout return")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS EAST CIRCUIT: ",failures," failures");quit(failures)
