extends "res://tests/world/camera_compare.gd"
## Separate normal-speed shots. Wall probes pause AI; seals and player input remain real.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_arena_clip.json";root.add_child(app)
 install_fixture_contract("P-R14",Vector2(4768,1280))
 await setup("P-R14",Vector2(440,742));mark("arena-entry")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(55);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(220);end("arena-entry")
 for direction: int in [-1,1]:
  await setup("P-R14",Vector2(592,742))
  app.room.encounter.set_physics_process(false);app.room.boss_contact.enabled=false
  var wall:=app.room.seals[0 if direction<0 else 1].position.x
  app.player.reset_at(Vector2(wall-direction*160,742));await ticks(3);reset_camera();await ticks(90)
  var label:="left-wall" if direction<0 else "right-wall"
  mark(label)
  app.controller.router.set_source_axis(&"keyboard_mouse",direction);await ticks(70)
  app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(90)
  app.camera.shake(7,.5);await ticks(70);end(label)
 await finish()
