extends "res://tests/world/plains_region_routes.gd"
## Shore entry, ability preview, qualified H revisit, explicit collection and return.
func run() -> void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://plains_water_routes.json"
 for suffix: String in ["",".backup",".tmp",".corrupt"]:DirAccess.remove_absolute(app.save_path+suffix)
 root.add_child(app);app.start_new();await settle();app.load_room("P-R20","");await settle()
 check(await path([Vector2(592,878),Vector2(736,782),Vector2(848,782)],"P-R20"),"shore pier gives a safe view of patrol and spike bed")
 await clear_enemies(128)
 await hop(Vector2(1120,750),Vector2(-1,.2))
 check(await walk(Vector2(1408,878),"P-R20"),"shore piers reconnect to lower water approach")
 app.controller.router.request_action(&"grapple",Vector2.UP);await ticks(8)
 check(app.controller.traversal.state==&"free","pre-H sight of equipment does not grant access")
 var candidate:=app.state.value.duplicate(true);candidate.flags.append("H")
 app.state.commit(candidate,app.state.revision);app._apply_capabilities()
 app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(8)
 for anchor: Vector2 in app.room.hook_points:
  check(await hook(anchor),"shore H route "+str(anchor));app.controller.router.set_jump_held(&"keyboard_mouse",false)
 app.controller.router.set_source_axis(&"keyboard_mouse",1);app.controller.router.set_jump_held(&"keyboard_mouse",true);await ticks(20);app.controller.router.set_jump_held(&"keyboard_mouse",false)
 check(await walk(Vector2(1888,430),"P-R20"),"shore collection upper dry bank")
 app.controller.router.request_action(&"interact");await ticks(5)
 check(app.state.value.receipts.has("pickup_EQ_MAP_P02"),"actual shore equipment source collected")
 var latch:=app.room.get_node("RewardReturn") as WorldReturnLatch
 check(await walk(latch.position,"P-R20"),"shore return latch is on reward side")
 app.controller.router.request_action(&"interact");await ticks(5)
 check(app.state.has(latch.action_id),"shore short return explicitly opened")
 check(await path([Vector2(2240,526),Vector2(2096,622),Vector2(2240,718),Vector2(2096,814),Vector2(2128,878),Vector2(2298,878)],"P-R20"),"shore collection returns to lower route and actual east door")
 await settle();check(app.room.room_id=="P-R19","shore and root well are physically connected")
 if app.room.room_id=="P-R19":
  check(await walk(Vector2(560,1134),"P-R19"),"root well low-route spike preparation")
  await clear_enemies(128)
  check(await walk(Vector2(576,1134),"P-R19"),"root well regains the launch edge after firing")
  await full_jump(Vector2(768,1134))
  check(await path([Vector2(1440,1134),Vector2(2042,1134)],"P-R19"),"root well lower route remains separate from H+D collection")
  await settle();check(app.room.room_id=="P-R12","root well east door enters cellar main route")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(8)
 print("PLAINS WATER ROUTES: ",failures," failures");quit(failures)
