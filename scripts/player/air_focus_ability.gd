class_name AirFocusAbility
extends Node

# Only this active single-player capability owns global time scaling. UI/input
# remain unscaled; gameplay consumes the engine's shared scaled delta.
@export var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			stop()
var tuning: PlayerTuning
var stamina := 0.0
var air_time_used := 0.0
var active := false
var exhausted := false
var _previous_scale := 1.0

func configure(value: PlayerTuning) -> void:
	tuning = value
	reset()

func advance(real_delta: float, grounded: bool, aiming: bool, available: bool = true) -> void:
	if tuning == null or not is_finite(real_delta) or real_delta <= 0.0:
		return
	stamina = clampf(stamina, 0.0, tuning.focus_stamina_capacity)
	if not available or not enabled or not tuning.air_focus_enabled or not tuning.valid_focus_configuration():
		stop()
		return
	if grounded:
		stop()
		air_time_used = 0.0
		stamina = minf(tuning.focus_stamina_capacity, stamina + tuning.focus_stamina_recovery * real_delta)
		if stamina >= tuning.focus_rearm_stamina and stamina > 0.0:
			exhausted = false
		return
	if not aiming or exhausted or stamina <= 0.0 or air_time_used >= tuning.focus_max_air_duration - 1.0e-9:
		stop()
		return
	if not active:
		_previous_scale = Engine.time_scale
		active = true
	Engine.time_scale = _previous_scale * tuning.focus_time_scale
	var used := minf(real_delta, minf(stamina / tuning.focus_stamina_drain, tuning.focus_max_air_duration - air_time_used))
	stamina = maxf(0.0, stamina - used * tuning.focus_stamina_drain)
	air_time_used += used
	if stamina <= 1.0e-9:
		stamina = 0.0
		exhausted = true
		stop()
	elif air_time_used >= tuning.focus_max_air_duration - 1.0e-9:
		stop()

func stop() -> void:
	if active:
		Engine.time_scale = _previous_scale
		active = false

func reset() -> void:
	stop()
	air_time_used = 0.0
	exhausted = false
	stamina = tuning.focus_stamina_capacity if tuning != null else 0.0

func _exit_tree() -> void:
	stop()
