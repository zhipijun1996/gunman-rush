class_name WindkeeperPressureDefinition
extends WindkeeperDefinition
## Single tuning owner for the active six-move formal Windkeeper.
@export var selection_seed := 771903
@export var approach_speed := 240.0
@export var lunge_peak_speed := 1320.0
@export var final_chase_speed := 260.0
@export var ground_wave_speed := 300.0
@export var approach_range := 270.0
@export var close_range := 175.0
@export var sweep_approach_range := 130.0
@export var approach_bound_seconds := .65
@export var turn_seconds := .44
@export var wall_clearance := 182.0
@export var retreat_trigger_range := 105.0
@export var boundary_retreat_range := 72.0
@export var phase_three_jump_height_scale := 1.35
@export var retreat_distance := 175.0
@export var retreat_seconds := .48
@export var retreat_warning_seconds := .18
@export var retreat_cooldown_seconds := 2.2
@export var retreat_height := 58.0
@export var blocked_seconds := .16
@export var traverse_warning_seconds := .32
@export var normal_warning_seconds := .60
@export var sweep_warning_seconds := .72
@export var platform_warning_seconds := .78
@export var combo_link_seconds := .26
@export var group_recovery_seconds := 1.30
@export var lunge_seconds := .54
@export var lunge_height := 160.0
@export var lunge_warning_seconds := .42
@export var lunge_min_distance := 240.0
@export var lunge_max_distance := 360.0
@export var lunge_landing_offset := 60.0
@export var support_hop_height := 72.0
@export var stomp_seconds := .28
@export var sweep_seconds := .42
@export var gust_seconds := .46
@export var gust_volley_fractions: Array[float] = [.28, .66]
@export var seeds_seconds := .22
@export var platform_seconds := .38
@export var seed_speed := 300.0
@export var seed_spread := .24
@export var wind_pressure_speed := 76.0
@export var wind_pressure_range := 410.0
@export var wind_pressure_height := 210.0
@export var wind_pressure_phase_two_height := 300.0
@export var wave_radius := 9.0
@export var camping_seconds := 1.6
@export var camping_radius := 42.0
@export var recent_group_penalty := .42
@export var maximum_group_repeats := 2
@export var death_seconds := 1.9
@export var death_impact_seconds := 1.05
@export var death_fall_gravity := 900.0
@export var reward_coin_total := 20

func is_valid() -> bool:
	if not super.is_valid() or not continuous_combat: return false
	for value: float in [approach_speed,lunge_peak_speed,final_chase_speed,ground_wave_speed,
		wall_clearance,boundary_retreat_range,phase_three_jump_height_scale,retreat_trigger_range,retreat_distance,retreat_seconds,retreat_warning_seconds,retreat_cooldown_seconds,retreat_height,blocked_seconds,
		approach_range,close_range,sweep_approach_range,approach_bound_seconds,turn_seconds,traverse_warning_seconds,normal_warning_seconds,
		sweep_warning_seconds,platform_warning_seconds,combo_link_seconds,group_recovery_seconds,
		lunge_seconds,lunge_height,lunge_warning_seconds,lunge_min_distance,lunge_max_distance,lunge_landing_offset,support_hop_height,stomp_seconds,sweep_seconds,gust_seconds,seeds_seconds,
		platform_seconds,seed_speed,seed_spread,wind_pressure_speed,wind_pressure_range,
		wind_pressure_height,wind_pressure_phase_two_height,wave_radius,camping_seconds,camping_radius,death_seconds,death_impact_seconds,death_fall_gravity]:
		if not is_finite(value) or value <= 0: return false
	var previous := 0.0
	for fraction: float in gust_volley_fractions:
		if not is_finite(fraction) or fraction <= previous or fraction >= 1.0: return false
		previous = fraction
	return lunge_min_distance <= lunge_max_distance and lunge_max_distance*1.5/lunge_seconds <= lunge_peak_speed and not gust_volley_fractions.is_empty() and sweep_approach_range < close_range and close_range < approach_range and wind_pressure_speed <= 80.0 and recent_group_penalty > 0.0 and recent_group_penalty <= 1.0 and maximum_group_repeats >= 1 and death_impact_seconds < death_seconds and reward_coin_total >= 0
