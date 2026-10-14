class_name WeaponDefinition
extends Resource
## One immutable loadout; Lv3 preserves the corresponding Lv2 primary mode.
enum Mode { PULSE, MACHINE, LASER, SHURIKEN, FAN, BOOMERANG, BOMB, MINE, SINGULARITY }
@export var id: StringName = &"pulse_gun"
@export var display_name := "脉冲枪"
@export var tier := 1
@export var branch: StringName = &""
@export var mode: Mode = Mode.PULSE
@export var rounds := 1
@export var interval := 0.11
@export var burst_duration := 0.065
@export var recoil_scale := 0.72
@export var damage := 1.0
@export var projectile_speed := 850.0
@export var range_limit := 420.0
@export var entity_lifetime := 4.0
@export var throw_windup := 0.055
@export var flash_speed := 950.0
@export var flash_duration := 0.085
@export var second_flash_delay := 0.30
@export var second_flash_duration := 0.05
@export var steering_speed := 300.0
@export var steering_focus_drain_ratio := 0.25
@export var return_speed := 1800.0
@export var catch_radius := 24.0
@export var catch_speed := 900.0
@export var fuse_seconds := 0.16
@export var blast_radius := 145.0
@export var blast_speed := 1050.0
@export var hold_seconds := 0.42
@export var attract_radius := 230.0
@export var attract_speed := 210.0
@export var attract_stop_ring := 66.0
@export var attract_limit := 8
@export var beam_duration := 0.60
@export var beam_tick := 0.12
@export var beam_push := 850.0
@export var beam_lift_ratio := 1.04
@export var beam_drain := 13.0
@export var beam_growth := 18.0
@export var skill_name := ""
@export var skill_cost := 60.0
@export var skill_charge := 0.28
@export var skill_multiplier := 1.6
@export var skill_damage := 7.0
@export var skill_rounds := 7
@export var skill_interval := 0.065
@export var skill_cooldown := 2.0
@export var skill_stagger_seconds := 0.12
@export var skill_stagger_cooldown := 0.45
@export var skill_knockback_speed := 500.0
@export var skill_knockback_seconds := 0.10
@export var chain_limit := 3
@export var chain_range := 120.0
func is_valid() -> bool:
	if tier < 1 or tier > 3 or id.is_empty(): return false
	var allowed := {&"pulse_gun":Mode.PULSE,&"triple_machine_gun":Mode.MACHINE,&"shadow_shuriken":Mode.SHURIKEN,&"recoil_bomb":Mode.BOMB,&"sustained_laser":Mode.LASER,&"fan_shuriken":Mode.FAN,&"remote_boomerang":Mode.BOOMERANG,&"magnetic_mine":Mode.MINE,&"collapse_singularity":Mode.SINGULARITY,&"machine_storm":Mode.MACHINE,&"laser_cannon":Mode.LASER,&"blade_bloom":Mode.FAN,&"moon_boomerang":Mode.BOOMERANG,&"magnetic_storm":Mode.MINE,&"star_collapse":Mode.SINGULARITY}
	if not allowed.has(id) or int(allowed[id])!=mode:return false
	for value: float in [interval,burst_duration,recoil_scale,damage,projectile_speed,range_limit,entity_lifetime,flash_speed,flash_duration,second_flash_delay,second_flash_duration,return_speed,catch_radius,blast_radius,hold_seconds,beam_tick,skill_cost]:
		if not is_finite(value) or value <= 0: return false
	for value: float in [throw_windup,steering_speed,steering_focus_drain_ratio,catch_speed,blast_speed,attract_radius,attract_speed,attract_stop_ring,beam_duration,beam_tick,beam_push,beam_drain,beam_growth,beam_lift_ratio,skill_cost,skill_charge,skill_multiplier,skill_damage,skill_interval,skill_cooldown,skill_stagger_seconds,skill_stagger_cooldown,skill_knockback_speed,skill_knockback_seconds,chain_range]:
		if not is_finite(value) or value<=0:return false
	if recoil_scale > 1 or rounds < 1 or attract_limit<1 or attract_limit>16 or skill_rounds<1 or skill_rounds>12 or chain_limit<0 or chain_limit>8:return false
	var required_tier := 3 if not skill_name.is_empty() else 1 if mode in [Mode.PULSE,Mode.SHURIKEN,Mode.BOMB] else 2
	if tier!=required_tier or rounds!=(3 if mode==Mode.MACHINE else 1):return false
	if tier == 3 and skill_name.is_empty(): return false
	if tier == 1: return branch.is_empty() and mode in [Mode.PULSE,Mode.SHURIKEN,Mode.BOMB]
	return (mode in [Mode.MACHINE,Mode.LASER,Mode.FAN,Mode.BOOMERANG,Mode.MINE,Mode.SINGULARITY]) and not branch.is_empty()
