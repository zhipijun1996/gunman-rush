extends "res://tests/world/approved_final_connections.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 for pair:Array in [["P-R01","P-R31"],["P-R31","P-R34"],["P-R31","P-R32"],["P-R33","P-R35"]]:
  await paired(pair[0],pair[1]);await paired(pair[1],pair[0])
 await WorldAudioLifecycle.drain_world(app);quit(failures)
