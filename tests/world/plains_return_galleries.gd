extends "res://tests/world/plains_first_loop.gd"
## Removing dense rungs must preserve actual upper returns, not just entry spawns.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_galleries.json"
 for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
 root.add_child(app);app.start_new();await settle()
 check(await path([Vector2(496,446),Vector2(900,398),Vector2(800,270),Vector2(736,270),Vector2(912,142)],"P-R03"),"meadow upper gallery remains physically reachable")
 app.load_room("P-R22","");await settle()
 check(await path([Vector2(320,718),Vector2(160,590),Vector2(320,462),Vector2(160,334)],"P-R22"),"canal staggered galleries replace small ladder rungs")
 await hop(Vector2(352,142),Vector2(-.4,1))
 check(app.player.is_on_floor() and absf(app.player.position.y-142)<8,"recoil reaches upper return shelf")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS RETURN GALLERIES: ",failures," failures");quit(failures)
