class_name PlayerActionResourceView
extends RefCounted

# Compatibility view, not a second owner of jump or shot counters.
var _jump: JumpAbility
var _shots: ActionResources

func bind(jump: JumpAbility, shots: ActionResources) -> void:
	_jump = jump
	_shots = shots

func snapshot() -> ActionResourceSnapshot:
	var result := ActionResourceSnapshot.new()
	result.jumps_used = _jump.used_jumps
	result.jump_limit = _jump.tuning.max_jumps
	result.jump_enabled = _jump.enabled
	result.shots_remaining = _shots.shot_charges
	result.shot_limit = _shots.tuning.max_air_shots
	result.pending_ground_shots = _shots.pending_ground_shots
	return result
