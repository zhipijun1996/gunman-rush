extends "res://tests/world/camera_controller.gd"
## Existing formal Boss/H scenes in explicitly isolated pre-migration room contracts.
## No scene/platform/physics edit, no claim that the 29 pending rooms are reachable.
func install_fixture_contract(rid: String, size: Vector2) -> void:
 var all: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://build/world/contracts.json"))
 for original: Dictionary in all.rooms:
  if str(original.room_id)!=rid:continue
  var value:=original.duplicate(true)
  value.doors=[];value.entry_spawns=[]
  value.world_geometry={"bounds_world_units":[0,0,size.x,size.y],"space_rects":[[0,0,size.x,size.y]],"boundary":[{"side":"up","from":[0,0],"to":[size.x,0]},{"side":"down","from":[0,size.y],"to":[size.x,size.y]},{"side":"left","from":[0,0],"to":[0,size.y]},{"side":"right","from":[size.x,0],"to":[size.x,size.y]}]}
  value.camera={"profile":"bounded_follow","zones":[],"links":[],"transition":"occluded"}
  app.content.data.rooms[rid]=value
  return
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_motion_test.json";root.add_child(app)
 install_fixture_contract("P-R14",Vector2(4768,1280))
 await app.review.begin("P-R14","","h")
 var camera:=app.camera as WorldCamera
 app.player.reset_at(Vector2(440,742));await ticks(3);camera.reset_view();await ticks(90)
 var previous:=camera.position;var largest:=0.0
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i: int in 55:
  await ticks(1)
  if camera.position.distance_to(previous)>22:print("ARENA DELTA ",app.player.position," from ",previous," to ",camera.position," limits ",camera.legal_centers," zone ",camera.zones.active_id)
  largest=maxf(largest,camera.position.distance_to(previous));previous=camera.position
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(45)
 expect(app.room.battle_started and camera.zones.active_id=="arena","real Boss activation selects fixed/limited composition")
 expect(largest<22,"Boss entry remains continuous; largest frame="+str(largest))
 app.controller.router.set_camera_look(&"keyboard_mouse",-1);await ticks(40)
 expect(not camera.looking,"Boss composition explicitly disallows inspection")
 app.controller.router.set_camera_look(&"keyboard_mouse",0)
 app.controller.router.request_action(&"jump");await ticks(8)
 app.controller.router.request_action(&"shoot_release",Vector2.DOWN)
 var visible:=true
 for i: int in 60:
  await ticks(1)
  visible=visible and view().grow(-16).has_point(app.player.position-Vector2(0,18))
 expect(visible,"Boss jump/recoil keeps actor in final view")
 camera.shake(7,.5)
 app.submit_damage(&"camera_test",DamageRequest.Kind.MONSTER,100,&"camera_death")
 await ticks(3);await settle();await ticks(30)
 expect(not camera.looking and camera._takeover.is_empty(),"death/rest reload cancels transient camera control")
 # Actual H target and geometry already exist in this scene's upper traversal route.
 await app.review.begin("P-R14","","h");camera=app.camera as WorldCamera
 app.player.reset_at(Vector2(2304,366));await ticks(3);camera.reset_view();await ticks(30)
 var received:=0
 app.controller.router.request_action(&"grapple",(Vector2(2448,240)-app.player.position-Vector2(0,-6)).normalized())
 visible=true;var start:=app.player.position
 for i: int in 100:
  await ticks(1)
  if i==40:app.controller.router.request_action(&"grapple",(Vector2(2624,240)-app.player.position-Vector2(0,-6)).normalized())
  if app.controller.traversal.state in [&"hook_pull",&"hook_hang",&"hook_kick"]:received+=1
  visible=visible and view().grow(-16).has_point(app.player.position)
 expect(received>0 and app.player.position.distance_to(start)>280,"real H cast/contact produces long traversal")
 expect(visible,"high-speed H never loses the actor")
 expect(camera.zoom==Vector2(1.6,1.6),"H traversal restores the ordinary base scale")
 camera=await fixture("P-R22",Vector2(880,334))
 var pursuit_ticks:=0
 visible=true
 app.controller.router.set_source_axis(&"keyboard_mouse",-1)
 for i: int in 60:
  await ticks(1)
  if camera.fall_catchup:pursuit_ticks+=1
  visible=visible and view().grow(-16).has_point(app.player.position)
 app.controller.router.clear("fall_check")
 expect(pursuit_ticks>0 and visible,"actual shaft descent enters pursuit without losing the actor")
 app.ui.begin_transition();camera.shake(5,1)
 app._fail_terrain();await ticks(8)
 expect(not camera.fall_catchup and not camera.looking and camera._takeover.is_empty(),"terrain return uses occluded lifecycle reset")
 print("CAMERA MOTION: ",camera_checks," checks; ",failures," failures")
 await finish()
