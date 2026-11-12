extends "res://tests/world/camera_compare.gd"
## Same inputs and physical terrain for four short, normal-speed comparisons.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_refinement_clip.json";root.add_child(app)
 await setup("P-R23",Vector2(800,622));mark("vertical-cycle")
 await ticks(35);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(14);app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(90)
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(45);app.controller.router.set_jump_held(&"keyboard_mouse",false);await ticks(100);end("vertical-cycle")
 await setup("P-R23",Vector2(800,622));mark("ascending")
 check(await path([Vector2(1056,526),Vector2(1190,430),Vector2(1380,334)],"P-R23"),"clip climb");await ticks(65);end("ascending")
 mark("descending")
 check(await path([Vector2(1190,430),Vector2(1056,526),Vector2(800,622)],"P-R23"),"clip descend");await ticks(65);end("descending")
 install_fixture_contract("P-R14",Vector2(4608,1344))
 await setup("P-R14",Vector2(248,742));mark("arena-entry")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(55);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(145)
 app.controller.router.request_action(&"jump");await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(85);end("arena-entry")
 await finish()
