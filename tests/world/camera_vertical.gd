extends "res://tests/world/camera_motion.gd"
## Actual input on unchanged terrain: small phase bias, climb, drop, and fixed-scale arena.
var sampling := false
var sample_visible := true
var sample_focus := 0.0
var sample_step := 0.0
var sample_previous := Vector2.ZERO
var sample_zoom_error := 0.0
func sample() -> void:
 if not sampling:return
 var camera:=app.camera as WorldCamera
 sample_visible=sample_visible and view().grow(-16).has_point(app.player.position-Vector2(0,18))
 sample_focus=maxf(sample_focus,absf(camera.vertical_focus))
 sample_step=maxf(sample_step,camera.position.distance_to(sample_previous));sample_previous=camera.position
 sample_zoom_error=maxf(sample_zoom_error,absf(camera.zoom.x-float(camera.settings.zoom)))
func start_sample() -> void:
 sample_visible=true;sample_focus=0;sample_step=0;sample_zoom_error=0;sample_previous=app.camera.position;sampling=true
func end_sample(label: String,small_focus: bool=true) -> void:
 sampling=false
 expect(sample_visible,label+" keeps actor visible")
 expect(sample_zoom_error<.0001,label+" never changes zoom")
 expect(sample_step<22,label+" has no abrupt screen movement: "+str(sample_step))
 if small_focus:expect(sample_focus<=8.01,label+" phase offset stays within 8 world units")
 print("FOCUS SAMPLE ",label," amplitude=",sample_focus," step=",sample_step)
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_vertical_test.json";root.add_child(app)
 process_frame.connect(sample)
 var camera: WorldCamera
 for hold_ticks: int in [14,45]:
  camera=await fixture("P-R23",Vector2(800,622));start_sample()
  var ground_focus:=camera.vertical_focus
  expect(ground_focus<0 and ground_focus>=-8.01,"standing adds only a subtle upward bias")
  var falling_focus:=-1000.0;var landing_focus:=0.0;var airborne:=false
  app.controller.router.set_jump_held(&"keyboard_mouse",true)
  for i: int in 150:
   await ticks(1)
   if i==hold_ticks:app.controller.router.set_jump_held(&"keyboard_mouse",false)
   if not app.player.is_on_floor():
    airborne=true
    if app.player.velocity.y>200:falling_focus=maxf(falling_focus,camera.vertical_focus)
   elif airborne:landing_focus=camera.vertical_focus;break
  expect(airborne and falling_focus>0,"actual jump transitions to a small downward bias")
  var landing_y:=camera.position.y
  await ticks(12);var early:=camera.vertical_focus
  await ticks(90)
  expect(early<landing_focus and early>ground_focus-1,"landing gradually returns to upward bias")
  expect(absf(camera.position.y-landing_y)<45,"landing does not yank composition by a large distance: "+str(camera.position.y-landing_y))
  end_sample("in-place jump "+str(hold_ticks))
 camera=await fixture("P-R23",Vector2(800,622));start_sample()
 expect(await path([Vector2(1056,526),Vector2(1190,430),Vector2(1380,334)],"P-R23"),"actual input climbs three higher landings")
 await ticks(70);end_sample("ascending platforms")
 start_sample()
 expect(await path([Vector2(1190,430),Vector2(1056,526),Vector2(800,622)],"P-R23"),"actual input drops to three lower landings")
 await ticks(70);end_sample("descending platforms")
 camera=await fixture("P-R22",Vector2(832,142));start_sample()
 expect(await path([Vector2(880,334),Vector2(736,526),Vector2(416,782),Vector2(544,1038)],"P-R22"),"actual shaft descent retains its authored landing survey")
 await ticks(40);end_sample("shaft descent",false)
 install_fixture_contract("P-R14",Vector2(4768,1280));await app.review.begin("P-R14","","base")
 app.player.reset_at(Vector2(440,742));await ticks(3);camera=app.camera;camera.reset_view();await ticks(60);start_sample()
 app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(60)
 app.controller.router.set_source_axis(&"keyboard_mouse",0);await ticks(240)
 expect(app.room.battle_started and camera.zones.active_id=="arena","Boss entry selects bounded arena composition")
 var display:=app.room.arena_bounds.grow_individual(0,float(camera.settings.arena_vertical_padding),0,float(camera.settings.arena_vertical_padding))
 print("ARENA VIEW ",view()," expected ",display," base ",camera.base_center)
 expect(display.grow(2).encloses(view()),"settled Boss view respects combat display boundaries at exploration scale")
 end_sample("Boss entry")
 camera.reset_view();expect(not camera.looking,"arena lifecycle clears transient inspection")
 print("CAMERA VERTICAL/ARENA: ",camera_checks," checks; ",failures," failures")
 await finish()
