class_name PlainsRevisionPose
extends RefCounted
## A draw-local snapshot. Float properties retain GDScript's 64-bit arithmetic.
## Raw fields are distinct: Ground vitality and Flora intentionally clamp at
## different points. Never cache by Dictionary identity across draws.
var clock: float
var stride: float
var travel: float
var raw_load: float
var raw_strike: float
var load: float
var strike: float
var recovery: float
var hurt: float
var raw_turn: float
var turn: float
var air: bool
var vertical: float
var dead: bool
var raw_death: float
var death: float
var drive: float
var appendage_follow: float
var aim: float
var death_clock: float
var landing: float
var live: PlainsRevisionPose

static func prepare(values: Dictionary) -> PlainsRevisionPose:
	var result := PlainsRevisionPose.new()
	result.clock = float(values.get("clock", 0.0))
	result.stride = float(values.get("stride", 0.0))
	result.travel = clampf(float(values.get("travel", 0.0)), 0.0, 1.0)
	result.raw_load = float(values.get("load", 0.0))
	result.raw_strike = float(values.get("strike", 0.0))
	result.load = clampf(result.raw_load, 0.0, 1.0)
	result.strike = clampf(result.raw_strike, 0.0, 1.0)
	result.recovery = clampf(float(values.get("recovery", 0.0)), 0.0, 1.0)
	result.hurt = clampf(float(values.get("hurt", 0.0)), 0.0, 1.0)
	result.raw_turn = float(values.get("turn", 0.0))
	result.turn = clampf(result.raw_turn, -1.0, 1.0)
	result.air = bool(values.get("air", false))
	result.vertical = float(values.get("vertical", 0.0))
	result.dead = bool(values.get("dead", false))
	result.raw_death = float(values.get("death", 0.0))
	result.death = clampf(result.raw_death, 0.0, 1.0)
	result.drive = clampf(float(values.get("drive", 0.0)), -1.0, 1.0)
	result.appendage_follow = clampf(float(values.get("appendage_follow", result.travel)), 0.0, 1.0)
	result.aim = float(values.get("aim", 0.0))
	result.death_clock = float(values.get("death_clock", 0.0))
	result.landing = float(values.get("landing", 0.0))
	if result.dead:
		var captured := values.duplicate()
		captured["dead"] = false
		result.live = prepare(captured)
	return result
