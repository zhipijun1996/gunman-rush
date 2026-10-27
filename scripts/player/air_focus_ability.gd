class_name AirFocusAbility
extends Node

signal active_changed(value: bool)

# Only this active single-player capability owns global time scaling. UI/input
# remain unscaled; gameplay consumes the engine's shared scaled delta.
@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			stop()
var tuning: PlayerTuning
var stamina_state := StaminaState.new()
var stamina: float:
	get: return stamina_state.current
var air_time_used := 0.0
var active := false:
	set(value):
		if active != value:
			active = value
			active_changed.emit(value)
var exhausted := false
var _previous_scale := 1.0
# The equipped item runtime may refine world speed. Zero requests a frozen
# world scope; Engine.time_scale itself always remains positive for player/UI.
var world_scale_resolver: Callable
var world_freeze_callback: Callable

func configure(value: PlayerTuning, resource: StaminaState = null) -> void:
	stop()
	tuning = value
	if resource != null:
		stamina_state = resource
	reset()

func advance(real_delta: float, grounded: bool, aiming: bool, available: bool = true, sustained: bool = false, drain_ratio: float = 1.0) -> void:
	if tuning == null or not is_finite(real_delta) or real_delta <= 0.0:
		return
	if not available or not enabled or not tuning.air_focus_enabled or not tuning.valid_focus_configuration():
		stop()
		return
	if grounded:
		stop()
		air_time_used = 0.0
		stamina_state.grant_continuous(tuning.focus_stamina_recovery * real_delta, stamina_state.epoch)
		if stamina >= tuning.focus_rearm_stamina and stamina > 0.0:
			exhausted = false
		return
	if not aiming or exhausted or stamina <= 0.0 or (not sustained and air_time_used >= tuning.focus_max_air_duration - 1.0e-9):
		stop()
		return
	if not active:
		_previous_scale = Engine.time_scale
		active = true
	var world_scale := tuning.focus_time_scale
	if world_scale_resolver.is_valid():
		var candidate: Variant = world_scale_resolver.call(world_scale)
		if (candidate is float or candidate is int) and is_finite(float(candidate)) and float(candidate) >= 0.0 and float(candidate) <= 1.0:
			world_scale = float(candidate)
	if world_freeze_callback.is_valid(): world_freeze_callback.call(is_zero_approx(world_scale))
	Engine.time_scale = _previous_scale * (1.0 if is_zero_approx(world_scale) else world_scale)
	var drain := tuning.focus_stamina_drain*clampf(drain_ratio,.01,1.0)
	var time_left := real_delta if sustained else maxf(0,tuning.focus_max_air_duration-air_time_used)
	var used := minf(real_delta,minf(stamina/drain,time_left))
	stamina_state.consume_continuous(minf(stamina, used * drain), stamina_state.epoch)
	air_time_used += used
	if stamina <= 1.0e-9:
		exhausted = true
		stop()
	elif (not sustained and air_time_used >= tuning.focus_max_air_duration - 1.0e-9):
		stop()

func stop() -> void:
	if world_freeze_callback.is_valid(): world_freeze_callback.call(false)
	if active:
		Engine.time_scale = _previous_scale
		active = false

func reset() -> void:
	stop()
	air_time_used = 0.0
	exhausted = false
	if tuning != null:
		stamina_state.configure(StaminaDefinition.from_focus_prototype(tuning))

func _exit_tree() -> void:
	stop()
