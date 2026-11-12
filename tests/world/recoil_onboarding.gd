extends "res://tests/world/plains_intro.gd"
## P21's one safe preparation prompt; normal controls and recoil, no tutorial gate.
var assertions:=0
var capture:=false
func verify(ok:bool,label:String)->void:
 assertions+=1;check(ok,label)
func run()->void:
 capture="capture" in OS.get_cmdline_user_args()
 root.size=Vector2i(1280,720)
 app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
 await load_review("P-R21")
 await fixture(Vector2(560,526));await ticks(10)
 var router:=app.controller.router
 verify(app.ui.onboarding_hint.lesson=="recoil" and not app.paused,"single safe-platform recoil instruction does not pause")
 for device:StringName in [&"keyboard_mouse",&"gamepad",&"touch"]:
  router.activate_device(device);await ticks(5)
  var instruction:=PlayerControlGuide.hint("recoil",device,router.profile.values,app.ui.pad_style())
  verify(app.ui.onboarding_hint.instruction.text.contains(instruction.binding),"actual device binding in recoil prompt: "+str(device))
 router.activate_device(&"keyboard_mouse");await ticks(5)
 if capture:
  root.get_texture().get_image().save_png("res://build/corner-rework/p21-recoil.png");await ticks(55)
 router.request_action(&"shoot_release",Vector2.LEFT);await ticks(40)
 verify(not app.tutorial.learned_hints.has("keyboard_mouse:recoil"),"ground shot cannot complete air recoil instruction")
 router.set_jump_held(&"keyboard_mouse",true);await ticks(10);router.set_jump_held(&"keyboard_mouse",false)
 verify(not app.ui.onboarding_hint.desired,"airborne motion is not covered by a teaching panel")
 await ticks(60)
 verify(app.ui.onboarding_hint.lesson=="recoil" and not app.tutorial.learned_hints.has("keyboard_mouse:recoil"),"ordinary jump does not complete recoil")
 router.set_jump_held(&"keyboard_mouse",true);await ticks(10)
 router.request_action(&"shoot_release",Vector2(-.94,.34));await ticks(10)
 router.set_jump_held(&"keyboard_mouse",false)
 var saw_air:=app.tutorial._hint_recoil_moved
 if capture:root.get_texture().get_image().save_png("res://build/corner-rework/p21-action.png")
 for i:int in 140:
  await ticks(1)
  if app.player.is_on_floor():break
 await ticks(5)
 verify(saw_air and app.tutorial.learned_hints.has("keyboard_mouse:recoil"),"accepted air shot, reverse travel and actual landing complete recoil")
 verify(not app.ui.onboarding_hint.desired,"mastered recoil prompt disappears")
 app.tutorial.reset_proof();await fixture(Vector2(560,526));await ticks(5)
 verify(not app.ui.onboarding_hint.desired,"proof reset does not repeat the mastered prompt")
 # A failed attempt cannot be completed by landing after a covered segment return.
 app.tutorial.learned_hints.erase("keyboard_mouse:recoil")
 router.set_jump_held(&"keyboard_mouse",true);await ticks(10)
 router.request_action(&"shoot_release",Vector2.LEFT);await ticks(8)
 app.controller.segment_returned.emit();await ticks(60)
 verify(not app.tutorial.learned_hints.has("keyboard_mouse:recoil"),"failed segment return clears pending air-recoil proof")
 for rid:String in ["P-R22","P-R23","P-R24"]:
  await load_review(rid);await ticks(5)
  verify(app.room.onboarding.is_empty() and not app.ui.onboarding_hint.desired,"practice room has no extra button lesson: "+rid)
 await WorldAudioLifecycle.drain_world(app)
 print("RECOIL ONBOARDING: ",assertions," checks; ",failures," failures");quit(failures)
