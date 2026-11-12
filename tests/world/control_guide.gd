extends "res://tests/world/plains_intro.gd"
## Real opening, shared device descriptions and pause/focus ownership.
var assertions:=0
var capture:=false
func verify(ok: bool,label: String) -> void:
	assertions+=1;check(ok,label)
func mark(label: String) -> void:
	print("GUIDE MEDIA ",label," frame=",Engine.get_process_frames())
	if capture:root.get_texture().get_image().save_png("res://build/onboarding/"+label.replace(" ","-")+".png")
func tap(button: Button) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true);await ticks(1)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await ticks(3)
func run() -> void:
	capture="capture" in OS.get_cmdline_user_args()
	root.size=Vector2i(1280,720)
	app=preload("res://game/application/world/fixed_world.tscn").instantiate();root.add_child(app)
	await load_review("P-R03")
	for i: int in 180:
		if app.introduction.dialogue_active:break
		await ticks(1)
	verify(app.paused and not app.ui.onboarding_hint.desired,"wake dialogue suppresses nonmodal prompts")
	var texts:=WorldText.catalog.duplicate(true)
	WorldText.catalog.clear()
	verify(PlayerControlGuide.text("title")==str(texts["guide.title"]),"unconfigured menu resolves the compiled runtime text catalog")
	WorldText.configure({"strings":texts})
	app.introduction.advance();await fixture(Vector2(128,1774));await ticks(20)
	verify(app.ui.onboarding_hint.lesson=="move" and not app.paused,"safe first movement prompt does not pause")
	mark("move");if capture:await ticks(45)
	app.controller.router.set_source_axis(&"keyboard_mouse",1);await ticks(20);app.controller.router.set_source_axis(&"keyboard_mouse",0)
	verify(app.tutorial.learned_hints.has("keyboard_mouse:move"),"real accepted travel marks movement understood")
	await fixture(Vector2(288,1774));await ticks(18)
	verify(app.ui.onboarding_hint.lesson=="pickup","approaching actual gun selects interaction")
	app.controller.interact_requested.emit();await ticks(4)
	verify(app.state.has("intro_gun"),"real interaction commits ground gun pickup")
	while app.introduction.dialogue_active:app.introduction.advance()
	await ticks(20)
	verify(app.ui.onboarding_hint.lesson=="shoot","closed first bell selects shot instruction")
	mark("keyboard shot");if capture:await ticks(50)
	var router:=app.controller.router
	var saved:=router.profile.values.duplicate(true)
	var modified:=saved.duplicate(true);modified.keyboard.jump=[KEY_J];modified.mouse_shoot_button=MOUSE_BUTTON_MIDDLE
	verify(router.profile.configure(modified),"remapped input profile accepted")
	var rows:=PlayerControlGuide.rows(&"keyboard_mouse",router.profile.values)
	verify(rows[1].binding=="J" and str(rows[2].binding)==PlayerControlGuide.text("mouse_middle"),"help and hints resolve actual remapped keys and mouse")
	verify(router.profile.configure(saved),"restore original user bindings")
	app.overlay.set_enabled(true);router.activate_device(&"gamepad");await ticks(15)
	verify(router.current_device==&"gamepad" and app.ui.onboarding_hint.instruction.text.contains("R1"),"touch-capable device still displays active gamepad instructions")
	verify(PlayerControlGuide.binding("jump",&"gamepad",saved,{},"ps")=="× / L2","PS jump includes face button and trigger")
	verify(PlayerControlGuide.binding("jump",&"gamepad",saved,{},"switch")=="B / ZL","Nintendo jump uses physical south and trigger")
	mark("gamepad shot");if capture:await ticks(50)
	router.activate_device(&"touch");await ticks(15)
	verify(app.overlay.onboarding_action==&"shoot" and app.ui.onboarding_hint.instruction.text.contains(PlayerControlGuide.text("touch_right")),"touch prompt and noninteractive control emphasis agree")
	mark("touch shot");if capture:await ticks(50)
	app.overlay.set_enabled(false);router.activate_device(&"keyboard_mouse")
	# First bell is opened by the real projectile, not a UI completion flag.
	var bell:=app.room.mechanisms["P-R03:first_bell"] as WorldShotLatch
	router.request_action(&"shoot_release",(bell.bell_position-app.player.position-Vector2(0,-6)).normalized());await ticks(25)
	verify(bell.is_open and app.ui.onboarding_hint.lesson!="shoot","real accepted bell opening completes the shot lesson")
	await fixture(Vector2(552,1774));await ticks(15)
	verify(app.ui.onboarding_hint.lesson=="jump","first physical step selects variable jump instruction")
	mark("jump");if capture:await ticks(45)
	router.set_jump_held(&"keyboard_mouse",true);await ticks(8);router.set_jump_held(&"keyboard_mouse",false);await ticks(35)
	verify(not app.tutorial.learned_hints.has("keyboard_mouse:jump") and app.ui.onboarding_hint.lesson=="jump","jumping in place does not falsely complete the step goal")
	# Isolate this explicit landing fixture from later combat, retaining terrain.
	for enemy:EnemyActor in app.room.enemies.values():
		enemy.cancel_attacks();enemy.process_mode=Node.PROCESS_MODE_DISABLED;enemy.motor.position=Vector2(-10000,-10000)
	router.set_source_axis(&"keyboard_mouse",1);router.set_jump_held(&"keyboard_mouse",true);await ticks(16);router.set_jump_held(&"keyboard_mouse",false)
	for i: int in 65:
		await ticks(1)
		if app.player.position.x>704:router.set_source_axis(&"keyboard_mouse",0)
		if app.player.is_on_floor():break
	router.set_source_axis(&"keyboard_mouse",0);await ticks(5)
	verify(app.tutorial.learned_hints.has("keyboard_mouse:jump") and app.ui.onboarding_hint.lesson!="jump","actual accepted jump and upper-step landing complete the goal")
	app.tutorial.reset_proof();await ticks(4)
	verify(app.tutorial.learned_hints.has("keyboard_mouse:jump"),"terrain/death proof reset does not re-teach mastered prompt")
	app.toggle_pause();app._ui_command("help","");await ticks(5)
	verify(app.paused and paused and app.ui.page=="help" and not app.ui.onboarding_hint.desired,"formal pause page opens guide and suppresses prompts")
	verify(app.ui.shell.find_children("*","ControlGuideDiagram",true,false).size()==1,"formal guide includes the live action illustration")
	var epoch:=router.epoch
	var tab:=app.ui.shell.find_child("GuideTab_gamepad",true,false) as Button
	await tap(tab)
	verify(router.current_device==&"keyboard_mouse" and router.epoch==epoch,"manual device tab changes only help presentation")
	verify((app.ui.shell.find_child("GuideTab_gamepad",true,false) as Button).button_pressed,"actual pointer selects the requested device tab")
	mark("pause gamepad");if capture:await ticks(65)
	app.ui.show_controls(&"touch");await ticks(5)
	mark("pause touch");if capture:await ticks(65)
	app.ui.show_controls(&"keyboard_mouse");await ticks(5)
	mark("pause keyboard");if capture:await ticks(65)
	var locked:=PlayerControlGuide.rows(&"keyboard_mouse",saved)
	verify(not locked.any(func(row:Dictionary)->bool:return row.id=="hook"),"locked abilities do not appear as available actions")
	var unlocked:=PlayerControlGuide.rows(&"gamepad",saved,{"hook":true,"double":true})
	verify(unlocked.any(func(row:Dictionary)->bool:return row.id=="hook") and unlocked.any(func(row:Dictionary)->bool:return row.id=="recoil"),"available abilities and common recoil instructions remain accessible")
	app._close_panel();await ticks(2)
	verify(app.paused and paused and app.ui.page=="pause","Back returns to paused menu")
	app._close_panel();await ticks(3)
	verify(not app.paused and not paused and router.consume_actions(99999).is_empty(),"continue restores gameplay without buffered jump or shot")
	await WorldAudioLifecycle.drain_world(app)
	print("CONTROL GUIDE: ",assertions," checks; ",failures," failures");quit(failures)
