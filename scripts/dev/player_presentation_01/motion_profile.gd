class_name PlayerMotionCandidateProfile
extends Resource
## Task-only cosmetic parameters. No input, Motor, resources or weapon settings.
@export_range(1, 12) var idle_fps := 4.0
@export_range(1, 16) var fall_fps := 8.0
@export_range(24, 160) var gait_cycle_distance := 96.0
@export_range(0.05, 0.6) var takeoff_seconds := 0.22
@export_range(0.05, 0.6) var landing_seconds := 0.32
@export_range(0, 16) var takeoff_particles := 6
@export_range(0, 24) var landing_particles := 10
@export_range(0, 48) var particle_cap := 32
@export_range(20, 60) var dust_spread_speed := 28.0
@export_range(20, 70) var dust_lift_speed := 32.0
@export_range(1, 3) var dust_particle_size := 1.5
@export var dust_color := Color("dccb9e")

func valid() -> bool:
	return is_finite(idle_fps) and idle_fps >= 1 and idle_fps <= 12 and is_finite(fall_fps) and fall_fps >= 1 and fall_fps <= 16 and is_finite(gait_cycle_distance) and gait_cycle_distance >= 24 and gait_cycle_distance <= 160 and is_finite(takeoff_seconds) and takeoff_seconds >= 0.05 and takeoff_seconds <= 0.6 and is_finite(landing_seconds) and landing_seconds >= 0.05 and landing_seconds <= 0.6 and takeoff_particles >= 0 and takeoff_particles <= 16 and landing_particles >= 0 and landing_particles <= 24 and particle_cap >= 0 and particle_cap <= 48 and is_finite(dust_spread_speed) and dust_spread_speed >= 20 and dust_spread_speed <= 60 and is_finite(dust_lift_speed) and dust_lift_speed >= 20 and dust_lift_speed <= 70 and is_finite(dust_particle_size) and dust_particle_size >= 1 and dust_particle_size <= 3 and dust_color.is_equal_approx(dust_color.clamp())
