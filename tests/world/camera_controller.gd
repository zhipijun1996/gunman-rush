extends "res://tests/world/plains_intro.gd"
## Real formal-entry camera + controlled motion probes. Position writes only set declared fixtures.
var camera_checks := 0
func view() -> Rect2:
 var half:=app.camera.get_viewport_rect().size/(2*app.camera.zoom)
 return Rect2(app.camera.get_screen_center_position()-half,half*2)
func expect(ok: bool,label: String) -> void:
 camera_checks+=1;check(ok,label)
func fixture(rid: String,point: Vector2) -> WorldCamera:
 await app.review.begin(rid,"","base")
 app.player.reset_at(point);await ticks(3)
 var camera:=app.camera as WorldCamera
 camera.reset_view();await ticks(90)
 return camera
func key(code: Key,held: bool) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=held
 app.player.get_node("KeyboardMouseAdapter")._unhandled_input(e)
func run() -> void:
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();app.save_path="user://camera_controller_test.json";root.add_child(app)
 var camera:=await fixture("P-R23",Vector2(600,622))
 expect(camera==root.get_camera_2d(),"formal entry owns the active camera")
 expect(camera.zoom==Vector2(1.6,1.6),"uniform base zoom")
 var router:=app.controller.router
 router.set_source_axis(&"keyboard_mouse",1);await ticks(24);router.set_source_axis(&"keyboard_mouse",0);await ticks(60)
 expect(camera.observation_direction==1 and camera.lead>80,"walking right adds persistent visible-width lead")
 var lead_before:=camera.lead
 router.set_aim(&"keyboard_mouse",Vector2.LEFT,true);await ticks(12);router.primary_release(Vector2.LEFT);router.set_aim(&"keyboard_mouse",Vector2.LEFT,false);await ticks(20)
 expect(camera.observation_direction==1 and camera.lead>lead_before-5,"reverse aim and one shot do not flip observation")
 router.set_source_axis(&"keyboard_mouse",-1);await ticks(40);router.set_source_axis(&"keyboard_mouse",0);await ticks(60)
 expect(camera.observation_direction==-1 and camera.lead< -80,"explicit turn smoothly changes lead and stop retains it")
 camera=await fixture("P-R23",Vector2(800,622));router=app.controller.router
 var center:=camera.position
 key(KEY_W,true);await ticks(12)
 expect(not camera.looking,"manual inspection waits for deliberate hold")
 await ticks(55)
 expect(camera.looking and camera.position.y<center.y-35,"held movement up inspects when there is no interaction target")
 expect(view().grow(-24).has_point(app.player.position),"manual look keeps actor visible")
 key(KEY_W,false);await ticks(90)
 expect(absf(camera.position.y-center.y)<4,"release restores current composition, not actor center")
 key(KEY_S,true);await ticks(55)
 expect(camera.looking and camera.position.y>center.y+35,"held movement down inspects on solid ground")
 router.request_action(&"jump");await ticks(2)
 expect(not camera.looking,"jump cancels inspection immediately")
 await ticks(90)
 expect(not camera.looking,"held view does not rearm after jumping")
 key(KEY_S,false);await ticks(10)
 key(KEY_W,true);await ticks(50)
 router.request_action(&"shoot_release",Vector2.RIGHT);await ticks(2)
 expect(not camera.looking,"shoot cancels inspection")
 key(KEY_W,false);await ticks(15)
 # A real interaction wins over the same up gesture; aim never requests inspection.
 camera=await fixture("P-R23",Vector2(448,622));router=app.controller.router
 key(KEY_W,true);await ticks(45)
 expect(app.paused and not camera.looking,"nearby sign consumes shared up before inspection")
 key(KEY_W,false)
 if app.paused:app._close_panel()
 camera=await fixture("P-R23",Vector2(800,622));router=app.controller.router
 router.set_aim(&"keyboard_mouse",Vector2.UP,true);await ticks(40)
 expect(not camera.looking,"upward aiming never inspects")
 key(KEY_W,true);await ticks(40)
 expect(not camera.looking,"aim wins over held movement up")
 router.set_aim(&"keyboard_mouse",Vector2.UP,false);await ticks(40)
 expect(not camera.looking,"ending aim does not revive a consumed gesture")
 key(KEY_W,false);await ticks(2)
 key(KEY_W,true);await ticks(40)
 expect(camera.looking,"fresh up after aim may inspect")
 router.set_focus_heal_held(&"keyboard_mouse",true);await ticks(2)
 expect(not camera.looking,"recovery hold takes priority over inspection")
 router.set_focus_heal_held(&"keyboard_mouse",false);key(KEY_W,false);await ticks(3)
 router.clear("camera_test")
 var pad:=app.player.get_node("GamepadAdapter") as GamepadAdapter
 pad.set_physics_process(false)
 pad.sample_tick(Vector2.UP,Vector2.ZERO)
 await ticks(55)
 expect(camera.looking,"left stick up inspects without a new button")
 router.clear("pause_fixture");pad.sample_tick(Vector2.UP,Vector2.ZERO);await ticks(40)
 expect(not camera.looking,"held left stick remains blocked after cancellation")
 pad.sample_tick(Vector2.ZERO,Vector2.ZERO);pad.sample_tick(Vector2.DOWN,Vector2.ZERO);await ticks(50)
 expect(camera.looking,"left stick re-arms only after neutral")
 pad.sample_tick(Vector2.ZERO,Vector2.ZERO);await ticks(3)
 router.clear("touch_fixture");app.overlay.set_enabled(true)
 var touch:=InputEventScreenTouch.new();touch.index=7;touch.pressed=true;touch.position=app.overlay.left_center
 app.overlay.handle_touch(touch)
 var drag:=InputEventScreenDrag.new();drag.index=7;drag.position=touch.position+Vector2.UP*app.overlay.radius
 app.overlay.handle_touch(drag);await ticks(55)
 expect(camera.looking and router.camera_look_axis<0,"existing touch left stick inspects")
 router.activate_device(&"keyboard_mouse");await ticks(3)
 app.overlay.handle_touch(drag);await ticks(40)
 expect(not camera.looking,"old touch hold cannot revive inspection after device switch")
 drag.position=touch.position;app.overlay.handle_touch(drag);await ticks(2)
 drag.position=touch.position+Vector2.UP*app.overlay.radius;app.overlay.handle_touch(drag);await ticks(40)
 expect(camera.looking,"touch neutral then up re-arms inspection")
 touch.pressed=false;app.overlay.handle_touch(touch);await ticks(50)
 expect(not camera.looking and is_zero_approx(router.camera_look_axis),"touch release has no shot or interaction")
 app.overlay.set_enabled(false)
 # Controlled state probe isolates impulse duration from human input direction.
 camera=await fixture("P-R23",Vector2(600,622));app.controller.active=false
 for i: int in 20:app.player.velocity=Vector2(-650,0);await ticks(1)
 expect(camera.observation_direction==1,"short external impulse cannot turn the view")
 for i: int in 45:app.player.velocity=Vector2(-650,0);await ticks(1)
 expect(camera.observation_direction==-1,"sustained displacement confirms the true trend")
 camera.reset_view();app.player.velocity=Vector2(0,800);await ticks(15)
 expect(camera.fall_catchup,"fast fall enters catch-up")
 app.player.velocity=Vector2.ZERO;await ticks(45)
 expect(not camera.fall_catchup,"ordinary motion exits fall catch-up")
 # Cinematic token ownership and bounded shake do not mutate the follow baseline.
 var baseline:=camera.base_center
 var token:=camera.begin_takeover(app,baseline+Vector2(80,-40),Rect2(0,0,1792,896));await ticks(40)
 camera.end_takeover(token-1);expect(not camera._takeover.is_empty(),"stale cinematic cannot release another owner")
 camera.end_takeover(token);var before:=camera.position;await ticks(1)
 expect(camera.position.distance_to(before)<20,"cinematic returns without a hard snap")
 camera.shake(500,1);await ticks(5)
 expect(camera.position.distance_to(camera.base_center)<=10 and camera.legal_centers.grow(.1).has_point(camera.position),"shake stays in final safe view without moving baseline")
 camera.reset_view()
 expect(camera.look_offset==0 and camera.action_offset==Vector2.ZERO and camera.lead==0 and not camera.fall_catchup and camera._takeover.is_empty(),"lifecycle reset clears all transient camera state")
 print("CAMERA CONTROLLER: ",camera_checks," checks; ",failures," failures")
 await finish()
