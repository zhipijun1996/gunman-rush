class_name BossDuelDefinition
extends ThornForestDefinition
## Isolated prototype configuration. V1 resources never load this class.
@export var arena_size := Vector2(1000, 520)
@export var entrance_gap := 24.0
@export var entrance_overlap := 48.0
@export var floor_depth := 36.0
@export var canopy_depth := 18.0
@export var safe_inset := 70.0
@export var player_half_height := 18.0
@export var branch_offset := Vector2(230, -70)
@export var branch_size := Vector2(140, 18)
@export var counter_offset := Vector2(0, -140)
@export var counter_size := Vector2(300, 18)
@export var counter_stand_offset := Vector2(85, -158)
@export var boss_offset := Vector2(0, -188)
@export var inner_hook_offset := Vector2(65, -185)
@export var return_hook_offset := Vector2(230, -115)
@export var slam_timeout := 1.5
@export var pursuit_gravity := 1400.0
@export var pursuit_flight_seconds := 0.72
@export var landing_recovery_seconds := 0.7
@export var bell_enabled := true
@export var bell_radius := 24.0
@export var bell_hold_offset := Vector2(66, -48)
@export var bell_warning_seconds := 0.8
@export var bell_outbound_seconds := 0.9
@export var bell_gravity := 700.0
@export var bell_return_speed := 320.0
@export var bell_restitution := 0.72
@export var bell_max_bounces := 2
@export var bell_lifetime := 4.0
@export var bell_escape_clearance := 4.0
@export var bell_motion_safe_margin := 1.0
@export var bell_contact_rebound_seconds := 0.20
@export var bell_counter_enabled := true
@export var bell_counter_damage := 4.0
@export var bell_counter_speed := 460.0
@export var bell_counter_max_flight := 1.1
@export var bell_counter_stagger_seconds := 0.8
@export var phase2_health_ratio := 0.4
@export var phase2_overlap_seconds := 0.25
func is_valid() -> bool:
	if not super.is_valid() or queen: return false
	for value: float in [arena_size.x,arena_size.y,entrance_gap,entrance_overlap,floor_depth,canopy_depth,safe_inset,player_half_height,branch_size.x,branch_size.y,counter_size.x,counter_size.y,slam_timeout,pursuit_gravity,pursuit_flight_seconds,landing_recovery_seconds,bell_radius,bell_warning_seconds,bell_outbound_seconds,bell_gravity,bell_return_speed,bell_restitution,bell_lifetime,bell_escape_clearance,bell_motion_safe_margin,bell_contact_rebound_seconds,bell_counter_damage,bell_counter_speed,bell_counter_max_flight,bell_counter_stagger_seconds,phase2_health_ratio,phase2_overlap_seconds]:
		if not is_finite(value) or value <= 0: return false
	return phase2_health_ratio < 1 and bell_hold_offset.is_finite() and bell_hold_offset.x > collision_size.x*.5+bell_radius and bell_max_bounces > 0 and bell_restitution <= 1 and counter_size.x < branch_offset.x * 2.0 - branch_size.x
