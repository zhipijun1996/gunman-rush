extends "res://tests/world/camera_motion.gd"
## Isolated boundary probes: real seals/input; Boss AI paused after actual activation.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_arena_test.json";root.add_child(app)
 for rid: String in ["P-R14","P-R11"]:
  for size: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
   root.size=size
   if not await app.review.begin(rid,"","base"):
    expect(false,"review rejected "+rid+": "+app.status);quit(1);return
   var arena:=app.room.arena_bounds
   app.player.reset_at(Vector2(arena.position.x+80,arena.end.y-18));await ticks(3)
   expect(app.room.battle_started,"real entry activates seals "+rid)
   app.room.encounter.set_physics_process(false);app.room.boss_contact.enabled=false
   var camera:=app.camera as WorldCamera
   camera.reset_view()
   for direction: int in [-1,1]:
    var wall:=app.room.seals[0 if direction<0 else 1].global_position.x
    # Place only at the declared side fixture, then walk into its real collision.
    app.player.reset_at(Vector2(wall-direction*80,arena.end.y-18));await ticks(3);camera.reset_view()
    app.controller.router.set_source_axis(&"keyboard_mouse",direction);await ticks(40)
    app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(210)
    var edge:=view().position.x if direction<0 else view().end.x
    var label:=rid+" "+str(size)+" side="+str(direction)
    expect(absf(edge-wall)<.5,label+" actual screen edge equals wall: "+str(edge-wall))
    expect(absf(app.player.position.x-wall)<32,label+" reached actual seal by input: "+str(app.player.position)+" wall="+str(wall))
    expect(camera.zoom==Vector2.ONE*float(camera.settings.zoom),label+" keeps exploration zoom")
    var bounded:=true
    camera.shake(7,.5)
    for i: int in 40:
     await ticks(1)
     bounded=bounded and view().position.x>=arena.position.x-.1 and view().end.x<=arena.end.x+.1
    expect(bounded,label+" shake never reveals outside either wall")
 print("CAMERA ARENA: ",camera_checks," checks; ",failures," failures")
 await finish()
