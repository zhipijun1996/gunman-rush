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
var _cancel_fade:=0.0
var _last_ratio:=0.0
var reduced:=false
var _release_pose_allowed:=false
var body:UnderworldPlayer
func _pose(index:int) -> void:
	if not is_instance_valid(body):body=PlayerPresentationRuntime.current_body(controller.motor)
	if body!=null:
		body.authored_pose.focus_frame=index
		if index>=0:body.authored_pose.session=controller.session_id
func _reset_presentation() -> void:
	_release_pose_allowed=false
	flash=0;_cancel_fade=0;_pose(-1);GameAudio.stop_origin(self,false)
func _exit_tree() -> void:
	_reset_presentation()

func _ready() -> void:
	process_physics_priority=1100
	z_index=5
	var unlit:=CanvasItemMaterial.new();unlit.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=unlit
	controller.router.cancelled.connect(func(_reason: String) -> void: cancel(false);_reset_presentation())
	controller.router.device_changed.connect(func(_source: StringName) -> void: cancel(false);_reset_presentation())
	controller.jump_ability.jumped.connect(func() -> void: cancel(true);_release_pose_allowed=false)
	controller.shoot_ability.shot_fired.connect(func(_direction: Vector2,_packet: int) -> void: cancel(true);_release_pose_allowed=false)
	controller.actor_resources.health.changed.connect(func(result: ActorResourceResult) -> void:
		if result.operation==&"damage" and result.amount_applied<0: cancel(true);_release_pose_allowed=false)
func available() -> bool:
	var health:=controller.actor_resources.health
	return controller.active and controller.motor.is_on_floor() and not health.terminal and not health.normal_healing_blocked and health.current<health.capacity and controller.combat_energy.can_consume(float(settings.cost))
func ratio() -> float: return clampf(elapsed/float(settings.charge_seconds),0,1)
func cancel(require_release: bool) -> void:
	if elapsed>0:
		_last_ratio=ratio();_cancel_fade=float(settings.presentation.cancel_seconds)
		GameAudio.stop_origin(self)
	_pose(-1)
	elapsed=0.0
	pending=false
	blocked=require_release and controller.router.focus_heal_held()
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if not controller.active: return
	if event is InputEventKey and not event.echo and event.physical_keycode==int(settings.keyboard_key):
		controller.router.set_focus_heal_held(&"keyboard_mouse",event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.button_index==int(controller.router.profile.gamepad_binding(event.device,"heal").index):
		controller.router.set_focus_heal_held(&"gamepad",event.pressed)
		get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:
	flash=maxf(0,flash-delta)
	_cancel_fade=maxf(0,_cancel_fade-delta)
	queue_redraw()
	if flash>0 and _release_pose_allowed and controller.active and controller.motor.is_on_floor() and absf(controller.motor.velocity.x)<10 and not controller.router.aim_engaged:
		_pose(5 if flash>float(settings.presentation.release_seconds)*.5 else 6)
	elif elapsed<=0:_pose(-1)
	if not controller.router.focus_heal_held():
		if elapsed>0:cancel(false)
		blocked=false;return
	if blocked or pending: return
	if not available() or absf(controller.router.axis)>.01 or controller.router.aim_engaged or controller.traversal.busy() or absf(controller.motor.velocity.x)>10:
		cancel(true);return
	var starting:=elapsed<=0
	if starting: _origin=controller.motor.position
	if controller.motor.position.distance_to(_origin)>2: cancel(true);return
	elapsed+=delta/Engine.time_scale
	if starting:GameAudio.cue_focus(self,&"heal_gather")
	_pose(1 if ratio()<.16 else 2 if ratio()<.4 else 3+posmod(int(elapsed*7),2))
	if elapsed+0.000001>=float(settings.charge_seconds):
		elapsed=float(settings.charge_seconds)
		pending=true
		ready_to_heal.emit()
	queue_redraw()
func resolve(accepted: bool) -> void:
	if not accepted:
		cancel(true);return
	pending=false;elapsed=0
	GameAudio.stop_origin(self)
	flash=float(settings.presentation.release_seconds);_cancel_fade=0;_release_pose_allowed=true
	_pose(5);GameAudio.cue_focus(self,&"heal_release")
	queue_redraw()
func _draw() -> void:
	var strength:=.55 if reduced else 1.0
	if elapsed>0 or _cancel_fade>0:
		var progress:=ratio() if elapsed>0 else _last_ratio
		var fade:=1.0 if elapsed>0 else _cancel_fade/float(settings.presentation.cancel_seconds)
		PixelVfx.clip(self,&"focus-gather",Vector2(2,-2),minf(.98,progress),0,Color(1,1,1,fade*strength))
	if flash>0:
		var progress:=1-flash/float(settings.presentation.release_seconds)
		PixelVfx.clip(self,&"focus-restore",Vector2(0,15),progress,0,Color(1,1,1,strength))
