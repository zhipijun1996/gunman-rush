class_name WorldFocusHeal
extends Node2D
## Held intent and local action lifetime; the application commits HP/currency together.
var controller: PlayerController
var settings: Dictionary
signal ready_to_heal
var pending:=false
var elapsed:=0.0
var blocked:=false
var flash:=0.0
var _origin:=Vector2.ZERO
func _ready() -> void:
	process_physics_priority=1100
	z_index=5
	controller.router.cancelled.connect(func(_reason: String) -> void: cancel(false))
	controller.router.device_changed.connect(func(_source: StringName) -> void: cancel(false))
	controller.jump_ability.jumped.connect(func() -> void: cancel(true))
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_packet: int) -> void: cancel(true))
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.amount_applied<0: cancel(true))
func available() -> bool:
	var health:=controller.actor_resources.health
	return controller.active and controller.motor.is_on_floor() and not health.terminal and not health.normal_healing_blocked and health.current<health.capacity and controller.combat_energy.can_consume(float(settings.cost))
func ratio() -> float: return clampf(elapsed/float(settings.charge_seconds),0,1)
func cancel(require_release: bool) -> void:
	elapsed=0.0
	pending=false
	blocked=require_release and controller.router.focus_heal_held()
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if not controller.active: return
	if event is InputEventKey and not event.echo and event.physical_keycode==int(settings.keyboard_key):
		controller.router.set_focus_heal_held(&"keyboard_mouse",event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.button_index==int(settings.gamepad_button):
		controller.router.set_focus_heal_held(&"gamepad",event.pressed)
		get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:
	flash=maxf(0,flash-delta)
	if not controller.router.focus_heal_held(): cancel(false);return
	if blocked or pending: return
	if not available() or absf(controller.router.axis)>.01 or controller.router.aim_engaged or controller.traversal.busy() or absf(controller.motor.velocity.x)>10:
		cancel(true);return
	if elapsed<=0: _origin=controller.motor.position
	if controller.motor.position.distance_to(_origin)>2: cancel(true);return
	elapsed+=delta/Engine.time_scale
	if elapsed+0.000001>=float(settings.charge_seconds):
		elapsed=float(settings.charge_seconds)
		pending=true
		ready_to_heal.emit()
	queue_redraw()
func resolve(accepted: bool) -> void:
	pending=false
	elapsed=0
	if accepted: flash=.25
	else: cancel(true)
	queue_redraw()
func _draw() -> void:
	if elapsed>0: draw_arc(Vector2.ZERO,25,-PI*.5,-PI*.5+TAU*ratio(),32,DemoClockworkTheme.TEAL,2)
	if flash>0: draw_arc(Vector2.ZERO,25+(1-flash/.25)*8,0,TAU,32,Color(DemoClockworkTheme.TEAL,flash/.25),2)
