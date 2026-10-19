extends SceneTree

# Fixtures initialize position only. Every gun/H transition comes from a real
# adapter and is consumed by the real Controller and unique Motor.
const DT := 1.0/60.0
var checks := 0
var failures := 0
var fixture: RefCounted
var controller: PlayerController
var keyboard: KeyboardMouseAdapter
var gamepad: GamepadAdapter
var overlay: TouchOverlay
var device := ""
var gun_origin := Vector2.ZERO
var hook_origin := Vector2.ZERO

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+device+": "+label)
func step(count := 1) -> void:
	for i: int in count:
		await physics_frame
		controller.physics_tick(DT)
func mouse(button: MouseButton, held: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=button;event.pressed=held
	event.position=fixture.motor.get_canvas_transform()*(fixture.motor.global_position+Vector2(200,-6))
	keyboard._unhandled_input(event)
func touch(index: int, point: Vector2, held: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index;event.position=point;event.pressed=held
	overlay.handle_touch(event)
func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index;event.position=point
	overlay.handle_touch(event)
func start_gun(index := 1) -> void:
	match device:
		"pc":mouse(MOUSE_BUTTON_LEFT,true)
		"pad":
			gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT)
			gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT)
		"touch":
			gun_origin=overlay.right_center
			touch(index,gun_origin,true)
			drag(index,gun_origin+Vector2.RIGHT*overlay.radius)
func start_hook() -> void:
	match device:
		"pc":mouse(MOUSE_BUTTON_RIGHT,true)
		"pad":gamepad.sample_tick(Vector2.ZERO,Vector2.RIGHT,false,true)
		"touch":
			hook_origin=overlay.hook_center
			touch(2,hook_origin,true)
			drag(2,hook_origin+Vector2.RIGHT*overlay.hook_radius)
func end_hook() -> void:
	match device:
		"pc":mouse(MOUSE_BUTTON_RIGHT,false)
		"pad":gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO,false,false)
		"touch":touch(2,hook_origin+Vector2.RIGHT*overlay.hook_radius,false)
func end_old_gun() -> void:
	match device:
		"pc":mouse(MOUSE_BUTTON_LEFT,false)
		"pad":gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO,false,false)
		"touch":touch(1,gun_origin+Vector2.RIGHT*overlay.radius,false)
func run() -> void:
	fixture=preload("res://tests/combat_tests.gd").new();fixture.tree=self
	for weapon: String in ["sustained_laser","laser_cannon"]:
		for producer: String in ["pc","pad","touch"]:
			device=producer
			for existing_beam: bool in [false,true]:
				await fixture.fixture(Vector2(80,-10000))
				controller=fixture.controller
				check(controller.enable_shot_energy(),"formal shooting energy enabled")
				controller.traversal.grant(&"grapple")
				check(controller.shoot_ability.equip(load("res://resources/weapons/%s.tres"%weapon)),"equip actual "+weapon)
				controller.physics_tick(DT)
				overlay=InputSetup.attach(fixture.motor,controller.router)
				keyboard=fixture.motor.get_node("KeyboardMouseAdapter")
				gamepad=fixture.motor.get_node("GamepadAdapter");gamepad.set_physics_process(false)
				overlay.set_enabled(device=="touch")
				if device=="pad":
					gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
					gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
				if existing_beam:
					start_gun();await step(2)
					check(controller.shoot_ability.behavior().phase==&"beam","real held gun starts beam before H")
				var packet_before:=controller.shoot_ability.packet_id
				var shots_before:=controller.action_resources.shot_charges
				var energy_before:=controller.actor_resources.stamina.current
				start_hook()
				await step(3)
				check(controller.router.aim_mode==&"grapple" and controller.router.aim_engaged,"H owns valid adapter aim")
				check(controller.shoot_ability.behavior().phase==&"idle","H aim leaves no active laser")
				check(controller.shoot_ability.packet_id==packet_before and controller.action_resources.shot_charges==shots_before,"H aim creates no packet or shot-charge expense")
				check(is_equal_approx(controller.actor_resources.stamina.current,energy_before),"H aim does not reserve shooting energy or drain prior beam")
				check(fixture.motor.recoil_velocity.is_zero_approx() and not fixture.motor._sustained_recoil,"H aim leaves no laser motor drive")
				controller._physics_process(.001)
				check(controller.air_focus_ability.active and is_equal_approx(Engine.time_scale,.15),"H aim still requests actual controller 15 percent focus")
				if existing_beam:end_old_gun()
				# A fresh touch gun held during H is legal only after H ends.
				if device=="touch":start_gun(3)
				end_hook()
				await step()
				check(Engine.time_scale==.15,"manual physics driver did not alter focus scale")
				controller._physics_process(.001)
				check(Engine.time_scale==1.0,"actual hook cast restores normal speed while busy")
				check(controller.traversal.state!=&"free" and controller.shoot_ability.packet_id==packet_before,"H release starts traversal without another laser packet")
				for i: int in 100:
					await step()
					if controller.traversal.state==&"free":break
				check(controller.traversal.state==&"free","real miss/retract finishes without position reset")
				if device=="pad":
					gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
					gamepad.sample_tick(Vector2.ZERO,Vector2.ZERO)
				if device!="touch":start_gun()
				await step(2)
				check(controller.shoot_ability.behavior().phase==&"beam" and controller.shoot_ability.packet_id==packet_before+1,"fresh gun resumes exactly one normal beam after H")
				controller.router.clear("laser_hook_cancel")
				await step()
				check(controller.shoot_ability.behavior().phase==&"idle" and fixture.motor.recoil_velocity.is_zero_approx(),"cancellation clears beam motor drive")
				print("LASER H CASE: ",weapon,"/",device,"/existing_beam=",existing_beam," packet=",packet_before,"->",controller.shoot_ability.packet_id)
	fixture.world.free()
	await process_frame
	print("GRAPPLE LASER INPUT: %d assertions, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
