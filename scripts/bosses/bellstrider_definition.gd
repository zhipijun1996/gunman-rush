class_name BellstriderDefinition
extends WindkeeperDefinition
## Live Bellstrider tuning. Player motion and weapon resources are not modified.
@export var selection_seed := 412783
@export var phase_two_charge_speed := 420.0
@export var roll_acceleration_seconds := 0.22
@export var roll_max_seconds := 1.35
@export var roll_warning_seconds := 0.85
@export var minimum_roll_start_distance := 136.0
@export var minimum_roll_travel := 140.0
@export var combo_brake_seconds := 0.24
@export var combo_turn_seconds := 0.22
@export var combo_warning_seconds := 0.48
@export var return_roll_chance := 0.55
@export var ring_speed := 280.0
@export var ring_radius := 10.0
@export var ring_warning_seconds := 0.7
@export var ring_interval_seconds := 0.62
@export var ring_settle_seconds := 0.2
@export var ring_lifetime := 2.8
@export var lob_aim_seconds := 0.65
@export var lob_lock_seconds := 0.35
@export var lob_flight_seconds := 1.65
@export var lob_lower_flight_seconds := 1.9
@export var lob_gravity := 860.0
@export var lob_followup_seconds := 0.25
@export var lob_impact_radius := 40.0
@export var lob_impact_seconds := 0.2
@export var observe_seconds := 0.25
@export var approach_seconds := 0.65
@export var approach_distance := 480.0
@export var near_distance := 200.0
@export var elevated_height := 76.0
@export var camping_seconds := 1.8
@export var camping_radius := 44.0
@export var max_group_repeats := 2
@export var recent_group_penalty := 0.48
@export var death_seconds := 1.8
@export var reward_impact_seconds := 1.05
# Coins consume the existing reward/epoch chain; this resource owns the amount.
@export var reward_coin_total := 12
@export var reward_large_coin_value := 5
@export var reward_pickup_lock_seconds := 0.35


func is_valid() -> bool:
	if not super.is_valid():
		return false
	for number: float in [
		phase_two_charge_speed,
		roll_acceleration_seconds,
		roll_max_seconds,
		roll_warning_seconds,
		minimum_roll_start_distance,
		minimum_roll_travel,
		combo_brake_seconds,
		combo_turn_seconds,
		combo_warning_seconds,
		ring_speed,
		ring_radius,
		ring_warning_seconds,
		ring_interval_seconds,
		ring_settle_seconds,
		ring_lifetime,
		lob_aim_seconds,
		lob_lock_seconds,
		lob_flight_seconds,
		lob_lower_flight_seconds,
		lob_gravity,
		lob_followup_seconds,
		lob_impact_radius,
		lob_impact_seconds,
		observe_seconds,
		approach_seconds,
		approach_distance,
		near_distance,
		elevated_height,
		camping_seconds,
		camping_radius,
		death_seconds,
		reward_impact_seconds,
		reward_pickup_lock_seconds
	]:
		if not is_finite(number) or number <= 0.0:
			return false
	return (
		return_roll_chance >= 0.0
		and return_roll_chance <= 1.0
		and recent_group_penalty > 0.0
		and recent_group_penalty <= 1.0
		and max_group_repeats >= 1
		and death_seconds >= reward_impact_seconds
		and lob_lower_flight_seconds >= lob_flight_seconds
		and reward_coin_total >= 0
		and reward_large_coin_value == 5
	)
