extends "res://tests/world/plains_first_loop.gd"
## Declared side-gallery fixture; accepted shots, boarding and real wall contact.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_well.json"
 for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
 root.add_child(app);app.start_new();await settle();app.load_room("P-R08","");await settle()
 app.player.reset_at(Vector2(720,814));await ticks(5)
 var latch:=app.room.mechanisms["P-R08:well_lift"] as WorldShotLatch
 var lift:=latch.motion_target as WorldMovingPlatform
 app.controller.router.request_action(&"shoot_release",(Vector2(800,784)-app.player.position).normalized());await ticks(35)
 check(lift.motion_running,"gallery bell restarts the actual shared lift")
 for i: int in 500:
  await ticks(1)
  if lift.position.y<890:break
 check(await walk(Vector2(720,814),"P-R08"),"recover shooting displacement on broad gallery")
 app.controller.router.request_action(&"shoot_release",(Vector2(800,784)-app.player.position).normalized());await ticks(25)
 check(not lift.motion_running,"gallery bell parks lift for boarding")
 var parked:=lift.position;await ticks(60);check(lift.position==parked,"parked boarding window remains available")
 check(await walk(Vector2(840,814),"P-R08"),"gallery edge preparation")
 await full_jump(Vector2(912,lift.position.y-28))
 check(app.player.is_on_floor() and absf(app.player.position.x-912)<8 and absf(app.player.position.y-(lift.position.y-28))<6,"jump from actual gallery onto parked carrier")
 # Separate contact fixture on a visited middle gallery. No damage/recovery injection.
 app.player.reset_at(Vector2(720,814));await ticks(8)
 var hp:=app.controller.actor_resources.health.current
 await hop(Vector2(980,670),Vector2(-1,.7));await ticks(60)
 check(app.controller.actor_resources.health.current==hp-1,"wall spikes punish overshooting with one accepted hit")
 check(app.player.position.distance_to(Vector2(720,814))<16 and app.player.is_on_floor(),"wall hit returns to visited clear gallery")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS WELL: ",failures," failures");quit(failures)
