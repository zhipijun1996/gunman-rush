class_name WeaponMotionDefinition
extends Resource
## Shared motion budget; actual base distance comes only from the current PlayerTuning.
@export var lv2_total_ratio := 1.5
@export var secondary_ratio := 0.5
@export var blink_pause_seconds := 0.075
@export var apex_hold_seconds := 0.075
@export var apex_blend_seconds := 0.14
func base_distance(tuning: PlayerTuning, grounded: bool) -> float:
	return tuning.shot_burst_speed*tuning.shot_burst_duration*(tuning.ground_recoil_multiplier if grounded else 1.0)
