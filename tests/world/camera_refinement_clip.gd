extends "res://tests/world/camera_compare.gd"
## Normal-speed focused evidence: actual jump inputs and existing Boss scene.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_refinement_clip.json";root.add_child(app)
 await setup("P-R23",Vector2(800,622));mark("vertical-cycle")
 await ticks(35);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(14);app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(125);end("vertical-cycle")
 install_fixture_contract("P-R14",Vector2(4768,1280))
 await setup("P-R14",Vector2(440,742));mark("arena-entry")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(55);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(110)
 app.controller.router.request_action(&"jump");await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(85);end("arena-entry")
 await finish()
