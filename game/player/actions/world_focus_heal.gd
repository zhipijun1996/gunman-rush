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
	elif event is InputEventJoypadButton and event.button_index==int(settings.gamepad_button):
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
	var center:=Vector2(2,-8)
	var count:=int(settings.presentation.particles)/(2 if reduced else 1)
	var strength:=.5 if reduced else 1.0
	if elapsed>0 or _cancel_fade>0:
		var progress:=ratio() if elapsed>0 else _last_ratio
		var fade:=1.0 if elapsed>0 else _cancel_fade/float(settings.presentation.cancel_seconds)
		# Fine inward trails collect into the hands; no enclosing circular outline.
		for i:int in count:
			var travel:=fposmod(progress*2+float(i)/count,1)
			var angle:=float(i)*2.399+travel*.6
			var radius:=lerpf(float(settings.presentation.gather_radius),3,travel)
			var at:=(center+Vector2.from_angle(angle)*Vector2(radius,radius*.7)).round()
			var alpha:=sin(travel*PI)*fade*strength
			var tail:=(at-center).normalized()*lerpf(2,5,progress)
			draw_line(at,at+tail,Color(.61,.76,.71,alpha*.45),1)
			draw_rect(Rect2(at,Vector2(1,2)),Color(.96,.88,.58,alpha))
		var pulse:=(.3+progress*.55)*fade*strength
		for r:int in range(10,1,-2):
			draw_circle(center,float(r),Color(.9,.72,.35,pulse*.035))
		draw_rect(Rect2(center-Vector2(1,2),Vector2(3,4)),Color(1,.94,.73,pulse))
		# A quiet contact glow stays on the sole instead of tinting the screen.
		draw_line(Vector2(-12,18),Vector2(12,18),Color(.9,.76,.44,pulse*.32),1)
	if flash>0:
		var progress:=1-flash/float(settings.presentation.release_seconds)
		var radius:=lerpf(5,float(settings.presentation.release_radius),1-pow(1-progress,3))
		var alpha:=pow(1-progress,2)*strength
		for i:int in 8:
			var angle:=float(i)*TAU/8+.2
			var radial:=Vector2.from_angle(angle)
			var side:=radial.orthogonal()
			var tip:=center+radial*radius
			var base:=center+radial*maxf(3,radius-8)
			draw_colored_polygon(PackedVector2Array([tip,base+side*2,base-radial*4,base-side*2]),Color(.94,.87,.58,alpha))
		for i:int in count:
			var angle:=float(i)*2.399
			var at:=(center+Vector2.from_angle(angle)*(radius+float(i%3)*4)+Vector2(0,-progress*12)).round()
			draw_rect(Rect2(at,Vector2(1,2)),Color(.76,.9,.79,alpha*.8))
