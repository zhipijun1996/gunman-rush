extends SceneTree
var failures:=0
var assertions:=0
var app:FixedWorldApp
func _initialize()->void:run.call_deferred()
func ticks(n:int)->void:
 for i:int in n:await physics_frame
func check(ok:bool,label:String)->void:
 assertions+=1
 if not ok:failures+=1;printerr("CALIBRATION FAILED: ",label)
func button(index:int,pressed:bool)->InputEventJoypadButton:
 var e:=InputEventJoypadButton.new();e.device=7;e.button_index=index;e.pressed=pressed;return e
func run()->void:
 app=preload("res://game/application/world/fixed_world.tscn").instantiate()
 app.settings_path="user://gamepad_calibration_"+str(OS.get_process_id())+".json"
 root.add_child(app);check(await app.review.begin("P-R20","","h"),"formal world")
 app.toggle_pause()
 var wizard:=WorldGamepadCalibration.show(app.ui,app.preferences,app.settings_view.applied)
 check(app.paused and wizard.step==0 and wizard.save_button.disabled,"calibration opens paused with save disabled")
 wizard.capture(button(1,true));check(wizard.step==0,"press alone does not advance")
 wizard.capture(button(1,false));check(wizard.step==1,"physical south captured on release")
 wizard.capture(button(1,true));wizard.capture(button(1,false));check(wizard.step==1 and not wizard.error.is_empty(),"duplicate cannot steal jump for healing")
 wizard.capture(button(0,true));wizard.capture(button(0,false))
 wizard.capture(button(JOY_BUTTON_BACK,true));wizard.capture(button(JOY_BUTTON_BACK,false))
 check(wizard.step==3 and wizard.bindings.jump_trigger.index==JOY_BUTTON_BACK,"digital LT may be a formerly misidentified Back event")
 wizard.capture(button(16,true));wizard.capture(button(16,false))
 wizard.capture(button(15,true));wizard.capture(button(15,false))
 check(wizard.step==5 and not wizard.save_button.disabled,"separate map key completes wizard")
 wizard.save_bindings();await ticks(2)
 check(not app.paused,"successful checked save applies and resumes")
 var profile:=app.controller.router.profile
 check(profile.gamepad_binding(7,"jump").index==1 and profile.gamepad_binding(7,"heal").index==0,"physical south/east override wrong normalized letter positions")
 var restored:=WorldSettings.new();restored.open(app.settings_path,app.save_profile)
 var loaded_profile:=InputProfile.new();check(loaded_profile.configure(restored.value.input),"reloaded calibration remains a valid profile")
 for role:String in ["jump","heal","jump_trigger","item_trigger","map"]:
  var before:=profile.gamepad_binding(7,role);var after:=loaded_profile.gamepad_binding(7,role)
  check(before.kind==after.kind and int(before.index)==int(after.index),"reload preserves actual binding "+role)
 var pad:=app.player.get_node("GamepadAdapter") as GamepadAdapter;pad.connected_device=7
 var router:=app.controller.router;router.clear("calibration input fixture")
 pad._unhandled_input(button(1,true));var a:=router.consume_actions(10000)
 check(a.size()==1 and a[0].type==&"jump","south reaches real shared jump router")
 pad._unhandled_input(button(1,false));router.consume_actions(10001)
 app.focus_heal._unhandled_input(button(0,true));check(router.focus_heal_held(),"east holds real focus-heal intent")
 app.focus_heal._unhandled_input(button(0,false));check(not router.focus_heal_held(),"east release ends heal hold")
 pad._unhandled_input(button(JOY_BUTTON_BACK,true));app._unhandled_input(button(JOY_BUTTON_BACK,true));a=router.consume_actions(10002)
 check(a.size()==1 and a[0].type==&"jump" and not app.paused,"calibrated LT jumps without opening map")
 router.clear("pause");pad._unhandled_input(button(JOY_BUTTON_BACK,false));check(router.consume_actions(10003).is_empty(),"cancelled LT release does not queue an action")
 pad._unhandled_input(button(JOY_BUTTON_BACK,true));a=router.consume_actions(10004)
 check(a.size()==1 and a[0].type==&"jump","fresh LT rearms after neutral")
 pad._unhandled_input(button(JOY_BUTTON_BACK,false));router.consume_actions(10005)
 router.item_skill_available=true
 pad._unhandled_input(button(16,true));a=router.consume_actions(10006)
 check(a.size()==1 and a[0].type==&"item_skill" and not app.paused,"calibrated RT activates only its own item intent")
 pad._unhandled_input(button(16,false));router.consume_actions(10007)
 app._unhandled_input(button(15,true));check(app.paused and app.ui.page=="map","separate View button opens actual map")
 var model:=WorldGamepadCalibration.new()
 for index:int in [1,0,4,16]:model.capture(button(index,true));model.capture(button(index,false))
 model.skip_optional();check(model.step==5 and model.bindings.map.kind=="none","map may be skipped without sharing the LT key")
 model._connection_changed(7,false);check(model.step==0 and model.bindings.is_empty(),"disconnect cancels partial capture")
 model.free()
 var invalid:=profile.values.duplicate(true);invalid.gamepad_device_bindings[InputProfile.gamepad_key(7)].map={"kind":"button","index":4}
 check(not InputProfile.new().configure(invalid),"persisted conflicting LT/map binding is rejected")
 await WorldAudioLifecycle.drain_world(app);app.queue_free();await ticks(5)
 print("GAMEPAD CALIBRATION: ",assertions," assertions; ",failures," failures");quit(failures)
