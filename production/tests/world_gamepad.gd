extends SceneTree
## Send native Godot input events through the same viewport and adapters as a device.
class MemorySlot extends PlayableWorldSave:
	var payload := {}
	var revision := 0
	func load_profile() -> Dictionary: return {"accepted":true,"payload":payload.duplicate(true),"revision":revision}
	func commit(candidate: Dictionary, next_revision: int) -> bool:
		payload=candidate.duplicate(true)
		revision=next_revision
		return true

var shell: WorldShell
var failures:=0
var checks:=0
var shots:=0

func _initialize() -> void: run.call_deferred()
func frames(n:int) -> void:
	for i in n: await physics_frame
func check(ok:bool, why:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL gamepad ",why," page=",shell.page)
func inject(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func pad(button: JoyButton, down:bool) -> void:
	var e:=InputEventJoypadButton.new()
	e.device=0
	e.button_index=button
	e.pressed=down
	inject(e)
func tap(button:JoyButton) -> void:
	pad(button,true)
	await frames(2)
	pad(button,false)
	await frames(2)
func stick(axis:JoyAxis, value:float) -> void:
	var e:=InputEventJoypadMotion.new()
	e.device=0
	e.axis=axis
	e.axis_value=value
	inject(e)
func key(code:Key,down:bool) -> void:
	var e:=InputEventKey.new()
	e.keycode=code
	e.physical_keycode=code
	e.pressed=down
	inject(e)
func touch(at:Vector2,down:bool, finger:=1) -> void:
	var e:=InputEventScreenTouch.new()
	e.position=at
	e.index=finger
	e.pressed=down
	root.push_input(e,true)

func drag(finger:int,from:Vector2,to:Vector2) -> void:
	var e:=InputEventScreenDrag.new()
	e.index=finger
	e.position=to
	e.relative=to-from
	root.push_input(e,true)

func wound(session:OrdinaryRoomSession,id:StringName) -> void:
	var hit:=DamageRequest.new()
	hit.event_id=id
	hit.source_id=&"touch_control_test"
	hit.target_id=&"player"
	hit.kind=DamageRequest.Kind.MONSTER
	hit.amount=1
	hit.token=session.lifetime.token()
	hit.actor_epoch=session.lifetime.actor_epoch
	hit.health_epoch=session.controller.actor_resources.health.epoch
	session.policy.submit(hit)
	session.policy.resolve_batch()

func healing_and_skills() -> void:
	var session:=shell.world.active
	var health:=session.controller.actor_resources.health
	var energy:=session.controller.combat_energy
	var controls:=session.touch_controls
	session.player.reset_at(Vector2(960,585))
	await frames(55)
	wound(session,&"touch_heal_first")
	energy.grant("touch_heal_setup",energy.capacity())
	await frames(40)
	var hp:=health.current
	var charge:=energy.current
	var point:=controls.healing_button.get_center()
	touch(point,true)
	await frames(18)
	check(health.current<health.capacity and session.focus_heal.ratio()>0 and session.controller.router.focus_heal_held(),"long touch starts an actual heal while both feet are planted")
	touch(point,false)
	await frames(60)
	check(health.current==hp and energy.current==charge and is_zero_approx(session.focus_heal.ratio()),"early release cancels the charge without spending resonance")
	touch(point,true)
	await frames(12)
	var origin:=controls.right_center
	var aimed:=origin+Vector2(66,-20)
	touch(origin,true,2)
	drag(2,origin,aimed)
	await frames(4)
	touch(aimed,false,2)
	await frames(75)
	check(shots>=2 and health.current==hp and energy.current==charge,"aiming and firing cancel an in-progress heal without spending or resuming the held contact")
	touch(point,false)
	await frames(14)
	touch(origin,true,2)
	drag(2,origin,aimed)
	await frames(2)
	touch(point,true)
	await frames(3)
	check(session.controller.router.aim_engaged and not session.controller.router.focus_heal_held(),"pressing heal on top of an ongoing aim is ignored")
	touch(aimed,false,2)
	await frames(72)
	check(health.current==hp and energy.current==charge,"a blocked healing finger cannot become a fresh hold after a shot")
	touch(point,false)
	await frames(8)
	touch(point,true)
	await frames(14)
	var canceled:=InputEventScreenTouch.new()
	canceled.index=1
	canceled.position=point
	canceled.canceled=true
	root.push_input(canceled,true)
	await frames(65)
	check(not session.controller.router.focus_heal_held() and health.current==hp and energy.current==charge,"a canceled OS touch clears the charge and all held contact state")
	touch(point,true)
	await frames(70)
	touch(point,false)
	check(health.current==hp+1 and energy.current==charge-session.focus_heal.settings.cost,"completed thumb hold restores one real HP and pays the configured resonance cost")
	await frames(55)
	wound(session,&"touch_heal_transfer")
	await frames(30)
	touch(point,true)
	await frames(5)
	check(session.focus_heal.ratio()>0,"second heal is still charging at handoff")
	shell.world.enter_room("G23","",preload("system_room_fixture.gd").flat("G23"))
	await frames(3)
	session=shell.world.active
	controls=session.touch_controls
	controls.set_enabled(true)
	touch(point,false)
	await frames(70)
	check(session.room.room_id=="G23" and not session.controller.router.focus_heal_held() and is_zero_approx(session.focus_heal.ratio()),"a held contact and its old release cannot heal in the next room")
	var progress:=session.state.candidate()
	if not progress.flags.has("intro_active_skill"):progress.flags.append("intro_active_skill")
	progress.services.owned["P26"]=1
	progress.services.equipped=["P26"]
	progress.services.selected="P26"
	check(session.state.commit(progress,session.state.revision),"touch combat fixture owns the pulse and the selected protected-time equipment")
	session.controller.combat_energy.grant("touch_item_ready",session.controller.combat_energy.capacity())
	await frames(4)
	touch(controls.skill_center,true)
	touch(controls.skill_center,false)
	await frames(3)
	check(session.controller.router.weapon_skill_available and session.controller.shoot_ability.behavior().phase==&"intro_pulse","the dedicated touch weapon skill starts the real pulse")
	await frames(75)
	touch(controls.item_skill_center,true)
	touch(controls.item_skill_center,false)
	await frames(4)
	check(session.controller.router.item_skill_available and session.equipment.fx.protected>0,"the separate active equipment key triggers the equipped protection effect")

func help_text() -> String:
	var text:=""
	for label:Label in shell.page_host.find_children("*","Label",true,false): text+=label.text+"\n"
	return text

func run() -> void:
	root.size=Vector2i(1280,720)
	shell=preload("res://game/application/world_shell.tscn").instantiate()
	var slot:=MemorySlot.new()
	slot.configure_world("user://gamepad_test_unused.json",false)
	shell.storage=slot
	root.add_child(shell)
	await frames(8)
	var home:=root.gui_get_focus_owner()
	check(home!=null and home.name=="BeginAdventure","title focuses the available new-game action")
	await tap(JOY_BUTTON_DPAD_DOWN)
	await frames(4)
	var down:=root.gui_get_focus_owner()
	check(down!=null and down!=home and not (down as Button).disabled,"D-pad navigates around the disabled Continue button")
	await tap(JOY_BUTTON_DPAD_UP)
	await tap(JOY_BUTTON_A)
	for i in 130:
		if shell.world!=null and shell.page==&"play":break
		await physics_frame
	check(shell.world!=null and shell.page==&"play","native confirm starts the real P01 game")
	if shell.world==null:
		await preload("world_audio_cleanup.gd").drain(shell)
		shell.free()
		quit(1)
		return
	# Give the controls an unobstructed rehearsal floor and the overlay its corresponding map identity.
	for fixture: String in ["G12","G23"]:
		shell.world.route_map.rooms[fixture]=shell.world.catalog.lookup("rooms",fixture).row
	shell.world.enter_room("G12","",preload("system_room_fixture.gd").flat("G12"))
	await frames(10)
	var session:=shell.world.active
	var router:=session.controller.router
	check(session.player.get_node_or_null("GamepadAdapter")!=null,"ordinary playable actors have the registered adapter")
	session.player.reset_at(Vector2(960,585))
	await frames(12)
	var x:=session.player.position.x
	stick(JOY_AXIS_LEFT_X,0.88)
	await frames(16)
	stick(JOY_AXIS_LEFT_X,0)
	await frames(5)
	check(router.current_device==&"gamepad" and session.player.position.x>x+25,"left analog stick drives the physical body")
	var floor_y:=session.player.position.y
	pad(JOY_BUTTON_A,true)
	await frames(10)
	pad(JOY_BUTTON_A,false)
	check(session.player.position.y<floor_y-24,"face button makes a real jump")
	await frames(90)
	floor_y=session.player.position.y
	var original_profile:=router.profile.values.duplicate(true)
	var calibrated:=original_profile.duplicate(true)
	calibrated["gamepad_device_bindings"]={InputProfile.gamepad_key(0):{
		"jump":{"kind":"button","index":JOY_BUTTON_RIGHT_STICK},"heal":{"kind":"button","index":JOY_BUTTON_B},
		"jump_trigger":{"kind":"axis","index":JOY_AXIS_TRIGGER_LEFT},"item_trigger":{"kind":"axis","index":JOY_AXIS_TRIGGER_RIGHT},
		"map":{"kind":"button","index":JOY_BUTTON_BACK}}}
	check(router.reconfigure(calibrated),"the adapter and calibration view share the same validated input profile")
	pad(JOY_BUTTON_A,true)
	await frames(7)
	pad(JOY_BUTTON_A,false)
	check(absf(session.player.position.y-floor_y)<1,"the old jump binding is inactive on the remapped device")
	pad(JOY_BUTTON_RIGHT_STICK,true)
	await frames(9)
	pad(JOY_BUTTON_RIGHT_STICK,false)
	check(session.player.position.y<floor_y-24,"the calibrated physical button actually jumps")
	router.reconfigure(original_profile)
	await frames(90)
	var stage:=session.state.candidate()
	stage.flags.append("gun")
	check(session.state.commit(stage,session.state.revision),"fixture owns the production sidearm")
	session.controller.shoot_ability.shot_fired.connect(func(_direction:Vector2,_id:int)->void:shots+=1)
	stick(JOY_AXIS_RIGHT_Y,-1)
	await frames(4)
	check(router.aim_engaged and router.aim_direction.y<-.8,"right stick supplies world-space aim")
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	stick(JOY_AXIS_RIGHT_Y,0)
	check(shots==1,"right shoulder fires once with the real sidearm")
	await tap(JOY_BUTTON_START)
	check(shell.page==&"pause" and paused and session.controller.router.axis==0,"Start pauses gameplay and clears held input")
	await tap(JOY_BUTTON_B)
	check(shell.page==&"play" and not paused,"Back resumes play")
	await tap(JOY_BUTTON_BACK)
	check(shell.world.route_map.visible and paused,"the configured map button opens the map")
	await tap(JOY_BUTTON_BACK)
	check(not shell.world.route_map.visible and not paused,"a second map gesture returns to play")
	key(KEY_A,true)
	await frames(5)
	key(KEY_A,false)
	check(router.current_device==&"keyboard_mouse","keyboard regains gameplay input")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await frames(4)
	check(shell.page==&"pause" and paused,"Escape opens pause without opening equipment")
	shell.get_node("WorldShellInput").notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(5)
	check(shell.page==&"play" and not paused,"the operating-system back notification returns through the same pause stack")
	var controls:=session.touch_controls
	controls.set_enabled(true)
	controls.update_layout()
	touch(controls.pause_button.get_center(),true)
	await frames(3)
	touch(controls.pause_button.get_center(),false)
	check(shell.page==&"pause" and paused and router.current_device==&"touch" and not controls.visible and controls.enabled,"touch pause dispatches from its safe-area button")
	shell.open_help()
	await frames(6)
	var text:=help_text()
	check(shell.page==&"help" and "互动" in text and "右半屏" in text and "按住回复" in text,"the current touch guide describes the real interact and drag/release controls")
	var tab:Button
	for candidate:Button in shell.page_host.find_children("*","Button",true,false):
		if candidate.get_meta("device",&"")==&"keyboard_mouse":tab=candidate
	if tab!=null:tab.grab_focus()
	await tap(JOY_BUTTON_DPAD_RIGHT)
	await tap(JOY_BUTTON_A)
	var selected:=help_text()
	check(tab!=null and root.gui_get_focus_owner()!=null and "右摇杆" in selected and "共鸣回复" in selected and "右半屏" not in selected,"the joypad navigates device tabs and selects actual physical controls")
	await tap(JOY_BUTTON_B)
	check(shell.page==&"pause","Back exits help to the menu it came from")
	await tap(JOY_BUTTON_START)
	check(shell.page==&"play" and not paused,"Start closes pause after visiting help")
	await healing_and_skills()
	check(await preload("world_audio_cleanup.gd").drain(shell),"shutdown releases shell and room audio")
	shell.free()
	print("WORLD GAMEPAD failures=",failures," checks=",checks)
	quit(1 if failures else 0)
