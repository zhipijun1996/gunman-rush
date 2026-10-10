class_name BossAttackPattern
extends RefCounted

var telegraphing := false
var warning_progress := 0.0
var _clock := 0.0
var _interval := 0.0
var _warning := 0.0

func configure(definition: BossDefinition, phase: int) -> void:
	_interval = definition.attack_interval * (definition.phase_two_interval_scale if phase == 2 else 1.0)
	_warning = definition.telegraph_duration
	cancel()

func cancel() -> void:
	_clock = 0.0
	telegraphing = false
	warning_progress = 0.0

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	_clock += delta
	if not telegraphing:
		if _clock >= _interval:
			_clock = 0.0
			telegraphing = true
		return false
	warning_progress = clampf(_clock / _warning, 0.0, 1.0)
	if _clock < _warning:
		return false
	cancel()
	return true
