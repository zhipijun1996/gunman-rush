extends "res://tests/world/plains_intro.gd"
## Actual narrow upper landing, unchanged P03 terrain; no special camera override.
func key(code: Key,held: bool) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=held
 app.player.get_node("KeyboardMouseAdapter")._unhandled_input(e)
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_small_room.json";root.add_child(app)
 await app.review.begin("P-R03","","base");app.player.reset_at(Vector2(1568,142));await ticks(3)
 if app.camera.has_method("reset_view"):app.camera.call("reset_view")
 else:app.camera.enter_room(FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units))
 await ticks(70);print("CLIP_START small-room ",Engine.get_physics_frames())
 key(KEY_D,true);await ticks(12);key(KEY_D,false);await ticks(32)
 key(KEY_W,true);await ticks(45);key(KEY_W,false);await ticks(32)
 key(KEY_A,true);await ticks(12);key(KEY_A,false);await ticks(45)
 print("CLIP_END small-room ",Engine.get_physics_frames());await finish()
