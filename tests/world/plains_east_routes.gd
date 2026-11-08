extends "res://tests/world/plains_region_routes.gd"
## Declared H cluster; all crossings after the entry use accepted physical input.
func windmill_cluster() -> bool:
 if not await path([Vector2(320,1518)],"P-R02"):return false
 app.controller.router.request_action(&"interact");await ticks(8)
 if not await walk(Vector2(480,1518),"P-R02"):return false
 await full_jump(Vector2(704,1518))
 if not await walk(Vector2(752,1518),"P-R02"):return false
 if not await ride_up("RoofWinch","P-R02:RoofWinch",Vector2(752,1464),244):return false
 await full_jump(Vector2(1008,142))
 if not await route([Vector2(1146,142)],"P-R02","P-R10"):return false
 if not await walk(Vector2(1088,2062),"P-R10"):return false
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 for i: int in 16:
  if not await hook(app.room.hook_points[i]):return false
  app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20)
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 if not await path([Vector2(704,462),Vector2(576,526),Vector2(384,526)],"P-R10"):return false
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 for i: int in range(16,20):
  if not await hook(app.room.hook_points[i]):return false
  app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(12)
 app.controller.router.set_jump_held(&"keyboard_mouse",false)
 if not await route([Vector2(544,142),Vector2(634,142)],"P-R10","P-R16"):return false
 if not await walk(Vector2(320,750),"P-R16"):return false
 app.controller.router.request_action(&"interact");await ticks(8)
 check(app.state.value.rest.room=="P-R16","windmill shelter before optional Boss")
 await hop(Vector2(576,654),Vector2(-1,.6));await clear_enemies()
 if not await route([Vector2(688,654)],"P-R16"):return false
 await hop(Vector2(1040,590),Vector2(-1,.3))
 await full_jump(Vector2(1376,750))
 return await route([Vector2(1786,750)],"P-R16","P-R11")
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_east_routes.json"
 root.add_child(app)
 check(await app.review.begin("P-R02","","h"),"declared H shelter fixture")
 check(await windmill_cluster(),"shelter winch, windmill H ecology, rest and optional Boss approach")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS EAST ROUTES: ",failures," failures");quit(failures)
