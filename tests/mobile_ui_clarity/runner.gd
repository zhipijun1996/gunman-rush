extends SceneTree
## Actual Controls and native input; window/touch settings are explicit fixtures.
## Exported browser coverage supplies the backing-store/HiDPI pixel evidence.
var app: DemoApp
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var windows := [Vector2i(1280,720),Vector2i(1000,540),Vector2i(853,290),Vector2i(844,390)]
var baseline := Rect2()
func _initialize() -> void: run.call_deferred()
func frames(count: int = 5) -> void:
 for i: int in count:await process_frame
func check(ok: bool, message: String) -> void:
 checks+=1
 observations.append({"passed":ok,"assertion":message})
 if not ok:failures+=1;printerr("FAIL: "+message)
func rect_equal(a: Rect2,b: Rect2) -> bool:
 return a.position.distance_to(b.position)<1.0 and a.size.distance_to(b.size)<1.0
func run() -> void:
 root.content_scale_size=Vector2i(1280,720)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
 root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
 root.size=windows[0]
 app=DemoApp.new();app.meta_persistence_enabled=false;root.add_child(app)
 await frames(10)
 for size: Vector2i in windows:
  root.size=size
  await frames(8)
  app.menu._layout_menu()
  await frames()
  var primary:=app.menu._content.get_node("BeginAdventure") as Button
  var actual:=primary.get_global_rect()
  if baseline==Rect2():baseline=actual
  check(rect_equal(actual,baseline),"title proportions stay identical in the shared logical canvas at "+str(size))
  check(primary.custom_minimum_size.y==62,"primary keeps authored62-unit height at "+str(size))
  check(primary.get_theme_font_size("font_size")==24,"primary keeps authored24-unit font at "+str(size))
  check(app.menu._title_label.get_theme_font_size("font_size")==36,"title keeps authored36-unit font at "+str(size))
  check(root.get_visible_rect().encloses(actual),"primary stays fully visible at "+str(size))
  check(DemoUiModalMetrics.ui_scale(root)==1.0,"UI geometry does not invert screen density at "+str(size))
 app._show_home()
 await frames(10)
 var home:=app.home_scene
 var desktop_menu:=home._menu_button.get_global_rect()
 check(not home._status.visible,"Home removes duplicate old status row")
 check(home._home_top.visible,"desktop Home retains actual menu Button")
 home.overlay.set_enabled(true)
 await frames(10)
 check(not home._home_top.visible,"touch Home uses only original overlay menu target")
 check(rect_equal(home.overlay._pause_rect,desktop_menu),"desktop and touch Home menus share the same logical geometry")
 check(home._resource_hud._rows.scale==Vector2.ONE,"Home HUD retains desktop/world scale on touch")
 var left:=Rect2(home.overlay.left_center-Vector2.ONE*home.overlay.radius,Vector2.ONE*home.overlay.radius*2)
 var right:=Rect2(home.overlay.right_center-Vector2.ONE*home.overlay.radius,Vector2.ONE*home.overlay.radius*2)
 var jump:=Rect2(home.overlay.jump_center-Vector2.ONE*home.overlay.jump_radius,Vector2.ONE*home.overlay.jump_radius*2)
 var control:=home._interaction.get_global_rect()
 check(not control.intersects(left) and not control.intersects(right) and not control.intersects(jump),"Home interaction target clears real touch pads")
 check(not home._resource_hud._location_plate.get_global_rect().intersects(left),"Home location text clears real left pad")
 check(not home._prompt.visible and not home._prompt_backing.visible,"idle touch Home omits desktop key instructions")
 var shots:=home.controller.shoot_ability._shot_serial
 var point:=home.overlay._pause_rect.get_center()
 for pressed: bool in [true,false]:
  var event:=InputEventScreenTouch.new();event.index=91;event.position=point;event.pressed=pressed;root.push_input(event,true);await frames(3)
 check(app.menu.visible_panel==&"home" and home.input_blocked,"native touch opens original Home menu and blocks actor input")
 check(home.controller.shoot_ability._shot_serial==shots,"menu touch does not leak a shot")
 for pressed: bool in [true,false]:
  var event:=InputEventJoypadButton.new();event.button_index=JOY_BUTTON_B;event.pressed=pressed;root.push_input(event,true);await frames(3)
 check(not paused and not home.input_blocked,"original Home cancel resumes controls")
 var setting:="display/window/dpi/allow_hidpi"
 check(ProjectSettings.get_setting_with_override_and_custom_features(setting,PackedStringArray(["web"]))==true,"Web renders at display density")
 var font:=load("res://assets/ui/demo_ui_01/r2/fonts/fusion-pixel-12px-proportional-zh_hans.otf") as FontFile
 check(font.oversampling==0.0,"font rasterization follows real display scale")
 await app._music.shutdown()
 await (get_first_node_in_group(&"game_audio") as GameAudio).shutdown()
 root.remove_child(app);app.queue_free();await frames(3)
 DirAccess.make_dir_recursive_absolute("res://build/verification/mobile-ui-clarity")
 var file:=FileAccess.open("res://build/verification/mobile-ui-clarity/native.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"actual native controls with explicit window/touch fixtures; not physical phone"},"  "));file.close()
 print("MOBILE UI CLARITY: %s checks, %s failures" % [checks,failures])
 quit(1 if failures else 0)
