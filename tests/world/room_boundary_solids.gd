extends SceneTree
## Query real formal-room physics at the reported pocket, then exercise its wall.
var app: FixedWorldApp
var failures := 0
var assertions := 0
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
 for i: int in n: await physics_frame
func check(ok: bool,label: String) -> void:
 assertions += 1
 if not ok: failures += 1; printerr("BOUNDARY FAILED: ",label)
func solid(at: Vector2) -> bool:
 var query := PhysicsPointQueryParameters2D.new()
 query.position=at;query.collision_mask=1;query.exclude=[app.player.get_rid()]
 return not app.player.get_world_2d().direct_space_state.intersect_point(query).is_empty()
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 check(await app.review.begin("P-R20","","h"),"real P20 entry")
 await ticks(5)
 for enemy: EnemyActor in app.room.enemies.values():
  enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)
 for at: Vector2 in [Vector2(2140,400),Vector2(2200,400),Vector2(2500,200),Vector2(2900,600)]:
  check(solid(at),"drawn exterior is physically filled "+str(at))
 for at: Vector2 in [Vector2(2032,400),Vector2(2200,600),Vector2(2944,900),Vector2(640,1270),Vector2(1280,10)]:
  check(not solid(at),"chamber or real doorway remains open "+str(at))
 var safety:=SegmentRespawn.new();safety.configure(app.controller,app.lifetime)
 check(not safety.is_safe(Vector2(2200,430)),"reported pocket is never accepted as a safe ledge")
 for start: Vector2 in [Vector2(2050,410),Vector2(2050,450),Vector2(2050,490),Vector2(2067,440),Vector2(2067,455)]:
  app.controller.router.clear("declared corner approach");app.player.reset_at(start);await ticks(2)
  app.controller.router.set_source_axis(&"keyboard_mouse",1)
  var escaped:=false
  for frame: int in 60:
   if frame==0:app.controller.router.set_jump_held(&"keyboard_mouse",true)
   if frame==8:app.controller.router.request_action(&"shoot_release",Vector2(-.7,.7))
   await ticks(1)
   if app.player.position.x>2124 and app.player.position.y<430:escaped=true
  check(not escaped,"real jump/recoil remains inside concave corner "+str(start))
 var latch:=app.room.get_node("RewardReturn") as WorldReturnLatch
 var step:Rect2=latch.return_steps[1]
 check(latch.position.x+step.end.x<=2080,"return step leaves body-sized clearance beside upper ceiling")
 app.state.value.flags.append("reward_return_EQ_MAP_P02_open");latch._refresh(app.state.revision);await ticks(3)
 app.controller.router.clear("return ladder fixture");app.player.reset_at(Vector2(2050,478));await ticks(5)
 check(app.player.is_on_floor(),"actual opened second return step safely supports player")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true)
 for frame:int in 90:await ticks(1)
 check(app.player.position.x<2112 or app.player.position.y>=498,"return ladder wall jump cannot eject body into ceiling mass")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("ROOM BOUNDARY SOLIDS: ",assertions," assertions; ",failures," failures");quit(failures)
