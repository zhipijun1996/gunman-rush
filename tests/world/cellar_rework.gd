extends "res://tests/world/approved_exploration_rooms.gd"
func run()->void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_room("P-R12")
 await ride("P12","DrainCage")
 await hop(Vector2(720,1454),Vector2(976,1198),Vector2(-.6,.8),"P12 first recoil crossing")
 await load_room("P-R12")
 await ticks(60) # Observe the live crossing wheel from the safe preparation bank.
 await hop(Vector2(928,1198),Vector2(704,942),Vector2(.6,.8),"P12 return-facing second crossing")
 await load_room("P-R12")
 await hop(Vector2(736,942),Vector2(976,686),Vector2(-.6,.8),"P12 third crossing to preparation shore")
 await load_room("P-R12")
 await clock_shutter()
 await cache("open_P12_cellar_cache",Vector2(160,1326),20)
 await pickup_return("pickup_EQ_MAP_P01","reward_return_EQ_MAP_P01_open",Vector2(1104,462),Vector2(1152,462))
 await WorldAudioLifecycle.drain_world(app);quit(failures)
