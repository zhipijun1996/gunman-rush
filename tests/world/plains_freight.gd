extends "res://tests/world/plains_region_routes.gd"
## Declared approach fixtures; no writes after placement, including lift phase.
func begin(rid: String,point: Vector2) -> void:
 app.controller.router.clear("freight_fixture");app.load_room(rid,"");await settle();app.player.reset_at(point);await ticks(5)
func run() -> void:
 var selected:=""
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--room="):selected=argument.trim_prefix("--room=")
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_freight"+selected+".json"
 for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
 root.add_child(app);app.start_new();await settle()
 var candidate:=app.state.value.duplicate(true)
 candidate.flags.append_array(["intro_move","intro_shoot","intro_complete","station_briefed"])
 app.state.commit(candidate,app.state.revision);app._apply_capabilities()
 if selected.is_empty() or selected=="P-R09":
  await begin("P-R09",Vector2(1200,622))
  check(await ride_up("FreightLift","P-R09:FreightLift",Vector2(1184,568),148),"mining freight carries actual player to upper storey")
  await full_jump(Vector2(1440,142))
  check(app.player.is_on_floor() and absf(app.player.position.y-142)<8,"mining freight exits on actual upper landing")
  check(await route([Vector2(1360,142),Vector2(1280,-18)],"P-R09","P-R29"),"mining return crosses real paired doorway")
 if selected.is_empty() or selected=="P-R29":
  await begin("P-R29",Vector2(400,1518))
  check(await ride_up("GrainLift","P-R29:GrainLift",Vector2(400,1456),660),"grain lift returns to entry without repeated short rungs")
  await full_jump(Vector2(352,654))
  check(await path([Vector2(144,654)],"P-R29"),"grain lift reaches upper entry bank")
 if selected.is_empty() or selected=="P-R34":
  await begin("P-R34",Vector2(1664,398))
  check(await market_cross(),"market ferry links high east route")
  check(await route([Vector2(2298,398)],"P-R34","P-R35"),"market high route enters junction")
 if selected.is_empty() or selected=="P-R35":
  await begin("P-R35",Vector2(1168,1134))
  check(await ride_up("JunctionLift","P-R35:JunctionLift",Vector2(1168,1072),180),"junction central carrier supplies upper navigation")
  await full_jump(Vector2(1424,142))
  check(app.player.is_on_floor() and absf(app.player.position.y-142)<8,"junction freight reaches clock approach landing")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS FREIGHT: ",failures," failures");quit(failures)
