class_name ActionResources
extends Node

var tuning: PlayerTuning
var shot_charges := 0
var pending_ground_shots := 0
var _flight_cap := 0

func reset() -> void:
	_flight_cap = tuning.max_air_shots
	shot_charges = _flight_cap
	pending_ground_shots = 0

func advance(grounded: bool) -> void:
	_flight_cap = tuning.max_air_shots if grounded else mini(_flight_cap, tuning.max_air_shots)
	shot_charges = mini(shot_charges, _flight_cap)

func try_consume_shot(grounded: bool) -> bool:
	if tuning.max_air_shots <= 0 or shot_charges <= 0:
		return false
	if grounded:
		pending_ground_shots += 1
	else:
		shot_charges -= 1
	return true

func finish_frame(grounded: bool, started_grounded: bool) -> void:
	if grounded:
		reset()
	elif started_grounded:
		shot_charges = maxi(0, mini(shot_charges, tuning.max_air_shots) - pending_ground_shots)
		pending_ground_shots = 0

func grant_shot(amount: int) -> int:
	var granted := mini(maxi(0, amount), maxi(0, mini(_flight_cap, tuning.max_air_shots) - shot_charges))
	shot_charges += granted
	return granted

func can_grant_shot() -> bool:
	return shot_charges < mini(_flight_cap, tuning.max_air_shots)
