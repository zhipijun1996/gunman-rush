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
@export var dust_color := Color("afaf84")

func valid() -> bool:
	return is_finite(idle_fps) and idle_fps >= 1 and idle_fps <= 12 and is_finite(fall_fps) and fall_fps >= 1 and fall_fps <= 16 and is_finite(gait_cycle_distance) and gait_cycle_distance >= 24 and gait_cycle_distance <= 160 and is_finite(takeoff_seconds) and takeoff_seconds >= 0.05 and takeoff_seconds <= 0.6 and is_finite(landing_seconds) and landing_seconds >= 0.05 and landing_seconds <= 0.6 and takeoff_particles >= 0 and takeoff_particles <= 16 and landing_particles >= 0 and landing_particles <= 24 and particle_cap >= 0 and particle_cap <= 48 and dust_color.is_equal_approx(dust_color.clamp())
