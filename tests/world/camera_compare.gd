extends "res://tests/world/plains_intro.gd"
## Matched before/after input clips. Resets establish declared fixture starts only.
var start_frame := 0
func mark(name: String) -> void:
 start_frame=Engine.get_physics_frames();print("CLIP_START ",name," ",start_frame)
func end(name: String) -> void:
 print("CLIP_END ",name," ",Engine.get_physics_frames())
func reset_camera() -> void:
 if app.camera.has_method("reset_view"):app.camera.call("reset_view")
 else:app.camera.call("enter_room",FixedWorldProvider.rect(app.room.contract.world_geometry.bounds_world_units))
func setup(rid: String,point: Vector2,stage: String="base") -> void:
 await app.review.begin(rid,"",stage);app.player.reset_at(point);await ticks(3);reset_camera();await ticks(80)
func key(code: Key,held: bool) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=held;app.player.get_node("KeyboardMouseAdapter")._unhandled_input(e)
func install_fixture_contract(rid: String,size: Vector2) -> void:
 var all: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/world/contracts.json"))
 for row: Dictionary in all.rooms:
  if str(row.room_id)!=rid:continue
  var value:=row.duplicate(true);value.doors=[];value.entry_spawns=[]
  value.world_geometry={"bounds_world_units":[0,0,size.x,size.y],"space_rects":[[0,0,size.x,size.y]],"boundary":[{"side":"up","from":[0,0],"to":[size.x,0]},{"side":"down","from":[0,size.y],"to":[size.x,size.y]},{"side":"left","from":[0,0],"to":[0,size.y]},{"side":"right","from":[size.x,0],"to":[size.x,size.y]}]}
  value.camera={"profile":"bounded_follow","zones":[],"links":[]};app.content.data.rooms[rid]=value
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_compare.json";root.add_child(app)
 await setup("P-R23",Vector2(600,622));mark("turn-fire")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(28);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(40)
 app.controller.router.set_aim(&"keyboard_mouse",Vector2.LEFT,true);await ticks(25);app.controller.router.primary_release(Vector2.LEFT);app.controller.router.set_aim(&"keyboard_mouse",Vector2.LEFT,false);await ticks(45)
 app.controller.router.set_source_axis(&"keyboard_mouse",-1);await ticks(38);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(65);end("turn-fire")
 await setup("P-R22",Vector2(800,1486));mark("recoil")
 await cross(Vector2(1168,1390),Vector2(-1,.6));await walk(Vector2(1824,1390),"P-R22")
 await cross(Vector2(2224,1326),Vector2(-1,.45));await ticks(30);end("recoil")
 await setup("P-R22",Vector2(832,142));mark("shaft")
 await path([Vector2(880,334),Vector2(736,526),Vector2(416,782),Vector2(544,1038),Vector2(256,1262),Vector2(544,1486)],"P-R22");await ticks(20);end("shaft")
 await setup("P-R23",Vector2(800,622));mark("look")
 key(KEY_W,true);await ticks(85);key(KEY_W,false);await ticks(65)
 key(KEY_S,true);await ticks(85);key(KEY_S,false);await ticks(40)
 key(KEY_W,true);await ticks(40);app.controller.router.request_action(&"jump");await ticks(35);key(KEY_W,false);await ticks(50);end("look")
 await setup("P-R23",Vector2(1056,526));mark("corner")
 await path([Vector2(1190,430),Vector2(1380,334),Vector2(1232,238),Vector2(1088,142),Vector2(1088,-18)],"P-R23");await settle();await ticks(30);end("corner")
 await setup("P-R21",Vector2(1440,942));mark("door")
 await walk(Vector2(1600,1134),"P-R21");await settle();await ticks(45)
 await path([Vector2(768,-18)],"P-R22");await settle();await ticks(30);end("door")
 await setup("P-R23",Vector2(600,622))
 var main: Dictionary={"id":"main","trigger":[0,0,1000,896],"display":[0,0,1024,896],"profile":"bounded_follow","offset":[0,-60]}
 var secret: Dictionary={"id":"secret","trigger":[832,0,960,896],"display":[768,0,1024,896],"profile":"bounded_follow","offset":[0,-60],"requires":[["camera_fixture_secret"]]}
 var portal: Dictionary={"a":"main","b":"secret","band":[640,0,512,896],"display":[0,0,1792,896],"axis":"x","requires":[["camera_fixture_secret"]]}
 app.room.contract.camera={"profile":"bounded_follow","zones":[main,secret],"links":[portal]}
 var surfaces: Array[Rect2]=[Rect2(832,0,960,896)];var cover:=UnderworldTerrain.build(surfaces);cover.z_index=2000;app.room.add_child(cover)
 if app.room.has_method("update_camera_concealment"):app.room.set("camera_concealers",{"secret":cover})
 app.camera.call("enter_room",Rect2(0,0,1792,896));await ticks(60);mark("secret-turnback")
 await ticks(40)
 var candidate:=app.state.value.duplicate(true);candidate.flags.append("camera_fixture_secret");app.state.commit(candidate,app.state.revision)
 if not app.room.has_method("update_camera_concealment"):cover.hide()
 await ticks(40);await walk(Vector2(800,622),"P-R23");await ticks(20);await walk(Vector2(600,622),"P-R23");await ticks(45);end("secret-turnback")
 mark("secret-return")
 await path([Vector2(1056,526),Vector2(1190,430)],"P-R23");await ticks(30)
 await path([Vector2(1056,526),Vector2(800,622),Vector2(600,622)],"P-R23");await ticks(30)
 app.state.restore();reset_camera();await ticks(30);end("secret-return")
 install_fixture_contract("P-R14",Vector2(4608,1344))
 await setup("P-R14",Vector2(1792,558),"h");mark("hook")
 for point: Vector2 in [Vector2(1648,408)]:
  app.controller.router.request_action(&"grapple",(point-app.player.position-Vector2(0,-6)).normalized());await ticks(45)
 app.controller.router.request_action(&"jump");await ticks(50);end("hook")
 await setup("P-R14",Vector2(248,742));mark("boss-respawn")
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(55);app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(45)
 app.controller.router.request_action(&"jump");await ticks(8);app.controller.router.request_action(&"shoot_release",Vector2.DOWN);await ticks(70)
 app.submit_damage(&"camera_clip",DamageRequest.Kind.MONSTER,100,&"camera_clip_death");await ticks(4);await settle();await ticks(45);end("boss-respawn")
 await finish()
