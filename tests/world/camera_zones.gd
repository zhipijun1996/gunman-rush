extends "res://tests/world/camera_controller.gd"
## Declared spatial secret fixture; actor positioning isolates zone handoff from current P23 challenges.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_zones_test.json";root.add_child(app)
 var camera:=await camera_fixture("P-R23",Vector2(600,622))
 var closed: Dictionary=app.state.value.duplicate(true)
 var main: Dictionary={"id":"main","trigger":[0,0,1000,896],"display":[0,0,1024,896],"profile":"bounded_follow","offset":[0,-60]}
 var secret: Dictionary={"id":"secret","trigger":[832,0,960,896],"display":[768,0,1024,896],"profile":"bounded_follow","offset":[0,-60],"requires":[["camera_fixture_secret"]],"conceal":[[832,0,960,896]]}
 var portal: Dictionary={"a":"main","b":"secret","band":[640,0,512,896],"display":[0,0,1792,896],"axis":"x","requires":[["camera_fixture_secret"]]}
 app.room.contract.camera={"profile":"bounded_follow","zones":[main,secret],"links":[portal]}
 # Same material mask as production room preparation, attached without changing collisions.
 var surfaces: Array[Rect2]=[Rect2(832,0,960,896)]
 var cover:=UnderworldTerrain.build(surfaces);cover.z_index=2000;app.room.add_child(cover);app.room.camera_concealers.secret=cover
 app.controller.active=false;app.player.reset_at(Vector2(600,622))
 camera.enter_room(Rect2(0,0,1792,896));await ticks(90)
 var initial:=camera.position
 camera.shake(7,3);key(KEY_PAGEUP,true);await ticks(50)
 expect(camera.zones.active_id=="main" and camera.zones.transition.is_empty(),"closed secret cannot be selected by look/lead/shake")
 expect(cover.visible and view().end.x<=1024.1,"closed secret masks internal content including narrow-screen overflow")
 key(KEY_PAGEUP,false);await ticks(100)
 var opened: Dictionary=app.state.value.duplicate(true);opened.flags.append("camera_fixture_secret")
 expect(app.state.commit(opened,app.state.revision),"secret opening uses committed world state")
 await ticks(90)
 expect(camera.position.distance_to(initial)<1 and camera.zones.active_id=="main" and cover.visible,"opening alone neither pulls view nor removes concealment")
 app.controller.active=false
 var previous:=camera.position;var largest:=0.0
 # Spatial probe samples the declared traversal band in both directions, including reversal.
 for x: int in range(600,1001,4):
  app.player.position=Vector2(x,622);await ticks(1)
  largest=maxf(largest,camera.position.distance_to(previous));previous=camera.position
  expect(view().grow(-20).has_point(app.player.position),"player visible through secret approach")
 expect(not camera.zones.transition.is_empty() and not cover.visible,"entering band begins local handoff")
 for x: int in range(1000,599,-4):
  app.player.position=Vector2(x,622);await ticks(1)
  largest=maxf(largest,camera.position.distance_to(previous));previous=camera.position
 await ticks(90)
 expect(camera.zones.active_id=="main" and camera.zones.transition.is_empty() and cover.visible,"mid-band reversal restores main composition and concealment")
 previous=camera.position
 for x: int in range(600,1301,4):
  app.player.position=Vector2(x,622);await ticks(1)
  largest=maxf(largest,camera.position.distance_to(previous));previous=camera.position
 expect(camera.zones.active_id=="secret" and camera.zones.transition.is_empty(),"far side becomes new zone without permanent union")
 for x: int in range(1300,599,-4):
  app.player.position=Vector2(x,622);await ticks(1)
  largest=maxf(largest,camera.position.distance_to(previous));previous=camera.position
 await ticks(90)
 expect(largest<16,"secret handoff has no hard clamp jump; max per frame="+str(largest))
 expect(camera.zones.active_id=="main" and cover.visible,"full return restores main zone")
 expect(app.state.restore() and app.state.has("camera_fixture_secret"),"opened fact survives save reload")
 camera.reset_view();await ticks(60)
 expect(camera.zones.active_id=="main" and camera.zones.transition.is_empty() and camera.look_offset==0,"reload does not restore temporary camera handoff")
 # Small room independent from viewport aspect: fixed axes, safe final shake.
 app.room.contract.camera={"profile":"fixed_arena","zones":[{"id":"small","trigger":[400,400,384,320],"display":[400,400,384,320],"profile":"fixed_arena","look_up":false,"look_down":false}],"links":[]}
 app.player.position=Vector2(592,560);camera.enter_room(Rect2(400,400,384,320))
 for size: Vector2i in [Vector2i(1280,720),Vector2i(960,720),Vector2i(1920,720)]:
  root.size=size;await ticks(3);camera.reset_view();camera.shake(7,.5);await ticks(3)
  expect(camera.legal_centers.size.length()<.1 and view().has_point(app.player.position),"small-room axis fixed at aspect "+str(size))
  expect(camera.zoom==Vector2(1.6,1.6),"small room does not auto zoom")
 print("CAMERA ZONES: ",camera_checks," checks; ",failures," failures")
 await finish()
