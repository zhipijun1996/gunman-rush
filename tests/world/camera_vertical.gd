extends "res://tests/world/camera_motion.gd"
## Actual controller jump; measure the observation target and final screen position.
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_vertical_test.json";root.add_child(app)
 var camera:=await fixture("P-R23",Vector2(800,622))
 for hold_ticks: int in [14,45]:
  camera=await fixture("P-R23",Vector2(800,622))
  var ground_focus:=camera.vertical_focus
  expect(ground_focus< -25,"standing observation is above the head")
  var rise_focus:=ground_focus;var apex_focus:=1000.0;var apex_frame:=1000.0;var falling_focus:=-1000.0;var landing_focus:=0.0
  var airborne:=false;var previous:=camera.position;var max_frame:=0.0
  app.controller.router.set_jump_held(&"keyboard_mouse",true)
  for i: int in 150:
   await ticks(1)
   if i==hold_ticks:app.controller.router.set_jump_held(&"keyboard_mouse",false)
   max_frame=maxf(max_frame,camera.position.distance_to(previous));previous=camera.position
   if not app.player.is_on_floor():
    airborne=true
    if app.player.velocity.y< -200:rise_focus=camera.vertical_focus
    if absf(app.player.velocity.y)<45:apex_focus=camera.vertical_focus;apex_frame=camera.position.y-app.player.position.y
    if app.player.velocity.y>200:falling_focus=maxf(falling_focus,camera.vertical_focus)
   elif airborne:
    landing_focus=camera.vertical_focus;break
  expect(airborne and rise_focus>ground_focus and rise_focus<0,"rising focus gradually moves down from its grounded offset")
  expect(absf(apex_frame)<32,"actual apex view stays near actor center: "+str(apex_frame))
  expect(falling_focus>15,"falling smoothly anticipates below the actor")
  var landing_y:=camera.position.y
  await ticks(12);var early:=camera.vertical_focus
  await ticks(90)
  expect(early<landing_focus and early>ground_focus-1,"landing transitions instead of snapping the focus upward")
  expect(camera.vertical_focus< -25 and camera.position.y<landing_y,"landing restores a modest upward composition")
  expect(max_frame<22,"jump cycle has no abrupt view step: "+str(max_frame))
  print("VERTICAL PHASES ",ground_focus," ",rise_focus," ",apex_focus," ",apex_frame," ",falling_focus," ",landing_focus," ",early)
 # Compact real arena: settle to the whole field, including both combat edges.
 install_fixture_contract("P-R14",Vector2(4768,1280));await app.review.begin("P-R14","","base")
 app.player.reset_at(Vector2(440,742));await ticks(3);camera=app.camera;camera.reset_view();await ticks(60)
 var previous:=camera.position;var zoom_before:=camera.zoom.x;var zoom_step:=0.0
 app.controller.router.set_source_axis(&"keyboard_mouse",1)
 for i: int in 60:
  await ticks(1);zoom_step=maxf(zoom_step,absf(camera.zoom.x-zoom_before));zoom_before=camera.zoom.x
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(150)
 expect(app.room.battle_started and view().grow(2).encloses(app.room.arena_bounds),"compact Boss arena fits both edges and full combat height")
 expect(camera.zoom.x>=float(camera.settings.arena_min_zoom)-.001 and camera.zoom.x<1.2,"explicit Boss fit stays inside allowed scale")
 expect(zoom_step<.025,"Boss pullback changes scale smoothly")
 camera.reset_view();expect(not camera.looking,"arena lifecycle clears transient inspection")
 print("CAMERA VERTICAL/ARENA: ",camera_checks," checks; ",failures," failures")
 await finish()
